#!/usr/bin/env bash
# This bash script builds the mGBA xcframework for iOS/iOS frontend.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
BUILD_DIR_DEVICE="${ROOT_DIR}/build/ios-device"
BUILD_DIR_SIM="${ROOT_DIR}/build/ios-sim"
OUT_DIR="${ROOT_DIR}/src/platform/ios/Frameworks"
PRODUCT_NAME="mgba"

rm -rf "${BUILD_DIR_DEVICE}" "${BUILD_DIR_SIM}"
mkdir -p "${BUILD_DIR_DEVICE}" "${BUILD_DIR_SIM}" "${OUT_DIR}"

# Device (arm64)
cmake -S "${ROOT_DIR}" -B "${BUILD_DIR_DEVICE}" -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=18.0 \
  -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO \
  -DCMAKE_XCODE_ATTRIBUTE_DEBUG_INFORMATION_FORMAT="dwarf-with-dsym" \
  -DLIBMGBA_ONLY=ON -DBUILD_STATIC=ON -DBUILD_SHARED=OFF \
  -DBUILD_QT=OFF -DBUILD_SDL=OFF -DBUILD_HEADLESS=OFF \
  -DBUILD_GL=OFF -DBUILD_GLES2=ON -DBUILD_GLES3=OFF \
  -DENABLE_DIRECTORIES=ON -DENABLE_VFS=ON -DCMAKE_BUILD_TYPE=Debug

cmake --build "${BUILD_DIR_DEVICE}" --config Debug --target mgba

# Simulator (arm64 + x86_64)
cmake -S "${ROOT_DIR}" -B "${BUILD_DIR_SIM}" -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=18.0 \
  -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO \
  -DCMAKE_XCODE_ATTRIBUTE_DEBUG_INFORMATION_FORMAT="dwarf-with-dsym" \
  -DCMAKE_OSX_SYSROOT="iphonesimulator" \
  -DLIBMGBA_ONLY=ON -DBUILD_STATIC=ON -DBUILD_SHARED=OFF \
  -DBUILD_QT=OFF -DBUILD_SDL=OFF -DBUILD_HEADLESS=OFF \
  -DBUILD_GL=OFF -DBUILD_GLES2=ON -DBUILD_GLES3=OFF \
  -DENABLE_DIRECTORIES=ON -DENABLE_VFS=ON -DCMAKE_BUILD_TYPE=Debug

cmake --build "${BUILD_DIR_SIM}" --config Debug --target mgba

DEVICE_LIB="${BUILD_DIR_DEVICE}/Debug-iphoneos/libmgba.a"
SIM_LIB="${BUILD_DIR_SIM}/Debug-iphonesimulator/libmgba.a"

# Stage per-slice headers including generated flags.h
STAGE_DEVICE_HEADERS="${BUILD_DIR_DEVICE}/stage-headers"
STAGE_SIM_HEADERS="${BUILD_DIR_SIM}/stage-headers"
rm -rf "${STAGE_DEVICE_HEADERS}" "${STAGE_SIM_HEADERS}"
mkdir -p "${STAGE_DEVICE_HEADERS}" "${STAGE_SIM_HEADERS}"
rsync -a "${ROOT_DIR}/include/" "${STAGE_DEVICE_HEADERS}/"
rsync -a "${ROOT_DIR}/include/" "${STAGE_SIM_HEADERS}/"
# Overwrite flags.h with the slice-specific generated one
if [ -f "${BUILD_DIR_DEVICE}/include/mgba/flags.h" ]; then
  mkdir -p "${STAGE_DEVICE_HEADERS}/mgba"
  cp "${BUILD_DIR_DEVICE}/include/mgba/flags.h" "${STAGE_DEVICE_HEADERS}/mgba/flags.h"
fi
if [ -f "${BUILD_DIR_SIM}/include/mgba/flags.h" ]; then
  mkdir -p "${STAGE_SIM_HEADERS}/mgba"
  cp "${BUILD_DIR_SIM}/include/mgba/flags.h" "${STAGE_SIM_HEADERS}/mgba/flags.h"
fi

rm -rf "${OUT_DIR}/mGBA.xcframework"
xcodebuild -create-xcframework \
  -library "${DEVICE_LIB}" -headers "${STAGE_DEVICE_HEADERS}" \
  -library "${SIM_LIB}" -headers "${STAGE_SIM_HEADERS}" \
  -output "${OUT_DIR}/mGBA.xcframework"

echo "Built xcframework at ${OUT_DIR}/mGBA.xcframework"


