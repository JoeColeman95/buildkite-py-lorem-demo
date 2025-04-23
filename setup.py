from setuptools import setup

setup(name='py-lorem',
    version='1.0',
    description='Generate mock sentences/paragraphs with the Lorem Ipsum prose',
    url='https://github.com/nubela/py-lorem',
    author='nubela',
    author_email='nubela@gmail.com',
    license='MIT',
    packages=['loremipsum'],
    package_data={
        'loremipsum': ['loremipsum.txt'],
    },
    include_package_data=True,
    zip_safe=False)