#!/bin/bash
# Выпуск Tentakit: собирает универсальную версию и кладёт zip на сайт.
#   ./release.sh            → ../site/public/download/Tentakit.zip
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${VERSION:-0.11}"
OUT="../site/public/download"

APP_NAME=Tentakit BUNDLE_ID=app.tentakit UNIVERSAL=1 VERSION="$VERSION" ./build.sh

mkdir -p "$OUT"
rm -f "$OUT/Tentakit.zip"
ditto -c -k --keepParent build/Tentakit.app "$OUT/Tentakit.zip"
echo "$VERSION" > "$OUT/latest.txt"

lipo -archs build/Tentakit.app/Contents/MacOS/Tentakit
ls -lh "$OUT/Tentakit.zip"
echo "Выпуск $VERSION готов: $OUT/Tentakit.zip"
