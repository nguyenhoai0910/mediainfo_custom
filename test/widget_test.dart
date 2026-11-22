import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediainfo_custom/main.dart';
import 'package:mediainfo_custom/utils.dart';
import 'dart:typed_data';

void main() {
  // ─────────────────────────────────────────────
  // Group 1: App khởi động
  // ─────────────────────────────────────────────
  group('App startup', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(const MediaInfoApp());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('shows app title in AppBar', (tester) async {
      await tester.pumpWidget(const MediaInfoApp());
      expect(find.text('mediainfo_custom'), findsOneWidget);
    });

    testWidgets('dark theme is applied', (tester) async {
      await tester.pumpWidget(const MediaInfoApp());
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme?.brightness, Brightness.dark);
    });
  });

  // ─────────────────────────────────────────────
  // Group 2: Tab navigation
  // ─────────────────────────────────────────────
  group('Tab navigation', () {
    testWidgets('shows 3 tabs: PHOTO, VIDEO, DIFF', (tester) async {
      await tester.pumpWidget(const MediaInfoApp());
      expect(find.text('PHOTO'), findsOneWidget);
      expect(find.text('VIDEO'), findsOneWidget);
      expect(find.text('DIFF'),  findsOneWidget);
    });

    testWidgets('PHOTO tab is selected by default', (tester) async {
      await tester.pumpWidget(const MediaInfoApp());
      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.controller?.index, 0);
    });

    testWidgets('can switch to VIDEO tab', (tester) async {
      await tester.pumpWidget(const MediaInfoApp());
      await tester.tap(find.text('VIDEO'));
      await tester.pumpAndSettle();
      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.controller?.index, 1);
    });

    testWidgets('can switch to DIFF tab', (tester) async {
      await tester.pumpWidget(const MediaInfoApp());
      await tester.tap(find.text('DIFF'));
      await tester.pumpAndSettle();
      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.controller?.index, 2);
    });
  });

  // ─────────────────────────────────────────────
  // Group 3: PHOTO tab UI
  // ─────────────────────────────────────────────
  group('PHOTO tab UI', () {
    testWidgets('shows Select file button', (tester) async {
      await tester.pumpWidget(const MediaInfoApp());
      expect(find.text('[ Select file ]'), findsOneWidget);
    });

    testWidgets('Analyze button disabled khi chua chon file', (tester) async {
      await tester.pumpWidget(const MediaInfoApp());
      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, '[ Analyze ]').first,
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('shows placeholder text in output box', (tester) async {
      await tester.pumpWidget(const MediaInfoApp());
      expect(find.text('// Output will appear here'), findsOneWidget);
    });

    testWidgets('shows No file selected khi chua chon', (tester) async {
      await tester.pumpWidget(const MediaInfoApp());
      expect(find.text('No file selected'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────
  // Group 4: DIFF tab UI
  // ─────────────────────────────────────────────
  group('DIFF tab UI', () {
    Future<void> goToDiff(WidgetTester tester) async {
      await tester.pumpWidget(const MediaInfoApp());
      await tester.tap(find.text('DIFF'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows File 1 and File 2 buttons', (tester) async {
      await goToDiff(tester);
      expect(find.text('[ File 1 ]'), findsOneWidget);
      expect(find.text('[ File 2 ]'), findsOneWidget);
    });

    testWidgets('Compare button disabled khi chua chon file', (tester) async {
      await goToDiff(tester);
      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, '[ Compare ]'),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('shows Not selected cho ca 2 file', (tester) async {
      await goToDiff(tester);
      expect(find.text('Not selected'), findsNWidgets(2));
    });
  });

  // ─────────────────────────────────────────────
  // Group 5: formatSize
  // ─────────────────────────────────────────────
  group('formatSize', () {
    test('bytes', () => expect(formatSize(512), '512 B'));
    test('KB',    () => expect(formatSize(2048), '2.00 KB'));
    test('MB',    () => expect(formatSize(5 * 1024 * 1024), '5.00 MB'));
    test('GB',    () => expect(formatSize(2 * 1024 * 1024 * 1024), '2.00 GB'));
  });

  // ─────────────────────────────────────────────
  // Group 6: fileExt
  // ─────────────────────────────────────────────
  group('fileExt', () {
    test('lowercase jpg', () => expect(fileExt('photo.JPG'), '.jpg'));
    test('lowercase mp4', () => expect(fileExt('video.MP4'), '.mp4'));
    test('no extension',  () => expect(fileExt('noextension'), ''));
  });

  // ─────────────────────────────────────────────
  // Group 7: formatDuration
  // ─────────────────────────────────────────────
  group('formatDuration', () {
    test('zero',   () => expect(formatDuration(0),    '00:00:00.00'));
    test('61.5s',  () => expect(formatDuration(61.5), '00:01:01.50'));
    test('1h1m1s', () => expect(formatDuration(3661), '01:01:01.00'));
  });

  // ─────────────────────────────────────────────
  // Group 8: formatBitrate
  // ─────────────────────────────────────────────
  group('formatBitrate', () {
    test('kbps', () => expect(formatBitrate(500000),  '500 kbps'));
    test('Mbps', () => expect(formatBitrate(5000000), '5.00 Mbps'));
  });

  // ─────────────────────────────────────────────
  // Group 9: estimateJpegQuality
  // ─────────────────────────────────────────────
  group('estimateJpegQuality', () {
    test('returns -1 voi PNG', () {
      final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
      expect(estimateJpegQuality(bytes, '.png'), -1);
    });
    test('returns -1 voi extension khong phai jpg', () {
      final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
      expect(estimateJpegQuality(bytes, '.webp'), -1);
    });
  });

  // ─────────────────────────────────────────────
  // Group 10: parseFraction
  // ─────────────────────────────────────────────
  group('parseFraction', () {
    test('30000/1001 ~ 29.97', () => expect(parseFraction('30000/1001'), closeTo(29.97, 0.01)));
    test('24/1 = 24',          () => expect(parseFraction('24/1'), 24.0));
    test('plain number',       () => expect(parseFraction('25.0'), 25.0));
    test('empty -> null',      () => expect(parseFraction(''), isNull));
    test('invalid -> null',    () => expect(parseFraction('abc/def'), isNull));
  });

  // ─────────────────────────────────────────────
  // Group 11: fourccName
  // ─────────────────────────────────────────────
  group('fourccName', () {
    test('avc1 -> h264',    () => expect(fourccName('avc1'), 'h264'));
    test('avc3 -> h264',    () => expect(fourccName('avc3'), 'h264'));
    test('hvc1 -> hevc',    () => expect(fourccName('hvc1'), 'hevc'));
    test('mp4a -> aac',     () => expect(fourccName('mp4a'), 'aac'));
    test('av01 -> av1',     () => expect(fourccName('av01'), 'av1'));
    test('unknown trimmed', () => expect(fourccName('opus'), 'opus'));
  });
}
