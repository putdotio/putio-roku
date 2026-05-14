-include .env

APP_NAME := put.io
VERSION = 2.9.0
ARTIFACT_NAME := putio-roku-v2.zip

DIST_DIR := dist
ZIP_DIR := $(DIST_DIR)/apps
TMP_DIR := $(DIST_DIR)/tmp
APP_ZIP_FILE := $(ZIP_DIR)/$(APP_NAME).zip
ARTIFACT_ZIP_FILE := $(ZIP_DIR)/$(ARTIFACT_NAME)
ROKU_RESPONSE_FILE := $(TMP_DIR)/roku-response.html
ROKU_APP_FILES := $(shell find manifest source components images -type f ! -name '*~' 2>/dev/null)

ROKU_DEV_CONSOLE_PORT ?= 8085

ifdef ROKU_DEV_PASSWORD
	ROKU_DEV_USERPASS := rokudev:$(ROKU_DEV_PASSWORD)
else
	ROKU_DEV_USERPASS := rokudev
endif

MAKEFLAGS += --no-builtin-rules
.SUFFIXES:
.DEFAULT_GOAL := build

.PHONY: build
build: $(APP_ZIP_FILE)

.PHONY: $(APP_NAME)
$(APP_NAME): build

$(APP_ZIP_FILE): $(ROKU_APP_FILES)
	@echo "*** Creating $(APP_NAME).zip ***"
	@rm -f "$(APP_ZIP_FILE)"
	@mkdir -p "$(ZIP_DIR)"
	@find images components -type f -name '*.png' -print | zip -0 "$(APP_ZIP_FILE)" -@
	@find manifest source components images -type f ! -name '*.png' ! -name '*~' -print | zip -9 "$(APP_ZIP_FILE)" -@
	@test -f "$(APP_ZIP_FILE)"
	@echo "*** Packaging $(APP_NAME) complete ***"

.PHONY: clean
clean:
	rm -rf build
	rm -rf "$(TMP_DIR)"
	rm -f "$(APP_ZIP_FILE)"
	rm -f "$(ARTIFACT_ZIP_FILE)"

.PHONY: check-roku-static
check-roku-static:
	@echo "*** Running Roku static checks ***"
	pnpm exec bslint --project bsconfig.json

.PHONY: check-roku-live
check-roku-live:
	pnpm run check:live

.PHONY: verify
verify: clean check-roku-live check-roku-static build
	@test -f "$(APP_ZIP_FILE)"

.PHONY: smoke
smoke: verify

.PHONY: artifact
artifact: verify
	@mv "$(APP_ZIP_FILE)" "$(ARTIFACT_ZIP_FILE)"
	@test -f "$(ARTIFACT_ZIP_FILE)"

.PHONY: check-roku-dev-target
check-roku-dev-target:
	@if [ -z "$(ROKU_DEV_TARGET)" ]; then \
		echo "ERROR: ROKU_DEV_TARGET is not set."; \
		exit 1; \
	fi
	@echo "Checking dev server at $(ROKU_DEV_TARGET)..."
	@mkdir -p "$(TMP_DIR)"
	@curl --connect-timeout 2 --max-time 4 --silent --show-error \
		--output "$(ROKU_RESPONSE_FILE)" \
		http://$(ROKU_DEV_TARGET):8060/query/device-info
	@ROKU_DEV_NAME=$$(sed -n 's:.*<friendly-device-name>\(.*\)</friendly-device-name>.*:\1:p' "$(ROKU_RESPONSE_FILE)"); \
		if [ -z "$$ROKU_DEV_NAME" ]; then \
			ROKU_DEV_NAME=$$(sed -n 's:.*<friendlyName>\(.*\)</friendlyName>.*:\1:p' "$(ROKU_RESPONSE_FILE)"); \
		fi; \
		echo "Device reports as \"$${ROKU_DEV_NAME:-unknown}\"."
	@curl --connect-timeout 2 --max-time 4 --silent --show-error \
		--output /dev/null \
		http://$(ROKU_DEV_TARGET)
	@echo "Dev server is ready."

.PHONY: active-app
active-app: check-roku-dev-target
	@curl --connect-timeout 2 --max-time 4 --silent --show-error \
		http://$(ROKU_DEV_TARGET):8060/query/active-app

.PHONY: device-info
device-info: check-roku-dev-target
	@curl --connect-timeout 2 --max-time 4 --silent --show-error \
		http://$(ROKU_DEV_TARGET):8060/query/device-info

.PHONY: install
install: verify check-roku-dev-target
	@echo "Installing $(APP_NAME)..."
	@mkdir -p "$(TMP_DIR)"
	@HTTP_STATUS=""; \
		for attempt in 1 2; do \
			HTTP_STATUS=$$(curl --user "$(ROKU_DEV_USERPASS)" --digest --silent --show-error \
				-F "mysubmit=Install" -F "archive=@$(APP_ZIP_FILE)" \
				--output "$(ROKU_RESPONSE_FILE)" \
				--write-out "%{http_code}" \
				http://$(ROKU_DEV_TARGET)/plugin_install); \
			if [ "$$HTTP_STATUS" = "200" ]; then \
				break; \
			fi; \
			if [ "$$attempt" = "1" ]; then \
				echo "Install attempt returned HTTP $$HTTP_STATUS; retrying..."; \
				sleep 2; \
			fi; \
		done; \
		if [ "$$HTTP_STATUS" != "200" ]; then \
			echo "ERROR: Device returned HTTP $$HTTP_STATUS"; \
			exit 1; \
		fi
	@MSG=$$(sed -n 's:.*<font color="red">\(.*\)</font>.*:\1:p' "$(ROKU_RESPONSE_FILE)"); \
		echo "Result: $$MSG"

.PHONY: remove
remove: check-roku-dev-target
	@echo "Removing dev app..."
	@mkdir -p "$(TMP_DIR)"
	@HTTP_STATUS=$$(curl --user "$(ROKU_DEV_USERPASS)" --digest --silent --show-error \
		-F "mysubmit=Delete" -F "archive=" \
		--output "$(ROKU_RESPONSE_FILE)" \
		--write-out "%{http_code}" \
		http://$(ROKU_DEV_TARGET)/plugin_install); \
		if [ "$$HTTP_STATUS" != "200" ]; then \
			echo "ERROR: Device returned HTTP $$HTTP_STATUS"; \
			exit 1; \
		fi
	@MSG=$$(sed -n 's:.*<font color="red">\(.*\)</font>.*:\1:p' "$(ROKU_RESPONSE_FILE)"); \
		echo "Result: $$MSG"

.PHONY: run
run: remove install

.PHONY: launch
launch: check-roku-dev-target
	@echo "Launching dev app on $(ROKU_DEV_TARGET)..."
	@curl --connect-timeout 2 --max-time 10 --silent --show-error \
		--request POST \
		http://$(ROKU_DEV_TARGET):8060/launch/dev \
		>/dev/null
	@ACTIVE_APP=""; \
		for _ in 1 2 3 4 5 6 7 8 9 10; do \
			ACTIVE_APP=$$(curl --connect-timeout 2 --max-time 4 --silent --show-error \
				http://$(ROKU_DEV_TARGET):8060/query/active-app); \
			if echo "$$ACTIVE_APP" | grep '<app id="dev"' >/dev/null; then \
				echo "$$ACTIVE_APP"; \
				exit 0; \
			fi; \
			sleep 1; \
		done; \
		echo "$$ACTIVE_APP"; \
		echo "ERROR: Dev app did not become active."; \
		exit 1

.PHONY: console
console: check-roku-dev-target
	@echo "Attaching to BrightScript console at $(ROKU_DEV_TARGET):$(ROKU_DEV_CONSOLE_PORT). Press Ctrl-C to detach."
	@nc $(ROKU_DEV_TARGET) $(ROKU_DEV_CONSOLE_PORT)

.PHONY: live-test
live-test: check-roku-dev-target active-app device-info

.PHONY: live-test-control
live-test-control:
	ROKU_DEV_TARGET=$(ROKU_DEV_TARGET) pnpm roku:live control-smoke

.PHONY: live-test-press
live-test-press:
	@if [ -z "$(KEYS)" ]; then \
		echo "ERROR: KEYS is not set. Example: make live-test-press KEYS=\"Back Info\""; \
		exit 1; \
	fi
	ROKU_DEV_TARGET=$(ROKU_DEV_TARGET) pnpm roku:live press $(KEYS)

.PHONY: live-test-deeplink
live-test-deeplink:
	@if [ -z "$(CONTENT_ID)" ]; then \
		echo "ERROR: CONTENT_ID is not set. Example: make live-test-deeplink CONTENT_ID=1587417579"; \
		exit 1; \
	fi
	ROKU_DEV_TARGET=$(ROKU_DEV_TARGET) pnpm roku:live launch-deeplink $(CONTENT_ID) $(or $(MEDIA_TYPE),movie)

.PHONY: live-test-launch
live-test-launch: launch

.PHONY: live-test-install
live-test-install: run launch
