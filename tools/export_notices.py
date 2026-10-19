"""Complete redistributable notices shared by every supported package path."""
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]


def copy_runtime_notices(destination):
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=True)
    for name in ('GODOT-LICENSE.txt', 'GODOT-COPYRIGHT.txt', 'ASSET-CREDITS.md'):
        shutil.copy2(ROOT / 'docs' / name, destination / name)
    source = ROOT / 'game/addons/twovoip'
    provenance = json.loads((source / 'PROVENANCE.json').read_text())
    notices = destination / 'third-party-notices/twovoip'
    notices.mkdir(parents=True, exist_ok=True)
    for name, expected in provenance['licenses'].items():
        if Path(name).name != name or hashlib.sha256((source / name).read_bytes()).hexdigest() != expected:
            raise ValueError('Runtime codec notice/provenance mismatch: ' + name)
        shutil.copy2(source / name, notices / name)
    shutil.copy2(source / 'PROVENANCE.json', notices / 'PROVENANCE.json')
    # Include this small bundle on all platforms, even where optional Mac capture
    # is absent, so all_resources exports cannot omit its accompanying notices.
    source = ROOT / 'game/addons/world_rise_mic'
    notices = destination / 'third-party-notices/world_rise_mic'
    notices.mkdir(parents=True, exist_ok=True)
    for name in ('LICENSE', 'GODOT-CPP-LICENSE', 'PROVENANCE.json', 'README.md'):
        shutil.copy2(source / name, notices / name)
