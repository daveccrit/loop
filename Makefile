# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Note that this Makefile is not invoked by the Mozilla build
# system, which is why it can have dependencies on things the
# build system at-large doesn't yet support.

LOOP_SERVER_URL := $(shell echo $${LOOP_SERVER_URL-http://localhost:5000/v0})
LOOP_FEEDBACK_API_URL := $(shell echo $${LOOP_FEEDBACK_API_URL-"https://input.allizom.org/api/v1/feedback"})
LOOP_FEEDBACK_PRODUCT_NAME := $(shell echo $${LOOP_FEEDBACK_PRODUCT_NAME-Loop})
LOOP_DOWNLOAD_FIREFOX_URL := $(shell echo $${LOOP_DOWNLOAD_FIREFOX_URL-"https://www.mozilla.org/firefox/new/?scene=2&utm_source=hello.firefox.com&utm_medium=referral&utm_campaign=non-webrtc-browser\#download-fx"})
LOOP_PRIVACY_WEBSITE_URL := $(shell echo $${LOOP_PRIVACY_WEBSITE_URL-"https://www.mozilla.org/privacy/firefox-hello/"})
LOOP_LEGAL_WEBSITE_URL := $(shell echo $${LOOP_LEGAL_WEBSITE_URL-"https://www.mozilla.org/about/legal/terms/firefox-hello/"})
LOOP_PRODUCT_HOMEPAGE_URL := $(shell echo $${LOOP_PRODUCT_HOMEPAGE_URL-"https://www.firefox.com/hello/"})
FIREFOX_VERSION=45.0

NODE_LOCAL_BIN := ./node_modules/.bin
REPO_BIN_DIR := ./bin
RSYNC := rsync --archive --exclude='*.jsx'

install: npm_install

npm_install:
	@npm install

# build the dist dir, which contains a production version of the code and
# assets
.PHONY: dist
dist:
	mkdir -p dist
	$(RSYNC) content/* dist
	NODE_ENV="production" $(NODE_LOCAL_BIN)/webpack \
		-p -v --display-errors
	sed 's#webappEntryPoint.js#js/standalone.js#' \
		< content/index.html > dist/index.html

.PHONY: distclean
distclean:
	rm -fr dist

.PHONY: distserver
distserver: remove_old_config dist
	LOOP_CONTENT_DIR=dist node server.js

BUILT := ./built
VENV := $(BUILT)/.venv
BABEL := $(NODE_LOCAL_BIN)/babel --extensions '.jsx'
ESLINT := $(NODE_LOCAL_BIN)/eslint
FLAKE8 := $(NODE_LOCAL_BIN)/flake8

.PHONY: .venv
.venv:
	virtualenv -p python2.7 $(VENV)
	. $(VENV)/bin/activate && pip install -r bin/require.pip

# XXX maybe just build one copy of shared in standalone, and then use
# server.js magic to redirect?
# XXX ecma3 transform for IE?
.PHONY: ui
ui:
	mkdir -p $(BUILT)/$@
	$(RSYNC) $@ $(BUILT)
	$(BABEL) $@ --out-dir $(BUILT)/$@
	mkdir -p $(BUILT)/$@/shared
	$(RSYNC) shared $(BUILT)/$@
	$(BABEL) shared --out-dir $(BUILT)/$@/shared

.PHONY: standalone
standalone:
	mkdir -p $(BUILT)/$@
	$(RSYNC) $@ $(BUILT)
	$(BABEL) $@ --out-dir $(BUILT)/$@
	mkdir -p $(BUILT)/$@/content/shared
	$(RSYNC) shared $(BUILT)/$@/content
	$(BABEL) shared --out-dir $(BUILT)/$@/content/shared

.PHONY: add-on
add-on:
	mkdir -p $(BUILT)/$@
	$(RSYNC) $@/chrome.manifest $@/chrome/bootstrap.js $(BUILT)/$@
	sed "s/@FIREFOX_VERSION@/$(FIREFOX_VERSION)/g" add-on/install.rdf.in | \
		grep -v "#filter substitution" > $(BUILT)/$@/install.rdf
	mkdir -p $(BUILT)/$@/chrome/content/panels
	$(RSYNC) $@/panels $(BUILT)/$@/chrome/content
	$(BABEL) $@/panels --out-dir $(BUILT)/$@/chrome/content/panels
	mkdir -p $(BUILT)/$@/chrome/content/modules
	$(RSYNC) $@/chrome/modules $(BUILT)/$@/chrome/content
	mkdir -p $(BUILT)/$@/chrome/test
	$(RSYNC) $@/chrome/test $(BUILT)/$@/chrome
	mkdir -p $(BUILT)/$@/chrome/content/preferences
	$(RSYNC) $@/preferences $(BUILT)/$@/chrome/content
	mkdir -p $(BUILT)/$@/chrome/content/shared
	$(RSYNC) shared $(BUILT)/$@/chrome/content
	$(BABEL) shared --out-dir $(BUILT)/$@/chrome/content/shared
	$(RSYNC) $@/chrome/skin $(BUILT)/$@/chrome/

#
# Tests
#

eslint:
	$(ESLINT) --ext .js --ext .jsm --ext .jsx add-on shared standalone

flake8: .venv
	. $(VENV)/bin/activate && flake8 .

.PHONY: lint
lint: eslint flake8

karma: build
	$(NODE_LOCAL_BIN)/karma start test/karma/karma.coverage.desktop.js
	$(NODE_LOCAL_BIN)/karma start test/karma/karma.coverage.shared_standalone.js


#
# Build & run
#

XPI_FILE := built/loop@mozilla.org.xpi

# so we can type "make xpi" without depend on the file directly
.PHONY: xpi
xpi: $(XPI_FILE)

$(XPI_FILE): $(REPO_BIN_DIR)/build_extension.sh build
	@$(REPO_BIN_DIR)/build_extension.sh $(@F) add-on

.PHONY: build
build: add-on standalone ui

.PHONY: clean
clean:
	rm -rf $(BUILT)

.PHONY: cleanbuild
cleanbuild: clean build

test: lint karma

.PHONY: runserver
runserver: remove_old_config
	$(REPO_BIN_DIR)/run-server.sh

frontend:
	@echo "Not implemented yet."

# Try hg first, if not fall back to git.
SOURCE_STAMP := $(shell hg parent --template '{node|short}\n' 2> /dev/null)
ifndef SOURCE_STAMP
SOURCE_STAMP := $(shell git describe --always --tag)
endif

SOURCE_DATE := $(shell hg parent --template '{date|date}\n' 2> /dev/null)
ifndef SOURCE_DATE
SOURCE_DATE := $(shell git log -1 --format="%H%n%aD")
endif

version:
	@echo $(SOURCE_STAMP) > content/VERSION.txt
	@echo $(SOURCE_DATE) >> content/VERSION.txt


# The local node server used for client dev (server.js) used to use a static
# content/config.js.  Now that information is server up dynamically.  This
# target is depended on by runserver, and removes any copies of that to avoid
# confusion.
remove_old_config:
	@rm -f content/config.js


# The services development deployment, however, still wants a static config
# file, and needs an easy way to generate one.  This target is for folks
# working with that deployment.
.PHONY: config
config:
	@echo "var loop = loop || {};" > content/config.js
	@echo "loop.config = loop.config || {};" >> content/config.js
	@echo "loop.config.serverUrl = '`echo $(LOOP_SERVER_URL)`';" >> content/config.js
	@echo "loop.config.feedbackApiUrl = '`echo $(LOOP_FEEDBACK_API_URL)`';" >> content/config.js
	@echo "loop.config.feedbackProductName = '`echo $(LOOP_FEEDBACK_PRODUCT_NAME)`';" >> content/config.js
	@echo "loop.config.downloadFirefoxUrl = '`echo $(LOOP_DOWNLOAD_FIREFOX_URL)`';" >> content/config.js
	@echo "loop.config.privacyWebsiteUrl = '`echo $(LOOP_PRIVACY_WEBSITE_URL)`';" >> content/config.js
	@echo "loop.config.legalWebsiteUrl = '`echo $(LOOP_LEGAL_WEBSITE_URL)`';" >> content/config.js
	@echo "loop.config.learnMoreUrl = '`echo $(LOOP_PRODUCT_HOMEPAGE_URL)`';" >> content/config.js
	@echo "loop.config.roomsSupportUrl = 'https://support.mozilla.org/kb/group-conversations-firefox-hello-webrtc';" >> content/config.js
	@echo "loop.config.guestSupportUrl = 'https://support.mozilla.org/kb/respond-firefox-hello-invitation-guest-mode';" >> content/config.js
	@echo "loop.config.generalSupportUrl = 'https://support.mozilla.org/kb/respond-firefox-hello-invitation-guest-mode';" >> content/config.js
	@echo "loop.config.tilesIframeUrl = 'https://tiles.cdn.mozilla.net/iframe.html';" >> content/config.js
	@echo "loop.config.tilesSupportUrl = 'https://support.mozilla.org/tiles-firefox-hello';" >> content/config.js
	@echo "loop.config.unsupportedPlatformUrl = 'https://support.mozilla.org/en-US/kb/which-browsers-will-work-firefox-hello-video-chat';" >> content/config.js
