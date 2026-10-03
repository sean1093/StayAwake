#!/usr/bin/env bash
# 編譯 universal（arm64 + x86_64）release 版，組成 build/StayAwake.app 並做 ad-hoc 簽章，
# 再打包成 build/StayAwake.zip（GitHub Release 上傳的就是這個檔案）。
#
# 用法：./build.sh [版本]，例如 ./build.sh 1.2.0 或 ./build.sh v1.2.0（也可用 VERSION 環境變數）。
# 沒給版本就沿用 Info.plist 裡的值。
set -euo pipefail
cd "$(dirname "$0")"

version="${1:-${VERSION:-}}"
version="${version#v}"
if [[ -n "$version" && ! "$version" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    echo "Invalid version '$version' (expected e.g. 1.2.0)" >&2
    exit 1
fi

app="build/StayAwake.app"
rm -rf build
mkdir -p "$app/Contents/MacOS"

binaries=()
for arch in arm64 x86_64; do
    # 每個架構用獨立的 scratch path；共用 .build 時切換 --arch 會讓 SwiftPM 的建置快取錯亂。
    flags=(-c release --arch "$arch" --scratch-path ".build/$arch")
    swift build "${flags[@]}"
    binaries+=("$(swift build "${flags[@]}" --show-bin-path)/StayAwake")
done
lipo -create "${binaries[@]}" -output "$app/Contents/MacOS/StayAwake"
cp Info.plist "$app/Contents/Info.plist"
if [[ -n "$version" ]]; then
    plutil -replace CFBundleShortVersionString -string "$version" "$app/Contents/Info.plist"
    plutil -replace CFBundleVersion -string "$version" "$app/Contents/Info.plist"
fi
codesign --force --sign - "$app"
# 不帶 extended attributes（例如 com.apple.provenance），避免 zip 裡出現 ._ 檔，
# 用一般 unzip 解壓時才不會多出檔案、破壞簽章。
ditto -c -k --norsrc --noextattr --keepParent "$app" build/StayAwake.zip

built_version=$(plutil -extract CFBundleShortVersionString raw "$app/Contents/Info.plist")
echo "Built $app $built_version and build/StayAwake.zip"
