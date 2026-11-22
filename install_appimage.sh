#!/bin/bash
set -e

APP=mediainfo-custom
BINARY=mediainfo_custom
VERSION=1.0.0
APPIMAGE="${APP}_${VERSION}_x86_64.AppImage"

if [ ! -f "$APPIMAGE" ]; then
    echo "❌ File not found: $APPIMAGE"
    echo "   Run ./build_appimage.sh first"
    exit 1
fi

INSTALL_DIR="$HOME/.local/bin"
ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"
DESKTOP_DIR="$HOME/.local/share/applications"
APPIMAGE_PATH="$(readlink -f "$APPIMAGE")"

mkdir -p "$INSTALL_DIR" "$ICON_DIR" "$DESKTOP_DIR"

echo "📋 Copying AppImage..."
cp "$APPIMAGE_PATH" "$INSTALL_DIR/$APP.AppImage"
chmod +x "$INSTALL_DIR/$APP.AppImage"

echo "🖼️  Copying icon..."
cp web/icons/Icon-512.png "$ICON_DIR/$APP.png"

echo "🖥️  Creating launcher..."
cat > "$DESKTOP_DIR/$APP.desktop" << DESKTOP
[Desktop Entry]
Name=MediaInfo Custom
Comment=Media file analyzer - image, video info and diff
Exec=$INSTALL_DIR/$APP.AppImage
Icon=$APP
Terminal=false
Type=Application
Categories=Utility;AudioVideo;
DESKTOP
chmod +x "$DESKTOP_DIR/$APP.desktop"

update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo ""
echo "✅ Done! Launcher: $DESKTOP_DIR/$APP.desktop"
echo "   Log out and back in if the icon does not appear in the launcher"
