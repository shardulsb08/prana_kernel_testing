# To use latest bpf features, it is better to build the kernel using the latest llvm.

mkdir -p brf/deps
cd brf/deps

git clone --branch llvmorg-17.0.6 https://github.com/llvm/llvm-project.git
mkdir llvm-project/build; cd llvm-project/build
cmake ../llvm -DLLVM_TARGETS_TO_BUILD="BPF;X86" \
    -DLLVM_ENABLE_PROJECTS=clang \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_BUILD_RUNTIME=OFF
make

echo "PATH="/build/brf/deps/llvm-project/build/bin:$PATH"" >> ~/.bashrc
echo "export PATH" >> ~/.bashrc


# Pahole
# sudo dnf -y install elfutils-devel elfutils-libs elfutils-libelf
# git clone --branch v1.24 https://github.com/acmel/dwarves.git
mkdir dwarves/build; cd dwarves/build
cmake ../
make
sudo make install

libbpf:
git clone https://github.com/libbpf/libbpf.git
