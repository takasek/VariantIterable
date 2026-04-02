.PHONY: test format lint-format

test:
	swift test

format:
	swift-format format --recursive --in-place Sources Tests

lint-format:
	swift-format lint --recursive Sources Tests
