#!/bin/bash
# ============================================================
# Build file .deb cho mediainfo_custom
# Chạy từ thư mục gốc project: ~/mediainfo_custom/
# ============================================================

set -e

APP=mediainfo-custom
VERSION=1.0.0
ARCH=amd64
BUNDLE=build/linux/x64/release/bundle
DEB_DIR=/tmp/${APP}_${VERSION}

echo "🔨 Build release trước..."
flutter build linux --release

echo "📦 Tạo cấu trúc .deb..."
rm -rf "$DEB_DIR"
mkdir -p "$DEB_DIR/DEBIAN"
mkdir -p "$DEB_DIR/usr/bin"
mkdir -p "$DEB_DIR/usr/lib/$APP"
mkdir -p "$DEB_DIR/usr/share/applications"
mkdir -p "$DEB_DIR/usr/share/icons/hicolor/256x256/apps"

# Copy toàn bộ bundle vào /usr/lib/
cp -r "$BUNDLE/." "$DEB_DIR/usr/lib/$APP/"

# Tạo launcher script trong /usr/bin/
cat > "$DEB_DIR/usr/bin/$APP" << LAUNCHER
#!/bin/bash
exec /usr/lib/$APP/mediainfo_custom "\$@"
LAUNCHER
chmod +x "$DEB_DIR/usr/bin/$APP"

# .desktop file
cat > "$DEB_DIR/usr/share/applications/$APP.desktop" << DESKTOP
[Desktop Entry]
Name=MediaInfo Custom
Comment=Media file analyzer - image, video info and diff
Exec=mediainfo_custom
Icon=mediainfo_custom
Terminal=false
Type=Application
Categories=Utility;AudioVideo;
DESKTOP

# Icon
mkdir -p "$DEB_DIR/usr/share/icons/hicolor/512x512/apps"
cp web/icons/Icon-512.png "$DEB_DIR/usr/share/icons/hicolor/512x512/apps/mediainfo_custom.png"
echo "✅ Icon: web/icons/Icon-512.png"

# Tính size
INSTALLED_SIZE=$(du -sk "$DEB_DIR/usr" | cut -f1)

# DEBIAN/control
cat > "$DEB_DIR/DEBIAN/control" << CONTROL
Package: $APP
Version: $VERSION
Architecture: $ARCH
Maintainer: shiroe <shiroe@local>
Installed-Size: $INSTALLED_SIZE
Depends: libgtk-3-0, libblkid1, liblzma5
Description: MediaInfo Custom
 Analyze image and video files.
 Shows file info, metadata, quality analysis, and diff between two images.
CONTROL

# postinst: update icon cache sau khi cài
cat > "$DEB_DIR/DEBIAN/postinst" << 'POSTINST'
#!/bin/bash
update-desktop-database /usr/share/applications/ 2>/dev/null || true
gtk-update-icon-cache /usr/share/icons/hicolor/ 2>/dev/null || true
POSTINST
chmod +x "$DEB_DIR/DEBIAN/postinst"

echo "📝 Đóng gói .deb..."
dpkg-deb --build --root-owner-group "$DEB_DIR" "${APP}_${VERSION}_${ARCH}.deb"

echo ""
echo "✅ Xong! File: ${APP}_${VERSION}_${ARCH}.deb"
echo ""
echo "Cài đặt:"
echo "  Double-click file .deb trong file manager"
echo "  hoặc: sudo dpkg -i ${APP}_${VERSION}_${ARCH}.deb"
