import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:exif/exif.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

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

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _output = '';
  String? _file1;
  String? _file2;
  bool _loading = false;

  // Ordered output sections, each one is filled when its task finishes
  static const _sectionOrder = ['file', 'hash', 'meta', 'quality'];
  final Map<String, String> _sections = {};

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

  void _setSection(String key, String text) {
    if (!mounted) return;
    setState(() {
      _sections[key] = text;
      _output = _sectionOrder
          .where(_sections.containsKey)
          .map((k) => _sections[k]!.trimRight())
          .join('\n');
    });
  }

  Future<void> _pickFile({bool isFile2 = false}) async {
    // Static call, compatible with Linux desktop
    final result = await FilePicker.pickFiles();
    if (result == null) {
      return;
    }
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

  Widget _buildPhotoTab() => _buildSingleFileTab(isVideo: false);
  Widget _buildVideoTab() => _buildSingleFileTab(isVideo: true);

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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: _loading ? null : () => _pickFile(),
                child: const Text('[ Select file ]', style: TextStyle(fontFamily: 'monospace')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _file1 != null ? _basename(_file1!) : 'No file selected',
                  style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFCCCCCC), fontSize: 13),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: (_loading || _file1 == null) ? null : () => _analyze(isVideo: isVideo),
            child: Text(_loading ? '[ Processing... ]' : '[ Analyze ]', style: const TextStyle(fontFamily: 'monospace')),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: _loading ? null : () => _pickFile(),
                child: const Text('[ File 1 ]', style: TextStyle(fontFamily: 'monospace')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _file1 != null ? _basename(_file1!) : 'Not selected',
                  style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFCCCCCC), fontSize: 13),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: _loading ? null : () => _pickFile(isFile2: true),
                child: const Text('[ File 2 ]', style: TextStyle(fontFamily: 'monospace')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _file2 != null ? _basename(_file2!) : 'Not selected',
                  style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFCCCCCC), fontSize: 13),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: (_loading || _file1 == null || _file2 == null) ? null : _runDiff,
            child: Text(_loading ? '[ Processing... ]' : '[ Compare ]', style: const TextStyle(fontFamily: 'monospace')),
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
            color: _output.isEmpty ? const Color(0xFF555555) : const Color(0xFF00FF00),
            height: 1.6,
          ),
        ),
      ),
    );
  }

  Future<void> _analyze({required bool isVideo}) async {
    final filePath = _file1!;
    final ext = _ext(filePath);
    _sections.clear();
    setState(() {
      _loading = true;
      _output = '// Starting analysis...\n';
    });

    try {
      // Step 1: basic file info (instant)
      final fileBuf = StringBuffer();
      await _addFileInfoWithoutHash(fileBuf, filePath);
      _setSection('file', fileBuf.toString());

      // Step 2: start hashing in background, do NOT await yet
      _setSection('hash', 'SHA256   : [ Calculating... ]\n');
      final hashFuture = compute(_hashFileInBackground, filePath).then((h) {
        _setSection('hash', 'SHA256   : $h\n');
        return h;
      });

      // Step 3: metadata runs in parallel with hashing
      _setSection('meta', '// Reading metadata...\n');
      final metaBuf = StringBuffer();
      if (Platform.isAndroid || Platform.isIOS) {
        if (_imageExts.contains(ext)) {
          await _mobileAnalyzeImageBasic(metaBuf, filePath);
        } else if (_videoExts.contains(ext)) {
          _mobileAnalyzeVideoBasic(metaBuf, filePath);
        }
      } else {
        await _desktopAnalyzeBasic(metaBuf, filePath);
      }
      _setSection('meta', metaBuf.toString());

      // Step 4: wait for hash (quality output embeds it)
      final hash = await hashFuture;

      // Step 5: image quality (isolate reads the file itself)
      if (_imageExts.contains(ext)) {
        _setSection('quality', 'Quality   : [ Analyzing quality... ]\n');
        final qualityOutput = await compute(_analyzeQualityInBackground, {
          'filePath': filePath,
          'ext': ext,
          'hash': hash,
        });
        _setSection('quality', qualityOutput);
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _output = '$_output\n// Error: $e';
        });
      }
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
        title: const Text('mediainfo', style: TextStyle(fontFamily: 'monospace', fontSize: 16, color: Color(0xFF00FF00), letterSpacing: 2)),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontFamily: 'monospace'),
          tabs: const [Tab(text: 'PHOTO'), Tab(text: 'VIDEO'), Tab(text: 'DIFF')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildPhotoTab(), _buildVideoTab(), _buildDiffTab()],
      ),
    );
  }
}

// Stream the file through SHA256 without loading it fully into memory
Future<String> _hashFileInBackground(String path) async {
  final digest = await sha256.bind(File(path).openRead()).first;
  return digest.toString();
}

String _analyzeQualityInBackground(Map<String, dynamic> data) {
  final String filePath = data['filePath'];
  final String ext = data['ext'];
  final String hash = data['hash'];
  final buf = StringBuffer()..writeln('========================================');
  try {
    // Read inside the isolate so no big buffer is copied between isolates
    final Uint8List bytes = File(filePath).readAsBytesSync();
    final original = img.decodeImage(bytes);
    if (original == null) {
      buf.writeln('Quality   : // Cannot decode image');
      return buf.toString();
    }
    final int width = original.width, height = original.height;

    // Downscale for statistics only (keeps the real resolution for the report)
    const int maxSide = 1024;
    img.Image work = original;
    if (width > maxSide || height > maxSide) {
      work = img.copyResize(
        original,
        width: width >= height ? maxSide : null,
        height: height > width ? maxSide : null,
      );
    }
    final gray = img.grayscale(work);

    // Single pass: collect luminance values (0..65535 scale)
    final int total = gray.width * gray.height;
    final values = Float64List(total);
    int idx = 0;
    double sum = 0;
    for (final p in gray) {
      final v = p.luminanceNormalized * 65535.0;
      values[idx++] = v;
      sum += v;
    }
    final double mean = sum / total;

    double sumSq = 0, sumCubed = 0;
    for (int i = 0; i < total; i++) {
      final d = values[i] - mean;
      final d2 = d * d;
      sumSq += d2;
      sumCubed += d2 * d;
    }
    final double variance = sumSq / total;
    final double std = variance > 0 ? sqrt(variance) : 0;
    final double skewness = std > 0 ? (sumCubed / total) / (std * std * std) : 0;

    final int quality = _estimateJpegQuality(bytes, ext);
    final issues = <String>[];
    if (mean < 13000) {
      issues.add('Too Dark');
    } else if (mean > 50000) {
      issues.add('Too Bright');
    }
    if (std < 5000) {
      issues.add('Low Contrast/Blurry');
    }
    final verdict = issues.isEmpty ? 'Good' : issues.join(', ');
    final filename = filePath.split(Platform.pathSeparator).last;
    buf.writeln('Quality   : {@type: Quality, $filename | Brightness= ${mean.toStringAsFixed(2)} | Contrast= ${std.toStringAsFixed(2)} | Balance= ${skewness.toStringAsFixed(2)} | Verdict= $verdict | Resolution= ${width}x$height | Quality= ${quality >= 0 ? quality : 'N/A'} | sha256= $hash}');
  } catch (e) {
    buf.writeln('Quality   : // Error: $e');
  }
  return buf.toString();
}

int _estimateJpegQuality(Uint8List bytes, String ext) {
  if (ext != '.jpg' && ext != '.jpeg') {
    return -1;
  }
  // Check JPEG SOI marker (0xFF 0xD8)
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
    return -1;
  }
  int i = 2;
  while (i < bytes.length - 1) {
    if (bytes[i] != 0xFF) {
      break;
    }
    final marker = bytes[i + 1];
    if (marker == 0xDB) {
      if (i + 5 >= bytes.length) {
        break;
      }
      final qtValue = bytes[i + 5].toDouble();
      if (qtValue <= 0) {
        return 100;
      }
      final scale = qtValue * 100.0 / 16.0;
      return scale >= 100 ? 1 : (scale <= 0 ? 100 : ((200.0 - scale) / 2.0).round().clamp(1, 100));
    }
    if (i + 3 >= bytes.length) {
      break;
    }
    i += 2 + ((bytes[i + 2] << 8) | bytes[i + 3]);
  }
  return -1;
}

const _imageExts = {'.jpg', '.jpeg', '.png', '.heic', '.webp', '.tiff', '.tif', '.bmp', '.gif'};
const _videoExts = {'.mp4', '.mov', '.avi', '.mkv', '.m4v', '.wmv', '.flv', '.webm', '.3gp'};
String _ext(String filePath) => filePath.contains('.') ? '.${filePath.split('.').last.toLowerCase()}' : '';

Future<void> _addFileInfoWithoutHash(StringBuffer buf, String filePath) async {
  try {
    final stat = await File(filePath).stat();
    buf
      ..writeln('=== File ===')
      ..writeln('Name     : ${filePath.split(Platform.pathSeparator).last}')
      ..writeln('Size     : ${_formatSize(stat.size)}')
      ..writeln('Modified : ${stat.modified}');
  } catch (e) {
    buf.writeln('// File info error: $e');
  }
}

String _formatSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(2)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

Future<void> _mobileAnalyzeImageBasic(StringBuffer buf, String filePath) async {
  try {
    final bytes = await File(filePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded != null) {
      buf
        ..writeln('')
        ..writeln('=== Image ===')
        ..writeln('Width    : ${decoded.width} px')
        ..writeln('Height   : ${decoded.height} px')
        ..writeln('Format   : ${_ext(filePath).toUpperCase().replaceAll('.', '')}');
    }
    final exifData = await readExifFromBytes(bytes);
    if (exifData.isNotEmpty) {
      buf.writeln('\n=== EXIF ===');
      for (final entry in exifData.entries) {
        if (entry.key.contains('Model') || entry.key.contains('DateTime') || entry.key.startsWith('GPS')) {
          buf.writeln('${entry.key.padRight(25)}: ${entry.value}');
        }
      }
    }
  } catch (e) {
    buf.writeln('// Image basic decode error: $e');
  }
}

void _mobileAnalyzeVideoBasic(StringBuffer buf, String filePath) {
  buf
    ..writeln('=== Video ===')
    ..writeln('// FFprobe: uncomment after adding ffmpeg_kit_flutter');
}

Future<void> _desktopAnalyzeBasic(StringBuffer buf, String filePath) async {
  final exiftoolPath = await _findExiftool();
  if (exiftoolPath == null) {
    buf
      ..writeln('\n=== Notice ===')
      ..writeln('exiftool not found.');
    if (_imageExts.contains(_ext(filePath))) {
      await _mobileAnalyzeImageBasic(buf, filePath);
    }
    return;
  }
  buf.writeln('\n=== Metadata (exiftool) ===');
  try {
    final result = await Process.run(exiftoolPath, [filePath], stdoutEncoding: utf8, stderrEncoding: utf8);
    if (result.exitCode == 0) {
      buf.write(result.stdout as String);
    }
  } catch (e) {
    buf.writeln('// Process error: $e');
  }
}

Future<String?> _findExiftool() async {
  final candidates = Platform.isWindows ? ['exiftool.exe', 'exiftool'] : ['exiftool'];
  for (final cmd in candidates) {
    try {
      final result = await Process.run(Platform.isWindows ? 'where' : 'which', [cmd]);
      if (result.exitCode == 0) {
        return (result.stdout as String).trim().split('\n').first.trim();
      }
    } catch (_) {}
  }
  final hardcoded = [
    if (Platform.isWindows) ...[r'C:\Windows\exiftool.exe', r'C:\Program Files\ExifTool\exiftool.exe'],
    if (Platform.isMacOS) ...['/usr/local/bin/exiftool', '/opt/homebrew/bin/exiftool'],
    if (Platform.isLinux) ...['/usr/bin/exiftool', '/usr/local/bin/exiftool'],
  ];
  for (final p in hardcoded) {
    if (await File(p).exists()) {
      return p;
    }
  }
  return null;
}