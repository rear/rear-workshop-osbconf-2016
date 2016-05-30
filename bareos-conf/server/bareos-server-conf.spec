%define		rpmrelease %{nil}

Name:		bareos-server-conf	
Version:	1.0
Release:	1%{?dist}
Summary:	Bareos server configuration files	

Group:		Applications/File
License:	GPLv3
URL:		https://github.com/rear/rear-workshop-osbconf-2016
Source0:	https://build.opensuse.org/package/show/home:gdha/bareos-server-conf/bareos-server-conf.tar.gz
BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-XXXXXX)

#BuildRequires:	bareos-dir	
#Requires:	

%description
Bareos server configuration files used during the workshop of rear DR exercise
with Bareos and rear

%prep
%setup 


%build
mkdir -vp %{buildroot}

%install
mkdir -vp %{buildroot}/etc/bareos
# copy the config files
cp -rv * %{buildroot}/etc/bareos/

%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-, bareos, bareos, 0755)
/etc/bareos/


%changelog
* Mon May 30 2016 Gratien D'haese ( gratien.dhaese at gmail.com ) 1.0-1
- Initial package
