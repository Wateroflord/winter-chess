import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'board.dart';
import 'engine.dart';
import 'lessons.dart';
import 'ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChessApp());
}

const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

class Store {
  static final _s = JsonStore('chess.json');
  static Map<String, dynamic> d = {};
  static Future<void> load() async => d = await _s.read();
  static Future<void> save() => _s.write(d);

  static List<Map> get games => ((d['games'] as List?) ?? const []).whereType<Map>().toList();
  static Future<void> addGame(Map g) {
    final l = [g, ...games];
    d['games'] = l.take(60).toList();
    return save();
  }

  static Set<String> get solved => {...((d['solved'] as List?) ?? const []).map((e) => '$e')};
  static Set<String> get lessonsDone => {...((d['lessons'] as List?) ?? const []).map((e) => '$e')};
}

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Шахматы',
        debugShowCheckedModeBanner: false,
        theme: winterTheme(const Color(0xFFB8E8FF)),
        home: const Menu(),
      );
}

class Menu extends StatefulWidget {
  const Menu({super.key});

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  bool? engine;

  @override
  void initState() {
    super.initState();
    Store.load().then((_) => setState(() {}));
    Stockfish.instance.start().then((ok) {
      if (mounted) setState(() => engine = ok);
    });
  }

  void go(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w)).then((_) => setState(() {}));

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String title, String sub, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: WCard(
            onTap: onTap,
            child: Row(children: [
              Icon(icon, color: W.accent, size: 28),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: W.h2), Text(sub, style: W.small)])),
              const Icon(Icons.chevron_right, color: W.muted),
            ]),
          ),
        );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                Row(children: [
                  const SizedBox(width: 52, height: 52, child: PieceImage('w', 'n')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Шахматы', style: W.h1),
                      Text(
                        engine == null
                            ? 'Запускаю Stockfish…'
                            : engine!
                                ? 'Движок Stockfish подключён'
                                : 'Stockfish недоступен на этом устройстве — играет встроенный бот',
                        style: W.small.copyWith(color: engine == true ? W.good : W.muted),
                      ),
                    ]),
                  ),
                ]),
                const SizedBox(height: 16),
                tile(Icons.smart_toy_outlined, 'Игра с ботом', '8 уровней: от новичка до полного Stockfish', () => go(const BotSetup())),
                tile(Icons.people_outline, 'Вдвоём на одном устройстве', 'С часами, доска может поворачиваться', () => go(const LocalSetup())),
                tile(Icons.extension_outlined, 'Задачи', 'Мат в 1–3 хода, вилки, связки — ${Store.solved.length} решено', () => go(const PuzzleScreen())),
                tile(Icons.school_outlined, 'Уроки', 'Правила и основы для начинающих — ${Store.lessonsDone.length} из ${lessons.length}', () => go(const LessonsScreen())),
                tile(Icons.analytics_outlined, 'Мои партии и разбор', 'Ошибки, лучшие ходы, точность — ${Store.games.length} партий', () => go(const GamesScreen())),
                const SizedBox(height: 18),
                const Text('Движок Stockfish (GPL-3.0) — github.com/official-stockfish/Stockfish. Фигуры cburnett (GPL). Задачи — открытая база Lichess (CC0).',
                    style: W.small, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- Настройка игры ----------------

class BotSetup extends StatefulWidget {
  const BotSetup({super.key});

  @override
  State<BotSetup> createState() => _BotSetupState();
}

class _BotSetupState extends State<BotSetup> {
  int level = (Store.d['level'] as num?)?.toInt() ?? 2;
  String color = '${Store.d['color'] ?? 'w'}';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Игра с ботом')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            const Section('Играть за'),
            Wrap(spacing: 8, children: [
              for (final c in [('w', 'Белых'), ('b', 'Чёрных'), ('r', 'Случайно')]) Chip2(c.$2, selected: color == c.$1, onTap: () => setState(() => color = c.$1)),
            ]),
            const Section('Сила бота'),
            for (var i = 0; i < botLevels.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: WCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  borderColor: level == i ? W.accent : null,
                  onTap: () => setState(() => level = i),
                  child: Row(children: [
                    Text('${i + 1}', style: W.h2.copyWith(color: W.accent)),
                    const SizedBox(width: 14),
                    Expanded(child: Text(botLevels[i].name, style: W.body)),
                    Text('≈${botLevels[i].elo}', style: W.small),
                  ]),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Store.d['level'] = level;
                Store.d['color'] = color;
                Store.save();
                final c = color == 'r' ? (math.Random().nextBool() ? 'w' : 'b') : color;
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => GameScreen(bot: botLevels[level], levelIndex: level, player: c)));
              },
              child: const Padding(padding: EdgeInsets.all(12), child: Text('Начать', style: TextStyle(fontSize: 16))),
            ),
          ],
        ),
      );
}

class LocalSetup extends StatefulWidget {
  const LocalSetup({super.key});

  @override
  State<LocalSetup> createState() => _LocalSetupState();
}

class _LocalSetupState extends State<LocalSetup> {
  int tc = (Store.d['tc'] as num?)?.toInt() ?? 0;
  bool autoFlip = Store.d['autoFlip'] == true;

  static const controls = [(0, 0, 'Без часов'), (3, 2, '3+2'), (5, 0, '5 мин'), (10, 0, '10 мин'), (15, 10, '15+10'), (30, 0, '30 мин')];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Вдвоём')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            const Section('Контроль времени'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 0; i < controls.length; i++) Chip2(controls[i].$3, selected: tc == i, onTap: () => setState(() => tc = i)),
            ]),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Поворачивать доску после каждого хода', style: W.body),
              subtitle: const Text('Удобно, когда передаёте телефон друг другу', style: W.small),
              value: autoFlip,
              onChanged: (v) => setState(() => autoFlip = v),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Store.d['tc'] = tc;
                Store.d['autoFlip'] = autoFlip;
                Store.save();
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (_) => GameScreen(minutes: controls[tc].$1, increment: controls[tc].$2, autoFlip: autoFlip)));
              },
              child: const Padding(padding: EdgeInsets.all(12), child: Text('Начать', style: TextStyle(fontSize: 16))),
            ),
          ],
        ),
      );
}

// ---------------- Партия ----------------

class GameScreen extends StatefulWidget {
  final BotLevel? bot;
  final int levelIndex;
  final String player; // за кого играет человек против бота
  final int minutes, increment;
  final bool autoFlip;
  const GameScreen({super.key, this.bot, this.levelIndex = 0, this.player = 'w', this.minutes = 0, this.increment = 0, this.autoFlip = false});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final game = ch.Chess();
  final List<String> moves = [], sans = [];
  late bool flipped = widget.bot != null && widget.player == 'b';
  bool thinking = false;
  String? result;
  String? hint;
  int whiteMs = 0, blackMs = 0;
  Timer? _clock;
  DateTime? _tick;
  bool saved = false;

  bool get vsBot => widget.bot != null;
  ch.Color get human => widget.player == 'w' ? ch.Color.WHITE : ch.Color.BLACK;

  @override
  void initState() {
    super.initState();
    whiteMs = blackMs = widget.minutes * 60000;
    if (widget.minutes > 0) {
      _clock = Timer.periodic(const Duration(milliseconds: 100), (_) => _tickClock());
    }
    if (vsBot && game.turn != human) _botMove();
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _tickClock() {
    if (result != null || moves.isEmpty) {
      _tick = DateTime.now();
      return;
    }
    final now = DateTime.now();
    final dt = now.difference(_tick ?? now).inMilliseconds;
    _tick = now;
    setState(() {
      if (game.turn == ch.Color.WHITE) {
        whiteMs -= dt;
        if (whiteMs <= 0) _finish('Время белых вышло — победа чёрных', '0-1');
      } else {
        blackMs -= dt;
        if (blackMs <= 0) _finish('Время чёрных вышло — победа белых', '1-0');
      }
    });
  }

  void _apply(String uci) {
    if (result != null) return;
    final san = sanOf(game, uci);
    final mover = game.turn;
    if (!playUci(game, uci)) return;
    HapticFeedback.selectionClick();
    moves.add(uci);
    sans.add('${san ?? uci}');
    hint = null;
    if (widget.increment > 0 && moves.length > 2) {
      if (mover == ch.Color.WHITE) {
        whiteMs += widget.increment * 1000;
      } else {
        blackMs += widget.increment * 1000;
      }
    }
    if (!vsBot && widget.autoFlip) flipped = game.turn == ch.Color.BLACK;
    _checkEnd();
    setState(() {});
    if (vsBot && result == null && game.turn != human) _botMove();
  }

  void _checkEnd() {
    if (game.in_checkmate) {
      _finish(game.turn == ch.Color.WHITE ? 'Мат! Победа чёрных' : 'Мат! Победа белых', game.turn == ch.Color.WHITE ? '0-1' : '1-0');
    } else if (game.in_stalemate) {
      _finish('Пат — ничья', '1/2-1/2');
    } else if (game.insufficient_material) {
      _finish('Ничья: мало фигур для мата', '1/2-1/2');
    } else if (game.in_threefold_repetition) {
      _finish('Ничья: троекратное повторение', '1/2-1/2');
    } else if (game.in_draw) {
      _finish('Ничья по правилу 50 ходов', '1/2-1/2');
    }
  }

  void _finish(String text, String score) {
    result = text;
    if (!saved && moves.isNotEmpty) {
      saved = true;
      Store.addGame({
        'date': DateTime.now().toIso8601String(),
        'mode': vsBot ? 'bot' : 'local',
        'level': vsBot ? widget.bot!.name : null,
        'player': widget.player,
        'moves': moves,
        'sans': sans,
        'result': score,
        'text': text,
      });
    }
    Future.microtask(() {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(text, style: W.h2),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReviewScreen(game: Store.games.first)));
              },
              child: const Text('Разбор партии'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _botMove() async {
    setState(() => thinking = true);
    final fen = game.fen;
    final m = await botMove(fen, widget.bot!);
    if (!mounted) return;
    setState(() => thinking = false);
    if (m != null && game.fen == fen) _apply(m);
  }

  void _undo() {
    if (thinking || moves.isEmpty) return;
    final n = vsBot ? (game.turn == human ? 2 : 1) : 1;
    for (var i = 0; i < n && moves.isNotEmpty; i++) {
      game.undo();
      moves.removeLast();
      sans.removeLast();
    }
    result = null;
    hint = null;
    setState(() {});
  }

  Future<void> _hint() async {
    if (thinking || result != null) return;
    setState(() => thinking = true);
    final e = await evaluate(game.fen, movetime: 600);
    if (!mounted) return;
    setState(() {
      thinking = false;
      hint = e.best;
    });
  }

  void _resign() async {
    if (result != null || moves.isEmpty) return;
    final ok = await confirmDialog(context, 'Сдаться?', 'Партия будет записана как поражение.', ok: 'Сдаться');
    if (!ok) return;
    final loser = vsBot ? human : game.turn;
    setState(() => _finish(loser == ch.Color.WHITE ? 'Белые сдались' : 'Чёрные сдались', loser == ch.Color.WHITE ? '0-1' : '1-0'));
  }

  String _fmt(int ms) {
    final s = (ms / 1000).ceil().clamp(0, 99999);
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Widget _clockView(ch.Color c) {
    final ms = c == ch.Color.WHITE ? whiteMs : blackMs;
    final active = game.turn == c && result == null && moves.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: active ? W.accent : W.surface2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(_fmt(ms),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: active ? W.bg : (ms < 20000 ? W.bad : W.text), fontFeatures: const [FontFeature.tabularFigures()])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = flipped ? ch.Color.WHITE : ch.Color.BLACK;
    final bottom = flipped ? ch.Color.BLACK : ch.Color.WHITE;
    String name(ch.Color c) {
      if (!vsBot) return c == ch.Color.WHITE ? 'Белые' : 'Чёрные';
      return c == human ? 'Ты' : 'Бот · ${widget.bot!.name}';
    }

    Widget side(ch.Color c) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Icon(Icons.circle, size: 14, color: c == ch.Color.WHITE ? Colors.white : Colors.black),
            const SizedBox(width: 8),
            Text(name(c), style: W.body.copyWith(fontWeight: FontWeight.w700)),
            if (thinking && vsBot && c != human) ...[
              const SizedBox(width: 8),
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
            const Spacer(),
            if (widget.minutes > 0) _clockView(c),
          ]),
        );

    final last = moves.isEmpty ? null : moves.last;
    final board = ChessBoard(
      game: game,
      flipped: flipped,
      lastMove: last,
      hintMove: hint,
      canMove: (c) => result == null && !thinking && (!vsBot || c == human),
      onMove: _apply,
    );
    final moveList = Wrap(spacing: 6, runSpacing: 4, children: [
      for (var i = 0; i < sans.length; i++)
        Text(i.isEven ? '${i ~/ 2 + 1}. ${sans[i]}' : sans[i], style: W.small.copyWith(color: i == sans.length - 1 ? W.accent : W.text)),
    ]);
    final buttons = Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      IconButton(tooltip: 'Перевернуть доску', icon: const Icon(Icons.swap_vert), onPressed: () => setState(() => flipped = !flipped)),
      IconButton(tooltip: 'Отменить ход', icon: const Icon(Icons.undo), onPressed: _undo),
      IconButton(tooltip: 'Подсказка', icon: const Icon(Icons.lightbulb_outline), onPressed: _hint),
      IconButton(tooltip: 'Сдаться', icon: const Icon(Icons.flag_outlined), onPressed: _resign),
    ]);
    return Scaffold(
      appBar: AppBar(title: Text(vsBot ? 'Против бота' : 'Вдвоём')),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth > box.maxHeight * 1.2;
          final boardSize = wide ? math.min(box.maxHeight - 100, box.maxWidth * 0.6) : math.min(box.maxWidth - 16, box.maxHeight - 220);
          final boardCol = SizedBox(
            width: boardSize,
            child: Column(mainAxisSize: MainAxisSize.min, children: [side(top), board, side(bottom)]),
          );
          final info = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (result != null)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(result!, style: W.h2.copyWith(color: W.accent), textAlign: TextAlign.center)),
            buttons,
            const SizedBox(height: 6),
            moveList,
          ]);
          if (wide) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.all(8), child: boardCol),
              Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: info)),
            ]);
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(children: [Center(child: boardCol), const SizedBox(height: 4), info]),
          );
        }),
      ),
    );
  }
}

// ---------------- Мои партии и разбор ----------------

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final games = Store.games;
    return Scaffold(
      appBar: AppBar(title: const Text('Мои партии')),
      body: games.isEmpty
          ? const Center(child: Text('Сыграй партию — она появится здесь', style: W.body))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                for (final g in games)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: WCard(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReviewScreen(game: g))),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${g['text'] ?? g['result']}', style: W.body.copyWith(fontWeight: FontWeight.w700)),
                            Text(
                              '${g['mode'] == 'bot' ? 'Бот «${g['level']}», ты за ${g['player'] == 'w' ? 'белых' : 'чёрных'}' : 'Вдвоём'} · ${((g['moves'] as List?) ?? const []).length ~/ 2 + 1} ходов · ${'${g['date']}'.substring(0, 10)}',
                              style: W.small,
                            ),
                          ]),
                        ),
                        const Icon(Icons.analytics_outlined, color: W.muted),
                      ]),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _MoveNote {
  final String san, uci;
  final int before, after; // оценка в сантипешках для белых
  final String? best;
  final String? bestSan;
  _MoveNote(this.san, this.uci, this.before, this.after, this.best, this.bestSan);
}

double _winPct(int cp) => 50 + 50 * (2 / (1 + math.exp(-0.00368208 * cp)) - 1);

class ReviewScreen extends StatefulWidget {
  final Map game;
  const ReviewScreen({super.key, required this.game});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final List<_MoveNote> notes = [];
  int done = 0;
  int ply = 0; // сколько ходов показано на доске
  late final List<String> moves = [for (final m in (widget.game['moves'] as List? ?? const [])) '$m'];
  late final List<String> sans = [for (final m in (widget.game['sans'] as List? ?? const [])) '$m'];
  bool flipped = false;
  bool cancelled = false;

  @override
  void initState() {
    super.initState();
    flipped = widget.game['player'] == 'b';
    ply = moves.length;
    _analyze();
  }

  @override
  void dispose() {
    cancelled = true;
    super.dispose();
  }

  Future<void> _analyze() async {
    final g = ch.Chess();
    int whiteEval(Eval e, ch.Color turn) => turn == ch.Color.WHITE ? e.score : -e.score;
    var prev = await evaluate(g.fen, movetime: 250);
    var prevW = whiteEval(prev, g.turn);
    for (var i = 0; i < moves.length && !cancelled; i++) {
      final best = prev.best;
      final bestSan = best == null ? null : sanOf(g, best);
      playUci(g, moves[i]);
      final e = g.game_over ? Eval(g.in_checkmate ? -10000 : 0, null, null) : await evaluate(g.fen, movetime: 250);
      final w = whiteEval(e, g.turn);
      notes.add(_MoveNote(i < sans.length ? sans[i] : moves[i], moves[i], prevW, w, best, bestSan));
      prev = e;
      prevW = w;
      if (!mounted) return;
      setState(() => done = i + 1);
    }
  }

  /// Потеря хода в «процентах шанса» для ходившей стороны.
  double _loss(int i) {
    final n = notes[i];
    final white = i.isEven;
    final b = _winPct(white ? n.before : -n.before), a = _winPct(white ? n.after : -n.after);
    return (b - a).clamp(0, 100).toDouble();
  }

  (String, Color)? _mark(int i) {
    final l = _loss(i);
    if (l >= 20) return ('??', W.bad);
    if (l >= 10) return ('?', const Color(0xFFFFA25E));
    if (l >= 5) return ('?!', W.warn);
    return null;
  }

  double _accuracy(bool white) {
    final xs = [for (var i = 0; i < notes.length; i++) if (i.isEven == white) (103.1668 * math.exp(-0.04354 * _loss(i)) - 3.1669).clamp(0, 100)];
    return xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
  }

  @override
  Widget build(BuildContext context) {
    final g = ch.Chess();
    for (var i = 0; i < ply; i++) {
      playUci(g, moves[i]);
    }
    final shown = ply > 0 && ply - 1 < notes.length ? notes[ply - 1] : null;
    final next = ply < notes.length ? notes[ply] : null;
    final mistakes = [for (var i = 0; i < notes.length; i++) if (_mark(i) != null) i];
    return Scaffold(
      appBar: AppBar(title: Text('Разбор: ${widget.game['result']}'), actions: [
        IconButton(icon: const Icon(Icons.swap_vert), onPressed: () => setState(() => flipped = !flipped)),
      ]),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 32),
              children: [
                if (done < moves.length)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(children: [
                      LinearProgressIndicator(value: moves.isEmpty ? 1 : done / moves.length),
                      const SizedBox(height: 4),
                      Text('Анализирую: $done из ${moves.length} ходов', style: W.small),
                    ]),
                  ),
                ChessBoard(game: g, flipped: flipped, lastMove: ply > 0 ? moves[ply - 1] : null, hintMove: next?.best, canMove: (_) => false, onMove: (_) {}),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  IconButton(icon: const Icon(Icons.first_page), onPressed: () => setState(() => ply = 0)),
                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: ply > 0 ? () => setState(() => ply--) : null),
                  Text('$ply / ${moves.length}', style: W.body),
                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: ply < moves.length ? () => setState(() => ply++) : null),
                  IconButton(icon: const Icon(Icons.last_page), onPressed: () => setState(() => ply = moves.length)),
                ]),
                if (shown != null)
                  WCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${(ply + 1) ~/ 2}. ${ply.isOdd ? '' : '… '}${shown.san} ${_mark(ply - 1)?.$1 ?? ''}',
                          style: W.h2.copyWith(color: _mark(ply - 1)?.$2 ?? W.text)),
                      const SizedBox(height: 4),
                      Text('Оценка: ${_evalText(shown.after)} (в пользу ${shown.after >= 0 ? 'белых' : 'чёрных'})', style: W.small),
                      if (_mark(ply - 1) != null && shown.bestSan != null)
                        Text('Лучше было: ${shown.bestSan}', style: W.body.copyWith(color: W.good)),
                    ]),
                  ),
                if (next?.bestSan != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Зелёная стрелка — лучший ход здесь: ${next!.bestSan}', style: W.small)),
                if (done == moves.length && moves.isNotEmpty) ...[
                  const Section('Итог'),
                  WCard(
                    child: Column(children: [
                      for (final white in [true, false])
                        Row(children: [
                          Expanded(child: Text(white ? 'Белые' : 'Чёрные', style: W.body)),
                          Text('точность ${_accuracy(white).round()}%', style: W.body.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(width: 12),
                          Text(
                            '?? ${[for (var i = 0; i < notes.length; i++) if (i.isEven == white && _mark(i)?.$1 == '??') i].length}  '
                            '? ${[for (var i = 0; i < notes.length; i++) if (i.isEven == white && _mark(i)?.$1 == '?') i].length}  '
                            '?! ${[for (var i = 0; i < notes.length; i++) if (i.isEven == white && _mark(i)?.$1 == '?!') i].length}',
                            style: W.small,
                          ),
                        ]),
                      const SizedBox(height: 6),
                      const Text('?? — грубая ошибка, ? — ошибка, ?! — неточность', style: W.small),
                    ]),
                  ),
                  if (mistakes.isNotEmpty) ...[
                    const Section('Ошибки'),
                    for (final i in mistakes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: WCard(
                          padding: const EdgeInsets.all(10),
                          onTap: () => setState(() => ply = i + 1),
                          child: Row(children: [
                            Text('${i ~/ 2 + 1}${i.isEven ? '.' : '…'} ${notes[i].san} ${_mark(i)!.$1}', style: W.body.copyWith(color: _mark(i)!.$2, fontWeight: FontWeight.w700)),
                            const Spacer(),
                            if (notes[i].bestSan != null) Text('лучше ${notes[i].bestSan}', style: W.small.copyWith(color: W.good)),
                          ]),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _evalText(int cp) {
    if (cp.abs() >= 9000) return 'мат';
    return (cp / 100).toStringAsFixed(1);
  }
}

// ---------------- Задачи ----------------

class Puzzle {
  final String id, fen, theme;
  final List<String> moves;
  final int rating;
  Puzzle(this.id, this.fen, this.moves, this.rating, this.theme);
}

const themeNames = {
  'mateIn1': 'Мат в 1 ход',
  'mateIn2': 'Мат в 2 хода',
  'mateIn3': 'Мат в 3 хода',
  'fork': 'Вилка',
  'pin': 'Связка',
  'skewer': 'Сквозной удар',
  'discoveredAttack': 'Вскрытое нападение',
  'hangingPiece': 'Незащищённая фигура',
  'endgame': 'Эндшпиль',
  'promotion': 'Превращение пешки',
  'sacrifice': 'Жертва',
};

class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key});

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  List<Puzzle> all = [];
  String theme = '${Store.d['ptheme'] ?? 'mateIn1'}';
  Puzzle? cur;
  ch.Chess game = ch.Chess();
  int step = 0;
  String? status;
  Color statusColor = W.text;
  bool busy = false;
  String? last;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/puzzles.json').then((s) {
      final j = jsonDecode(s) as Map;
      all = [
        for (final p in (j['puzzles'] as List? ?? const []).whereType<Map>())
          Puzzle('${p['id']}', '${p['fen']}', [for (final m in p['moves'] as List) '$m'], (p['r'] as num).toInt(), '${p['theme']}'),
      ];
      _next();
    });
  }

  List<Puzzle> get pool => all.where((p) => theme == 'all' || p.theme == theme).toList();

  void _next() {
    final solved = Store.solved;
    final list = pool;
    if (list.isEmpty) {
      setState(() => cur = null);
      return;
    }
    final unsolved = list.where((p) => !solved.contains(p.id)).toList();
    final p = (unsolved.isEmpty ? list : unsolved)[0];
    cur = p;
    game = ch.Chess.fromFEN(p.fen);
    step = 0;
    failed = false;
    status = null;
    last = null;
    setState(() {});
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted || cur != p) return;
      playUci(game, p.moves[0]);
      setState(() {
        last = p.moves[0];
        step = 1;
        status = '${game.turn == ch.Color.WHITE ? 'Белые' : 'Чёрные'} начинают и выигрывают';
        statusColor = W.text;
      });
    });
  }

  ch.Color get me => cur == null ? ch.Color.WHITE : (ch.Chess.fromFEN(cur!.fen).turn == ch.Color.WHITE ? ch.Color.BLACK : ch.Color.WHITE);

  void _move(String uci) {
    final p = cur;
    if (p == null || busy || step >= p.moves.length) return;
    final expected = p.moves[step];
    final ok = uci == expected || uci.substring(0, 4) == expected.substring(0, 4) && expected.length == 4;
    playUci(game, uci);
    last = uci;
    final mateOk = game.in_checkmate; // любой мат засчитываем
    if (!ok && !mateOk) {
      failed = true;
      setState(() {
        status = 'Не тот ход. Попробуй ещё раз';
        statusColor = W.bad;
        busy = true;
      });
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        game.undo();
        setState(() {
          busy = false;
          last = p.moves[step - 1];
        });
      });
      return;
    }
    step++;
    if (mateOk || step >= p.moves.length) {
      _solved();
      return;
    }
    setState(() {
      status = 'Верно! Дальше…';
      statusColor = W.good;
      busy = true;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      playUci(game, p.moves[step]);
      last = p.moves[step];
      step++;
      setState(() => busy = false);
    });
  }

  void _solved() {
    HapticFeedback.mediumImpact();
    if (!failed) {
      final s = Store.solved..add(cur!.id);
      Store.d['solved'] = s.toList();
      Store.save();
    }
    setState(() {
      status = failed ? 'Решено (с ошибкой — засчитаю, если решишь с первого раза)' : 'Решено! 🎉';
      statusColor = W.good;
    });
  }

  Future<void> _showSolution() async {
    final p = cur;
    if (p == null) return;
    failed = true;
    busy = true;
    while (step < p.moves.length && mounted) {
      playUci(game, p.moves[step]);
      last = p.moves[step];
      step++;
      setState(() {});
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    busy = false;
    if (mounted) setState(() => status = 'Это было решение');
  }

  @override
  Widget build(BuildContext context) {
    final p = cur;
    final solvedCount = pool.where((x) => Store.solved.contains(x.id)).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Задачи')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 32),
              children: [
                SizedBox(
                  height: 40,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (final t in ['all', ...themeNames.keys])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Chip2(t == 'all' ? 'Все' : themeNames[t]!, selected: theme == t, onTap: () {
                          theme = t;
                          Store.d['ptheme'] = t;
                          Store.save();
                          _next();
                        }),
                      ),
                  ]),
                ),
                const SizedBox(height: 8),
                if (all.isEmpty)
                  const Padding(padding: EdgeInsets.all(24), child: Text('Задачи загружаются…', style: W.body))
                else if (p == null)
                  const Padding(padding: EdgeInsets.all(24), child: Text('В этой теме пока нет задач', style: W.body))
                else ...[
                  Row(children: [
                    Text(themeNames[p.theme] ?? p.theme, style: W.h2),
                    const Spacer(),
                    Text('рейтинг ${p.rating} · решено $solvedCount/${pool.length}', style: W.small),
                  ]),
                  const SizedBox(height: 6),
                  ChessBoard(
                    game: game,
                    flipped: me == ch.Color.BLACK,
                    lastMove: last,
                    canMove: (c) => !busy && c == me && step > 0 && step < p.moves.length,
                    onMove: _move,
                  ),
                  const SizedBox(height: 8),
                  if (status != null) Text(status!, style: W.h2.copyWith(color: statusColor), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: busy || step >= p.moves.length ? null : _showSolution, child: const Text('Решение'))),
                    const SizedBox(width: 8),
                    Expanded(child: FilledButton(onPressed: busy ? null : _next, child: const Text('Следующая'))),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- Уроки ----------------

class LessonsScreen extends StatefulWidget {
  const LessonsScreen({super.key});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  @override
  Widget build(BuildContext context) {
    final done = Store.lessonsDone;
    return Scaffold(
      appBar: AppBar(title: const Text('Уроки')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          for (var i = 0; i < lessons.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: WCard(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LessonScreen(index: i))).then((_) => setState(() {})),
                child: Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: done.contains('$i') ? W.good : W.surface2),
                    child: done.contains('$i') ? const Icon(Icons.check, color: W.bg, size: 20) : Text('${i + 1}', style: W.body),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(lessons[i].title, style: W.h2), Text(lessons[i].subtitle, style: W.small)])),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class LessonScreen extends StatefulWidget {
  final int index;
  const LessonScreen({super.key, required this.index});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  int step = 0;
  ch.Chess? game;
  bool solved = false;
  String? feedback;
  String? last;

  Lesson get lesson => lessons[widget.index];
  LessonStep get cur => lesson.steps[step];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final f = cur.fen;
    game = f == null ? null : ch.Chess.fromFEN(f, check_validity: false);
    solved = cur.answer.isEmpty;
    feedback = null;
    last = null;
  }

  void _move(String uci) {
    final g = game!;
    playUci(g, uci);
    if (cur.answer.any((a) => a == uci || (a.length == 4 && uci.startsWith(a)))) {
      HapticFeedback.mediumImpact();
      setState(() {
        solved = true;
        last = uci;
        feedback = 'Верно! 👍';
      });
    } else {
      setState(() {
        last = uci;
        feedback = 'Не то. Попробуй ещё раз';
      });
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        g.undo();
        setState(() => last = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = game;
    final isLast = step == lesson.steps.length - 1;
    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
              children: [
                LinearProgressIndicator(value: (step + 1) / lesson.steps.length),
                const SizedBox(height: 12),
                Text(cur.text, style: W.body.copyWith(fontSize: 15.5)),
                const SizedBox(height: 12),
                if (g != null)
                  ChessBoard(
                    key: ValueKey('$step'),
                    game: g,
                    lastMove: last,
                    marks: cur.marks.toSet(),
                    canMove: (c) => cur.answer.isNotEmpty && !solved,
                    onMove: _move,
                  ),
                if (feedback != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(feedback!, textAlign: TextAlign.center, style: W.h2.copyWith(color: solved ? W.good : W.bad)),
                  ),
                const SizedBox(height: 12),
                Row(children: [
                  if (step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() {
                          step--;
                          _load();
                        }),
                        child: const Text('Назад'),
                      ),
                    ),
                  if (step > 0) const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: !solved
                          ? null
                          : () {
                              if (isLast) {
                                final d = Store.lessonsDone..add('${widget.index}');
                                Store.d['lessons'] = d.toList();
                                Store.save();
                                Navigator.pop(context);
                              } else {
                                setState(() {
                                  step++;
                                  _load();
                                });
                              }
                            },
                      child: Text(isLast ? 'Урок пройден' : (cur.answer.isNotEmpty && !solved ? 'Сделай ход на доске' : 'Дальше')),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
