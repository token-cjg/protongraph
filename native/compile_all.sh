#!/bin/bash

platform=$1
target=0
threads=0


if [ -z "$2" ]
  then
    target="release"
  else
    target=$2
fi

if [ -z "$3" ]
  then
    threads=2
  else
    threads=$3
fi



cd godot-cpp
scons -j${threads} bits=64 generate_bindings=yes debug_symbols=no platform=$platform target=$target

# Make sure that we add the mesh optimizer.  nb, not sure that this is required any more? https://github.com/godotengine/godot/pull/47764 , https://github.com/protongraph/protongraph/issues/101
cd ../thirdparty/mesh_optimizer
scons -j${threads} platform=$platform bits=64 debug_symbols=no target=$target

# Add kafka client support so that we can consume and produce to kafka topics on a (secured) kafka cluster or vm.
cd ../librdkafka
scons -j${threads} platform=$platform bits=64 debug_symbols=no target=$target
