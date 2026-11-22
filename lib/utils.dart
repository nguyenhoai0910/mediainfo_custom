// lib/utils.dart
// Public helper functions tách ra từ main.dart để có thể unit test được.

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

// ---------------------------------------------------------------------------
// File extensions
// ---------------------------------------------------------------------------

const imageExts = {'.jpg', '.jpeg', '.png', '.heic', '.webp', '.tiff', '.tif', '.bmp', '.gif'};
const videoExts = {'.mp4', '.mov', '.avi', '.mkv', '.m4v', '.wmv', '.flv', '.webm', '.3gp'};

String fileExt(String filePath) =>
    filePath.contains('.') ? '.${filePath.split('.').last.toLowerCase()}' : '';

// ---------------------------------------------------------------------------
// File size formatting
// ---------------------------------------------------------------------------

String formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

String formatKiBMiB(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KiB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MiB';
}

// ---------------------------------------------------------------------------
// Duration / bitrate formatting
// ---------------------------------------------------------------------------

String formatDuration(double sec) {
  final total = sec.floor();
  final ms = ((sec - total) * 100).round().clamp(0, 99);
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(h)}:${two(m)}:${two(s)}.${two(ms)}';
}

String formatBitrate(int bps) {
  if (bps >= 1000000) return '${(bps / 1000000).toStringAsFixed(2)} Mbps';
  return '${(bps / 1000).toStringAsFixed(0)} kbps';
}

// ---------------------------------------------------------------------------
// JPEG quality estimation
// ---------------------------------------------------------------------------

int estimateJpegQuality(Uint8List bytes, String ext) {
  if (ext != '.jpg' && ext != '.jpeg') return -1;
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return -1;
  int i = 2;
  while (i < bytes.length - 1) {
    if (bytes[i] != 0xFF) break;
    final marker = bytes[i + 1];
    if (marker == 0xDB) {
      if (i + 5 >= bytes.length) break;
      final qtValue = bytes[i + 5].toDouble();
      if (qtValue <= 0) return 100;
      final scale = qtValue * 100.0 / 16.0;
      return scale >= 100 ? 1 : (scale <= 0 ? 100 : ((200.0 - scale) / 2.0).round().clamp(1, 100));
    }
    if (i + 3 >= bytes.length) break;
    i += 2 + ((bytes[i + 2] << 8) | bytes[i + 3]);
  }
  return -1;
}

// ---------------------------------------------------------------------------
// Video helpers
// ---------------------------------------------------------------------------

double? parseFraction(String s) {
  final parts = s.split('/');
  if (parts.length == 2) {
    final n = double.tryParse(parts[0]);
    final d = double.tryParse(parts[1]);
    if (n != null && d != null && d != 0) return n / d;
    return null;
  }
  return double.tryParse(s);
}

String fourccName(String fourcc) {
  switch (fourcc) {
    case 'avc1': case 'avc3': return 'h264';
    case 'hvc1': case 'hev1': return 'hevc';
    case 'av01': return 'av1';
    case 'vp09': return 'vp9';
    case 'mp4v': return 'mpeg4';
    case 'mp4a': return 'aac';
    case 'ac-3': return 'ac3';
    case 'ec-3': return 'eac3';
    case 'Opus': return 'opus';
    case 'alac': return 'alac';
    default: return fourcc.trim();
  }
}

// ---------------------------------------------------------------------------
// Tool finder
// ---------------------------------------------------------------------------

Future<String?> findTool(String name) async {
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
    if (await File(p).exists()) return p;
  }
  return null;
}
