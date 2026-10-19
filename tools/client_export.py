"""Package desktop client candidates; release/gameplay gates remain separate."""
import hashlib
import json
from pathlib import Path
import shutil
import zipfile


def export_client(target, skip_tests=False):
    from platform_cli import ROOT, GAME, validate, toolchain, import_game, run_process, write, digest, package_fingerprints
    if skip_tests:
        print('UNTESTED CLIENT PACKAGE: content validation skipped')
    else:
        validate()
    required = ('godot','macos_template') if target == 'macos' else ('godot','windows_release_template','windows_debug_template')
    chain = toolchain(required)
    version = json.loads((GAME/'content/release.json').read_text())['version']
    directory = ROOT/'output/clients'/target/('v'+version)
    directory.mkdir(parents=True, exist_ok=True)
    platform = 'macOS' if target == 'macos' else 'Windows Desktop'
    package = directory / ('WorldRise.zip' if target == 'macos' else 'WorldRise.exe')
    presets = GAME/'export_presets.cfg'
    old = presets.read_bytes() if presets.exists() else None
    raw_include = 'content/*.json,content/**/*.json'
    if target == 'macos':
        if not (GAME/'addons/world_rise_mic/libs/world_rise_mic.macos.universal.bin').is_file():
            raise ValueError('Build the pinned macOS microphone runtime before exporting a Mac client')
        raw_include += ',addons/world_rise_mic/libs/*.bin'
    common = f'''[preset.0]
name="World Rise Client"
platform="{platform}"
runnable=true
export_filter="all_resources"
include_filter="{raw_include}"
exclude_filter=""
script_export_mode=2

[preset.0.options]
'''
    if target == 'macos':
        options = f'''custom_template/debug="{Path(chain['macos_template']).as_posix()}"
custom_template/release="{Path(chain['macos_template']).as_posix()}"
application/bundle_identifier="org.worldrise.game"
application/short_version="{version}"
application/version="{version}"
codesign/codesign=1
codesign/entitlements/audio_input=true
codesign/entitlements/disable_library_validation=true
notarization/notarization=0
privacy/microphone_usage_description="Microphone access enables optional push-to-talk voice chat."
texture_format/s3tc_bptc=true
texture_format/etc2_astc=true
'''
    else:
        options = f'''custom_template/debug="{Path(chain['windows_debug_template']).as_posix()}"
custom_template/release="{Path(chain['windows_release_template']).as_posix()}"
binary_format/architecture="x86_64"
binary_format/embed_pck=true
codesign/enable=false
application/modify_resources=false
application/file_version="{version}"
application/product_version="{version}"
texture_format/s3tc_bptc=true
'''
    import_game()
    source_before=package_fingerprints()
    try:
        presets.write_text(common+options)
        run_process([chain['godot'],'--headless','--path',str(GAME),'--export-release','World Rise Client',str(package)],timeout=900,log=f'{target}-client-export.log',isolated=True,export_template=chain['macos_template'] if target=='macos' else None)
    finally:
        if old is None:presets.unlink(missing_ok=True)
        else:presets.write_bytes(old)
    if not package.is_file():raise RuntimeError('Client package not created')
    from export_notices import copy_runtime_notices
    copy_runtime_notices(directory)
    if target == 'macos':
        # Notices travel inside the downloadable ZIP as well as beside it.
        with zipfile.ZipFile(package,'a',zipfile.ZIP_DEFLATED) as archive:
            for notice in [*directory.glob('*.md'), *directory.glob('*.txt'), *directory.joinpath('third-party-notices').rglob('*')]:
                if notice.is_file():
                    archive.write(notice,notice.relative_to(directory).as_posix())
    source_after=package_fingerprints()
    if source_before!=source_after:print('SOURCE CHANGED DURING EXPORT: this candidate must be re-exported after the source freeze')
    write(directory/'manifest.json',{'game_version':version,'engine_version':chain['godot_version'],'target':target,'content_validated':not skip_tests,'release_gates_complete':False,'source_stable_during_export':source_before==source_after,'source_before':source_before,'source_after':source_after,'content_sha256':digest(list((GAME/'content').rglob('*.json'))),'scripts_sha256':digest(list((GAME/'scripts').rglob('*.gd'))),'files':{p.relative_to(directory).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in [package, *directory.glob('*.md'), *directory.glob('*.txt'), *directory.joinpath('third-party-notices').rglob('*'), *(directory.rglob('*.dll') if target=='windows' else [])] if p.is_file()}})
    print(f'CLIENT CANDIDATE: {package}; content validation/packaging only, release gates incomplete')
    return package
