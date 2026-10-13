"""Import data-only CC0 kits; retain licensed source and portable runtime files."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ALLOWED = {'.gltf', '.bin', '.png', '.txt'}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('archive', type=Path)
    parser.add_argument('kit')
    args = parser.parse_args()
    if not args.kit.replace('_', '').isalnum():
        raise ValueError('Invalid kit identifier')
    source = ROOT / 'art/environment/source' / args.kit
    runtime = ROOT / 'game/assets/environment' / args.kit
    imported = []
    with zipfile.ZipFile(args.archive) as archive:
        for entry in archive.infolist():
            path = PurePosixPath(entry.filename.replace('\\', '/'))
            if path.is_absolute() or '..' in path.parts or ':' in entry.filename:
                raise ValueError('Unsafe archive path')
            if entry.is_dir() or path.suffix.lower() not in ALLOWED:
                continue
            target = source / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.read(entry))
            output = runtime / path
            output.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(target, output)
            imported.append(str(path))
    manifest = {
        'archive_sha256': hashlib.sha256(args.archive.read_bytes()).hexdigest(),
        'licence': 'CC0-1.0', 'files': imported,
        'source_url': 'https://opengameart.org/content/stylized-nature-megakit',
    }
    (source / 'intake.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps({'source': str(source), 'runtime': str(runtime),
                      'files': len(imported), 'archive_sha256': manifest['archive_sha256']}))

if __name__ == '__main__':
    main()
