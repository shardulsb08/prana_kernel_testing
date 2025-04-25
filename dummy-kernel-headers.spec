Name:           dummy-kernel-headers
Version:        0.0.0
Release:        1%{?dist}
Summary:        Dummy kernel headers package for testing
Provides:       kernel-headers = %{version}-%{release}

License:        GPL-2.0
URL:            https://github.com/shardulsb08/prana_kernel_testing

BuildArch:      noarch

%description
This is a dummy package that provides kernel-headers to prevent conflicts
with the system package during kernel testing.

Note: The Version field is automatically updated to match the currently
built kernel version during installation.

%prep
# Nothing to do

%build
# Nothing to do

%install
# Create directories
mkdir -p %{buildroot}/usr/include

%files
%dir /usr/include

%changelog
* Thu Apr 25 2024 Shardul <shardul@example.com> - 0.0.0-1
- Initial package for kernel testing
- Version is dynamically updated during installation
