import 'dart:convert';
import 'dart:io';

import 'package:chess/chess.dart' as ch;
import 'package:flutter_test/flutter_test.dart';
import 'package:winter_chess/board.dart';
import 'package:winter_chess/lessons.dart';

void main() {
  test('клетки доски: обычный и перевёрнутый вид', () {
    expect(squareAt(7, 0, false), 'a1');
    expect(squareAt(0, 7, false), 'h8');
    expect(squareAt(0, 0, true), 'h1');
    expect(squareAt(7, 7, true), 'a8');
  });

  test('ходы UCI и запись SAN', () {
    final c = ch.Chess();
    expect(sanOf(c, 'e2e4'), 'e4');
    expect(playUci(c, 'e2e4'), isTrue);
    expect(playUci(c, 'e2e4'), isFalse);
    final p = ch.Chess.fromFEN('8/4P3/8/8/8/8/k7/7K w - - 0 1');
    expect(sanOf(p, 'e7e8q'), 'e8=Q');
    expect(sanOf(p, 'e7e8n'), 'e8=N');
  });

  test('в уроках все позиции корректны, а правильные ответы — допустимые ходы', () {
    for (final l in lessons) {
      for (final s in l.steps) {
        if (s.fen == null) {
          expect(s.answer, isEmpty, reason: '${l.title}: задание без позиции');
          continue;
        }
        expect(ch.Chess.validate_fen(s.fen!)['valid'], isTrue, reason: '${l.title}: ${s.fen}');
        for (final m in s.marks) {
          expect(RegExp(r'^[a-h][1-8]$').hasMatch(m), isTrue, reason: '${l.title}: клетка $m');
        }
        for (final a in s.answer) {
          final c = ch.Chess.fromFEN(s.fen!);
          final ok = a.length == 4
              ? c.moves({'verbose': true}).any((m) => '${(m as Map)['from']}${m['to']}' == a)
              : playUci(c, a);
          expect(ok, isTrue, reason: '${l.title}: ход $a невозможен в ${s.fen}');
        }
      }
    }
  });

  test('все задачи: ходы решения допустимы', () {
    final j = jsonDecode(File('assets/puzzles.json').readAsStringSync()) as Map;
    final list = j['puzzles'] as List;
    expect(list, isNotEmpty);
    for (final p in list.cast<Map>()) {
      final c = ch.Chess.fromFEN('${p['fen']}');
      for (final m in (p['moves'] as List).cast<String>()) {
        expect(playUci(c, m), isTrue, reason: 'задача ${p['id']}: ход $m');
      }
    }
  });
}
