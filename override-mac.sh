#!/bin/bash

ditto build/Products/Release/libAvalonia.Native.OSX.dylib /Library/Application\ Support/Microsoft/Grunt/Grunt.plugin/Contents/MacOS/libAvaloniaNative.dylib

for f in src/Avalonia.Native/bin/Debug/net6.0/*; do
  cp -fv "$f" "/Library/Application Support/Microsoft/Grunt/Grunt.plugin/Contents/MacOS/"
done
