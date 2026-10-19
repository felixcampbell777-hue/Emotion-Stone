"""Export the pinned Linux x86_64 dedicated server without changing client presets."""
import hashlib
import json
from pathlib import Path
import shutil


def export_server(skip_tests=False):
    from platform_cli import ROOT, GAME, toolchain, validate, import_game, run_process, write, digest, package_fingerprints
    if not skip_tests:
        validate()
    else:
        print('UNTESTED SERVER PACKAGE: content validation skipped; no gameplay certification')
    scene = GAME / 'scenes/world_rise_server.tscn'
    if not scene.is_file():
        raise ValueError('Dedicated server scene not available yet')
    chain = toolchain(('godot', 'linux_release_template', 'linux_debug_template'))
    version = json.loads((GAME / 'content/release.json').read_text())['version']
    output = ROOT / 'output/linux-server' / ('v' + version)
    output.mkdir(parents=True, exist_ok=True)
    executable = output / 'world-rise-server.x86_64'
    import_game()
    source_before={**package_fingerprints(),'durable_helper':hashlib.sha256((ROOT/'tools/network/durable_replace.py').read_bytes()).hexdigest()}
    presets = GAME / 'export_presets.cfg'
    previous = presets.read_bytes() if presets.exists() else None
    try:
        presets.write_text(f'''[preset.0]
name="World Rise Dedicated Server"
platform="Linux"
runnable=false
dedicated_server=true
custom_features="dedicated_server"
export_filter="all_resources"
include_filter="content/*.json,content/**/*.json"
exclude_filter=""
script_export_mode=2

[preset.0.options]
custom_template/debug="{Path(chain['linux_debug_template']).as_posix()}"
custom_template/release="{Path(chain['linux_release_template']).as_posix()}"
binary_format/architecture="x86_64"
binary_format/embed_pck=true
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
''')
        run_process([chain['godot'], '--headless', '--path', str(GAME), '--export-release', 'World Rise Dedicated Server', str(executable)], timeout=900, log='linux-server-export.log', isolated=True)
    finally:
        if previous is None:
            presets.unlink(missing_ok=True)
        else:
            presets.write_bytes(previous)
    if not executable.is_file():
        raise RuntimeError('Dedicated export did not create executable')
    executable.chmod(0o755)
    helper = ROOT / 'tools/network/durable_replace.py'
    if not helper.is_file():
        raise ValueError('Durable persistence helper missing')
    shutil.copy2(helper, output / 'durable_replace.py')
    from export_notices import copy_runtime_notices
    copy_runtime_notices(output)
    source_after={**package_fingerprints(),'durable_helper':hashlib.sha256((ROOT/'tools/network/durable_replace.py').read_bytes()).hexdigest()}
    if source_before!=source_after:print('SOURCE CHANGED DURING EXPORT: this candidate must be re-exported after the source freeze')
    write(output / 'manifest.json', {'game_version': version, 'engine_version': chain['godot_version'], 'architecture': 'linux-x86_64', 'validated_content': not skip_tests, 'source_stable_during_export':source_before==source_after,'source_before':source_before,'source_after':source_after, 'content_sha256': digest(list((GAME / 'content').rglob('*.json'))), 'scripts_sha256': digest(list((GAME / 'scripts').rglob('*.gd'))), 'files': {p.relative_to(output).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in output.rglob('*') if p.is_file() and p.name != 'manifest.json'}})
    print(f'SERVER PACKAGE: {output}; runtime/integration acceptance still required')
    return output
