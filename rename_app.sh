#!/bin/bash
# ============================================================
# Script đổi tên Flutter app: mediainfo_app → mediainfo_custom
# Chạy từ thư mục gốc của project: ~/mediainfo_app/
# ============================================================

set -e  # Dừng nếu có lỗi

echo "🔄 Bắt đầu đổi tên app: mediainfo_app → mediainfo_custom"
echo ""

# ── 1. pubspec.yaml ──────────────────────────────────────────
echo "📄 [1/8] pubspec.yaml"
sed -i 's/^name: mediainfo_app/name: mediainfo_custom/' pubspec.yaml
grep "^name:" pubspec.yaml

# ── 2. Android: applicationId & namespace ───────────────────
echo "📄 [2/8] android/app/build.gradle.kts"
sed -i 's/com\.local\.mediainfo_app/com.local.mediainfo_custom/g' android/app/build.gradle.kts
sed -i 's/com\.example\.mediainfo_app/com.example.mediainfo_custom/g' android/app/build.gradle.kts

echo "📄      android/app/src/main/AndroidManifest.xml"
sed -i 's/com\.local\.mediainfo_app/com.local.mediainfo_custom/g' android/app/src/main/AndroidManifest.xml
sed -i 's/com\.example\.mediainfo_app/com.example.mediainfo_custom/g' android/app/src/main/AndroidManifest.xml

echo "📄      android/app/src/debug/AndroidManifest.xml"
sed -i 's/com\.local\.mediainfo_app/com.local.mediainfo_custom/g' android/app/src/debug/AndroidManifest.xml
sed -i 's/com\.example\.mediainfo_app/com.example.mediainfo_custom/g' android/app/src/debug/AndroidManifest.xml

echo "📄      android/app/src/profile/AndroidManifest.xml"
sed -i 's/com\.local\.mediainfo_app/com.local.mediainfo_custom/g' android/app/src/profile/AndroidManifest.xml
sed -i 's/com\.example\.mediainfo_app/com.example.mediainfo_custom/g' android/app/src/profile/AndroidManifest.xml

# ── 3. Android: package folder (Kotlin) ─────────────────────
echo "📄 [3/8] Android Kotlin package folder"
OLD_KT_DIR="android/app/src/main/kotlin/com/local/mediainfo_app"
NEW_KT_DIR="android/app/src/main/kotlin/com/local/mediainfo_custom"
if [ -d "$OLD_KT_DIR" ]; then
    mkdir -p "android/app/src/main/kotlin/com/local/mediainfo_custom"
    mv "$OLD_KT_DIR/MainActivity.kt" "$NEW_KT_DIR/MainActivity.kt" 2>/dev/null || true
    rmdir "$OLD_KT_DIR" 2>/dev/null || true
    # Sửa package name bên trong file
    sed -i 's/package com\.local\.mediainfo_app/package com.local.mediainfo_custom/g' "$NEW_KT_DIR/MainActivity.kt"
    echo "   ✅ Đã di chuyển: $OLD_KT_DIR → $NEW_KT_DIR"
else
    echo "   ⚠️  Không tìm thấy $OLD_KT_DIR (bỏ qua)"
fi

# ── 4. Android: settings.gradle.kts ─────────────────────────
echo "📄 [4/8] android/settings.gradle.kts"
sed -i 's/mediainfo_app/mediainfo_custom/g' android/settings.gradle.kts

# ── 5. iOS: Bundle ID & display name ────────────────────────
echo "📄 [5/8] iOS Info.plist"
sed -i 's/mediainfo_app/mediainfo_custom/g' ios/Runner/Info.plist
sed -i 's/mediainfo-app/mediainfo-custom/g' ios/Runner/Info.plist

echo "📄      iOS project.pbxproj"
sed -i 's/mediainfo_app/mediainfo_custom/g' ios/Runner.xcodeproj/project.pbxproj

# ── 6. Linux: CMakeLists.txt ─────────────────────────────────
echo "📄 [6/8] linux/CMakeLists.txt"
sed -i 's/mediainfo_app/mediainfo_custom/g' linux/CMakeLists.txt
sed -i 's/mediainfo_app/mediainfo_custom/g' linux/runner/CMakeLists.txt 2>/dev/null || true

# ── 7. macOS ─────────────────────────────────────────────────
echo "📄 [7/8] macOS configs"
sed -i 's/mediainfo_app/mediainfo_custom/g' macos/Runner/Configs/AppInfo.xcconfig 2>/dev/null || true
sed -i 's/mediainfo_app/mediainfo_custom/g' macos/Runner.xcodeproj/project.pbxproj 2>/dev/null || true

# ── 8. Windows: CMakeLists.txt ───────────────────────────────
echo "📄 [8/8] windows/CMakeLists.txt"
sed -i 's/mediainfo_app/mediainfo_custom/g' windows/CMakeLists.txt
sed -i 's/mediainfo_app/mediainfo_custom/g' windows/runner/CMakeLists.txt 2>/dev/null || true

# ── Dọn dẹp build cache ──────────────────────────────────────
echo ""
echo "🧹 Xóa build cache..."
flutter clean

echo ""
echo "✅ Đổi tên hoàn tất!"
echo ""
echo "📋 Bước tiếp theo:"
echo "   flutter pub get"
echo "   flutter run"
echo ""
echo "⚠️  Lưu ý: Nếu dùng Android Studio / VS Code,"
echo "   hãy restart IDE sau khi chạy script này."
