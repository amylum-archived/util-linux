PACKAGE = util-linux
ORG = amylum

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz

DEP_DIR = /tmp/dep-dir

PACKAGE_VERSION = $$(git --git-dir=upstream/.git describe --tags | sed 's/v//')
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

PATH_FLAGS = --prefix=/usr --infodir=/tmp/trash
CONF_FLAGS = --enable-fs-paths-default=/usr/bin --disable-more --without-ncurses --disable-bash-completion
CFLAGS =
CPPFLAGS = -I$(DEP_DIR)/usr/include

PAM_VERSION = 1.2.1-10
PAM_URL = https://github.com/amylum/pam/releases/download/$(PAM_VERSION)/pam.tar.gz
PAM_TAR = /tmp/pam.tar.gz
PAM_DIR = /tmp/pam
PAM_PATH = -I$(PAM_DIR)/usr/include -L$(PAM_DIR)/usr/lib

.PHONY : default submodule manual deps container build version push local

default: container

submodule:
	git submodule update --init

manual: submodule
	./meta/launch /bin/bash || true

container: submodule
	./meta/launch

deps:
	rm -rf $(DEP_DIR)
	mkdir -p $(DEP_DIR)/usr/include
	cp -R /usr/include/{linux,asm,asm-generic} $(DEP_DIR)/usr/include/
	rm -rf $(PAM_DIR) $(PAM_TAR)
	mkdir $(PAM_DIR)
	curl -sLo $(PAM_TAR) $(PAM_URL)
	tar -x -C $(PAM_DIR) -f $(PAM_TAR)
	find $(PAM_DIR) -name '*.la' -delete

build: deps
	rm -rf $(BUILD_DIR)
	cp -R upstream $(BUILD_DIR)
	cd  $(BUILD_DIR) && ./autogen.sh
	sed -i "s|^\(usrsbin_execdir=.*\)/sbin'$$|\1/bin'|" $(BUILD_DIR)/configure
	cd $(BUILD_DIR) && CC=musl-gcc CFLAGS='$(CFLAGS) $(PAM_PATH)' CPPFLAGS='$(CPPFLAGS)' ./configure $(PATH_FLAGS) $(CONF_FLAGS)
	cd $(BUILD_DIR) && make DESTDIR=$(RELEASE_DIR) install
	rm -rf $(RELEASE_DIR)/usr/share/{doc,bash-completion}
	rm -rf $(RELEASE_DIR)/tmp
	mkdir -p $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)
	cp $(BUILD_DIR)/COPYING $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)/LICENSE
	cd $(RELEASE_DIR) && tar -czvf $(RELEASE_FILE) *

version:
	@echo $$(($(PATCH_VERSION) + 1)) > version

push: version
	git commit -am "$(VERSION)"
	ssh -oStrictHostKeyChecking=no git@github.com &>/dev/null || true
	git tag -f "$(VERSION)"
	git push --tags origin master
	targit -a .github -c -f $(ORG)/$(PACKAGE) $(VERSION) $(RELEASE_FILE)
	@sha512sum $(RELEASE_FILE) | cut -d' ' -f1

local: build push

