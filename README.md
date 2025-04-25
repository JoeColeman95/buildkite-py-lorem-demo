# Buildkite Pipeline Demo

This repository demonstrates a Buildkite pipeline for a Python Lorem Ipsum generator.

## Pipeline Features

- Runs Python code in Docker containers
- Generates lorem ipsum sentences and paragraphs
- Uses Buildkite annotations to display results
- Uploads and downloads artifacts
- Builds and pushes a Docker image to Buildkite Package Registry

## Structure

- `.buildkite/pipeline.yml` - Main pipeline configuration
- `.buildkite/assets/scripts/` - Supporting scripts
- `.buildkite/assets/docker/` - Dockerfile for hello-world image

## Running the Pipeline

1. Set up a Buildkite agent with the `BUILDKITE_CHALLENGEBUILD_REGISTRY_TOKEN` set via environment hook
2. Trigger the pipeline through Buildkite UI
3. Use the block step to optionally build and push the Docker image

## Considerations

This pipeline currently has retry logic as a bug was identified with the suggested py-lorem module where you would occasionaly not get 20 characters due to the `+ "."`  within `loremipsum/action.py`. As such, to avoid scope creep I have added a workaround to the pipeline to take this into account and retry up to 3 times if the output is not exactly 20 chars. If we do not succeed in the alloted retries, the behaviour is expected to be a fail via exit 1.

This was originally developed for MacOS, however, due to issues with MacOS and Docker, this moved to a Linux EC2.


# py-lorem

Lorem Ipsum library for Python

## Install

    pip install py-lorem

## Usage

    ```python
    import loremipsum

    # generate a random sentence of max 20 chars
    loremipsum.sentence(max_char=20)

    # generate a random sentence of arbitrary length
    loremipsum.sentence()

    # generate a random paragraph of max 100 chars
    loremipsum.paragraph(max_char=100)

    # generate a random paragraph of arbitrary length
    loremipsum.paragraph()
    ```

## License

The license for this is to of do-whatever-the-hell-you-want-with-it :)

## Author


nubela (nubela@gmail.com)
