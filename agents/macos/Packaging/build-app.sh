#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(tr -d '[:space:]' < VERSION)"
APP=.build/Curfew.app
ZIP=.build/Curfew.zip
ICONSET=.build/AppIcon.iconset
PLUGIN="$APP/Contents/Resources/CurfewLogin.bundle"
ARCHS=(--arch arm64 --arch x86_64)

swift build -c release "${ARCHS[@]}" --product curfew
swift build -c release "${ARCHS[@]}" --product CurfewApp
BIN="$(swift build -c release "${ARCHS[@]}" --show-bin-path)"

rm -rf "$APP" "$ZIP" "$ICONSET"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ICONSET"
cp "$BIN/CurfewApp" "$APP/Contents/MacOS/Curfew"
cp "$BIN/curfew" "$APP/Contents/Resources/curfew"
strip -x "$APP/Contents/MacOS/Curfew" "$APP/Contents/Resources/curfew"
cp -R Resources/Fonts Resources/Licenses "$APP/Contents/Resources/"

mkdir -p "$PLUGIN/Contents/MacOS"
clang -bundle -O2 -Wall -Wextra -Werror -arch arm64 -arch x86_64 -mmacosx-version-min=14.0 -fvisibility=hidden \
  -I Sources/CurfewLogin/include Sources/CurfewLogin/*.c \
  -framework Security -framework CoreFoundation -framework SystemConfiguration \
  -o "$PLUGIN/Contents/MacOS/CurfewLogin"
strip -x "$PLUGIN/Contents/MacOS/CurfewLogin"
cat > "$PLUGIN/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>com.rafay99.curfew.login</string>
  <key>CFBundleName</key>
  <string>CurfewLogin</string>
  <key>CFBundleExecutable</key>
  <string>CurfewLogin</string>
  <key>CFBundlePackageType</key>
  <string>BNDL</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
</dict>
</plist>
PLIST
plutil -lint "$PLUGIN/Contents/Info.plist" > /dev/null

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" Packaging/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" > /dev/null
  sips -z "$((size * 2))" "$((size * 2))" Packaging/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" > /dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>com.rafay99.curfew</string>
  <key>CFBundleName</key>
  <string>Curfew</string>
  <key>CFBundleDisplayName</key>
  <string>Curfew</string>
  <key>CFBundleExecutable</key>
  <string>Curfew</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST
plutil -lint "$APP/Contents/Info.plist" > /dev/null
printf 'APPL????' > "$APP/Contents/PkgInfo"

codesign --force -s - "$PLUGIN"
codesign --force -s - --identifier com.rafay99.curfew.agent "$APP/Contents/Resources/curfew"
codesign --force --deep -s - "$APP"
codesign --verify --deep --strict "$APP"

ditto -c -k --keepParent "$APP" "$ZIP"

echo "Curfew $VERSION"
lipo -archs "$APP/Contents/MacOS/Curfew"
lipo -archs "$APP/Contents/Resources/curfew"
lipo -archs "$PLUGIN/Contents/MacOS/CurfewLogin"
du -sh "$APP" "$ZIP"
shasum -a 256 "$ZIP"
