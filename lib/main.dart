import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:exif/exif.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'dart:convert';
import 'dart:io';
import 'dart:math'; // cho sqrt(), pow()

void main() {
  runApp(const MediaInfoApp());
}

class MediaInfoApp extends StatelessWidget {
  const MediaInfoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediaInfo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF00),
          surface: Color(0xFF2D2D2D),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _output = '';
  String? _file1;
  String? _file2;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickFile({bool isFile2 = false}) async {
    final result = await FilePicker.pickFiles();
    if (result == null) return;
    final path = result.single.path!;
    setState(() {
      if (isFile2) {
        _file2 = path;
      } else {
        _file1 = path;
      }
    });
  }

  String _basename(String path) => path.split('/').last;

  Widget _buildPhotoTab() {
    return _buildSingleFileTab(isVideo: false);
  }

  Widget _buildVideoTab() {
    return _buildSingleFileTab(isVideo: true);
  }

  Widget _buildSingleFileTab({required bool isVideo}) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3C3C3C),
                  foregroundColor: const Color(0xFF00FF00),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onPressed: _loading ? null : () => _pickFile(),
                child: const Text('[ Select file ]',
                    style: TextStyle(fontFamily: 'monospace')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _file1 != null ? _basename(_file1!) : 'No file selected',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFFCCCCCC),
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004400),
              foregroundColor: const Color(0xFF00FF00),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onPressed: (_loading || _file1 == null)
                ? null
                : () => _analyze(isVideo: isVideo),
            child: Text(
              _loading ? '[ Processing... ]' : '[ Analyze ]',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildOutputBox()),
        ],
      ),
    );
  }

  Widget _buildDiffTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3C3C3C),
                  foregroundColor: const Color(0xFF00FF00),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onPressed: _loading ? null : () => _pickFile(),
                child: const Text('[ File 1 ]',
                    style: TextStyle(fontFamily: 'monospace')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _file1 != null ? _basename(_file1!) : 'Not selected',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFFCCCCCC),
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3C3C3C),
                  foregroundColor: const Color(0xFF00FF00),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onPressed: _loading ? null : () => _pickFile(isFile2: true),
                child: const Text('[ File 2 ]',
                    style: TextStyle(fontFamily: 'monospace')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _file2 != null ? _basename(_file2!) : 'Not selected',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFFCCCCCC),
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004400),
              foregroundColor: const Color(0xFF00FF00),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onPressed: (_loading || _file1 == null || _file2 == null)
                ? null
                : _runDiff,
            child: Text(
              _loading ? '[ Processing... ]' : '[ Compare ]',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildOutputBox()),
        ],
      ),
    );
  }

  Widget _buildOutputBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        border: Border.all(color: const Color(0xFF444444)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          _output.isEmpty ? '// Output will appear here' : _output,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: _output.isEmpty
                ? const Color(0xFF555555)
                : const Color(0xFF00FF00),
            height: 1.6,
          ),
        ),
      ),
    );
  }

  Future<void> _analyze({required bool isVideo}) async {
    setState(() {
      _loading = true;
      _output = '';
    });
    try {
      // Không dùng compute() vì desktop cần gọi Process (không isolate-safe)
      final result = await _analyzeFile(_file1!);
      setState(() {
        _loading = false;
        _output = result;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _output = '// Error: $e';
      });
    }
  }

  Future<void> _runDiff() async {
    setState(() {
      _loading = true;
      _output = '';
    });
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      _loading = false;
      _output = '// Feature under development';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text(
          'mediainfo',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 16,
            color: Color(0xFF00FF00),
            letterSpacing: 2,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontFamily: 'monospace'),
          tabs: const [
            Tab(text: 'PHOTO'),
            Tab(text: 'VIDEO'),
            Tab(text: 'DIFF'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPhotoTab(),
          _buildVideoTab(),
          _buildDiffTab(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ANALYZE ENTRY POINT — routing theo platform
// ═══════════════════════════════════════════════════════════

Future<String> _analyzeFile(String filePath) async {
  if (Platform.isAndroid || Platform.isIOS) {
    return _analyzeFileMobile(filePath);
  } else {
    return _analyzeFileDesktop(filePath);
  }
}

// ═══════════════════════════════════════════════════════════
// SHARED HELPERS
// ═══════════════════════════════════════════════════════════

// Các extension ảnh / video phổ biến
const _imageExts = {'.jpg', '.jpeg', '.png', '.heic', '.webp', '.tiff', '.tif', '.bmp', '.gif'};
const _videoExts = {'.mp4', '.mov', '.avi', '.mkv', '.m4v', '.wmv', '.flv', '.webm', '.3gp'};

String _ext(String filePath) =>
    filePath.contains('.') ? '.${filePath.split('.').last.toLowerCase()}' : '';

String _basename(String filePath) => filePath.split(Platform.pathSeparator).last;

// Thông tin file hệ thống (dùng chung mọi platform)
Future<void> _addFileInfo(StringBuffer buf, String filePath) async {
  try {
    final file = File(filePath);
    final stat = await file.stat();
    final bytes = await file.readAsBytes();
    final hash = sha256.convert(bytes);

    buf.writeln('=== File ===');
    buf.writeln('Name     : ${_basename(filePath)}');
    buf.writeln('Size     : ${_formatSize(stat.size)}');
    buf.writeln('Modified : ${stat.modified}');
    buf.writeln('SHA256   : $hash');
  } catch (e) {
    buf.writeln('// File info error: $e');
  }
}

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

// ═══════════════════════════════════════════════════════════
// MOBILE — Android / iOS
// ═══════════════════════════════════════════════════════════

Future<String> _analyzeFileMobile(String filePath) async {
  final buf = StringBuffer();
  await _addFileInfo(buf, filePath);

  final ext = _ext(filePath);

  if (_imageExts.contains(ext)) {
    await _mobileAnalyzeImage(buf, filePath);
  } else if (_videoExts.contains(ext)) {
    await _mobileAnalyzeVideo(buf, filePath);
  } else {
    buf.writeln('');
    buf.writeln('// Unsupported file type: $ext');
  }

  return buf.toString();
}

// ── Ảnh (mobile) ────────────────────────────────────────
Future<void> _mobileAnalyzeImage(StringBuffer buf, String filePath) async {
  // 1. Kích thước ảnh bằng package image
  try {
    final bytes = await File(filePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded != null) {
      buf.writeln('');
      buf.writeln('=== Image ===');
      buf.writeln('Width    : ${decoded.width} px');
      buf.writeln('Height   : ${decoded.height} px');
      buf.writeln('Format   : ${_ext(filePath).toUpperCase().replaceAll('.', '')}');
    }
  } catch (e) {
    buf.writeln('// Image decode error: $e');
  }

  // 2. EXIF đầy đủ
  try {
    final bytes = await File(filePath).readAsBytes();
    final exifData = await readExifFromBytes(bytes);

    buf.writeln('');
    buf.writeln('=== EXIF ===');

    if (exifData.isEmpty) {
      buf.writeln('No EXIF data found');
      return;
    }

    // Nhóm theo category để dễ đọc
    final groups = <String, Map<String, String>>{
      'Camera'    : {},
      'Settings'  : {},
      'GPS'       : {},
      'Date'      : {},
      'Software'  : {},
      'Other'     : {},
    };

    for (final entry in exifData.entries) {
      final key = entry.key;
      final val = entry.value.toString();

      if (key.contains('Make') || key.contains('Model') || key.contains('LensMake') || key.contains('LensModel')) {
        groups['Camera']![key] = val;
      } else if (key.startsWith('GPS')) {
        groups['GPS']![key] = val;
      } else if (key.contains('DateTime') || key.contains('Date')) {
        groups['Date']![key] = val;
      } else if (key.contains('Software') || key.contains('Artist') || key.contains('Copyright')) {
        groups['Software']![key] = val;
      } else if (key.contains('Exposure') || key.contains('ISO') || key.contains('FNumber') ||
                 key.contains('Focal') || key.contains('Flash') || key.contains('White') ||
                 key.contains('Metering') || key.contains('Scene') || key.contains('Shutter')) {
        groups['Settings']![key] = val;
      } else {
        groups['Other']![key] = val;
      }
    }

    for (final group in groups.entries) {
      if (group.value.isEmpty) continue;
      buf.writeln('');
      buf.writeln('--- ${group.key} ---');
      for (final e in group.value.entries) {
        buf.writeln('${e.key.padRight(35)}: ${e.value}');
      }
    }
  } catch (e) {
    buf.writeln('// EXIF error: $e');
  }

  // Thêm dòng này ở cuối:
  await _analyzeQuality(buf, filePath);

}

// ── Video (mobile) — FFprobe ────────────────────────────
Future<void> _mobileAnalyzeVideo(StringBuffer buf, String filePath) async {
  buf.writeln('');
  buf.writeln('=== Video ===');

  // Uncomment khi đã thêm ffmpeg_kit_flutter vào pubspec:
  //
  // import 'package:ffmpeg_kit_flutter/ffprobe_kit.dart';
  // import 'package:ffmpeg_kit_flutter/media_information_session.dart';
  //
  // try {
  //   final session = await FFprobeKit.getMediaInformation(filePath);
  //   final info = session.getMediaInformation();
  //   if (info != null) {
  //     buf.writeln('Duration : ${info.getDuration()} s');
  //     buf.writeln('Bit Rate : ${info.getBitrate()} bps');
  //     buf.writeln('Format   : ${info.getFormat()}');
  //     for (final stream in info.getStreams() ?? []) {
  //       if (stream.getType() == 'video') {
  //         buf.writeln('');
  //         buf.writeln('--- Video Stream ---');
  //         buf.writeln('Codec    : ${stream.getCodec()}');
  //         buf.writeln('Size     : ${stream.getWidth()}x${stream.getHeight()}');
  //         buf.writeln('FPS      : ${stream.getRealFrameRate()}');
  //         buf.writeln('Bitrate  : ${stream.getBitrate()}');
  //       }
  //       if (stream.getType() == 'audio') {
  //         buf.writeln('');
  //         buf.writeln('--- Audio Stream ---');
  //         buf.writeln('Codec    : ${stream.getCodec()}');
  //         buf.writeln('Sample   : ${stream.getSampleRate()} Hz');
  //         buf.writeln('Channels : ${stream.getChannelLayout()}');
  //         buf.writeln('Bitrate  : ${stream.getBitrate()}');
  //       }
  //     }
  //   }
  // } catch (e) {
  //   buf.writeln('// FFprobe error: $e');
  // }

  buf.writeln('// FFprobe: uncomment sau khi thêm ffmpeg_kit_flutter');
}

// ═══════════════════════════════════════════════════════════
// DESKTOP — Windows / Linux / macOS
// ═══════════════════════════════════════════════════════════

Future<String> _analyzeFileDesktop(String filePath) async {
  final buf = StringBuffer();
  await _addFileInfo(buf, filePath);

  // Kiểm tra exiftool có sẵn không
  final exiftoolPath = await _findExiftool();

  if (exiftoolPath == null) {
    // Không có exiftool → fallback đọc EXIF bằng Dart (chỉ cho ảnh)
    buf.writeln('');
    buf.writeln('=== Notice ===');
    buf.writeln('exiftool not found. Install để xem metadata đầy đủ:');
    buf.writeln('');

    if (Platform.isWindows) {
      buf.writeln('  Windows : https://exiftool.org');
      buf.writeln('            hoặc: winget install exiftool');
    } else if (Platform.isMacOS) {
      buf.writeln('  macOS   : brew install exiftool');
    } else {
      buf.writeln('  Linux   : sudo apt install libimage-exiftool-perl');
      buf.writeln('            hoặc: sudo dnf install perl-Image-ExifTool');
    }

    buf.writeln('');
    buf.writeln('// Fallback: đọc EXIF bằng Dart package...');
    buf.writeln('');

    final ext = _ext(filePath);
    if (_imageExts.contains(ext)) {
      await _mobileAnalyzeImage(buf, filePath); // dùng lại hàm mobile
    } else {
      buf.writeln('// Không thể đọc metadata video mà không có exiftool');
    }

    return buf.toString();
  }

  // exiftool có → chạy và lấy toàn bộ metadata
  buf.writeln('');
  buf.writeln('=== Metadata (exiftool) ===');
  buf.writeln('Tool: $exiftoolPath');
  buf.writeln('');

  try {
    final result = await Process.run(
      exiftoolPath,
      [filePath],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );

    if (result.exitCode == 0) {
      final output = result.stdout as String;
      buf.write(output);
    } else {
      buf.writeln('// exiftool error (exit ${result.exitCode}):');
      buf.writeln(result.stderr);
    }
  } catch (e) {
    buf.writeln('// Process error: $e');
  }

    // Thêm dòng này trước return buf.toString():
  await _analyzeQuality(buf, filePath);
  return buf.toString();
}

// Tìm đường dẫn exiftool trên hệ thống
Future<String?> _findExiftool() async {
  // Các tên lệnh có thể có trên từng OS
  final candidates = Platform.isWindows
      ? ['exiftool.exe', 'exiftool']
      : ['exiftool'];

  for (final cmd in candidates) {
    try {
      // "where" (Windows) / "which" (Unix) kiểm tra PATH
      final which = Platform.isWindows ? 'where' : 'which';
      final result = await Process.run(which, [cmd]);
      if (result.exitCode == 0) {
        final path = (result.stdout as String).trim().split('\n').first.trim();
        if (path.isNotEmpty) return path;
      }
    } catch (_) {
      // Lệnh không tìm thấy, thử cái tiếp
    }
  }

  // Thử các đường dẫn cứng phổ biến
  final hardcoded = [
    if (Platform.isWindows) ...[
      r'C:\Windows\exiftool.exe',
      r'C:\Program Files\ExifTool\exiftool.exe',
    ],
    if (Platform.isMacOS) ...[
      '/usr/local/bin/exiftool',
      '/opt/homebrew/bin/exiftool',
    ],
    if (Platform.isLinux) ...[
      '/usr/bin/exiftool',
      '/usr/local/bin/exiftool',
    ],
  ];

  for (final p in hardcoded) {
    if (await File(p).exists()) return p;
  }

  return null; // không tìm thấy
}