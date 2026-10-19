"""Portable machine-local tool/cache and disposable Godot data paths."""
import os
from pathlib import Path
import sys


def cache_dir():
    return Path(os.environ.get('WORLD_RISE_TOOL_CACHE', Path.home() / '.cache' / 'comic-art-platform')).expanduser()


def isolated_environment(scratch):
    """Godot resolves user:// differently on each OS; never inherit player data."""
    root = Path(scratch)
    env = dict(os.environ)
    for key, suffix in {'APPDATA': 'roaming', 'LOCALAPPDATA': 'local',
                        'XDG_DATA_HOME': 'data', 'XDG_CONFIG_HOME': 'config',
                        'XDG_CACHE_HOME': 'cache', 'TMPDIR': 'tmp',
                        'TEMP': 'tmp', 'TMP': 'tmp'}.items():
        folder = root / suffix
        folder.mkdir(parents=True, exist_ok=True)
        env[key] = str(folder)
    # Godot's macOS backend uses HOME/Library/Application Support, not XDG.
    if sys.platform == 'darwin':
        folder = root / 'home'
        folder.mkdir(parents=True, exist_ok=True)
        env['HOME'] = str(folder)
    return env
