#!/bin/sh
set -eu
cd "$(dirname "$0")"
if [ -d Artifacts/llama.xcframework ]; then exit 0; fi
runtime_tmp=$(mktemp -d)
trap 'rm -rf "$runtime_tmp"' EXIT
curl --fail --location --retry 3 \
  https://github.com/ggml-org/llama.cpp/releases/download/b11734/llama-b11734-xcframework.zip \
  -o "$runtime_tmp/llama.zip"
printf '%s  %s\n' 89457e336c7ad85048d03b1a2f6500cdadad0bdfef9a1aaedb9e0a4f19ea4b86 "$runtime_tmp/llama.zip" | shasum -a 256 -c -
unzip -q "$runtime_tmp/llama.zip" -d "$runtime_tmp/unpacked"
mkdir -p Artifacts
mv "$runtime_tmp/unpacked/build-apple/llama.xcframework" Artifacts/
