"""Assemble native dash captures into reusable visual QA previews; never edits game art."""
import argparse
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path.home() / '.cache/comic-art-platform/python'))
from PIL import Image, ImageDraw


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--register', action='store_true', help='Retain previews after all capture processes finish')
    args = parser.parse_args()
    base = ROOT / 'output/verification'
    rendered = base / 'windows-render'
    previews = []
    for name in ['dash-attack', 'mana-dash-attack']:
        folder = rendered / name
        if not (folder / 'motion.json').is_file():
            continue
        rows = json.loads((folder / 'motion.json').read_text())
        frames = [Image.open(folder / f"frame-{r['frame']:02}.png").convert('RGB') for r in rows]
        animation = [frame.resize((800, 450), Image.Resampling.LANCZOS) for frame in frames]
        animation[0].save(rendered / f'{name}.gif', save_all=True, append_images=animation[1:], duration=33, loop=0)
        selected = [0, 6, 12, 20, 27, 34, 40, 46, 53, 60, 67, 73]
        sheet = Image.new('RGB', (456 * 4, 280 * 3), (18, 23, 28))
        draw = ImageDraw.Draw(sheet)
        for n, i in enumerate(selected):
            x, y = n % 4 * 456, n // 4 * 280
            sheet.paste(frames[i].resize((456, 256), Image.Resampling.LANCZOS), (x, y))
            r = rows[i]
            draw.text((x + 6, y + 260), f"{i:02} {r['state']} / {r['phase']:.2f} · waves {r.get('waves', 0)}", fill=(230, 234, 235))
        sheet.save(rendered / f'{name}-sheet.png')
        assert rows[-1]['state'] == 'free' and not rows[-1].get('glowing', False)
        if name == 'mana-dash-attack':
            assert any(r['glowing'] for r in rows) and any(r['waves'] > 0 for r in rows)
        previews.extend([f'{name}.gif', f'{name}-sheet.png'])
        print(f'NATIVE PREVIEW PASS: {name}, {len(rows)} frames, normal steel restored')
    if args.register:
        path = base / 'current-render-evidence.json'
        evidence = json.loads(path.read_text())
        cache = json.loads((ROOT / 'output/build-cache.json').read_text())
        release = json.loads((ROOT / 'game/content/release.json').read_text())
        assert evidence['game_key'] == cache['game_key'] and evidence['release'] == release['version']
        evidence['files'] = sorted(set(evidence['files']) | set(previews))
        path.write_text(json.dumps(evidence, indent=2) + '\n')


if __name__ == '__main__':
    main()
