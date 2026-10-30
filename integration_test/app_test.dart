// Прогон шахмат на эмуляторе: партия с ботом, подсказка, сдача и разбор, задачи, уроки.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:winter_chess/board.dart';
import 'package:winter_chess/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final errors = <String>[];

  testWidgets('chess', (tester) async {
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/shots');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    final old = FlutterError.onError;
    FlutterError.onError = (d) => errors.add('${d.exceptionAsString().split('\n').take(3).join(' | ')}\n${d.stack.toString().split('\n').take(5).join('\n')}');
    app.main();
    await tester.pump(const Duration(seconds: 4));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    var n = 0;
    Future<void> shot(String name) async {
      await tester.pump(const Duration(milliseconds: 1500));
      n++;
      try {
        final b = await binding.takeScreenshot('${n.toString().padLeft(2, '0')}_$name');
        File('${dir.path}/${n.toString().padLeft(2, '0')}_$name.png').writeAsBytesSync(b);
      } catch (e) {
        errors.add('shot $name: $e');
      }
    }

    Future<void> tapText(String t) async {
      final f = find.text(t);
      if (f.evaluate().isEmpty) {
        errors.add('no text: $t');
        return;
      }
      await tester.tap(f.first);
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> tapSquare(String sq) async {
      final board = find.byType(ChessBoard).first;
      final r = tester.getRect(board);
      final s = r.width / 8;
      final file = 'abcdefgh'.indexOf(sq[0]);
      final rank = int.parse(sq[1]) - 1;
      await tester.tapAt(Offset(r.left + (file + 0.5) * s, r.top + (7 - rank + 0.5) * s));
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> back() async {
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.popUntil((r) => r.isFirst);
      await tester.pump(const Duration(seconds: 1));
    }

    await shot('menu');
    try {
      await tapText('Игра с ботом');
      await shot('bot_setup');
      await tapText('Начать');
      await tester.pump(const Duration(seconds: 1));
      await tapSquare('e2');
      await shot('selected_e2');
      await tapSquare('e4');
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await shot('after_bot_reply');
      await tapSquare('g1');
      await tapSquare('f3');
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await tester.tap(find.byIcon(Icons.lightbulb_outline));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await shot('hint');
      await tester.tap(find.byIcon(Icons.swap_vert));
      await shot('flipped');
      await tester.tap(find.byIcon(Icons.flag_outlined));
      await tester.pump(const Duration(seconds: 1));
      await tapText('Сдаться');
      await tester.pump(const Duration(seconds: 2));
      await shot('resigned');
      await tapText('Разбор партии');
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await shot('review');
    } catch (e) {
      errors.add('game: $e');
    }
    await back();
    try {
      await tapText('Задачи');
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await shot('puzzle');
      await tapText('Решение');
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await shot('puzzle_solution');
    } catch (e) {
      errors.add('puzzles: $e');
    }
    await back();
    try {
      await tapText('Уроки');
      await tapText('Ладья, слон, ферзь');
      await shot('lesson');
    } catch (e) {
      errors.add('lessons: $e');
    }
    await back();
    try {
      await tapText('Вдвоём на одном устройстве');
      await tapText('5 мин');
      await tapText('Начать');
      await tapSquare('d2');
      await tapSquare('d4');
      await tester.pump(const Duration(seconds: 2));
      await shot('local_clock');
    } catch (e) {
      errors.add('local: $e');
    }
    FlutterError.onError = old;
    File('${dir.path}/errors.txt').writeAsStringSync(errors.join('\n\n'));
    // ignore: avoid_print
    print('ERRORS: ${errors.length}\n${errors.join('\n')}');
  });
}
