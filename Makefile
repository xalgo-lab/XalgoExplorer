.PHONY: build run release app dmg clean

SWIFT_ENV = CLANG_MODULE_CACHE_PATH=$(CURDIR)/.build/module-cache

build:
	$(SWIFT_ENV) swift build

run:
	$(SWIFT_ENV) swift run xAlgoExplorer

release:
	$(SWIFT_ENV) swift build -c release

app: release
	./scripts/package-app.sh

dmg: app
	./scripts/package-dmg.sh

clean:
	swift package clean
	rm -rf dist
