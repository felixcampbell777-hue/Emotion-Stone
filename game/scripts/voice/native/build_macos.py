"""Build the optional macOS microphone runtime with pinned Godot 4.5 bindings.
Run explicitly on macOS with Apple command-line developer tools installed.
No engine executable or OS privacy preference is modified.
"""
from pathlib import Path
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

PIN = 'e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77'
ROOT = Path(__file__).resolve().parents[4]
NATIVE = Path(__file__).resolve().parent
CACHE = Path(os.environ.get('WORLD_RISE_NATIVE_BUILD_CACHE', Path.home() / '.cache' / 'world-rise-native-mic'))


def run(args, **kwargs):
    subprocess.run([str(value) for value in args], check=True, **kwargs)


def main():
    if sys.platform != 'darwin':
        raise SystemExit('Build requires macOS and Apple command-line developer tools')
    CACHE.mkdir(parents=True, exist_ok=True)
    cpp = CACHE / 'godot-cpp'
    if not cpp.exists():
        run(['git', 'clone', '--depth', '1', '--branch', 'godot-4.5-stable', 'https://github.com/godotengine/godot-cpp.git', cpp])
    actual = subprocess.check_output(['git', '-C', str(cpp), 'rev-parse', 'HEAD'], text=True).strip()
    if actual != PIN:
        raise SystemExit('godot-cpp pin mismatch; use a fresh build cache')
    venv = CACHE / 'venv'
    if not venv.exists():
        run([sys.executable, '-m', 'venv', venv])
    scons = venv / 'bin' / 'scons'
    if not scons.exists():
        run([venv / 'bin' / 'pip', 'install', 'scons==4.10.1'])
    if 'v4.10.1' not in subprocess.check_output([str(scons), '--version'], text=True):
        raise SystemExit('SCons pin mismatch')
    with tempfile.TemporaryDirectory(prefix='world-rise-mic-build-') as scratch:
        work = Path(scratch)
        shutil.copy(NATIVE / 'SConstruct', work)
        shutil.copy(NATIVE / 'profile.json', work)
        shutil.copytree(NATIVE / 'src', work / 'src', ignore=shutil.ignore_patterns('*.o', '*.os'))
        env = dict(os.environ, WORLD_RISE_GODOT_CPP=str(cpp), WORLD_RISE_NATIVE_OUT=str(work / 'out'))
        for arch in ['arm64', 'x86_64']:
            run([scons, '-C', work, 'platform=macos', 'arch=' + arch, 'target=template_release', 'build_profile=profile.json', 'macos_deployment_target=12.0', '-j4'], env=env)
        candidate = work / 'world_rise_mic.bin'
        run(['lipo', '-create', work / 'out/libworld_rise_mic.arm64', work / 'out/libworld_rise_mic.x86_64', '-output', candidate])
        run(['install_name_tool', '-id', '@rpath/world_rise_mic.dylib', candidate])
        run(['codesign', '--force', '--sign', '-', candidate])
        run(['codesign', '--verify', '--strict', candidate])
        target = ROOT / 'game/addons/world_rise_mic/libs/world_rise_mic.macos.universal.bin'
        target.parent.mkdir(parents=True, exist_ok=True)
        pending = target.with_suffix('.pending')
        shutil.copyfile(candidate, pending)
        os.replace(pending, target)
        sha = hashlib.sha256(target.read_bytes()).hexdigest()
        loader = ROOT / 'game/scripts/voice/native_capture.gd'
        loader.write_text(re.sub(r'EXPECTED_SHA256 := "[^"]+"', 'EXPECTED_SHA256 := "' + sha + '"', loader.read_text()))
        manifest = {'godot_cpp_repository': 'https://github.com/godotengine/godot-cpp', 'godot_cpp_commit': PIN,
                    'scons': '4.10.1', 'engine': 'Godot 4.5.1', 'macos_deployment_target': '12.0',
                    'architectures': ['arm64', 'x86_64'], 'signing': 'ad hoc; distribution notarization remains required',
                    'payload_sha256': sha, 'source_sha256': hashlib.sha256((NATIVE / 'src/mic_capture.mm').read_bytes()).hexdigest()}
        (target.parents[1] / 'PROVENANCE.json').write_text(json.dumps(manifest, indent=2) + '\n')
        print('Built universal microphone runtime SHA-256:', sha)


if __name__ == '__main__':
    main()
