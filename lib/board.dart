import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'ui.dart';

/// Цвета доски.
class BoardColors {
  static const light = Color(0xFFD9E6F2);
  static const dark = Color(0xFF6F8FB3);
  static const lastMove = Color(0x99F6E27A);
  static const selected = Color(0xAA7FD8FF);
  static const check = Color(0xCCFF5C7A);
  static const hint = Color(0xAA5EE6A8);
}

String squareAt(int row, int col, bool flipped) {
  final file = flipped ? 7 - col : col;
  final rank = flipped ? row : 7 - row;
  return '${'abcdefgh'[file]}${rank + 1}';
}

String uciOf(Map m) => '${m['from']}${m['to']}${m['promotion'] ?? ''}';

/// Запись хода (SAN) для хода UCI в текущей позиции.
String? sanOf(ch.Chess c, String uci) {
  if (uci.length < 4) return null;
  for (final m in c.moves({'verbose': true})) {
    final mm = m as Map;
    if ('${mm['from']}${mm['to']}' != uci.substring(0, 4)) continue;
    final san = '${mm['san']}';
    if (uci.length > 4 && !san.contains('=${uci[4].toUpperCase()}')) continue;
    return san;
  }
  return null;
}

/// Сыграть ход в формате UCI (e2e4, e7e8q). true — ход сделан.
bool playUci(ch.Chess c, String uci) {
  if (uci.length < 4) return false;
  return c.move({'from': uci.substring(0, 2), 'to': uci.substring(2, 4), if (uci.length > 4) 'promotion': uci.substring(4, 5)});
}

/// Шахматная доска: нажми на фигуру, потом на клетку.
class ChessBoard extends StatefulWidget {
  final ch.Chess game;
  final bool flipped;
  final bool Function(ch.Color side) canMove; // можно ли сейчас ходить этой стороной
  final void Function(String uci) onMove;
  final String? lastMove; // uci
  final String? hintMove; // стрелка подсказки
  final Set<String> marks; // подсвеченные клетки (уроки)
  const ChessBoard({
    super.key,
    required this.game,
    required this.onMove,
    this.flipped = false,
    this.canMove = _always,
    this.lastMove,
    this.hintMove,
    this.marks = const {},
  });

  static bool _always(ch.Color _) => true;

  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

class _ChessBoardState extends State<ChessBoard> {
  String? selected;
  List<Map> targets = const [];

  void _tap(String sq) async {
    final g = widget.game;
    final p = g.get(sq);
    if (selected != null) {
      final ms = targets.where((m) => m['to'] == sq).toList();
      if (ms.isNotEmpty) {
        var promo = '';
        if (ms.length > 1 || '${ms.first['flags']}'.contains('p')) {
          final pick = await _promotion(g.turn);
          if (pick == null) return;
          promo = pick;
        }
        final uci = '$selected$sq$promo';
        setState(() {
          selected = null;
          targets = const [];
        });
        widget.onMove(uci);
        return;
      }
    }
    if (p != null && p.color == g.turn && widget.canMove(g.turn)) {
      setState(() {
        selected = sq;
        targets = [for (final m in g.moves({'verbose': true})) if (m['from'] == sq) m as Map];
      });
    } else {
      setState(() {
        selected = null;
        targets = const [];
      });
    }
  }

  Future<String?> _promotion(ch.Color color) => showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Превратить пешку в…', style: W.h2),
          content: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            for (final t in ['q', 'r', 'b', 'n'])
              InkWell(
                onTap: () => Navigator.pop(ctx, t),
                child: SizedBox(width: 56, height: 56, child: PieceImage(color == ch.Color.WHITE ? 'w' : 'b', t)),
              ),
          ]),
        ),
      );

  @override
  void didUpdateWidget(covariant ChessBoard old) {
    super.didUpdateWidget(old);
    if (selected != null && widget.game.get(selected!)?.color != widget.game.turn) {
      selected = null;
      targets = const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final last = widget.lastMove;
    String? checkSq;
    if (g.in_check) {
      for (var r = 0; r < 8 && checkSq == null; r++) {
        for (var f = 0; f < 8; f++) {
          final sq = '${'abcdefgh'[f]}${r + 1}';
          final p = g.get(sq);
          if (p != null && p.type.name == 'k' && p.color == g.turn) {
            checkSq = sq;
            break;
          }
        }
      }
    }
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(builder: (context, box) {
        final s = box.maxWidth / 8;
        return Stack(children: [
          Column(children: [
            for (var row = 0; row < 8; row++)
              Expanded(
                child: Row(children: [
                  for (var col = 0; col < 8; col++) _square(row, col, s, last, checkSq),
                ]),
              ),
          ]),
          if (widget.hintMove != null && widget.hintMove!.length >= 4)
            IgnorePointer(child: CustomPaint(size: Size(box.maxWidth, box.maxWidth), painter: _ArrowPainter(widget.hintMove!, widget.flipped))),
        ]);
      }),
    );
  }

  Widget _square(int row, int col, double s, String? last, String? checkSq) {
    final sq = squareAt(row, col, widget.flipped);
    final light = (row + col) % 2 == 0;
    final p = widget.game.get(sq);
    Color? overlay;
    if (last != null && last.length >= 4 && (last.substring(0, 2) == sq || last.substring(2, 4) == sq)) overlay = BoardColors.lastMove;
    if (widget.marks.contains(sq)) overlay = BoardColors.hint;
    if (sq == selected) overlay = BoardColors.selected;
    if (sq == checkSq) overlay = BoardColors.check;
    final isTarget = targets.any((m) => m['to'] == sq);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _tap(sq),
        child: Container(
          color: light ? BoardColors.light : BoardColors.dark,
          child: Stack(children: [
            if (overlay != null) Positioned.fill(child: ColoredBox(color: overlay)),
            if (p != null) Positioned.fill(child: Padding(padding: EdgeInsets.all(s * 0.04), child: PieceImage(p.color == ch.Color.WHITE ? 'w' : 'b', p.type.name))),
            if (isTarget)
              Center(
                child: p == null
                    ? Container(width: s * 0.3, height: s * 0.3, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x660A1020)))
                    : Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0x880A1020), width: s * 0.08)),
                      ),
              ),
            if (col == 0)
              Positioned(left: 2, top: 1, child: Text(sq[1], style: TextStyle(fontSize: s * 0.18, fontWeight: FontWeight.w700, color: light ? BoardColors.dark : BoardColors.light))),
            if (row == 7)
              Positioned(right: 3, bottom: 0, child: Text(sq[0], style: TextStyle(fontSize: s * 0.18, fontWeight: FontWeight.w700, color: light ? BoardColors.dark : BoardColors.light))),
          ]),
        ),
      ),
    );
  }
}

class PieceImage extends StatelessWidget {
  final String color, type;
  const PieceImage(this.color, this.type, {super.key});

  @override
  Widget build(BuildContext context) => SvgPicture.asset('assets/pieces/$color${type.toUpperCase()}.svg', fit: BoxFit.contain);
}

class _ArrowPainter extends CustomPainter {
  final String uci;
  final bool flipped;
  _ArrowPainter(this.uci, this.flipped);

  Offset _center(String sq, double s) {
    final f = 'abcdefgh'.indexOf(sq[0]);
    final r = int.parse(sq[1]) - 1;
    final col = flipped ? 7 - f : f;
    final row = flipped ? r : 7 - r;
    return Offset((col + 0.5) * s, (row + 0.5) * s);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 8;
    final a = _center(uci.substring(0, 2), s), b = _center(uci.substring(2, 4), s);
    final p = Paint()
      ..color = const Color(0xCC5EE6A8)
      ..strokeWidth = s * 0.16
      ..strokeCap = StrokeCap.round;
    final dir = (b - a) / (b - a).distance;
    final end = b - dir * s * 0.3;
    canvas.drawLine(a, end, p);
    final n = Offset(-dir.dy, dir.dx);
    final head = Path()
      ..moveTo(b.dx, b.dy)
      ..lineTo((end + n * s * 0.25).dx, (end + n * s * 0.25).dy)
      ..lineTo((end - n * s * 0.25).dx, (end - n * s * 0.25).dy)
      ..close();
    canvas.drawPath(head, Paint()..color = const Color(0xCC5EE6A8));
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter old) => old.uci != uci || old.flipped != flipped;
}
