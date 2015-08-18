PACKAGE = util-linux
ORG = amylum

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz

DEP_DIR = /tmp/dep-dir

PACKAGE_VERSION = 2.26.2
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

SOURCE_VERSION_DIR = $(shell echo $(PACKAGE_VERSION) | sed 's/\.[0-9]*$$//')
SOURCE_URL = https://www.kernel.org/pub/linux/utils/util-linux/v$(SOURCE_VERSION_DIR)/$(PACKAGE)-$(PACKAGE_VERSION).tar.gz
SOURCE_PATH = /tmp/source
SOURCE_TARBALL = /tmp/source.tar.gz

PATH_FLAGS = --prefix=$(RELEASE_DIR) --sbindir=$(RELEASE_DIR)/usr/bin --bindir=$(RELEASE_DIR)/usr/bin --mandir=$(RELEASE_DIR)/usr/share/man --libdir=$(RELEASE_DIR)/usr/lib --includedir=$(RELEASE_DIR)/usr/include --docdir=$(RELEASE_DIR)/usr/share/doc/$(PACKAGE) --infodir=/tmp/trash
CONF_FLAGS = --disable-shared --enable-fs-paths-default=/usr/bin --enable-chfn-chsh
CFLAGS = -static -static-libgcc -Wl,-static -lc
CPPFLAGS = -I$(DEP_DIR)

.PHONY : default source manual container build version push local

default: container

source:
	rm -rf $(SOURCE_PATH) $(SOURCE_TARBALL)
	mkdir $(SOURCE_PATH)
	curl -sLo $(SOURCE_TARBALL) $(SOURCE_URL)
	tar -x -C $(SOURCE_PATH) -f $(SOURCE_TARBALL) --strip-components=1

manual:
	./meta/launch /bin/bash || true

container:
	./meta/launch

build: source
	rm -rf $(BUILD_DIR) $(DEP_DIR)
	mkdir -p $(DEP_DIR)/usr/include
	cp -R /usr/include/linux $(DEP_DIR)/usr/include/
	cp -R $(SOURCE_PATH) $(BUILD_DIR)
	cd $(BUILD_DIR) && CC=musl-gcc CFLAGS='$(CFLAGS)' CPPFLAGS=$(CPPFLAGS) ./configure $(PATH_FLAGS) $(CONF_FLAGS)
	cd $(BUILD_DIR) && make install
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

local: build push

