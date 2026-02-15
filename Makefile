.PHONY: build install clean

build:
	swiftc -O -o helper/iphone_event helper/iphone_event.swift -framework Cocoa

install: build
	python3 -m venv .venv
	.venv/bin/pip install -e .

clean:
	rm -f helper/iphone_event
	rm -rf .venv __pycache__ *.egg-info
