import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'english_question.dart';
import 'korean_question.dart';
import 'language_pack.dart';
import 'profile.dart';

/// 오답 노트 한 장: 틀린 낱말·글자 문제를 그대로 다시 풀 수 있게 담아 둔다.
/// (한글·영어·일본어·중국어의 보기 고르기 문제 — 수학은 맞춤 복습이 맡는다)
class WrongNote {
  const WrongNote({
    required this.subject,
    required this.subjectEmoji,
    required this.subjectName,
    required this.instruction,
    required this.display,
    this.subDisplay = '',
    required this.choices,
    required this.answer,
    required this.answerText,
    this.speech = '',
    this.speechLang = 'ko-KR',
    this.emojiChoices = false,
    this.missCount = 1,
  });

  /// 'kr' / 'en' / 언어 팩 id
  final String subject;
  final String subjectEmoji;
  final String subjectName;
  final String instruction;
  final String display;
  final String subDisplay;
  final List<String> choices;
  final String answer;
  final String answerText;
  final String speech;
  final String speechLang;
  final bool emojiChoices;

  /// 같은 문제를 몇 번 틀렸는지
  final int missCount;

  /// 같은 문제인지 판별하는 키
  String get id => '$subject|$instruction|$display|$answer';

  WrongNote withMissCount(int count) => WrongNote(
        subject: subject,
        subjectEmoji: subjectEmoji,
        subjectName: subjectName,
        instruction: instruction,
        display: display,
        subDisplay: subDisplay,
        choices: choices,
        answer: answer,
        answerText: answerText,
        speech: speech,
        speechLang: speechLang,
        emojiChoices: emojiChoices,
        missCount: count,
      );

  factory WrongNote.fromKorean(KoreanQuestion q) => WrongNote(
        subject: 'kr',
        subjectEmoji: '📖',
        subjectName: '한글',
        instruction: q.instruction,
        display: q.display,
        subDisplay: q.subDisplay,
        choices: q.choices,
        answer: q.answer,
        answerText: q.answerText,
        speech: q.speech,
        emojiChoices: q.emojiChoices,
      );

  factory WrongNote.fromEnglish(EnglishQuestion q) => WrongNote(
        subject: 'en',
        subjectEmoji: '🔤',
        subjectName: '영어',
        instruction: q.instruction,
        display: q.display,
        subDisplay: q.subDisplay,
        choices: q.choices,
        answer: q.answer,
        answerText: q.answerText,
        speech: q.speech,
        speechLang: q.speechLang,
        emojiChoices: q.emojiChoices,
      );

  factory WrongNote.fromLang(LanguagePack pack, LangQuestion q) => WrongNote(
        subject: pack.id,
        subjectEmoji: pack.emoji,
        subjectName: pack.name,
        instruction: q.instruction,
        display: q.display,
        subDisplay: q.subDisplay,
        choices: q.choices,
        answer: q.answer,
        answerText: q.answerText,
        speech: q.speech,
        speechLang: pack.ttsLang,
        emojiChoices: q.emojiChoices,
      );

  Map<String, dynamic> toJson() => {
        'sub': subject,
        'se': subjectEmoji,
        'sn': subjectName,
        'in': instruction,
        'd': display,
        'sd': subDisplay,
        'c': choices,
        'a': answer,
        'at': answerText,
        'sp': speech,
        'sl': speechLang,
        'e': emojiChoices,
        'm': missCount,
      };

  factory WrongNote.fromJson(Map<String, dynamic> map) => WrongNote(
        subject: map['sub'] as String,
        subjectEmoji: map['se'] as String,
        subjectName: map['sn'] as String,
        instruction: map['in'] as String,
        display: map['d'] as String,
        subDisplay: map['sd'] as String? ?? '',
        choices: [for (final c in map['c'] as List) '$c'],
        answer: map['a'] as String,
        answerText: map['at'] as String,
        speech: map['sp'] as String? ?? '',
        speechLang: map['sl'] as String? ?? 'ko-KR',
        emojiChoices: map['e'] as bool? ?? false,
        missCount: map['m'] as int? ?? 1,
      );
}

class WrongNoteStore {
  static const _key = 'wrong_notes_v1';

  /// 노트가 무한히 커지지 않게 오래된 것부터 밀어낸다.
  static const maxNotes = 40;

  static Future<List<WrongNote>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rows = prefs.getStringList(Profiles.scoped(_key)) ?? const [];
    final notes = <WrongNote>[];
    for (final row in rows) {
      try {
        notes.add(
            WrongNote.fromJson(jsonDecode(row) as Map<String, dynamic>));
      } catch (_) {} // 깨진 줄은 조용히 건너뛴다
    }
    return notes;
  }

  static Future<void> _save(List<WrongNote> notes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      Profiles.scoped(_key),
      [for (final n in notes) jsonEncode(n.toJson())],
    );
  }

  /// 틀린 문제를 노트에 넣는다. 이미 있으면 틀린 횟수만 올리고 맨 뒤(최신)로.
  /// 보기 고르기 문제만 담는다 (타일 조립 문제 제외는 호출하는 쪽에서).
  static Future<void> add(WrongNote note) async {
    final notes = await load();
    final existing = notes.indexWhere((n) => n.id == note.id);
    if (existing >= 0) {
      final old = notes.removeAt(existing);
      notes.add(old.withMissCount(old.missCount + 1));
    } else {
      notes.add(note);
      if (notes.length > maxNotes) notes.removeAt(0);
    }
    await _save(notes);
  }

  /// 다시 풀어서 맞힌 문제는 노트에서 지운다.
  static Future<void> remove(String id) async {
    final notes = await load();
    notes.removeWhere((n) => n.id == id);
    await _save(notes);
  }

  /// 또 틀렸으면 틀린 횟수를 올린다.
  static Future<void> markMissed(String id) async {
    final notes = await load();
    final index = notes.indexWhere((n) => n.id == id);
    if (index < 0) return;
    notes[index] = notes[index].withMissCount(notes[index].missCount + 1);
    await _save(notes);
  }

  /// 노트에 쌓인 문제 수 (홈 배너용 — json 해석 없이 줄 수만 센다)
  static Future<int> count() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(Profiles.scoped(_key)) ?? const []).length;
  }
}
