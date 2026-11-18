#!/bin/bash
# Сборка приложения без Xcode (нужны только Command Line Tools).
#
#   ./build.sh                     — Tentakit для этого Mac
#   APP_NAME=Tentakit BUNDLE_ID=app.tentakit UNIVERSAL=1 ./build.sh
#                                  — Tentakit для всех Mac (Apple Silicon + Intel)
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="${APP_NAME:-Tentakit}"
BUNDLE_ID="${BUNDLE_ID:-app.tentakit}"
VERSION="${VERSION:-0.11}"
UNIVERSAL="${UNIVERSAL:-0}"

APP="build/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

compile() {  # $1 = архитектура, $2 = куда положить бинарник
  swiftc -O -swift-version 5 \
    -target "$1-apple-macos13.0" \
    Sources/*.swift Sources/UI/*.swift \
    -o "$2"
}

if [ "$UNIVERSAL" = "1" ]; then
  mkdir -p build/arch
  compile arm64  build/arch/arm64
  compile x86_64 build/arch/x86_64
  lipo -create build/arch/arm64 build/arch/x86_64 -output "$APP/Contents/MacOS/$APP_NAME"
else
  compile "$(uname -m)" "$APP/Contents/MacOS/$APP_NAME"
fi

# Иконки рисуются из SVG (Resources/art) скриптом Tools/make_icons.sh.
[ -f Resources/AppIcon.icns ] && [ -f Resources/MenuIcon.png ] || Tools/make_icons.sh
cp Resources/AppIcon.icns Resources/MenuIcon.png Resources/MenuIcon@2x.png "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Подпись: своим сертификатом (тогда macOS помнит доступ между обновлениями),
# а если его нет — временной подписью.
IDENTITY="MacTools Local Signing"
if security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
  codesign --force --sign "$IDENTITY" "$APP"
else
  echo "Сертификат «$IDENTITY» не найден, подписываю временной подписью"
  codesign --force --sign - "$APP"
fi
echo "Готово: $APP"
