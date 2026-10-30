"""Выбирает задачи из открытой базы Lichess (CC0) и сохраняет assets/puzzles.json."""
import csv, io, json, random, sys
import zstandard

QUOTA = {
    'mateIn1': 160, 'mateIn2': 160, 'mateIn3': 80,
    'fork': 80, 'pin': 60, 'skewer': 40, 'discoveredAttack': 40,
    'hangingPiece': 60, 'endgame': 60, 'promotion': 30, 'sacrifice': 40,
}
picked = {k: [] for k in QUOTA}
seen = set()
random.seed(7)
with open(sys.argv[1], 'rb') as fh:
    reader = io.TextIOWrapper(zstandard.ZstdDecompressor().stream_reader(fh), encoding='utf-8')
    for row in csv.DictReader(reader):
        try:
            rating, pop, plays = int(row['Rating']), int(row['Popularity']), int(row['NbPlays'])
        except Exception:
            continue
        if pop < 85 or plays < 500 or rating > 2300:
            continue
        themes = row['Themes'].split()
        for t in themes:
            if t in QUOTA and len(picked[t]) < QUOTA[t] and row['PuzzleId'] not in seen:
                # равномерно по сложности
                bucket = min(rating // 300, 7)
                if sum(1 for p in picked[t] if min(p['r'] // 300, 7) == bucket) > QUOTA[t] // 5:
                    continue
                picked[t].append({'id': row['PuzzleId'], 'fen': row['FEN'], 'moves': row['Moves'].split(), 'r': rating, 'theme': t})
                seen.add(row['PuzzleId'])
                break
        if all(len(picked[k]) >= QUOTA[k] for k in QUOTA):
            break
out = [p for k in QUOTA for p in sorted(picked[k], key=lambda p: p['r'])]
json.dump({'source': 'Lichess puzzle database (CC0)', 'puzzles': out}, open('assets/puzzles.json', 'w'), separators=(',', ':'))
print({k: len(v) for k, v in picked.items()}, len(out))
