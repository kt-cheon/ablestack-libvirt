Name:           libvirt
Version:        10.5.0
Release:        1.ablestack
Summary:        libvirt with ABLestack customization
License:        LGPL-2.1-or-later
URL:            https://libvirt.org/
Source0:        %{name}-%{version}.tar.gz
Patch0:         0001-ablestack-customization.patch

BuildRequires:  gcc
BuildRequires:  make
BuildRequires:  pkgconfig
BuildRequires:  libtool
BuildRequires:  autoconf
BuildRequires:  automake

%description
libvirt package customized for ABLestack deployments.
This spec is intentionally kept in Git, while the upstream SRPM is downloaded on demand and not tracked by version control.

%prep
%autosetup -p1

%build
%configure
%make_build

%install
%make_install

%files
%doc README
%{_bindir}/*
%{_libdir}/*

%changelog
* Mon Sep 29 2026 - ABLestack Team <support@ablestack.io> - 10.5.0-1.ablestack
- Initial ABLestack customization
