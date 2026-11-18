#!/bin/bash
# Рисует иконку приложения и значок для строки меню из SVG в Resources/art.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
swiftc -O Tools/render_svg.swift -o build/render_svg
R=build/render_svg
rm -rf build/AppIcon.iconset && mkdir -p build/AppIcon.iconset
for s in 16 32 128 256 512; do
  $R Resources/art/icon.svg "build/AppIcon.iconset/icon_${s}x${s}.png" $s
  $R Resources/art/icon.svg "build/AppIcon.iconset/icon_${s}x${s}@2x.png" $((s*2))
done
iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
$R Resources/art/glyph.svg Resources/MenuIcon.png 18
$R Resources/art/glyph.svg Resources/MenuIcon@2x.png 36
echo "Иконки готовы"
