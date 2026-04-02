.PHONY: test format lint-format

test:
	swift test

format:
	xcrun swift-format format --recursive --in-place Sources Tests

lint-format:
	xcrun swift-format lint --recursive Sources Tests
