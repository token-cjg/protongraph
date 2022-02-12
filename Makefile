CHECK_FILES+=

DOC_FILES+=	README.md

PKGNAME?=	protongraph
VERSION?=	0.0.1

# Jenkins CI integration
BUILD_NUMBER ?= 1

# Skip copyright check in the following paths
MKL_COPYRIGHT_SKIP?=^(tests|packaging)

OUTPUT= main

define RUN_CMAKE
	echo $(1) && mkdir $(1)/build && cd $(1)/build && cmake .. && cd -
endef

.PHONY:

all: mklove-check compile package

include mklove/Makefile.base

kafka: mklove-check compile-kafka package

package:
	mkdir -p bin/protongraph.app/Contents/MacOS/ || echo "build directory already exists"
	rm -r bin/protongraph.app/Contents/MacOS/secrets || echo "kafka secrets not found"
	cp -rf build/osx/protongraph.app bin
	cp bin/$(OUTPUT) bin/protongraph.app/Contents/MacOS/
	cp config/kafka.config bin/protongraph.app/Contents/MacOS/config
	cp -rf config/secrets bin/protongraph.app/Contents/MacOS/config
	cp native/thirdparty/librdkafka/bin/librdkafka.1.dylib bin/protongraph.app/Contents/MacOS/
	cp native/thirdparty/librdkafka/bin/librdkafka.dylib bin/protongraph.app/Contents/MacOS/
	cp native/thirdparty/mesh_optimizer/bin/libmeshoptimizer.dylib bin/protongraph.app/Contents/MacOS/
	install_name_tool -change /usr/local/lib/librdkafka.1.dylib @executable_path/librdkafka.1.dylib bin/protongraph.app/Contents/MacOS/main
	install_name_tool -change /usr/local/lib/libmeshoptimizer.dylib @executable_path/libmeshoptimizer.dylib bin/protongraph.app/Contents/MacOS/main	

compile:
	./native/compile_all.sh osx
