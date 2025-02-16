This project mainly intends to download the required kernel release (Mainline stable kernel by default) and run certain tests on it. The goal is to add as many tests as possible and depen on what utility they serve me.

Current way to run it:
./run_build.sh

Compiled image is stored in out/ directory.

The ./load_kernel.sh script tries to isntall the kernel in QEMU VM.
Fedora default credentails:
uname: user
passwd: fedora

Access it via:
ssh -p 2222 user@localhost
