#!/bin/bash
# this doesn't quite work yet, issues with linux template path + working directory, including gdns and tres files.
docker build -f Dockerfile.compile . -t gcc-build
docker run --rm -v "$PWD":/usr/src/myapp -w /usr/src/myapp gcc-build make SHELL=/bin/bash
