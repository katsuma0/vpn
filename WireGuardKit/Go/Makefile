# SPDX-License-Identifier: MIT
#
# Copyright (C) 2018-2019 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.

# These are generally passed to us by xcode, but we set working defaults for standalone compilation too.
ARCHS ?= x86_64 arm64
PLATFORM_NAME ?= macosx
SDKROOT ?= $(shell xcrun --sdk $(PLATFORM_NAME) --show-sdk-path)
CONFIGURATION_BUILD_DIR ?= $(CURDIR)/out
CONFIGURATION_TEMP_DIR ?= $(CURDIR)/.tmp

# Xcode runs this with a bare PATH, and macOS's make (3.81) doesn't hand
# exported variables to $(shell ...). So we look for go ourselves, in the
# places Homebrew, the go.dev installer and `go install` put it.
GO_SEARCH_PATH := $(PATH):/opt/homebrew/bin:/usr/local/bin:/usr/local/go/bin:$(HOME)/go/bin
export PATH := $(GO_SEARCH_PATH)
GO := $(shell PATH="$(GO_SEARCH_PATH)" command -v go 2>/dev/null)
ifeq ($(GO),)
# Last resort: ask your login shell, which knows about mise, asdf and friends.
GO := $(shell /bin/zsh -lc 'command -v go' 2>/dev/null)
endif
export CC ?= clang
LIPO ?= lipo
DESTDIR ?= $(CONFIGURATION_BUILD_DIR)
BUILDDIR ?= $(CONFIGURATION_TEMP_DIR)/wireguard-go-bridge

CFLAGS_PREFIX := $(if $(DEPLOYMENT_TARGET_CLANG_FLAG_NAME),-$(DEPLOYMENT_TARGET_CLANG_FLAG_NAME)=$($(DEPLOYMENT_TARGET_CLANG_ENV_NAME)),) -isysroot $(SDKROOT) -arch
GOARCH_arm64 := arm64
GOARCH_x86_64 := amd64
GOOS_macosx := darwin
GOOS_iphoneos := ios

build: $(DESTDIR)/libwg-go.a
version-header: $(DESTDIR)/wireguard-go-version.h

REAL_GOROOT := $(if $(GO),$(shell PATH="$(GO_SEARCH_PATH)" "$(GO)" env GOROOT 2>/dev/null))
export GOROOT := $(BUILDDIR)/goroot
$(GOROOT)/.prepared:
	@if [ -z "$(GO)" ]; then echo "error: Go isn't installed, or it's somewhere Xcode can't see. Install it with: brew install go"; exit 1; fi
	@if [ -z "$(REAL_GOROOT)" ]; then echo "error: Found Go at $(GO) but 'go env GOROOT' failed. Try reinstalling it with: brew reinstall go"; exit 1; fi
	@echo "Using $(GO) from $(REAL_GOROOT)"
	mkdir -p "$(GOROOT)"
	rsync -a --delete --exclude=pkg/obj/go-build "$(REAL_GOROOT)/" "$(GOROOT)/"
	chmod -R u+w "$(GOROOT)"
	cat goruntime-*.diff | patch -p1 -f -N -r- -d "$(GOROOT)"
	touch "$@"

define libwg-go-a
$(BUILDDIR)/libwg-go-$(1).a: export CGO_ENABLED := 1
$(BUILDDIR)/libwg-go-$(1).a: export CGO_CFLAGS := $(CFLAGS_PREFIX) $(ARCH)
$(BUILDDIR)/libwg-go-$(1).a: export CGO_LDFLAGS := $(CFLAGS_PREFIX) $(ARCH)
$(BUILDDIR)/libwg-go-$(1).a: export GOOS := $(GOOS_$(PLATFORM_NAME))
$(BUILDDIR)/libwg-go-$(1).a: export GOARCH := $(GOARCH_$(1))
$(BUILDDIR)/libwg-go-$(1).a: $(GOROOT)/.prepared go.mod
	"$(GO)" build -ldflags=-w -trimpath -v -o "$(BUILDDIR)/libwg-go-$(1).a" -buildmode c-archive
	rm -f "$(BUILDDIR)/libwg-go-$(1).h"
endef
$(foreach ARCH,$(ARCHS),$(eval $(call libwg-go-a,$(ARCH))))

$(DESTDIR)/wireguard-go-version.h: go.mod $(GOROOT)/.prepared
	 sed -E -n 's/.*golang\.zx2c4\.com\/wireguard +v[0-9.]+-[0-9]+-([0-9a-f]{8})[0-9a-f]{4}.*/#define WIREGUARD_GO_VERSION "\1"/p' "$<" > "$@"

$(DESTDIR)/libwg-go.a: $(foreach ARCH,$(ARCHS),$(BUILDDIR)/libwg-go-$(ARCH).a)
	@mkdir -vp "$(DESTDIR)"
	$(LIPO) -create -output "$@" $^

clean:
	rm -rf "$(BUILDDIR)" "$(DESTDIR)/libwg-go.a" "$(DESTDIR)/wireguard-go-version.h"

install: build

.PHONY: clean build version-header install
