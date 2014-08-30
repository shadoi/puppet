%{!?ruby_sitelibdir: %define ruby_sitelibdir %(ruby -rrbconfig -e 'puts Config::CONFIG["sitelibdir"]')}
%define pbuild %{_builddir}/%{name}-%{version}
%define suseconfdir conf/suse
%define confdir conf/redhat

Summary: A network tool for managing many disparate systems
Name: puppet
Version: 0.24.1
Release: 3%{?dist}
License: GPL
Group: System Environment/Base

URL: http://reductivelabs.com/projects/puppet/
Source: http://reductivelabs.com/downloads/puppet/%{name}-%{version}.tgz
Patch0: puppet.suse.patch
Patch1: puppet.service.patch

Requires: ruby >= 1.8.6
Requires: facter >= 1.3.7
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArchitectures: noarch
BuildRequires: ruby >= 1.8.6

%description
Puppet lets you centrally manage every important aspect of your system using a
cross-platform specification language that manages all the separate elements
normally aggregated in different files, like users, cron jobs, and hosts,
along with obviously discrete elements like packages, services, and files.

%package server
Group: System Environment/Base
Summary: Server for the puppet system management tool
Requires: puppet = %{version}-%{release}

%description server
Provides the central puppet server daemon which provides manifests to clients.
The server can also function as a certificate authority and file server.

%prep
%setup -q
%patch0 -p1
%patch1 -p1

%build
for f in bin/* ; do
 sed -i -e '1c#!/usr/bin/ruby' $f
done

%install
%{__rm} -rf %{buildroot}
%{__install} -d -m0755 %{buildroot}%{_sbindir}
%{__install} -d -m0755 %{buildroot}%{_bindir}
%{__install} -d -m0755 %{buildroot}%{ruby_sitelibdir}
%{__install} -d -m0755 %{buildroot}%{_sysconfdir}/puppet/manifests
%{__install} -d -m0755 %{buildroot}%{_docdir}/%{name}-%{version}
%{__install} -d -m0755 %{buildroot}%{_localstatedir}/lib/puppet
%{__install} -d -m0755 %{buildroot}%{_localstatedir}/run/puppet
%{__install} -d -m0755 %{buildroot}%{_localstatedir}/log/puppet
%{__install} -Dp -m0755 %{pbuild}/bin/* %{buildroot}%{_sbindir}
%{__mv} %{buildroot}%{_sbindir}/puppet %{buildroot}%{_bindir}/puppet
%{__mv} %{buildroot}%{_sbindir}/puppetrun %{buildroot}%{_bindir}/puppetrun
%{__install} -Dp -m0644 %{pbuild}/lib/puppet.rb %{buildroot}%{ruby_sitelibdir}/puppet.rb
%{__cp} -a %{pbuild}/lib/puppet %{buildroot}%{ruby_sitelibdir}
find %{buildroot}%{ruby_sitelibdir} -type f -perm +ugo+x -print0 | xargs -0 -r %{__chmod} a-x
%{__install} -Dp -m0644 %{confdir}/client.sysconfig %{buildroot}%{_sysconfdir}/sysconfig/puppet
%{__install} -Dp -m0755 %{suseconfdir}/client.init %{buildroot}%{_initrddir}/puppet
%{__install} -Dp -m0644 %{confdir}/server.sysconfig %{buildroot}%{_sysconfdir}/sysconfig/puppetmaster
%{__install} -Dp -m0755 %{suseconfdir}/server.init %{buildroot}%{_initrddir}/puppetmaster
%{__install} -Dp -m0644 %{confdir}/fileserver.conf %{buildroot}%{_sysconfdir}/puppet/fileserver.conf
%{__install} -Dp -m0644 %{confdir}/puppet.conf %{buildroot}%{_sysconfdir}/puppet/puppet.conf
%{__install} -Dp -m0644 %{confdir}/logrotate %{buildroot}%{_sysconfdir}/logrotate.d/puppet

%files
%defattr(-, root, root, 0755)
%{_bindir}/puppet
%{_sbindir}/puppetd
%{ruby_sitelibdir}/*
%{_initrddir}/puppet
%config(noreplace) %{_sysconfdir}/sysconfig/puppet
%config(noreplace) %{_sysconfdir}/puppet/puppet.conf
%doc CHANGELOG COPYING LICENSE README TODO examples
%exclude %{_sbindir}/puppetdoc
%config(noreplace) %{_sysconfdir}/logrotate.d/puppet
# These need to be owned by puppet so the server can
# write to them
%attr(-, puppet, puppet) %{_localstatedir}/run/puppet
%attr(-, puppet, puppet) %{_localstatedir}/log/puppet
%attr(-, puppet, puppet) %{_localstatedir}/lib/puppet

%files server
%defattr(-, root, root, 0755)
%{_sbindir}/puppetmasterd
%{_bindir}/puppetrun
%{_initrddir}/puppetmaster
%config(noreplace) %{_sysconfdir}/puppet/*
%config(noreplace) %{_sysconfdir}/sysconfig/puppetmaster
%{_sbindir}/puppetca

%pre
/usr/sbin/groupadd -r puppet 2>/dev/null || :
/usr/sbin/useradd -g puppet -c "Puppet" \
    -s /sbin/nologin -r -d /var/puppet puppet 2> /dev/null || :

%post
/sbin/chkconfig --add puppet
exit 0

%post server
/sbin/chkconfig --add puppetmaster

%preun
if [ "$1" = 0 ] ; then
	/sbin/service puppet stop > /dev/null 2>&1
	/sbin/chkconfig --del puppet
fi

%preun server
if [ "$1" = 0 ] ; then
	/sbin/service puppetmaster stop > /dev/null 2>&1
	/sbin/chkconfig --del puppetmaster
fi

%postun server
if [ "$1" -ge 1 ]; then
	 /sbin/service puppetmaster try-restart > /dev/null 2>&1
fi

%clean
%{__rm} -rf %{buildroot}

%changelog
* Sat Feb 16 2008 James Turnbull <james@lovedthanlost.net> - 0.24.1-1
- Fixed puppet configuation file references to match single puppet.conf file
- Update versions for 0.24.1 release

* Tue Aug  3 2006 Martin Vuk <martin.vuk@fri.uni-lj.si> - 0.18.4-3
- Replaced puppet-bin.patch with %build section from David's spec

* Tue Aug  1 2006 Martin Vuk <martin.vuk@fri.uni-lj.si> - 0.18.4-2
- Added supprot for enabling services in SuSE

* Tue Aug  1 2006 Martin Vuk <martin.vuk@fri.uni-lj.si> - 0.18.4-1
- New version and support for SuSE

* Wed Jul  5 2006 David Lutterkort <dlutter@redhat.com> - 0.18.2-1
- New version

* Wed Jun 28 2006 David Lutterkort <dlutter@redhat.com> - 0.18.1-1
- Removed lsb-config.patch and yumrepo.patch since they are upstream now

* Mon Jun 19 2006 David Lutterkort <dlutter@redhat.com> - 0.18.0-1
- Patch config for LSB compliance (lsb-config.patch)
- Changed config moves /var/puppet to /var/lib/puppet, /etc/puppet/ssl
  to /var/lib/puppet, /etc/puppet/clases.txt to /var/lib/puppet/classes.txt,
  /etc/puppet/localconfig.yaml to /var/lib/puppet/localconfig.yaml

* Fri May 19 2006 David Lutterkort <dlutter@redhat.com> - 0.17.2-1
- Added /usr/bin/puppetrun to server subpackage
- Backported patch for yumrepo type (yumrepo.patch)

* Wed May  3 2006 David Lutterkort <dlutter@redhat.com> - 0.16.4-1
- Rebuilt

* Fri Apr 21 2006 David Lutterkort <dlutter@redhat.com> - 0.16.0-1
- Fix default file permissions in server subpackage
- Run puppetmaster as user puppet
- rebuilt for 0.16.0

* Mon Apr 17 2006 David Lutterkort <dlutter@redhat.com> - 0.15.3-2
- Don't create empty log files in post-install scriptlet

* Fri Apr  7 2006 David Lutterkort <dlutter@redhat.com> - 0.15.3-1
- Rebuilt for new version

* Wed Mar 22 2006 David Lutterkort <dlutter@redhat.com> - 0.15.1-1
- Patch0: Run puppetmaster as root; running as puppet is not ready
  for primetime

* Mon Mar 13 2006 David Lutterkort <dlutter@redhat.com> - 0.15.0-1
- Commented out noarch; requires fix for bz184199

* Mon Mar  6 2006 David Lutterkort <dlutter@redhat.com> - 0.14.0-1
- Added BuildRequires for ruby

* Wed Mar  1 2006 David Lutterkort <dlutter@redhat.com> - 0.13.5-1
- Removed use of fedora-usermgmt. It is not required for Fedora Extras and
  makes it unnecessarily hard to use this rpm outside of Fedora. Just
  allocate the puppet uid/gid dynamically

* Sun Feb 19 2006 David Lutterkort <dlutter@redhat.com> - 0.13.0-4
- Use fedora-usermgmt to create puppet user/group. Use uid/gid 24. Fixed
problem with listing fileserver.conf and puppetmaster.conf twice

* Wed Feb  8 2006 David Lutterkort <dlutter@redhat.com> - 0.13.0-3
- Fix puppetd.conf

* Wed Feb  8 2006 David Lutterkort <dlutter@redhat.com> - 0.13.0-2
- Changes to run puppetmaster as user puppet

* Mon Feb  6 2006 David Lutterkort <dlutter@redhat.com> - 0.13.0-1
- Don't mark initscripts as config files

* Mon Feb  6 2006 David Lutterkort <dlutter@redhat.com> - 0.12.0-2
- Fix BuildRoot. Add dist to release

* Tue Jan 17 2006 David Lutterkort <dlutter@redhat.com> - 0.11.0-1
- Rebuild

* Thu Jan 12 2006 David Lutterkort <dlutter@redhat.com> - 0.10.2-1
- Updated for 0.10.2 Fixed minor kink in how Source is given

* Wed Jan 11 2006 David Lutterkort <dlutter@redhat.com> - 0.10.1-3
- Added basic fileserver.conf

* Wed Jan 11 2006 David Lutterkort <dlutter@redhat.com> - 0.10.1-1
- Updated. Moved installation of library files to sitelibdir. Pulled
initscripts into separate files. Folded tools rpm into server

* Thu Nov 24 2005 Duane Griffin <d.griffin@psenterprise.com>
- Added init scripts for the client

* Wed Nov 23 2005 Duane Griffin <d.griffin@psenterprise.com>
- First packaging
