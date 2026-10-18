"""Read-only, standard-library check of a collaborator's materialized checkout."""
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    result = subprocess.run(
        ['git', 'ls-files', '-z'], cwd=ROOT, capture_output=True, check=True)
    tracked = set(result.stdout.decode('utf-8').rstrip('\0').split('\0'))
    problems = []
    for name in sorted(tracked):
        path = ROOT / name
        if not path.is_file():
            problems.append('Missing tracked file: ' + name)
            continue
        # LFS stub text is not a usable model/image, even though Git reports clean.
        with path.open('rb') as stream:
            header = stream.read(160)
        if header.startswith(b'version https://git-lfs.github.com/spec/v1\n'):
            problems.append('Git LFS object not downloaded: ' + name)
    for name in ['game/project.godot', 'game/content/release.json',
                 'game/content/world_rise/floor_01.json',
                 'game/content/world_rise/floor_02.json',
                 'art/source/beta-heroine.blend',
                 'docs/maps/floor-02-island-codes.json']:
        if name not in tracked:
            problems.append('Required handoff file is not tracked: ' + name)
    references = set()
    for name in sorted(tracked):
        if not name.startswith('game/') or Path(name).suffix not in {
                '.gd', '.tscn', '.tres', '.godot', '.json', '.gdshader'}:
            continue
        path = ROOT / name
        if not path.is_file():
            continue
        source = path.read_text(encoding='utf-8', errors='replace')
        for target in re.findall(r'''["']res://([^"']+)["']''', source):
            if target.startswith('../output/'):
                continue  # Generated test report destinations, never input assets.
            if any(part in target for part in ('*', '%', '{')) or target.endswith('/'):
                continue  # Dynamic paths are exercised by Godot, not this check.
            resource = 'game/' + target
            if (ROOT / resource).is_dir():
                continue
            if (ROOT / resource).is_file():
                references.add(resource)
                if resource not in tracked:
                    problems.append('Runtime dependency is untracked: ' + resource)
            else:
                problems.append(f'{name}: missing literal runtime resource {target}')
    if problems:
        print('\n'.join(sorted(set(problems))))
        print('Run git lfs pull and resolve missing files before importing Godot.')
        return 1
    print(f'CHECKOUT OK: {len(tracked)} tracked files; '
          f'{len(references)} literal runtime dependencies; no missing files or LFS stubs.')
    print('Read-only check; no player data or test artifacts created. '
          'Dynamic paths/gameplay still require relevant Godot verification.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
