APP_NAME := Cliphoard
BUNDLE_ID := dev.local.Cliphoard
INSTALL_DIR ?= /Applications
PRODUCTS := build/DerivedData/Build/Products
RELEASE_APP := $(PRODUCTS)/Release/$(APP_NAME).app
DEBUG_APP := $(PRODUCTS)/Debug/$(APP_NAME).app
INSTALLED_APP := $(INSTALL_DIR)/$(APP_NAME).app

.PHONY: build install uninstall run dev clean

build:
	@scripts/build.sh Release

install: build
	@pkill -f "^$(INSTALLED_APP)/Contents/MacOS/" 2>/dev/null; sleep 0.5
	@rm -rf "$(INSTALLED_APP)"
	@ditto "$(RELEASE_APP)" "$(INSTALLED_APP)"
	@open "$(INSTALLED_APP)"
	@echo "Installed $(INSTALLED_APP)"

uninstall:
	@pkill -f "^$(INSTALLED_APP)/Contents/MacOS/" 2>/dev/null; sleep 0.5
	@if [ -d "$(INSTALLED_APP)" ]; then \
		"$(INSTALLED_APP)/Contents/MacOS/$(APP_NAME)" --unregister-login-item; \
		rm -rf "$(INSTALLED_APP)"; \
		echo "Removed $(INSTALLED_APP)"; \
	fi
	@echo "Your history and settings were kept. To delete them too:"
	@echo "  rm -rf ~/Library/Application\\ Support/$(BUNDLE_ID)"
	@echo "  defaults delete $(BUNDLE_ID)"
	@echo "  security delete-generic-password -s $(BUNDLE_ID) -a secrets-key"

run:
	@scripts/build.sh Debug && open "$(DEBUG_APP)"

dev:
	@scripts/dev.sh

clean:
	rm -rf build
