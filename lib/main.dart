import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:exif/exif.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';


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
  StreamSubscription? _intentSub;
  String _output = '';
  String? _file1;
  String? _file2;
  bool _loading = false;

  // Ordered output sections, each one is filled when its task finishes
  static const _sectionOrder = ['file', 'hash', 'info', 'video', 'meta', 'quality'];
  final Map<String, String> _sections = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    if (Platform.isAndroid || Platform.isIOS) {
      // App đang chạy nền thì nhận file qua stream
      _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
        _onShared,
        onError: (_) {},
      );
      // App được mở từ lạnh bằng "Open with" / "Share"
      ReceiveSharingIntent.instance.getInitialMedia().then((files) {
        _onShared(files);
        ReceiveSharingIntent.instance.reset();
      });
    }
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _setSection(String key, String text) {
    if (!mounted) return;
    setState(() {
      _sections[key] = text;
      // Trim trailing newlines and skip empty sections so no extra blank lines appear
      _output = _sectionOrder
          .where((k) => _sections.containsKey(k) && _sections[k]!.trim().isNotEmpty)
          .map((k) => _sections[k]!.trimRight())
          .join('\n');
    });
  }

  Future<void> _pickFile({bool isFile2 = false}) async {
    // Static call, compatible with Linux desktop
    final result = await FilePicker.pickFiles();
    final path = result.single.path!;
    setState(() {
      if (isFile2) {
        _file2 = path;
      } else {
        _file1 = path;
      }
    });
  }

  void _onShared(List<SharedMediaFile> files) {
    if (files.isEmpty || !mounted || _loading) return;
    final paths = files.map((f) => f.path).toList();

    // 2 file trở lên: sang tab DIFF và so sánh luôn
    if (paths.length >= 2) {
      setState(() {
        _file1 = paths[0];
        _file2 = paths[1];
      });
      _tabController.animateTo(2);
      _runDiff();
      return;
    }

    // 1 file: ảnh sang tab PHOTO, video sang tab VIDEO, rồi phân tích luôn
    final p = paths.first;
    final isVideo = files.first.type == SharedMediaType.video || _videoExts.contains(_ext(p));
    setState(() {
      _file1 = p;
      _output = '';
    });
    _tabController.animateTo(isVideo ? 1 : 0);
    _analyze(isVideo: isVideo);
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
      final fileSize = await File(filePath).length();

      // Trạng thái dùng chung để render lại section Info khi có đủ dữ liệu
      _VideoInfo? vInfo;
      String? hashVal;
      bool videoDone = false;
      void refreshInfo() {
        if (!_videoExts.contains(ext) || !videoDone) return;
        _setSection('info', _formatInfoSection(vInfo, fileSize, hashVal));
      }

      // Step 2: hash chạy nền
      _setSection('hash', 'SHA256   : [ Calculating... ]\n');
      final hashFuture = compute(_hashFileInBackground, filePath).then((h) {
        hashVal = h;
        _setSection('hash', 'SHA256   : $h\n');
        refreshInfo(); // cập nhật vid_sha256 khi hash xong
        return h;
      });

      // Step 3: video info
      if (_videoExts.contains(ext)) {
        _setSection('video', '\n=== Video ===\n// Reading video info...\n');
        vInfo = await _analyzeVideo(filePath, ext, fileSize);
        videoDone = true;
        _setSection('video', _formatVideoSection(vInfo));
        refreshInfo();
      }

      // Step 3b: thong tin anh (Image;/General;)
      if (_imageExts.contains(ext)) {
        _setSection('info', '=== Info ===\n// Reading image info...\n');
        final infoOut = await compute(_imageInfoInBackground, {
          'filePath': filePath,
          'ext': ext,
        });
        _setSection('info', infoOut);
      }

      // Step 4: metadata (exiftool on desktop), runs in parallel with hashing
      _setSection('meta', '// Reading metadata...\n');
      final metaBuf = StringBuffer();
      if (Platform.isAndroid || Platform.isIOS) {
        if (_imageExts.contains(ext)) {
          await _mobileAnalyzeImageBasic(metaBuf, filePath);
        }
      } else {
        await _desktopAnalyzeBasic(metaBuf, filePath);
      }
      _setSection('meta', metaBuf.toString());

      // Step 5: wait for hash (image quality output embeds it)
      final hash = await hashFuture;

      // Step 6: image quality only (isolate reads the file itself)
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
      _output = '// Comparing...';
    });
    try {
      final out = await compute(_diffInBackground, {'p1': _file1!, 'p2': _file2!});
      if (!mounted) return;
      setState(() {
        _loading = false;
        _output = out;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _output = '// Error: $e';
      });
    }
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
        physics: const NeverScrollableScrollPhysics(),
        children: [_buildPhotoTab(), _buildVideoTab(), _buildDiffTab()],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hash
// ---------------------------------------------------------------------------

// Stream the file through SHA256 without loading it fully into memory
Future<String> _hashFileInBackground(String path) async {
  final digest = await sha256.bind(File(path).openRead()).first;
  return digest.toString();
}

// ---------------------------------------------------------------------------
// Image quality
// ---------------------------------------------------------------------------

String _analyzeQualityInBackground(Map<String, dynamic> data) {
  final String filePath = data['filePath'];
  final String ext = data['ext'];
  final String hash = data['hash'];
  final buf = StringBuffer()..writeln('\n========================================');
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

// ---------------------------------------------------------------------------
// Image info (Image;{...} and General;{...} lines)
// ---------------------------------------------------------------------------

String _jsonObj(Map<String, Object?> m) =>
    '{${m.entries.map((e) => '${jsonEncode(e.key)}: ${jsonEncode(e.value)}').join(', ')}}';

String _formatKiBMiB(int bytes) {
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(2)} KiB';
  }
  return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MiB';
}

class _ImgMeta {
  String format = '';
  int? width;
  int? height;
  int? bitDepth;
  String? subsampling; // chi co voi JPEG
  String? comment; // JPEG COM marker
}

// Doc header JPEG: SOF (kich thuoc, bit depth, sampling) va COM (comment)
void _parseJpegMeta(Uint8List b, _ImgMeta m) {
  int i = 2;
  while (i + 3 < b.length) {
    if (b[i] != 0xFF) {
      i++;
      continue;
    }
    final marker = b[i + 1];
    if (marker == 0xFF) {
      i++;
      continue;
    }
    if (marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      i += 2;
      continue;
    }
    if (marker == 0xD9 || marker == 0xDA) {
      break;
    }
    final len = (b[i + 2] << 8) | b[i + 3];
    final s = i + 4;
    if (marker == 0xFE && m.comment == null) {
      final end = min(i + 2 + len, b.length);
      m.comment = utf8.decode(b.sublist(s, end), allowMalformed: true).trim();
    }
    final isSof = marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC;
    if (isSof && s + 6 <= b.length) {
      m.bitDepth = b[s];
      m.height = (b[s + 1] << 8) | b[s + 2];
      m.width = (b[s + 3] << 8) | b[s + 4];
      final n = b[s + 5];
      if (n == 1) {
        m.subsampling = 'Y';
      } else if (n >= 3 && s + 6 + n * 3 <= b.length) {
        final y = b[s + 6 + 1];
        final c = b[s + 6 + 3 + 1];
        final yh = y >> 4, yv = y & 0xF;
        final ch = c >> 4, cv = c & 0xF;
        String ratio = '?';
        if (ch > 0 && cv > 0) {
          final hr = yh ~/ ch, vr = yv ~/ cv;
          const map = {
            '1,1': '4:4:4',
            '2,1': '4:2:2',
            '2,2': '4:2:0',
            '1,2': '4:4:0',
            '4,1': '4:1:1',
          };
          ratio = map['$hr,$vr'] ?? '?';
        }
        m.subsampling = 'YCbCr$ratio ($yh $yv)';
      }
    }
    i += 2 + len;
  }
}

String _imageInfoInBackground(Map<String, String> data) {
  final filePath = data['filePath']!;
  final ext = data['ext']!;
  final buf = StringBuffer()..writeln('\n=== Info ===');
  try {
    final bytes = File(filePath).readAsBytesSync();
    final m = _ImgMeta();

    if (ext == '.jpg' || ext == '.jpeg') {
      m.format = 'JPEG';
      if (bytes.length > 4 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
        _parseJpegMeta(bytes, m);
      }
    } else if (ext == '.png' && bytes.length > 26) {
      m.format = 'PNG';
      final bd = ByteData.sublistView(bytes);
      m.width = bd.getUint32(16);
      m.height = bd.getUint32(20);
      m.bitDepth = bytes[24];
    } else {
      m.format = ext.replaceAll('.', '').toUpperCase();
      final d = img.decodeImage(bytes);
      if (d != null) {
        m.width = d.width;
        m.height = d.height;
        m.bitDepth = d.bitsPerChannel;
      }
    }

    const lossless = {'.png', '.bmp', '.gif', '.tif', '.tiff'};
    final compression = lossless.contains(ext) ? 'Lossless' : 'Lossy';

    buf.writeln('Image;${_jsonObj({
      '@type': 'Image',
      'Format': m.format,
      'Width': m.width?.toString(),
      'Height': m.height?.toString(),
      'Compression_Mode': compression,
      'BitDepth': m.bitDepth?.toString(),
      if (m.subsampling != null) 'ChromaSubsampling (4:4:4)': m.subsampling,
    })}');

    buf.writeln('General;${_jsonObj({
      '@type': 'General',
      'FileSize': _formatKiBMiB(bytes.length),
      if (m.comment != null && m.comment!.isNotEmpty) 'Comment': m.comment,
    })}');
  } catch (e) {
    buf.writeln('// Info error: $e');
  }
  return buf.toString();
}

// ---------------------------------------------------------------------------
// Image diff (port of PIL ImageChops.difference formula)
// ---------------------------------------------------------------------------

String _diffInBackground(Map<String, String> data) {
  final p1 = data['p1']!, p2 = data['p2']!;
  final buf = StringBuffer()..writeln('=== Diff ===');
  final a = img.decodeImage(File(p1).readAsBytesSync());
  final b = img.decodeImage(File(p2).readAsBytesSync());
  if (a == null || b == null) {
    buf.writeln('// Cannot decode ${a == null ? 'File 1' : 'File 2'}');
    return buf.toString();
  }
  if (a.width != b.width || a.height != b.height) {
    buf.writeln('// Size mismatch: ${a.width}x${a.height} vs ${b.width}x${b.height}');
    return buf.toString();
  }

  final w = a.width, h = a.height;
  int minX = w, minY = h, maxX = -1, maxY = -1;
  int sum = 0, maxVal = 0, count = 0;

  int ch(num normalized) => (normalized * 255).round();

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final pa = a.getPixel(x, y);
      final pb = b.getPixel(x, y);
      final dr = (ch(pa.rNormalized) - ch(pb.rNormalized)).abs();
      final dg = (ch(pa.gNormalized) - ch(pb.gNormalized)).abs();
      final db = (ch(pa.bNormalized) - ch(pb.bNormalized)).abs();
      final pm = max(dr, max(dg, db));
      sum += dr + dg + db;
      if (pm > maxVal) maxVal = pm;
      if (pm > 10) count++;
      if (pm > 0) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }

  // Same as PIL getbbox(): (left, upper, right, lower), right/lower exclusive
  final bbox = maxX < 0 ? 'None' : '($minX, $minY, ${maxX + 1}, ${maxY + 1})';
  final mean = sum / (w * h * 3);
  final pct = count / (w * h) * 100;

  buf
    ..writeln('File 1   : ${p1.split(Platform.pathSeparator).last}')
    ..writeln('File 2   : ${p2.split(Platform.pathSeparator).last}')
    ..writeln('Size     : ${w}x$h')
    ..writeln('BBox     : $bbox')
    ..writeln('Mean     : ${mean.toStringAsFixed(4)}')
    ..writeln('Max      : $maxVal')
    ..writeln('Pixels>10: $count (${pct.toStringAsFixed(2)}%)');
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

// ---------------------------------------------------------------------------
// Video analysis
// ---------------------------------------------------------------------------

class _VideoInfo {
  String source = '';
  String container = '';
  double? duration; // seconds
  int? width;
  int? height;
  int rotation = 0; // degrees: 0, 90, 180, 270
  double? fps;
  String? videoCodec;
  String? audioCodec;
  int? audioChannels;
  int? audioSampleRate;
  int? bitrate; // overall bits per second
  String? pixFmt; // ví dụ yuv420p
}

// Try ffprobe first (desktop only), then the built-in MP4/MOV parser
Future<_VideoInfo?> _analyzeVideo(String filePath, String ext, int fileSize) async {
  if (!(Platform.isAndroid || Platform.isIOS)) {
    final probed = await _probeWithFfprobe(filePath, fileSize);
    if (probed != null) {
      return probed;
    }
  }
  const mp4Family = {'.mp4', '.mov', '.m4v', '.3gp'};
  if (mp4Family.contains(ext)) {
    try {
      final moov = await _readMoovBox(filePath);
      if (moov != null) {
        final info = _parseMoov(moov, fileSize, ext == '.mov' ? 'QuickTime MOV' : 'MP4');
        info.source = 'built-in MP4 parser';
        return info;
      }
    } catch (_) {}
  }
  return null;
}

Future<_VideoInfo?> _probeWithFfprobe(String filePath, int fileSize) async {
  final tool = await _findTool('ffprobe');
  if (tool == null) {
    return null;
  }
  try {
    final r = await Process.run(
      tool,
      ['-v', 'error', '-print_format', 'json', '-show_format', '-show_streams', filePath],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (r.exitCode != 0) {
      return null;
    }
    final json = jsonDecode(r.stdout as String) as Map<String, dynamic>;
    final streams = ((json['streams'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final fmt = (json['format'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    Map<String, dynamic>? video;
    Map<String, dynamic>? audio;
    for (final s in streams) {
      if (s['codec_type'] == 'video' && video == null) {
        video = s;
      } else if (s['codec_type'] == 'audio' && audio == null) {
        audio = s;
      }
    }

    final info = _VideoInfo()
      ..source = 'ffprobe'
      ..container = (fmt['format_long_name'] ?? fmt['format_name'] ?? '').toString()
      ..duration = double.tryParse('${fmt['duration'] ?? ''}')
      ..bitrate = int.tryParse('${fmt['bit_rate'] ?? ''}');

    if (video != null) {
      info
        ..width = video['width'] as int?
        ..height = video['height'] as int?
        ..pixFmt = video['pix_fmt']?.toString()
        ..videoCodec = video['codec_name']?.toString()
        ..fps = _parseFraction('${video['avg_frame_rate'] ?? video['r_frame_rate'] ?? ''}');
      // Rotation can be in side data or in legacy tags
      double? rot;
      final sideData = video['side_data_list'];
      if (sideData is List) {
        for (final sd in sideData) {
          if (sd is Map && sd['rotation'] != null) {
            rot = double.tryParse('${sd['rotation']}');
          }
        }
      }
      if (rot == null && video['tags'] is Map) {
        rot = double.tryParse('${(video['tags'] as Map)['rotate'] ?? ''}');
      }
      if (rot != null) {
        info.rotation = ((rot.round() % 360) + 360) % 360;
      }
    }
    if (audio != null) {
      info
        ..audioCodec = audio['codec_name']?.toString()
        ..audioChannels = audio['channels'] as int?
        ..audioSampleRate = int.tryParse('${audio['sample_rate'] ?? ''}');
    }
    // Fallback bitrate from file size
    if ((info.bitrate == null || info.bitrate! <= 0) && info.duration != null && info.duration! > 0) {
      info.bitrate = (fileSize * 8 / info.duration!).round();
    }
    return info;
  } catch (_) {
    return null;
  }
}

double? _parseFraction(String s) {
  final parts = s.split('/');
  if (parts.length == 2) {
    final n = double.tryParse(parts[0]);
    final d = double.tryParse(parts[1]);
    if (n != null && d != null && d != 0) {
      return n / d;
    }
    return null;
  }
  return double.tryParse(s);
}

// --- Built-in MP4/MOV parser (no external dependency) ---

class _Box {
  final String type;
  final int start; // payload start
  final int end; // box end (exclusive)
  const _Box(this.type, this.start, this.end);
}

// Scan top-level boxes and return the payload of 'moov' only
Future<Uint8List?> _readMoovBox(String path) async {
  const int maxMoovSize = 128 * 1024 * 1024;
  final raf = await File(path).open();
  try {
    final len = await raf.length();
    int pos = 0;
    while (pos + 8 <= len) {
      await raf.setPosition(pos);
      final head = await raf.read(16);
      if (head.length < 8) {
        break;
      }
      final bd = ByteData.sublistView(head);
      int size = bd.getUint32(0);
      final type = String.fromCharCodes(head, 4, 8);
      int headerSize = 8;
      if (size == 1) {
        if (head.length < 16) {
          break;
        }
        size = bd.getUint64(8);
        headerSize = 16;
      } else if (size == 0) {
        size = len - pos;
      }
      if (size < headerSize) {
        break;
      }
      if (type == 'moov') {
        if (size > maxMoovSize) {
          return null;
        }
        await raf.setPosition(pos + headerSize);
        return await raf.read(size - headerSize);
      }
      pos += size;
    }
  } finally {
    await raf.close();
  }
  return null;
}

List<_Box> _boxes(Uint8List d, int start, int end) {
  final out = <_Box>[];
  final bd = ByteData.sublistView(d);
  int pos = start;
  while (pos + 8 <= end) {
    int size = bd.getUint32(pos);
    final type = String.fromCharCodes(d, pos + 4, pos + 8);
    int header = 8;
    if (size == 1) {
      if (pos + 16 > end) {
        break;
      }
      size = bd.getUint64(pos + 8);
      header = 16;
    } else if (size == 0) {
      size = end - pos;
    }
    if (size < header || pos + size > end) {
      break;
    }
    out.add(_Box(type, pos + header, pos + size));
    pos += size;
  }
  return out;
}

// Returns [timescale, duration] for mvhd / mdhd boxes
List<int> _readTimes(Uint8List d, ByteData bd, int s) {
  if (d[s] == 1) {
    return [bd.getUint32(s + 20), bd.getUint64(s + 24)];
  }
  return [bd.getUint32(s + 12), bd.getUint32(s + 16)];
}

_VideoInfo _parseMoov(Uint8List d, int fileSize, String container) {
  final bd = ByteData.sublistView(d);
  final info = _VideoInfo()..container = container;
  for (final b in _boxes(d, 0, d.length)) {
    if (b.type == 'mvhd' && b.start + 20 <= b.end) {
      final t = _readTimes(d, bd, b.start);
      if (t[0] > 0) {
        info.duration = t[1] / t[0];
      }
    } else if (b.type == 'trak') {
      _parseTrak(d, bd, b, info);
    }
  }
  if (info.duration != null && info.duration! > 0) {
    info.bitrate = (fileSize * 8 / info.duration!).round();
  }
  return info;
}

void _parseTrak(Uint8List d, ByteData bd, _Box trak, _VideoInfo info) {
  int? w, h;
  int rotation = 0;
  String handler = '';
  int mdTs = 0, mdDur = 0;
  String codec = '';
  int sampleCount = 0;
  int channels = 0, sampleRate = 0;

  for (final c in _boxes(d, trak.start, trak.end)) {
    if (c.type == 'tkhd') {
      final v1 = d[c.start] == 1;
      final widthOffset = v1 ? 88 : 76;
      final matrixOffset = v1 ? 52 : 40;
      if (c.start + widthOffset + 8 <= c.end) {
        w = bd.getUint32(c.start + widthOffset) >> 16;
        h = bd.getUint32(c.start + widthOffset + 4) >> 16;
        final a = bd.getInt32(c.start + matrixOffset) / 65536.0;
        final b = bd.getInt32(c.start + matrixOffset + 4) / 65536.0;
        rotation = (((atan2(b, a) * 180 / pi).round() % 360) + 360) % 360;
      }
    } else if (c.type == 'mdia') {
      for (final m in _boxes(d, c.start, c.end)) {
        if (m.type == 'mdhd' && m.start + 20 <= m.end) {
          final t = _readTimes(d, bd, m.start);
          mdTs = t[0];
          mdDur = t[1];
        } else if (m.type == 'hdlr' && m.start + 12 <= m.end) {
          handler = String.fromCharCodes(d, m.start + 8, m.start + 12);
        } else if (m.type == 'minf') {
          for (final s in _boxes(d, m.start, m.end)) {
            if (s.type != 'stbl') {
              continue;
            }
            for (final t in _boxes(d, s.start, s.end)) {
              if (t.type == 'stsd' && t.start + 16 <= t.end) {
                codec = String.fromCharCodes(d, t.start + 12, t.start + 16);
                // Audio sample entry: channels at +32, sample rate (16.16) at +40
                if (t.start + 44 <= t.end) {
                  channels = bd.getUint16(t.start + 32);
                  sampleRate = bd.getUint32(t.start + 40) >> 16;
                }
              } else if (t.type == 'stsz' && t.start + 12 <= t.end) {
                sampleCount = bd.getUint32(t.start + 8);
              }
            }
          }
        }
      }
    }
  }

  if (handler == 'vide' && info.width == null) {
    info
      ..width = w
      ..height = h
      ..rotation = rotation
      ..videoCodec = _fourccName(codec);
    if (mdTs > 0 && mdDur > 0 && sampleCount > 0) {
      info.fps = sampleCount / (mdDur / mdTs);
    }
  } else if (handler == 'soun' && info.audioCodec == null) {
    info
      ..audioCodec = _fourccName(codec)
      ..audioChannels = channels > 0 ? channels : null
      ..audioSampleRate = sampleRate > 0 ? sampleRate : null;
  }
}

String _fourccName(String fourcc) {
  switch (fourcc) {
    case 'avc1':
    case 'avc3':
      return 'h264';
    case 'hvc1':
    case 'hev1':
      return 'hevc';
    case 'av01':
      return 'av1';
    case 'vp09':
      return 'vp9';
    case 'mp4v':
      return 'mpeg4';
    case 'mp4a':
      return 'aac';
    case 'ac-3':
      return 'ac3';
    case 'ec-3':
      return 'eac3';
    case 'Opus':
      return 'opus';
    case 'alac':
      return 'alac';
    default:
      return fourcc.trim();
  }
}

// --- Video output formatting ---

String _formatDuration(double sec) {
  final total = sec.floor();
  final ms = ((sec - total) * 100).round().clamp(0, 99);
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(h)}:${two(m)}:${two(s)}.${two(ms)}';
}

String _formatBitrate(int bps) {
  if (bps >= 1000000) {
    return '${(bps / 1000000).toStringAsFixed(2)} Mbps';
  }
  return '${(bps / 1000).toStringAsFixed(0)} kbps';
}

// Width/height as displayed (swapped when rotated by 90 or 270 degrees)
List<int>? _displaySize(_VideoInfo v) {
  if (v.width == null || v.height == null) {
    return null;
  }
  final swap = v.rotation == 90 || v.rotation == 270;
  return swap ? [v.height!, v.width!] : [v.width!, v.height!];
}

String _formatVideoSection(_VideoInfo? v) {
  final buf = StringBuffer()..writeln('\n=== Video ===');
  if (v == null) {
    buf.writeln('// Cannot read video info. Unsupported container for the built-in parser.');
    buf.writeln('// Install ffprobe (ffmpeg) on desktop for full support.');
    return buf.toString();
  }
  final size = _displaySize(v);
  if (v.container.isNotEmpty) buf.writeln('Container : ${v.container}');
  if (v.duration != null) buf.writeln('Duration  : ${_formatDuration(v.duration!)}');
  if (size != null) buf.writeln('Resolution: ${size[0]}x${size[1]}');
  if (v.rotation != 0) buf.writeln('Rotation  : ${v.rotation} deg');
  if (v.fps != null) buf.writeln('Frame rate: ${v.fps!.toStringAsFixed(2)} fps');
  if (v.videoCodec != null) buf.writeln('V. codec  : ${v.videoCodec}');
  if (v.audioCodec != null) {
    final extra = <String>[
      if (v.audioChannels != null) '${v.audioChannels} ch',
      if (v.audioSampleRate != null) '${v.audioSampleRate} Hz',
    ];
    buf.writeln('A. codec  : ${v.audioCodec}${extra.isEmpty ? '' : ' (${extra.join(', ')})'}');
  } else {
    buf.writeln('A. codec  : none');
  }
  if (v.bitrate != null) buf.writeln('Bitrate   : ${_formatBitrate(v.bitrate!)}');
  buf.writeln('Source    : ${v.source}');
  return buf.toString();
}

String _formatInfoSection(_VideoInfo? v, int fileSize, String? sha256) {
  String obj(Map<String, Object?> m) =>
      '{${m.entries.map((e) => '${jsonEncode(e.key)}: ${jsonEncode(e.value)}').join(', ')}}';

  final buf = StringBuffer()..writeln('\n=== Info ===');

  if (v != null) {
    final size = _displaySize(v);
    buf.writeln('Video;${obj({
      '@type': 'Video',
      'Format': v.videoCodec?.toUpperCase(),
      'Width': size?[0].toString(),
      'Height': size?[1].toString(),
      'FrameRate': v.fps?.toStringAsFixed(3),
      'PixFmt': v.pixFmt,
    })}');
  }

  buf.writeln('General;${obj({
    '@type': 'General',
    'FileSize': '${(fileSize / 1024 / 1024).toStringAsFixed(1)} MiB',
    'TBR': v?.bitrate != null ? '${v!.bitrate} b/s' : null,
    'vid_url': null,
    'vid_md5': null,
    'vid_sha256': sha256,
    'vid_sha512': null,
  })}');

  return buf.toString();
}
// ---------------------------------------------------------------------------
// Common helpers
// ---------------------------------------------------------------------------

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

Future<void> _desktopAnalyzeBasic(StringBuffer buf, String filePath) async {
  final exiftoolPath = await _findTool('exiftool');
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

// Locate an external command line tool (exiftool, ffprobe, ...)
Future<String?> _findTool(String name) async {
  final candidates = Platform.isWindows ? ['$name.exe', name] : [name];
  for (final cmd in candidates) {
    try {
      final result = await Process.run(Platform.isWindows ? 'where' : 'which', [cmd]);
      if (result.exitCode == 0) {
        return (result.stdout as String).trim().split('\n').first.trim();
      }
    } catch (_) {}
  }
  final hardcoded = [
    if (Platform.isWindows) ...[
      'C:\\Windows\\$name.exe',
      'C:\\Program Files\\ExifTool\\$name.exe',
      'C:\\ffmpeg\\bin\\$name.exe',
    ],
    if (Platform.isMacOS) ...['/usr/local/bin/$name', '/opt/homebrew/bin/$name'],
    if (Platform.isLinux) ...['/usr/bin/$name', '/usr/local/bin/$name'],
  ];
  for (final p in hardcoded) {
    if (await File(p).exists()) {
      return p;
    }
  }
  return null;
}