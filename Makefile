SWIFT_SOURCES := Package.swift Sources Tests
SWIFT_CHECK_FLAGS := -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete

.PHONY: build check format format-check lint lint-format lint-swiftlint resolve test

check: lint build test

build:
	swift build $(SWIFT_CHECK_FLAGS) --product fluidaudio

resolve:
	swift package resolve

format:
	swift format format --in-place --parallel --recursive $(SWIFT_SOURCES)

format-check: lint-format

lint: lint-format lint-swiftlint

lint-format:
	swift format lint --strict --parallel --recursive $(SWIFT_SOURCES)

lint-swiftlint: resolve
	swift package plugin --allow-writing-to-package-directory swiftlint

test:
	swift test $(SWIFT_CHECK_FLAGS) --parallel
