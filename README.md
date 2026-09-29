# mediainfo_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

dependencies:
  flutter:
    sdk: flutter
  file_picker: ^13.1.0
  exif: ^3.3.0
  crypto: ^3.0.7
  ffmpeg_kit_flutter: ^6.0.3
  image: ^4.10.1

Desktop: dùng ffprobe nếu tìm thấy (đọc được mọi container: mp4, mkv, avi, webm...).
Fallback (desktop không có ffprobe, và cả mobile): parser MP4/MOV viết bằng Dart thuần, chỉ đọc box moov nên file video vài GB vẫn nhanh.
Kết quả hiện thành 2 section mới: === Video === (thông tin chi tiết) và dòng Quality (cùng format với ảnh, có kèm sha256).

