PKG=bareos-server-conf
version=1.0

all: dist rpm

dist: $(PKG).tar.gz

$(PKG).tar.gz:
	tar zcf ~/RPM/SOURCES/$(PKG).tar.gz \
	--exclude=Makefile \
	--exclude=$(PKG).spec \
	--transform='s,^\.,$(PKG)-$(version),S' .

rpm: $(PKG).spec
	rpmbuild -v -ba $(PKG).spec
