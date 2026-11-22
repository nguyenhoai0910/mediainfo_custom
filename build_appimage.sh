#!/bin/bash
set -e

APP=mediainfo-custom
BINARY=mediainfo_custom
VERSION=1.0.0
BUNDLE=build/linux/x64/release/bundle
APPDIR=/tmp/${APP}.AppDir
TOOL=appimagetool-x86_64.AppImage

echo "🔨 Building release..."
flutter build linux --release

if [ ! -f "$TOOL" ]; then
    echo "⬇️  Downloading appimagetool..."
    wget -q -L \
        "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage" \
        -O "$TOOL"
fi
chmod +x "$TOOL"

echo "📦 Creating AppDir..."
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/share/applications"
mkdir -p "$APPDIR/usr/share/icons/hicolor/512x512/apps"

cp -r "$BUNDLE/." "$APPDIR/usr/bin/"

cp web/icons/Icon-512.png "$APPDIR/$APP.png"
cp web/icons/Icon-512.png "$APPDIR/.DirIcon"
cp web/icons/Icon-512.png "$APPDIR/usr/share/icons/hicolor/512x512/apps/$APP.png"

cat > "$APPDIR/$APP.desktop" << DESKTOP
[Desktop Entry]
Name=MediaInfo Custom
Comment=Media file analyzer - image, video info and diff
Exec=$BINARY
Icon=$APP
Terminal=false
Type=Application
Categories=Utility;AudioVideo;
DESKTOP
cp "$APPDIR/$APP.desktop" "$APPDIR/usr/share/applications/"

cat > "$APPDIR/AppRun" << 'APPRUN'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
export LD_LIBRARY_PATH="$HERE/usr/bin/lib:$LD_LIBRARY_PATH"
exec "$HERE/usr/bin/mediainfo_custom" "$@"
APPRUN
chmod +x "$APPDIR/AppRun"

echo "📝 Packaging AppImage..."
ARCH=x86_64 ./"$TOOL" --appimage-extract-and-run "$APPDIR" "${APP}_${VERSION}_x86_64.AppImage"
chmod +x "${APP}_${VERSION}_x86_64.AppImage"

echo ""
echo "✅ Done! File: ${APP}_${VERSION}_x86_64.AppImage"
echo ""
echo "Run:"
echo "  chmod +x ${APP}_${VERSION}_x86_64.AppImage"
echo "  ./${APP}_${VERSION}_x86_64.AppImage"
echo ""
echo "Or double-click in the file manager"
echo "(requires: sudo apt install libfuse2)"