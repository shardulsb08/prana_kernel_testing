docker build -t kernel-builder-fedora .

docker run --rm -v $(pwd)/out:/build/out kernel-builder-fedora
