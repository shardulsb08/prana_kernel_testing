Name: dummy-kernel-headers
Version: 6.14.0
Release: 1
Summary: Dummy kernel headers to satisfy dependencies
License: GPL
Provides: kernel-headers = %{version}-%{release}
BuildArch: noarch

%description
Dummy package to provide kernel-headers for custom kernel 6.14.0.

%install
# No files to install, just providing metadata

%files
# Empty
