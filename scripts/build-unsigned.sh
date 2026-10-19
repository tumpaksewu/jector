#!/bin/sh
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"
output_dir=${1:-"$project_root/dist"}
mkdir -p "$output_dir" work
./Inference/prepare-runtime.sh
xcodegen generate
xcodebuild -project Jector.xcodeproj -scheme Jector -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath work/unsigned-build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= \
  DEVELOPMENT_TEAM= build > work/unsigned-build.log 2>&1
app="$project_root/work/unsigned-build/Build/Products/Release-iphoneos/Jector.app"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Info.plist")
uv run scripts/package_unsigned.py "$app" "$output_dir/Jector-v$version-unsigned.ipa"
