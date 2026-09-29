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
  static const _sectionOrder = ['file', 'hash', 'video', 'meta', 'quality'];
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
      final fileSize = await File(filePath).length();

      // Step 2: start hashing in background, do NOT await yet
      _setSection('hash', 'SHA256   : [ Calculating... ]\n');
      final hashFuture = compute(_hashFileInBackground, filePath).then((h) {
        _setSection('hash', 'SHA256   : $h\n');
        return h;
      });

      // Step 3: video info (ffprobe on desktop, built-in MP4 parser as fallback)
      if (_videoExts.contains(ext)) {
        _setSection('video', '=== Video ===\n// Reading video info...\n');
        final videoInfo = await _analyzeVideo(filePath, ext, fileSize);
        _setSection('video', _formatVideoSection(videoInfo));
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
  final buf = StringBuffer()..writeln('=== Video ===');
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