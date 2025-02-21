docker build -t kernel-builder .

docker run --rm -v $(pwd)/out:/build/out kernel-builder
