-include .env

APP_NAME := put.io
VERSION = 2.9.0
ARTIFACT_NAME := putio-roku-v2.zip

DIST_DIR := dist
ZIP_DIR := $(DIST_DIR)/apps
TMP_DIR := $(DIST_DIR)/tmp
ZIP_STAGING_DIR := $(TMP_DIR)/zip-root
APP_ZIP_FILE := $(ZIP_DIR)/$(APP_NAME).zip
APP_ZIP_ABS := $(abspath $(APP_ZIP_FILE))
ARTIFACT_ZIP_FILE := $(ZIP_DIR)/$(ARTIFACT_NAME)
ROKU_RESPONSE_FILE := $(TMP_DIR)/roku-response.html
ROKU_APP_FILES := $(shell LC_ALL=C find manifest source components images -type f ! -name '.*' ! -name '*~' 2>/dev/null | sort)
ROKU_ZIP_FILES := LC_ALL=C find manifest source components images -type f ! -name '.*' ! -name '*~' | sort

ROKU_DEV_CONSOLE_PORT ?= 8085
ROKU_TARGET := $(or $(ROKU_DEV_TARGET),$(ROKIT_TARGET))
ROKU_PASSWORD := $(or $(ROKU_DEV_PASSWORD),$(ROKIT_PASSWORD))

ifneq ($(strip $(ROKU_PASSWORD)),)
	ROKU_DEV_USERPASS := rokudev:$(ROKU_PASSWORD)
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

.PHONY: $(APP_ZIP_FILE)
$(APP_ZIP_FILE): $(ROKU_APP_FILES)
	@echo "*** Creating $(APP_NAME).zip ***"
	@rm -f "$(APP_ZIP_FILE)"
	@rm -rf "$(ZIP_STAGING_DIR)"
	@mkdir -p "$(ZIP_STAGING_DIR)" "$(ZIP_DIR)"
	@$(ROKU_ZIP_FILES) | while IFS= read -r file; do \
		mkdir -p "$(ZIP_STAGING_DIR)/$$(dirname "$$file")"; \
		cp "$$file" "$(ZIP_STAGING_DIR)/$$file"; \
	done
	@find "$(ZIP_STAGING_DIR)" -type f -exec touch -t 202001010000 {} +
	@(cd "$(ZIP_STAGING_DIR)" && $(ROKU_ZIP_FILES) | grep '\.png$$' | zip -X -0 "$(APP_ZIP_ABS)" -@)
	@(cd "$(ZIP_STAGING_DIR)" && $(ROKU_ZIP_FILES) | grep -v '\.png$$' | zip -X -9 "$(APP_ZIP_ABS)" -@)
	@rm -rf "$(ZIP_STAGING_DIR)"
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
	@if [ -z "$(ROKU_TARGET)" ]; then \
		echo "ERROR: ROKU_DEV_TARGET or ROKIT_TARGET is not set."; \
		exit 1; \
	fi
	@echo "Checking dev server at $(ROKU_TARGET)..."
	@mkdir -p "$(TMP_DIR)"
	@curl --connect-timeout 2 --max-time 4 --silent --show-error \
		--output "$(ROKU_RESPONSE_FILE)" \
		http://$(ROKU_TARGET):8060/query/device-info
	@ROKU_DEV_NAME=$$(sed -n 's:.*<friendly-device-name>\(.*\)</friendly-device-name>.*:\1:p' "$(ROKU_RESPONSE_FILE)"); \
		if [ -z "$$ROKU_DEV_NAME" ]; then \
			ROKU_DEV_NAME=$$(sed -n 's:.*<friendlyName>\(.*\)</friendlyName>.*:\1:p' "$(ROKU_RESPONSE_FILE)"); \
		fi; \
		echo "Device reports as \"$${ROKU_DEV_NAME:-unknown}\"."
	@curl --connect-timeout 2 --max-time 4 --silent --show-error \
		--output /dev/null \
		http://$(ROKU_TARGET)
	@echo "Dev server is ready."

.PHONY: active-app
active-app: check-roku-dev-target
	@curl --connect-timeout 2 --max-time 4 --silent --show-error \
		http://$(ROKU_TARGET):8060/query/active-app

.PHONY: device-info
device-info: check-roku-dev-target
	@curl --connect-timeout 2 --max-time 4 --silent --show-error \
		http://$(ROKU_TARGET):8060/query/device-info

.PHONY: install
install: verify check-roku-dev-target
	@echo "Installing $(APP_NAME)..."
	@mkdir -p "$(TMP_DIR)"
	@HTTP_STATUS=""; \
		for attempt in 1 2; do \
			HTTP_STATUS=$$(curl --user "$(ROKU_DEV_USERPASS)" --anyauth --http1.0 --silent --show-error \
				-F "mysubmit=Install" -F "archive=@$(APP_ZIP_FILE)" \
				--output "$(ROKU_RESPONSE_FILE)" \
				--write-out "%{http_code}" \
				http://$(ROKU_TARGET)/plugin_install); \
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
	@HTTP_STATUS=$$(curl --user "$(ROKU_DEV_USERPASS)" --anyauth --http1.0 --silent --show-error \
		-F "mysubmit=Delete" -F "archive=" \
		--output "$(ROKU_RESPONSE_FILE)" \
		--write-out "%{http_code}" \
		http://$(ROKU_TARGET)/plugin_install); \
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
	@echo "Launching dev app on $(ROKU_TARGET)..."
	@curl --connect-timeout 2 --max-time 10 --silent --show-error \
		--request POST \
		http://$(ROKU_TARGET):8060/launch/dev \
		>/dev/null
	@ACTIVE_APP=""; \
		for _ in 1 2 3 4 5 6 7 8 9 10; do \
			ACTIVE_APP=$$(curl --connect-timeout 2 --max-time 4 --silent --show-error \
				http://$(ROKU_TARGET):8060/query/active-app); \
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
	@echo "Attaching to BrightScript console at $(ROKU_TARGET):$(ROKU_DEV_CONSOLE_PORT). Press Ctrl-C to detach."
	@nc $(ROKU_TARGET) $(ROKU_DEV_CONSOLE_PORT)

.PHONY: live-test
live-test: check-roku-dev-target active-app device-info

.PHONY: live-test-control
live-test-control:
	ROKU_DEV_TARGET=$(ROKU_TARGET) ROKIT_TARGET=$(ROKU_TARGET) pnpm roku:live control-smoke

.PHONY: live-test-press
live-test-press:
	@if [ -z "$(KEYS)" ]; then \
		echo "ERROR: KEYS is not set. Example: make live-test-press KEYS=\"Back Info\""; \
		exit 1; \
	fi
	ROKU_DEV_TARGET=$(ROKU_TARGET) ROKIT_TARGET=$(ROKU_TARGET) pnpm roku:live press $(KEYS)

.PHONY: live-test-deeplink
live-test-deeplink:
	@if [ -z "$(CONTENT_ID)" ]; then \
		echo "ERROR: CONTENT_ID is not set. Example: make live-test-deeplink CONTENT_ID=1587417579"; \
		exit 1; \
	fi
	ROKU_DEV_TARGET=$(ROKU_TARGET) ROKIT_TARGET=$(ROKU_TARGET) pnpm roku:live launch-deeplink $(CONTENT_ID) $(or $(MEDIA_TYPE),movie)

.PHONY: live-test-playback
live-test-playback:
	@if [ -z "$(CONTENT_ID)" ]; then \
		echo "ERROR: CONTENT_ID is not set. Example: make live-test-playback CONTENT_ID=1587417579"; \
		exit 1; \
	fi
	ROKU_DEV_TARGET=$(ROKU_TARGET) ROKIT_TARGET=$(ROKU_TARGET) pnpm roku:live launch-playback $(CONTENT_ID) $(or $(MEDIA_TYPE),movie) $(or $(START_FROM),continue)

.PHONY: live-test-playback-remote
live-test-playback-remote:
	@if [ -z "$(CONTENT_ID)" ]; then \
		echo "ERROR: CONTENT_ID is not set. Example: make live-test-playback-remote CONTENT_ID=1587417579"; \
		exit 1; \
	fi
	ROKU_DEV_TARGET=$(ROKU_TARGET) ROKIT_TARGET=$(ROKU_TARGET) pnpm roku:live launch-playback-remote $(CONTENT_ID) $(or $(MEDIA_TYPE),movie) $(or $(START_FROM),continue)

.PHONY: live-test-player-ui
live-test-player-ui:
	@if [ -z "$(AUDIO_CONTENT_ID)" ]; then \
		echo "ERROR: AUDIO_CONTENT_ID is not set. Example: make live-test-player-ui AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id>"; \
		exit 1; \
	fi
	@if [ -z "$(SUBTITLE_CONTENT_ID)" ]; then \
		echo "ERROR: SUBTITLE_CONTENT_ID is not set. Example: make live-test-player-ui AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id>"; \
		exit 1; \
	fi
	ROKU_DEV_TARGET=$(ROKU_TARGET) ROKIT_TARGET=$(ROKU_TARGET) pnpm roku:live player-ui-smoke $(AUDIO_CONTENT_ID) $(SUBTITLE_CONTENT_ID) $(or $(MEDIA_TYPE),movie) $(or $(START_FROM),continue)

.PHONY: live-test-player-ui-screenshots
live-test-player-ui-screenshots:
	@if [ -z "$(AUDIO_CONTENT_ID)" ]; then \
		echo "ERROR: AUDIO_CONTENT_ID is not set. Example: make live-test-player-ui-screenshots AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id>"; \
		exit 1; \
	fi
	@if [ -z "$(SUBTITLE_CONTENT_ID)" ]; then \
		echo "ERROR: SUBTITLE_CONTENT_ID is not set. Example: make live-test-player-ui-screenshots AUDIO_CONTENT_ID=<multi-audio-file-id> SUBTITLE_CONTENT_ID=<subtitle-file-id>"; \
		exit 1; \
	fi
	@ROKU_DEV_TARGET=$(ROKU_TARGET) ROKIT_TARGET=$(ROKU_TARGET) ROKU_DEV_PASSWORD="$(ROKU_PASSWORD)" ROKIT_PASSWORD="$(ROKU_PASSWORD)" PLAYER_UI_REFERENCE_IMAGE="$(PLAYER_UI_REFERENCE_IMAGE)" pnpm roku:live player-ui-screenshots $(AUDIO_CONTENT_ID) $(SUBTITLE_CONTENT_ID) $(or $(MEDIA_TYPE),movie) $(or $(START_FROM),continue) $(or $(OUTPUT_DIR),dist/tmp/player-ui)

.PHONY: live-test-launch
live-test-launch: launch

.PHONY: live-test-install
live-test-install: run launch
