SHELL := /bin/bash

.PHONY: build run clean

build:
	./build.sh

run:
	./build/run.sh

clean:
	rm -rf source deps build
