#!/bin/bash

set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_NAME="${PROJECT_NAME:-IPificationSDK}"
BUILD_DIR="${PROJECT_DIR}/build"
DEVICE_ARCHIVE="${BUILD_DIR}/${PROJECT_NAME}-iphoneos.xcarchive"
SIMULATOR_ARCHIVE="${BUILD_DIR}/${PROJECT_NAME}-iossimulator.xcarchive"
DEVICE_FRAMEWORK="${DEVICE_ARCHIVE}/Products/Library/Frameworks/${PROJECT_NAME}.framework"
SIMULATOR_FRAMEWORK="${SIMULATOR_ARCHIVE}/Products/Library/Frameworks/${PROJECT_NAME}.framework"
DEVICE_DSYM="${DEVICE_ARCHIVE}/dSYMs/${PROJECT_NAME}.framework.dSYM"
SIMULATOR_DSYM="${SIMULATOR_ARCHIVE}/dSYMs/${PROJECT_NAME}.framework.dSYM"
XCFRAMEWORK="${BUILD_DIR}/${PROJECT_NAME}.xcframework"
ZIP_PATH="${BUILD_DIR}/${PROJECT_NAME}.xcframework.zip"
DSYM_DIR="${BUILD_DIR}/${PROJECT_NAME}.dSYMs"
DSYM_ZIP_PATH="${BUILD_DIR}/${PROJECT_NAME}.dSYMs.zip"

COMMON_SETTINGS=(
  SKIP_INSTALL=NO
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES
  ENABLE_BITCODE=NO
  CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO
  DEBUG_INFORMATION_FORMAT=dwarf-with-dsym
  STRIP_INSTALLED_PRODUCT=YES
  COPY_PHASE_STRIP=YES
  DEPLOYMENT_POSTPROCESSING=YES
  SWIFT_COMPILATION_MODE=wholemodule
  SWIFT_OPTIMIZATION_LEVEL=-Osize
  DEAD_CODE_STRIPPING=YES
  STRIP_STYLE=non-global
)

rm -rf "$DEVICE_ARCHIVE" "$SIMULATOR_ARCHIVE" "$XCFRAMEWORK" "$ZIP_PATH" "$DSYM_DIR" "$DSYM_ZIP_PATH"
mkdir -p "$BUILD_DIR"

xcodebuild archive \
  -project "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj" \
  -scheme "$PROJECT_NAME" \
  -configuration Release \
  -archivePath "$DEVICE_ARCHIVE" \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  ARCHS=arm64 \
  "${COMMON_SETTINGS[@]}"

xcodebuild archive \
  -project "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj" \
  -scheme "$PROJECT_NAME" \
  -configuration Release \
  -archivePath "$SIMULATOR_ARCHIVE" \
  -sdk iphonesimulator \
  -destination "generic/platform=iOS Simulator" \
  "${COMMON_SETTINGS[@]}"

for framework in "$DEVICE_FRAMEWORK" "$SIMULATOR_FRAMEWORK"; do
  module_dir="${framework}/Modules/${PROJECT_NAME}.swiftmodule"
  rm -rf "${module_dir}/Project"
  rm -f "${module_dir}"/*.abi.json "${module_dir}"/*.private.swiftinterface
  rm -rf "${framework}/_CodeSignature"
  find "$framework" -name .DS_Store -delete
  strip -x "${framework}/${PROJECT_NAME}" || true
done

# Debug symbols are shipped as a separate archive so the xcframework zip
# that integrators download only contains the frameworks.
xcodebuild -create-xcframework \
  -framework "$DEVICE_FRAMEWORK" \
  -framework "$SIMULATOR_FRAMEWORK" \
  -output "$XCFRAMEWORK"

find "$XCFRAMEWORK" -name .DS_Store -delete
ditto -c -k --sequesterRsrc --keepParent "$XCFRAMEWORK" "$ZIP_PATH"

mkdir -p "${DSYM_DIR}/ios-arm64" "${DSYM_DIR}/ios-arm64_x86_64-simulator"
cp -R "$DEVICE_DSYM" "${DSYM_DIR}/ios-arm64/"
cp -R "$SIMULATOR_DSYM" "${DSYM_DIR}/ios-arm64_x86_64-simulator/"
find "$DSYM_DIR" -name .DS_Store -delete
ditto -c -k --sequesterRsrc --keepParent "$DSYM_DIR" "$DSYM_ZIP_PATH"

device_size=$(stat -f%z "${DEVICE_FRAMEWORK}/${PROJECT_NAME}")
simulator_size=$(stat -f%z "${SIMULATOR_FRAMEWORK}/${PROJECT_NAME}")
zip_size=$(stat -f%z "$ZIP_PATH")
dsym_zip_size=$(stat -f%z "$DSYM_ZIP_PATH")

echo "Created $ZIP_PATH"
echo "Created $DSYM_ZIP_PATH"
echo "Zip: $zip_size bytes; device: $device_size bytes; simulator: $simulator_size bytes; dSYMs zip: $dsym_zip_size bytes"
