"""Local editing/build CLI. Routine content edits never invoke image generation."""
import argparse
import copy
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import zipfile

ROOT=Path(__file__).resolve().parents[1]
GAME=ROOT/'game'
CACHE=Path(os.environ['USERPROFILE'])/'.cache/comic-art-platform'
sys.path.insert(0,str(CACHE/'python'))
from jsonschema import Draft202012Validator


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def write(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    temporary=path.with_suffix(path.suffix+'.tmp')
    temporary.write_text(json.dumps(data,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    temporary.replace(path)


def valid(kind,data):
    validator=Draft202012Validator(read(ROOT/'schemas'/f'{kind}.schema.json'))
    errors=sorted(validator.iter_errors(data),key=lambda error:str(error.path))
    if errors:
        error=errors[0]
        raise ValueError(f'{kind} {list(error.path)}: {error.message}')


def validate():
    characters={}
    maps={}
    for kind,folder,collection in [('character','characters',characters),('map','maps',maps)]:
        for path in sorted((GAME/'content'/folder).glob('*.json')):
            data=read(path)
            valid(kind,data)
            if path.stem!=data['id']:
                raise ValueError(f'{path.name}: id must match filename')
            collection[data['id']]=data
    config=read(GAME/'content/platform.json')
    valid('platform',config)
    if config['start_map'] not in maps or config['player_character'] not in characters:
        raise ValueError('Platform references an unknown map or character')
    for name,data in maps.items():
        x0,z0,x1,z1=data['bounds']
        if x1<=x0 or z1<=z0:
            raise ValueError(f'{name}: bounds must have positive size')
        ids=[]
        for key in ['props','npcs','interactions','exits']:
            for item in data[key]:
                ids.append(item['id'])
                if 'at' in item and not (x0<=item['at'][0]<x1 and z0<=item['at'][1]<z1):
                    raise ValueError(f'{name}/{item["id"]}: position outside map bounds')
        if len(ids)!=len(set(ids)):
            raise ValueError(f'{name}: duplicate object id')
        if not (x0<=data['spawn'][0]<x1 and z0<=data['spawn'][1]<z1):
            raise ValueError(f'{name}: spawn outside map bounds')
        for npc in data['npcs']:
            if npc['character'] not in characters:
                raise ValueError(f'{name}/{npc["id"]}: unknown character')
        for exit in data['exits']:
            if exit['target'] not in maps:
                raise ValueError(f'{name}/{exit["id"]}: unknown target map')
            target=maps[exit['target']]['bounds']
            if not (target[0]<=exit['spawn'][0]<target[2] and target[1]<=exit['spawn'][1]<target[3]):
                raise ValueError(f'{name}/{exit["id"]}: exit spawn outside destination')
    print(f'VALID: {len(characters)} characters, {len(maps)} maps, platform settings')


def toolchain():
    path=ROOT/'tools/toolchain.local.json'
    if not path.exists():
        raise ValueError('Run tools/bootstrap_runtime.py once to set up portable tools.')
    data=read(path)
    for key in ['godot','blender','windows_release_template']:
        if not Path(data[key]).is_file():
            raise ValueError(f'Missing tool: {key}; rerun bootstrap_runtime.py')
    return data


def digest(paths,extra=''):
    result=hashlib.sha256(extra.encode())
    for path in sorted(paths):
        result.update(str(path.relative_to(ROOT)).encode())
        result.update(path.read_bytes())
    return result.hexdigest()


def run_process(arguments,timeout=240,log='last-build.log',rendered=False):
    started=time.perf_counter()
    options={}
    if rendered:
        info=subprocess.STARTUPINFO()
        info.dwFlags|=subprocess.STARTF_USESHOWWINDOW
        info.wShowWindow=0
        options['startupinfo']=info
    result=subprocess.run(arguments,cwd=ROOT,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=timeout,**options)
    log_path=ROOT/'output/verification'/log
    log_path.parent.mkdir(parents=True,exist_ok=True)
    log_path.write_text(result.stdout+result.stderr,encoding='utf-8')
    if result.returncode or 'SCRIPT ERROR:' in result.stderr or '\nERROR:' in result.stderr:
        print((result.stdout+result.stderr)[-8000:])
        raise RuntimeError(f'Command failed; see {log_path}')
    print(f'OK: {Path(arguments[0]).name} ({time.perf_counter()-started:.2f}s)')
    return result.stdout


def assets(regenerate=False):
    chain=toolchain()
    cache_path=ROOT/'output/build-cache.json'
    state=read(cache_path) if cache_path.exists() else {}
    builder_key=digest([ROOT/'tools/build_character.py',ROOT/'art/rig-spec.json'],chain['blender_version'])
    sources=[ROOT/'art/source/humanoid-v1.blend',ROOT/'art/source/greatsword-v1.blend']
    outputs=[GAME/'assets/characters/humanoid-v1.glb',GAME/'assets/characters/greatsword-v1.glb']
    rebuild=regenerate or state.get('builder_key')!=builder_key or not all(p.exists() for p in sources)
    if rebuild:
        # Preserve editable sources before any generator rebuild.
        stamp=datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
        for source in sources:
            if source.exists():
                history=ROOT/'art/source/history'/stamp
                history.mkdir(parents=True,exist_ok=True)
                shutil.copy2(source,history/source.name)
        run_process([chain['blender'],'--background','--factory-startup','--python',str(ROOT/'tools/build_character.py')],log='asset-build.log')
    source_key=digest(sources+[ROOT/'tools/export_sources.py'],chain['blender_version'])
    if not rebuild and state.get('source_key')==source_key and all(p.exists() for p in outputs) and state.get('asset_outputs')==digest(outputs):
        print('ASSET CACHE HIT: geometry and shared animation unchanged')
        return
    if not rebuild:
        run_process([chain['blender'],'--background','--factory-startup','--python',str(ROOT/'tools/export_sources.py')],log='asset-export.log')
    state.update(builder_key=builder_key,source_key=source_key,asset_outputs=digest(outputs))
    write(cache_path,state)
    print('ASSETS READY: editable Blender sources + shared GLB models')


def import_game():
    run_process([toolchain()['godot'],'--headless','--path',str(GAME),'--editor','--import'],log='import.log')


def build():
    validate()
    assets()
    chain=toolchain()
    cache_path=ROOT/'output/build-cache.json'
    state=read(cache_path)
    executable=ROOT/'output/windows/CoastalFoundation.exe'
    def build_key():
        files=[p for p in GAME.rglob('*') if p.is_file() and '.godot' not in p.parts and p.name!='export_presets.cfg']
        files += [ROOT/'tools/platform_cli.py',ROOT/'docs/PLAY.md',ROOT/'docs/GODOT-LICENSE.txt',ROOT/'docs/GODOT-COPYRIGHT.txt']
        template_hash=hashlib.sha256(Path(chain['windows_release_template']).read_bytes()).hexdigest()
        return digest(files,chain['godot_version']+template_hash)
    key=build_key()
    if executable.exists() and state.get('game_key')==key and state.get('executable_hash')==hashlib.sha256(executable.read_bytes()).hexdigest():
        print('WINDOWS CACHE HIT: existing build matches source')
        return executable
    import_game()
    executable.parent.mkdir(parents=True,exist_ok=True)
    presets=f'''[preset.0]
name="Windows Desktop"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter="content/*.json,content/**/*.json"
exclude_filter=""
export_path="../output/windows/CoastalFoundation.exe"
script_export_mode=2

[preset.0.options]
custom_template/debug="{Path(chain['windows_debug_template']).as_posix()}"
custom_template/release="{Path(chain['windows_release_template']).as_posix()}"
binary_format/architecture="x86_64"
binary_format/embed_pck=true
codesign/enable=false
application/file_version="0.1.0"
application/product_version="0.1.0"
application/product_name="Coastal Foundation"
application/file_description="Pixelated 3D exploration foundation"
texture_format/s3tc_bptc=true
'''
    (GAME/'export_presets.cfg').write_text(presets,encoding='utf-8')
    run_process([chain['godot'],'--headless','--path',str(GAME),'--export-release','Windows Desktop',str(executable)],log='windows-export.log')
    if not executable.is_file():
        raise RuntimeError('Windows export did not create an executable')
    shutil.copy2(ROOT/'docs/PLAY.md',executable.parent/'README.md')
    shutil.copy2(ROOT/'docs/GODOT-LICENSE.txt',executable.parent/'GODOT-LICENSE.txt')
    shutil.copy2(ROOT/'docs/GODOT-COPYRIGHT.txt',executable.parent/'GODOT-COPYRIGHT.txt')
    with zipfile.ZipFile(executable.parent/'CoastalFoundation-Windows.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
        for name in ['CoastalFoundation.exe','README.md','GODOT-LICENSE.txt','GODOT-COPYRIGHT.txt']:
            archive.write(executable.parent/name,name)
    state.update(game_key=build_key(),executable_hash=hashlib.sha256(executable.read_bytes()).hexdigest())
    write(cache_path,state)
    print(f'WINDOWS READY: {executable}')
    return executable


def recolored(data,assignments):
    result=copy.deepcopy(data)
    for assignment in assignments:
        slot,separator,value=assignment.partition('=')
        if not separator or slot not in result['palette']:
            raise ValueError(f'Invalid palette assignment: {assignment}')
        result['palette'][slot]=value
    valid('character',result)
    return result


def recipes_check():
    original=read(GAME/'content/characters/hero.json')
    changed=recolored(original,['dress=#9B6884'])
    assert changed['palette']['dress']=='#9B6884' and original['palette']['dress']=='#617688'
    variant=copy.deepcopy(changed)
    variant.update(id='recipe_example',display_name='Example')
    variant['modules']['hair']='crop'
    valid('character',variant)
    for bad in ['dress=not-a-color','missing=#123456']:
        try:
            recolored(original,[bad])
        except ValueError:
            pass
        else:
            raise AssertionError('Invalid palette accepted')
    invalid=copy.deepcopy(variant)
    invalid['modules']['hair']='unsupported'
    try:
        valid('character',invalid)
    except ValueError:
        pass
    else:
        raise AssertionError('Unsupported module accepted')
    print('EDIT RECIPES PASS: recolor, compatible variant, invalid colors/modules rejected')


def identifier(value):
    if not re.fullmatch(r'[a-z][a-z0-9_]*',value):
        raise ValueError('IDs must use lowercase letters, digits, and underscores.')
    return value


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    commands=parser.add_subparsers(dest='command',required=True)
    for name in ['validate','build','verify','capture','run','recipes-check']:
        command=commands.add_parser(name)
        if name=='capture':
            command.add_argument('--view',choices=['all','world','characters'],default='all')
    asset_command=commands.add_parser('assets')
    asset_command.add_argument('--regenerate',action='store_true')
    recolor=commands.add_parser('recolor')
    recolor.add_argument('character',type=identifier)
    recolor.add_argument('colors',nargs='+')
    variant=commands.add_parser('variant')
    variant.add_argument('base',type=identifier)
    variant.add_argument('id',type=identifier)
    variant.add_argument('--name')
    variant.add_argument('--hair',choices=['bob','crop'])
    variant.add_argument('--outfit',choices=['dress','tunic'])
    variant.add_argument('--equipment',choices=['none','greatsword'])
    variant.add_argument('--color',action='append',default=[])
    prop=commands.add_parser('move-prop')
    prop.add_argument('map',type=identifier)
    prop.add_argument('prop',type=identifier)
    prop.add_argument('x',type=float)
    prop.add_argument('z',type=float)
    args=parser.parse_args()
    if args.command=='validate':
        validate()
    elif args.command=='assets':
        assets(args.regenerate)
    elif args.command=='build':
        build()
    elif args.command in ['verify','capture']:
        validate()
        assets()
        import_game()
        if args.command=='verify':
            recipes_check()
            output=run_process([toolchain()['godot'],'--headless','--path',str(GAME),'--','--verify','--report',str(ROOT/'output/verification/integration-report.json')],log='integration.log')
            print(next(line for line in output.splitlines() if line.startswith('VERIFICATION_')))
        else:
            run_process([toolchain()['godot'],'--path',str(GAME),'--','--capture',str(ROOT/'output/verification'),'--capture-view',args.view],rendered=True,log='capture.log')
            print('RENDERED: output/verification/*.png and render-metrics.json')
    elif args.command=='run':
        executable=build()
        subprocess.Popen([str(executable)],cwd=executable.parent)
    elif args.command=='recipes-check':
        recipes_check()
    elif args.command=='recolor':
        path=GAME/'content/characters'/f'{args.character}.json'
        write(path,recolored(read(path),args.colors))
        print(f'CHANGED: {path.relative_to(ROOT)}; geometry/animation retained')
    elif args.command=='variant':
        path=GAME/'content/characters'/f'{args.id}.json'
        if path.exists():
            raise ValueError('Variant already exists; choose a new id.')
        data=recolored(read(GAME/'content/characters'/f'{args.base}.json'),args.color)
        data.update(id=args.id,display_name=args.name or args.id.replace('_',' ').title())
        for key in ['hair','outfit','equipment']:
            value=getattr(args,key)
            if value:
                data['modules'][key]=value
        valid('character',data)
        write(path,data)
        print(f'CREATED: {path.relative_to(ROOT)}; shared rig/animation retained')
    elif args.command=='move-prop':
        path=GAME/'content/maps'/f'{args.map}.json'
        data=read(path)
        found=next((item for item in data['props'] if item['id']==args.prop),None)
        if found is None:
            raise ValueError('Unknown prop id')
        b=data['bounds']
        if not (b[0]<=args.x<b[2] and b[1]<=args.z<b[3]):
            raise ValueError('New position outside map bounds')
        found['at']=[args.x,args.z]
        valid('map',data)
        write(path,data)
        print(f'CHANGED: {path.relative_to(ROOT)}; character assets retained')


if __name__=='__main__':
    try:
        main()
    except (ValueError,RuntimeError,FileNotFoundError,subprocess.TimeoutExpired) as error:
        print(f'ERROR: {error}',file=sys.stderr)
        sys.exit(1)
