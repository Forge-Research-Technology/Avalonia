#!/bin/bash

for f in src/Avalonia.Desktop/bin/Release/net6.0/*; do
  cp -fv "$f" "/Library/Application Support/Microsoft/Grunt/Grunt.plugin/Contents/MacOS/"
done

ditto build/Products/Release/libAvalonia.Native.OSX.dylib /Library/Application\ Support/Microsoft/Grunt/Grunt.plugin/Contents/MacOS/libAvaloniaNative.dylib
