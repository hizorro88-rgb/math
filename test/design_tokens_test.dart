import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 디자인 토큰 규칙을 지킨다 (CLAUDE.md '화면 규칙').
/// - 글자 크기는 AppFont 6단계만. 26 이상 숫자는 그림(이모지)·문제 숫자 크기.
/// - 화면·위젯에 색을 직접 적지 않는다 — theme.dart의 AppColors·SceneColors.
void main() {
  List<File> dartFiles(String dir) => Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('글자 크기는 AppFont 토큰만 쓴다 (26 미만 숫자 금지)', () {
    final literal = RegExp(r'fontSize:\s*(?:[\w.!]+\s*\?\s*)?(\d+(?:\.\d+)?)');
    final bad = <String>[];
    for (final file in dartFiles('lib')) {
      if (file.path.endsWith('theme.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final m in literal.allMatches(lines[i])) {
          if (double.parse(m.group(1)!) < 26) {
            bad.add('${file.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
        // 삼항식의 뒤쪽 값 (cond ? AppFont.x : 15)
        final tail = RegExp(r'fontSize:.*\?.*:\s*(\d+(?:\.\d+)?)\s*[,)]')
            .firstMatch(lines[i]);
        if (tail != null && double.parse(tail.group(1)!) < 26) {
          bad.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('화면·위젯에 색 값을 직접 적지 않는다', () {
    final hex = RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)');
    final named = RegExp(
        r'(?<![A-Za-z])Colors\.(grey|black54|black87|brown|red|orange|blue|blueGrey|amber|pink|purple|teal|yellow|green)\b');
    final bad = <String>[];
    for (final file in [
      ...dartFiles('lib/screens'),
      ...dartFiles('lib/widgets'),
      File('lib/main.dart'),
    ]) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (hex.hasMatch(lines[i]) || named.hasMatch(lines[i])) {
          bad.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });
}
