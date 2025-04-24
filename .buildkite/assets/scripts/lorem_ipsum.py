#!/usr/bin/env python3

import os
import sys
import importlib.util
import subprocess

def find_repo_root():
    """Find the repository root directory"""
    # First check if we're in a Docker container with a specific mount point
    if os.environ.get("BUILDKITE_PLUGIN_NAME") == "DOCKER":
        # Use the known mount point from pipeline.yml
        print("[INFO] Running in Docker container, using configured mount point")
        return "/buildkite-py-lorem-demo"

    # For local development, find repository markers
    current_dir = os.path.dirname(os.path.abspath(__file__))

    start_dir = current_dir

    max_levels = 5  # Safety limit to prevent traversal through time and space...
    levels = 0

    while current_dir != "/" and levels < max_levels:
        # Check for known directories or files indicate root of the repo
        if (os.path.exists(os.path.join(current_dir, ".buildkite")) or
            os.path.basename(current_dir) == "buildkite-py-lorem-demo"):
            print(f"[INFO] Found repository root at: {current_dir}")
            return current_dir

        # Go up one directory
        current_dir = os.path.dirname(current_dir)
        levels += 1

    # If we couldn't find a repo root, use the working directory
    #! N.B. May be better to exit with an error, continuing due to time constraints

    print("[WARNING] Could not determine repository root within safe bounds")
    print(f"[WARNING] Using current working directory: {os.getcwd()}")
    return os.getcwd()

def is_package_installed():
    """Check if loremipsum is installed correctly, if not, install from local"""
    try:
        # Check if the package is already installed and is working
        import loremipsum
        test = loremipsum.sentence()
        print("[INFO] Py-Lorem package already installed and working correctly")
        return True
    except (ImportError, FileNotFoundError) as e:
        print(f"[INFO] Py-Lorem package not installed or not working correctly: {str(e)}")

        # Install the package from local repository
        print("[INFO] Installing Py-Lorem package...")

        # Get the repository root first
        repo_root = find_repo_root()
        print(f"[INFO] Found repository root at: {repo_root}")

        # Verify the repository structure
        loremipsum_dir = os.path.join(repo_root, "loremipsum")
        setup_file = os.path.join(repo_root, "setup.py")

        if not os.path.exists(loremipsum_dir):
            print(f"[ERROR] loremipsum directory not found at {loremipsum_dir}")
            sys.exit(1)

        if not os.path.exists(setup_file):
            print(f"[ERROR] setup.py not found at {setup_file}")
            sys.exit(1)

        # Uninstall existing package if present
        subprocess.call([sys.executable, "-m", "pip", "uninstall", "--user", "-y", "py-lorem"])

        # Install package from the repository root where setup.py is located
        subprocess.check_call([sys.executable, "-m", "pip", "install", "--user", repo_root])
        print("[INFO] Local Py-Lorem package installed successfully")
        return False

def ensure_directory(directory):
    """Create directory if it doesn't exist"""
    if not os.path.exists(directory):
        os.makedirs(directory)

def validate_env_var(var_name):
    """Validate that an environment variable exists and has a value"""
    if var_name not in os.environ:
        print(f"[ERROR] Required environment variable {var_name} is not set.")
        sys.exit(1)

    if not os.environ[var_name]:
        print(f"[ERROR] Environment variable {var_name} is empty.")
        sys.exit(1)

def get_max_char_env_var(var_name):
    """Get and validate max_char environment variable"""
    validate_env_var(var_name)

    try:
        max_char = int(os.environ[var_name])
        if max_char <= 0:
            print(f"[ERROR] {var_name} must have a value of 1 or more.")
            sys.exit(1)
        return max_char
    except ValueError:
        print(f"[ERROR] {var_name} must be an integer.")
        sys.exit(1)


def generate_sentence():
    """Generate a sentence with exactly the specified number of characters"""
    max_char = get_max_char_env_var("SENTENCE_MAX_CHAR")
    print(f"[INFO] Generating sentence with exactly {max_char} chars")

    #! N.B. This is a workaround for the issue with the package sometimes returning 21 chars due to + "."
    #! I could've fixed the package but assumed that was out of scope for this task
    #! I will be using a loop to retry generating the sentence as a workaround
    #! But will also allow failure if it doesn't work after 3 attempts as a resonable limit

    max_attempts = 3
    for attempt in range(1, max_attempts + 1):
        sentence = loremipsum.sentence(max_char=max_char)
        actual_length = len(sentence)

        if actual_length == max_char:
            print(f"[INFO] Successfully generated sentence with exactly {max_char} chars (attempt {attempt})")

            ensure_directory("./assets/artifacts")

            with open("./assets/artifacts/result.txt", "w") as f:
                f.write(sentence)

            print(f"[INFO] Generated sentence: {sentence}")
            print(f"[INFO] Character count: {len(sentence)}")
            return sentence
        else:
            print(f"[WARNING] Attempt {attempt}/{max_attempts}: Generated {actual_length} chars instead of {max_char}, regenerating...")

    # Well, we tried... error thrown after 3 unsuccessful attempts of generating the sentence at exact length
    print(f"[ERROR] Failed to generate exact length of {max_char} characters after {max_attempts} attempts")
    print(f"[ERROR] Last attempt produced: {sentence} ({len(sentence)} chars)")
    sys.exit(1)

def generate_paragraph():
    """Generate a paragraph with exactly the specified number of characters"""
    max_char = get_max_char_env_var("PARAGRAPH_MAX_CHAR")
    print(f"[INFO] Generating paragraph with exactly {max_char} chars")

    #! N.B. I can likely strip the retry logic from this function
    #! But I will leave it in for consistency with the sentence generation

    max_attempts = 3
    for attempt in range(1, max_attempts + 1):
        paragraph = loremipsum.paragraph(max_char=max_char)
        actual_length = len(paragraph)

        if actual_length == max_char:
            print(f"[INFO] Successfully generated paragraph with exactly {max_char} chars (attempt {attempt})")

            ensure_directory("./assets/artifacts")

            with open("./assets/artifacts/result2.txt", "w") as f:
                f.write(paragraph)

            print(f"[INFO] Generated paragraph: {paragraph}")
            print(f"[INFO] Character count: {len(paragraph)}")
            return paragraph
        else:
            print(f"[WARNING] Attempt {attempt}/{max_attempts}: Generated {actual_length} chars instead of {max_char}, regenerating...")

    # Well, we tried... error thrown after 3 unsuccessful attempts of generating the paragraph at exact length
    print(f"[ERROR] Failed to generate exact length of {max_char} characters after {max_attempts} attempts")
    print(f"[ERROR] Last attempt produced: {paragraph} ({len(paragraph)} chars)")
    sys.exit(1)

def annotate_result(file_path):
    """Annotate the result in Buildkite if ANNOTATE env var is 'true'"""
    # If the env var for annotate is not set, default to false
    annotate = os.environ.get("ANNOTATE", "false")

    if annotate.lower() == "true":
        print("[INFO] Running buildkite-agent annotation...")
        try:
            # Run annotate command
            cmd = f"buildkite-agent annotate '$(cat {file_path})' --style info"
            subprocess.run(cmd, shell=True, check=True)
            print("[INFO] Successfully added annotation")
        except subprocess.CalledProcessError as e:
            print(f"[WARNING] Failed to run annotation command: {e}")

if __name__ == "__main__":

    # Ensure pre-requisites are met
    is_package_installed()
    import loremipsum
    validate_env_var("LOREMIPSUM_ACTION")
    action = os.environ["LOREMIPSUM_ACTION"].upper()

    if action == "SENTENCE":
        generate_sentence()
        annotate_result("./assets/artifacts/result.txt")
    elif action == "PARAGRAPH":
        generate_paragraph()
        annotate_result("./assets/artifacts/result2.txt")
    else:
        print(f"[ERROR] Unknown action: {action}")
        print("[ERROR] LOREMIPSUM_ACTION currently supports SENTENCE or PARAGRAPH")
        sys.exit(1)