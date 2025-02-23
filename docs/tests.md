# Available Tests

- **smoke_test**: Basic sanity checks for the kernel (e.g., version, module loading, lightweight stress test).

Users can refer to this to populate test_config.txt.

Test scripts are located in `host_drive/tests/` on the host and are mounted to `/home/user/host_drive/tests` in the VM. Run them manually via `003_run_tests.sh` or automatically using `002_launch_vm.sh --run-tests`.
