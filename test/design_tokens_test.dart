import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/theme.dart';

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

  test('단원 색은 UnitColors 팔레트에서만 고른다', () {
    final files = [
      'lib/models/curriculum.dart',
      'lib/models/korean_curriculum.dart',
      'lib/models/english_curriculum.dart',
      ...Directory('lib/models')
          .listSync()
          .whereType<File>()
          .map((f) => f.path)
          .where((p) => p.endsWith('_pack.dart')),
    ];
    final bad = <String>[];
    for (final path in files) {
      final lines = File(path).readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'Color\(0x').hasMatch(lines[i])) {
          bad.add('$path:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('단원 색에는 뜻이 정해진 색(듣기 파랑·정답 초록·오답 빨강)이 없다', () {
    const palette = {
      'pink': UnitColors.pink,
      'rose': UnitColors.rose,
      'orange': UnitColors.orange,
      'mustard': UnitColors.mustard,
      'caramel': UnitColors.caramel,
      'brown': UnitColors.brown,
      'teal': UnitColors.teal,
      'purple': UnitColors.purple,
      'violet': UnitColors.violet,
      'grape': UnitColors.grape,
    };
    final listenHue = HSLColor.fromColor(AppColors.listen).hue;
    for (final entry in palette.entries) {
      final hue = HSLColor.fromColor(entry.value).hue;
      // 듣기 파랑과 색상환에서 30도 넘게 떨어져 있어야 한다 (하늘·파랑·남색 금지)
      expect((hue - listenHue).abs(), greaterThan(30), reason: entry.key);
      expect(hue >= 180 && hue <= 250, isFalse, reason: '${entry.key} 파랑 계열');
      expect(hue > 80 && hue < 160, isFalse, reason: '${entry.key} 초록 계열');
      expect(hue < 15 || hue > 345, isFalse, reason: '${entry.key} 빨강 계열');
    }
  });

  test('퀴즈 보기 바탕에도 파랑이 없다 (파랑 = 듣기 버튼만)', () {
    for (final c in [...AppColors.choiceFills, ...AppColors.choiceBorders]) {
      final hsl = HSLColor.fromColor(c);
      expect(hsl.hue >= 180 && hsl.hue <= 250, isFalse, reason: '$c');
    }
  });
}
