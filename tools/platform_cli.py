"""Local editing/build CLI. Routine content edits never invoke image generation."""
import argparse
import copy
import hashlib
import json
import math
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
from icon_assets import prepare_icons, ICON_NAME


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
    valid('sea_dragon_pose',read(GAME/'content/sea_dragon_pose.json'))
    valid('unarmed_hands',read(GAME/'content/unarmed_hands.json'))
    characters={}
    maps={}
    for kind,folder,collection in [('character','characters',characters),('map','maps',maps)]:
        for path in sorted((GAME/'content'/folder).glob('*.json')):
            data=read(path)
            valid(kind,data)
            if path.stem!=data['id']:
                raise ValueError(f'{path.name}: id must match filename')
            collection[data['id']]=data
    regions=read(GAME/'content/alpha2_regions.json')
    for area,plan in regions.items():
        if area not in maps: raise ValueError('Unknown Alpha 2 region: '+area)
        bounds=maps[area]['bounds']; members=[]; groups=set()
        for route in plan['routes']:
            if len(route)<2: raise ValueError(area+': route needs connected points')
            for point in route:
                if len(point)!=2 or not all(isinstance(n,(int,float)) and math.isfinite(n) for n in point) or not bounds[0]<=point[0]<=bounds[2] or not bounds[1]<=point[1]<=bounds[3]: raise ValueError(area+': invalid route point')
        for group in plan['groups']:
            if group['id'] in groups or group['behavior'] not in ['pack','ambush','scavenge','guard','territory'] or not 0<group['trigger_radius']<=group['leash_radius'] or not group['warning'] or not group['members']: raise ValueError(area+': invalid encounter situation')
            groups.add(group['id']); members.extend(group['members'])
        expected=[e for e in maps[area]['enemies'] if e['kind']!='bellkeeper']
        if sorted(members,key=lambda e:e['id'])!=sorted(expected,key=lambda e:e['id']) or len({e['id'] for e in members})!=len(members): raise ValueError(area+': encounter plan/map mismatch; regenerate content')
        if plan['hills']!=maps[area].get('sculpted_terrain',[]): raise ValueError(area+': landforms differ from recipe')
    cores=read(GAME/'content/monster_cores.json'); valid('monster_cores',cores)
    ids={item['id'] for item in cores['cores']}
    if len(ids)!=len(cores['cores']): raise ValueError('Duplicate monster core IDs')
    for kind,table in cores['profiles'].items():
        if kind in cores['beasts'] or table['generic'] not in ids or (table['variant'] and table['variant'] not in ids): raise ValueError('Invalid monster core profile')
        if table['boss_bonus']>0 and table['drop_rate']!=1: raise ValueError('Boss cores must be guaranteed')
    magic=read(GAME/'content/magic_items.json'); valid('magic_items',magic)
    if len({i['id'] for i in magic['items']})!=len(magic['items']) or len({i['code'] for i in magic['items']})!=len(magic['items']): raise ValueError('Magic item IDs/codes must be unique')
    for category in ['ring','torso','leggings','boots','headwear','necklace']:
        if sum(i['category']==category for i in magic['items'])<4: raise ValueError('Every equipment category needs four items')
    for group in magic.get('sets',[]):
        if any(i not in {e['id'] for e in magic['items']} for i in group['items']): raise ValueError('Equipment set references an unknown item')
        categories=[next(e['category'] for e in magic['items'] if e['id']==i) for i in group['items']]
        if len(categories)!=len(set(categories)): raise ValueError('Equipment set pieces must use distinct categories')
    campaign=read(GAME/'content/goblin_campaign.json')
    valid('goblin_campaign',campaign)
    action_ids=[a['id'] for a in campaign['actions']]
    if len(action_ids)!=len(set(action_ids)): raise ValueError('Duplicate campaign interaction ID')
    for item in campaign['actions']+campaign['ambushes']:
        area=maps.get(item['map'])
        if not area: raise ValueError('Campaign area is missing')
        x,z=item['at']; b=area['bounds']
        if not b[0]<x<b[2] or not b[1]<z<b[3]: raise ValueError('Campaign interaction outside area')
    for group in campaign['ambushes']:
        enemy_ids={e['id'] for e in maps[group['map']].get('enemies',[])}
        if any(e not in enemy_ids for e in group['enemies']): raise ValueError('Unknown goblin ambusher')
    library=read(GAME/'content/alpha2_creatures.json'); valid('alpha2_creatures',library)
    for entry in library.values():
        if not (GAME/entry['model'].removeprefix('res://')).is_file(): raise ValueError('Missing collected creature model')
    for entry in read(ROOT/'art/library/ALPHA2-RUNTIME-ASSETS.json'):
        runtime=GAME/'assets/alpha2'/f"{entry['id']}.glb"
        if hashlib.sha256(runtime.read_bytes()).hexdigest()!=entry['runtime_sha256']: raise ValueError('Collected runtime asset changed; prepare and inspect it again')
        if 'source_sha256' in entry and hashlib.sha256((ROOT/'art/library/source'/entry['source']).read_bytes()).hexdigest()!=entry['source_sha256']: raise ValueError('Collected donor source changed')
    expedition=read(GAME/'content/alpha2.json'); valid('alpha2',expedition)
    expedition_maps=set(expedition['maps'])
    if expedition['start'] not in expedition_maps or not expedition_maps.issubset(maps): raise ValueError('Alpha 2 areas are missing')
    if any(not name.startswith('a2_') for name in expedition_maps): raise ValueError('Alpha 2 map IDs must stay isolated')
    action_ids=[entry['id'] for entry in expedition['actions']]
    if len(action_ids)!=len(set(action_ids)): raise ValueError('Duplicate Alpha 2 interaction ID')
    encounters={name+'/'+mob['id'] for name in expedition_maps for mob in maps[name].get('enemies',[])+maps[name].get('catalog_enemies',[])}
    if expedition['boss'] not in encounters: raise ValueError('Alpha 2 boss encounter is missing')
    for entry in expedition['actions']:
        if entry['map'] not in expedition_maps: raise ValueError('Alpha 2 action outside campaign')
        b=maps[entry['map']]['bounds']; x,z=entry['at']
        if not b[0]<x<b[2] or not b[1]<z<b[3]: raise ValueError('Alpha 2 interaction outside bounds')
        if any(key not in encounters for key in entry.get('requires',[])): raise ValueError('Unknown Alpha 2 guardian')
        if any(key not in action_ids for key in entry.get('requires_flags',[])): raise ValueError('Unknown Alpha 2 discovery requirement')
        if entry['type']=='loot' and entry.get('item') not in {e['id'] for e in magic['items']}: raise ValueError('Unknown Alpha 2 treasure')
    visited={expedition['start']}; pending=list(visited)
    while pending:
        for route in maps[pending.pop()]['exits']:
            if route['target'] not in expedition_maps: raise ValueError('Alpha 2 route leaks into another campaign')
            if route['target'] not in visited: visited.add(route['target']); pending.append(route['target'])
    if visited!=expedition_maps: raise ValueError('Unreachable Alpha 2 area')
    config=read(GAME/'content/platform.json')
    valid('platform',config)
    valid('forest_enemies',read(GAME/'content/forest_enemies.json'))
    progression=read(GAME/'content/progression.json')
    valid('progression',progression)
    thresholds=progression['level_thresholds']
    if thresholds[0]!=0 or thresholds!=sorted(thresholds) or any(thresholds[i+1]-thresholds[i] <= thresholds[i]-thresholds[i-1] for i in range(1,len(thresholds)-1)):
        raise ValueError('XP thresholds must start at zero and each level must cost more XP')
    skill_ids=[]
    for skill in progression['skills']:
        if skill['id'] in skill_ids or any(parent not in skill_ids for parent in skill['requires']):
            raise ValueError('Skill IDs must be unique and prerequisites must appear earlier')
        skill_ids.append(skill['id'])
    by_id={item['id']:item for item in progression['skills']}
    for skill in progression['skills']:
        if any(other not in by_id or skill['id'] not in by_id[other]['excludes'] or by_id[other]['branch']!=skill['branch'] for other in skill['excludes']):
            raise ValueError('Skill choices must exclude one another within the same branch')
        if skill.get('category') not in ['active','passive','capacity']:
            raise ValueError('Every skill needs an active, passive or capacity category')
    catalog=read(GAME/'content/menagery.json')
    valid('menagery',catalog)
    if any(entry['style'] not in progression['enemy_xp'] for entry in catalog['monsters']): raise ValueError('Every catalog creature needs a fixed XP reward')
    resin=catalog['resin_attack']
    if resin['aim_lock_remaining']>=resin['charge_seconds']: raise ValueError('Resin dash must have time to aim before locking')
    entries=catalog['features']+catalog['monsters']
    codes=[entry['code'] for entry in entries]
    if len(set(codes))!=len(codes): raise ValueError('Menagery codes must be globally unique')
    feature_codes={entry['code'] for entry in catalog['features']}
    for map_data in maps.values():
        for prop in map_data['props']:
            if prop['kind']=='catalog_feature' and prop.get('catalog_code') not in feature_codes:
                raise ValueError('Unknown Menagery feature code')
    beta=read(GAME/'content/beta.json'); pack_tuning=beta['wolf_packs']
    locomotion=beta['locomotion']
    anchor=beta['back_anchor']
    for key in ['width','height','depth','blade_distance']:
        if not isinstance(anchor[key],(int,float)) or not 0<anchor[key]<1: raise ValueError('Invalid Beta anchor dimension: '+key)
    if not -.2<anchor['pad_x']<.2 or not -.3<anchor['back_z']<0: raise ValueError('Invalid Beta back anchor position')
    for key in ['walk_speed','walk_cycle_distance','run_cycle_distance','burden_run_cycle_distance','walk_stride_scale','run_stride_scale','burden_run_stride_scale','walk_lift_scale','run_lift_scale','burden_run_lift_scale']:
        if not isinstance(locomotion[key],(int,float)) or not 0<locomotion[key]<=5: raise ValueError('Invalid Beta locomotion tuning: '+key)
    samples=read(GAME/'content/beta_locomotion_samples.json')
    if samples.get('samples_per_cycle')!=120: raise ValueError('Invalid locomotion sampling contract')
    for clip in ['Walk_Loop','Jog_Fwd_Loop','Sprint_Loop']:
        if len(samples['clips'][clip]['samples'])!=121: raise ValueError('Incomplete preset locomotion cycle: '+clip)
    for key in ['patrol_speed','circle_speed','circle_radius','circle_angular_speed','attack_distance','first_attack_delay','wave_interval','leash_radius','lost_sight_seconds']:
        if not isinstance(pack_tuning[key],(int,float)) or not 0<pack_tuning[key]<=20: raise ValueError('Invalid wolf pack tuning: '+key)
    if pack_tuning['attack_distance']<pack_tuning['circle_radius'] or pack_tuning['leash_radius']<=pack_tuning['circle_radius']: raise ValueError('Wolf attack/leash must cover its circle')
    for area in maps.values():
        for enemy in area.get('enemies',[]):
            territories=pack_tuning['territories'] if area['id']!='wr_floor_01' else {p['id']:p for p in read(GAME/'content/world_rise/floor_01.json')['packs'] if p['kind']=='beta_wolf'}
            if enemy['kind']=='beta_wolf' and enemy.get('pack') not in territories: raise ValueError('Wolf lacks a known pack territory')
    for territory in pack_tuning['territories'].values():
        if not 1<=territory['radius']<pack_tuning['leash_radius'] or len(territory['center'])!=2: raise ValueError('Invalid wolf patrol territory')
    monster_codes={entry['code']:entry for entry in catalog['monsters']}
    for map_data in maps.values():
        for mob in map_data.get('catalog_enemies',[]):
            if mob['code'] not in monster_codes: raise ValueError('Unknown catalog creature')
            if mob.get('spawn_mode')=='tree_drop' and monster_codes[mob['code']]['style'] not in ['green_slime','moss_slime','resin_slime','bramble_slime']: raise ValueError('Tree drops require an ordinary slime')
    combat=read(GAME/'content/combat.json')
    valid('combat',combat)
    valid('knockback',read(GAME/'content/knockback.json'))
    for key,attack in [('light',combat['light']),('heavy',combat['heavy']),('thrust',combat['thrust'])]+[(f'combo {i+2}',attack) for i,attack in enumerate(combat['combo'])]:
        if attack['active_start']>=attack['active_end']:
            raise ValueError(f'{key}: active_start must precede active_end')
        if attack['stamina_cost']>combat['max_stamina']:
            raise ValueError(f'{key}: stamina cost exceeds maximum stamina')
    parry=combat['parry']
    if not 0<=parry['active_start']<parry['active_end']<parry['duration']:
        raise ValueError('Parry window must fit within its duration')
    if parry['stamina_cost']>combat['max_stamina'] or combat['sprint_resume_stamina']>combat['max_stamina']:
        raise ValueError('Stamina costs/recovery threshold exceed maximum stamina')
    water=combat['water']
    if water['stamina_cost']>combat['max_stamina'] or not 0<water['release_phase']<1 or not 0<water['half_angle']<1.57:
        raise ValueError('Water cost, release phase or forward sweep angle is invalid')
    if combat['drawn_sprint_speed']<combat['drawn_walk_speed'] or combat['drawn_sprint_drain']<=combat['sprint_drain']:
        raise ValueError('Drawn sprint must be faster than dragging and drain more than sheathed sprint')
    motion=read(GAME/'content/sword_motion.json')
    valid('sword_motion',motion)
    for key,poses in motion.items():
        times=[pose['t'] for pose in poses]
        if times[0]!=0 or (key!='drag' and times[-1]!=1) or any(a>=b for a,b in zip(times,times[1:])):
            raise ValueError(f'{key}: sword poses need ordered normalized times from 0 to 1')
    first_person=read(GAME/'content/first_person_motion.json')
    valid('first_person_motion',first_person)
    for key,poses in first_person['paths'].items():
        times=[pose['t'] for pose in poses]
        if times[0]!=0 or times[-1]!=1 or any(a>=b for a,b in zip(times,times[1:])):
            raise ValueError(f'{key}: first-person grip phases must run from zero to one in order')
        if any(sum(component**2 for component in pose['direction'])<.01 for pose in poses):
            raise ValueError(f'{key}: first-person blade direction cannot collapse')
    for before,after in [('light','light2'),('light2','light3')]:
        join=next(pose for pose in first_person['paths'][before] if pose['t']==.74)
        entry=first_person['paths'][after][0]
        if join['grip']!=entry['grip'] or join['direction']!=entry['direction']:
            raise ValueError(f'{before}/{after}: linked first-person blade poses must match')
    if config['start_map'] not in maps or config['player_character'] not in characters:
        raise ValueError('Platform references an unknown map or character')
    for name,data in maps.items():
        x0,z0,x1,z1=data['bounds']
        if x1<=x0 or z1<=z0:
            raise ValueError(f'{name}: bounds must have positive size')
        ids=[]
        for key in ['props','npcs','interactions','exits','enemies','catalog_enemies']:
            for item in data.get(key,[]):
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


def validate_beta_sword():
    report_path=ROOT/'art/character/beta-sword-review/customization.json'
    if not report_path.exists(): raise ValueError('Missing current Beta sword source/export record')
    report=read(report_path)
    if report.get('license')!='CC0-1.0' or not report.get('saved_source_reopened') or report.get('embedded_texts') or report.get('drivers'):
        raise ValueError('Beta sword source/license verification is incomplete')
    for file,key in [('art/source/beta-greatsword.blend','source_sha256'),('game/assets/characters/greatsword-beta.glb','runtime_sha256')]:
        if hashlib.sha256((ROOT/file).read_bytes()).hexdigest()!=report.get(key):
            raise ValueError('Beta sword source/export mismatch; export the current editable source with tools/export_beta_sword.py')
    print('BETA SWORD VERIFIED: saved source/export hashes and CC0 provenance match')


def assets(regenerate=False):
    validate_beta_sword()
    wolf_report=read(ROOT/'art/library/beta-wolf-customization.json')
    if not wolf_report.get('saved_source_reopened') or wolf_report.get('embedded_scripts') or wolf_report.get('drivers'):
        raise ValueError('Export the current saved wolf with tools/export_beta_wolf.py')
    for name,key in [(wolf_report['source'],'source_sha256'),(wolf_report['runtime'],'runtime_sha256')]:
        if hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=wolf_report[key]: raise ValueError('Wolf source/export hash mismatch: '+name)
    if hashlib.sha256((ROOT/wolf_report['donor']).read_bytes()).hexdigest()!=wolf_report['donor_sha256']: raise ValueError('Original wolf donor changed')
    print('BETA WOLF VERIFIED: saved source/export and untouched donor match')
    beta_hero=read(ROOT/'art/character/beta-heroine-export.json')
    if beta_hero.get('editable_source'):
        for name,key in [(beta_hero['editable_source'],'editable_source_sha256'),(beta_hero['export'].replace('\\','/'),'export_sha256')]:
            if hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=beta_hero[key]: raise ValueError('Beta garment source/export mismatch; export with tools/export_beta_saved.py')
        print('BETA GARMENT VERIFIED: current editable skin/export hashes match')
    review=ROOT/'art/character/model-review.json'
    if review.exists() and read(review).get('status')=='awaiting_user_approval':
        if not regenerate and read(review).get('static_integration',{}).get('authorized'):
            validate_static_integration()
            print('STATIC REVIEW: canonical meshes/animation frozen; standalone export verified')
            return
        raise ValueError('Hero model awaits user approval before animation fitting. Use capture --draft --model-only --view hero for static review; Play.cmd still launches the verified release.')
    chain=toolchain()
    cache_path=ROOT/'output/build-cache.json'
    state=read(cache_path) if cache_path.exists() else {}
    builder_key=digest([ROOT/'tools/build_character.py',ROOT/'tools/motion_math.py',ROOT/'art/rig-spec.json',GAME/'content/sword_motion.json'],chain['blender_version'])
    sources=[ROOT/'art/source/humanoid-v1.blend',ROOT/'art/source/greatsword-v1.blend']
    outputs=[GAME/'assets/characters/humanoid-v1.glb',GAME/'assets/characters/greatsword-v1.glb']
    rebuild=regenerate or state.get('builder_key')!=builder_key or not all(p.exists() for p in sources)
    if rebuild:
        run_process([chain['blender'],'--background','--factory-startup','--python',str(ROOT/'tools/build_character.py')],log='asset-build.log')
    source_key=digest(sources+[ROOT/'tools/export_sources.py'],chain['blender_version'])
    if not rebuild and state.get('source_key')==source_key and all(p.exists() for p in outputs) and state.get('asset_outputs')==digest(outputs):
        print('ASSET CACHE HIT: geometry and shared animation unchanged')
        detail_assets(state,chain)
        write(cache_path,state)
        return
    if not rebuild:
        run_process([chain['blender'],'--background','--factory-startup','--python',str(ROOT/'tools/export_sources.py')],log='asset-export.log')
    state.update(builder_key=builder_key,source_key=source_key,asset_outputs=digest(outputs))
    detail_assets(state,chain)
    write(cache_path,state)
    print('ASSETS READY: editable Blender sources + shared GLB models')

def detail_assets(state,chain):
    npc=GAME/'assets/characters/humanoid-advanced-v1.glb'
    npc_key=digest([ROOT/'art/source/humanoid-v1.blend',ROOT/'tools/prepare_character_detail.py'],chain['blender_version'])
    if state.get('npc_detail_key')!=npc_key or not npc.exists() or state.get('npc_detail_output')!=digest([npc]):
        run_process([chain['blender'],'--background','--factory-startup','--disable-autoexec','--python-exit-code','1','--python',str(ROOT/'tools/prepare_character_detail.py'),'--','--npc'],log='npc-detail.log')
        state.update(npc_detail_key=npc_key,npc_detail_output=digest([npc]))
    output=GAME/'assets/characters/humanoid-hero-v1.glb'
    key=digest([ROOT/'art/source/humanoid-v1.blend',ROOT/'tools/prepare_character_detail.py',ROOT/'tools/remake_hero.py',ROOT/'tools/build_character.py',ROOT/'tools/motion_math.py',ROOT/'game/content/sword_motion.json',ROOT/'art/character/source/human_base_meshes_bundle.blend'],chain['blender_version'])
    if state.get('detail_key')==key and output.exists() and state.get('detail_output')==digest([output]):
        print('DETAIL CACHE HIT: higher-detail character unchanged')
        return
    run_process([chain['blender'],'--background','--factory-startup','--disable-autoexec','--python-exit-code','1','--python',str(ROOT/'tools/prepare_character_detail.py')],log='character-detail.log')
    state.update(detail_key=key,detail_output=digest([output]))


def import_game():
    run_process([toolchain()['godot'],'--headless','--path',str(GAME),'--editor','--import'],log='import.log')

def audit_walk_skirt():
    path=ROOT/'output/verification/walk-skirt.json'
    report=read(path) if path.exists() else {}
    source_hash=hashlib.sha256((ROOT/'art/source/humanoid-v1.blend').read_bytes()).hexdigest()
    if report.get('passed') and report.get('source_hash')==source_hash and report.get('recipe_hash')==hashlib.sha256((ROOT/'tools/audit_walk_skirt.py').read_bytes()).hexdigest():
        print(f"WALK SKIRT CACHE HIT: {report['covered_vertices']} covered vertices")
        return
    run_process([toolchain()['blender'],'--background','--factory-startup','--python-exit-code','1','--python',str(ROOT/'tools/audit_walk_skirt.py')],log='walk-skirt.log')
    if not read(path).get('passed'): raise RuntimeError('Walking legs escape the skirt envelope')


def audit_sword():
    files=['art/source/humanoid-v1.blend','art/source/greatsword-v1.blend','game/content/sword_motion.json','game/content/combat.json','tools/audit_sword.py','tools/motion_math.py']
    inputs={name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in files}
    path=ROOT/'output/verification/sword-clearance.json'
    report=read(path) if path.exists() else {}
    if report.get('passed') and report.get('inputs')==inputs:
        print(f'SWORD CLEARANCE CACHE HIT: {report["samples"]} poses, no intersections')
        audit_walk_skirt()
        audit_character_detail()
        return
    run_process([toolchain()['blender'],'--background','--factory-startup','--python-exit-code','1','--python',str(ROOT/'tools/audit_sword.py')],log='sword-clearance.log')
    report=read(path)
    if not report.get('passed') or report.get('inputs')!=inputs:
        raise RuntimeError('Sword clearance audit failed or does not match current assets')
    audit_walk_skirt()
    audit_character_detail()

def validate_static_integration():
    import struct
    review=read(ROOT/'art/character/model-review.json')['static_integration']
    for name,expected in review['frozen_assets'].items():
        if hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=expected:
            raise ValueError('Unapproved animated source/export changed: '+name)
    report=read(ROOT/'art/character/standalone-export.json')
    for name,expected in [(report['export'],report['export_sha256']),('tools/export_personal_heroine_static.py',report['recipe_sha256'])]:
        if hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=expected: raise ValueError('Standalone export needs refresh: '+name)
    raw=(ROOT/report['export']).read_bytes()
    length=struct.unpack_from('<I',raw,12)[0];document=json.loads(raw[20:20+length])
    if document.get('animations') or document.get('skins'): raise ValueError('Standalone review must contain no rigs or animations')

def audit_character_detail():
    review=ROOT/'art/character/model-review.json'
    if review.exists() and read(review).get('status')=='awaiting_user_approval' and read(review).get('static_integration',{}).get('authorized'):
        validate_static_integration()
        print('ADVANCED BASELINE FROZEN: no animation retargeting during static review')
        return
    files=['art/source/humanoid-v1.blend','art/source/greatsword-v1.blend','game/content/sword_motion.json','game/content/combat.json','tools/audit_sword.py','tools/motion_math.py','tools/prepare_character_detail.py','tools/remake_hero.py','tools/build_character.py','game/assets/characters/humanoid-hero-v1.glb','art/character/source/human_base_meshes_bundle.blend']
    inputs={name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in files}
    path=ROOT/'output/verification/advanced-sword-clearance.json'
    report=read(path) if path.exists() else {}
    if report.get('passed') and report.get('inputs')==inputs:
        print(f'ADVANCED SWORD CACHE HIT: {report["samples"]} poses, no intersections')
    else:
        run_process([toolchain()['blender'],'--background','--factory-startup','--disable-autoexec','--python-exit-code','1','--python',str(ROOT/'tools/audit_sword.py'),'--','--advanced'],timeout=1200,log='advanced-sword-clearance.log')
        if not read(path).get('passed') or read(path).get('inputs')!=inputs: raise RuntimeError('Advanced sword clearance failed')
    skirt=ROOT/'output/verification/advanced-walk-skirt.json'
    report=read(skirt) if skirt.exists() else {}
    if report.get('passed') and report.get('source_hash')==inputs['art/source/humanoid-v1.blend'] and report.get('recipe_hash')==hashlib.sha256((ROOT/'tools/audit_walk_skirt.py').read_bytes()).hexdigest() and report.get('detail_recipe_hash')==inputs['tools/prepare_character_detail.py'] and report.get('hero_recipe_hash')==inputs['tools/remake_hero.py']:
        print(f'ADVANCED SKIRT CACHE HIT: {report["covered_vertices"]} covered vertices')
    else:
        run_process([toolchain()['blender'],'--background','--factory-startup','--python-exit-code','1','--python',str(ROOT/'tools/audit_walk_skirt.py'),'--','--advanced'],log='advanced-walk-skirt.log')
        if not read(skirt).get('passed'): raise RuntimeError('Advanced walking skirt clearance failed')


def build():
    validate()
    assets()
    audit_sword()
    icon=prepare_icons()
    chain=toolchain()
    cache_path=ROOT/'output/build-cache.json'
    state=read(cache_path)
    version=read(GAME/'content/release.json')['version']
    executable=ROOT/f'output/windows/v{version}/CoastalFoundation.exe'
    def build_key():
        files=[p for p in GAME.rglob('*') if p.is_file() and '.godot' not in p.parts and p.name!='export_presets.cfg']
        files += [ROOT/'tools/platform_cli.py',ROOT/'tools/icon_assets.py',ROOT/'tools/install_desktop_shortcut.ps1',ROOT/'tools/Install Desktop Shortcut.cmd',ROOT/'tools/Play Compatibility.cmd',icon,ROOT/'docs/PLAY.md',ROOT/'docs/MAP-BUILDER.md',ROOT/'docs/ASSET-CREDITS.md',ROOT/'docs/GODOT-LICENSE.txt',ROOT/'docs/GODOT-COPYRIGHT.txt']
        template_hash=hashlib.sha256(Path(chain['windows_release_template']).read_bytes()).hexdigest()
        return digest(files,chain['godot_version']+template_hash)
    key=build_key()
    if executable.exists() and state.get('game_key')==key and state.get('executable_hash')==hashlib.sha256(executable.read_bytes()).hexdigest():
        if not (executable.parent/'MapBuilder.exe').exists() or hashlib.sha256((executable.parent/'MapBuilder.exe').read_bytes()).hexdigest()!=state.get('executable_hash'):
            shutil.copy2(executable,executable.parent/'MapBuilder.exe')
        print('WINDOWS CACHE HIT: existing build matches source')
        return executable
    import_game()
    executable.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(icon,executable.parent/ICON_NAME)
    presets=f'''[preset.0]
name="Windows Desktop"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter="content/*.json,content/**/*.json"
exclude_filter=""
export_path="../output/windows/v{version}/CoastalFoundation.exe"
script_export_mode=2

[preset.0.options]
custom_template/debug="{Path(chain['windows_debug_template']).as_posix()}"
custom_template/release="{Path(chain['windows_release_template']).as_posix()}"
binary_format/architecture="x86_64"
binary_format/embed_pck=true
codesign/enable=false
application/file_version="{version}"
application/product_version="{version}"
application/product_name="Coastal Foundation"
application/file_description="Woodland 3D exploration, advanced graphics and timed sword combat"
texture_format/s3tc_bptc=true
'''
    (GAME/'export_presets.cfg').write_text(presets,encoding='utf-8')
    run_process([chain['godot'],'--headless','--path',str(GAME),'--export-release','Windows Desktop',str(executable)],log='windows-export.log')
    if not executable.is_file():
        raise RuntimeError('Windows export did not create an executable')
    shutil.copy2(executable,executable.parent/'MapBuilder.exe')
    shutil.copy2(ROOT/'docs/MAP-BUILDER.md',executable.parent/'MAP-BUILDER.md')
    shutil.copy2(ROOT/'docs/PLAY.md',executable.parent/'README.md')
    shutil.copy2(ROOT/'docs/GODOT-LICENSE.txt',executable.parent/'GODOT-LICENSE.txt')
    shutil.copy2(ROOT/'docs/GODOT-COPYRIGHT.txt',executable.parent/'GODOT-COPYRIGHT.txt')
    shutil.copy2(ROOT/'docs/ASSET-CREDITS.md',executable.parent/'ASSET-CREDITS.md')
    for name in ['install_desktop_shortcut.ps1','Install Desktop Shortcut.cmd','Play Compatibility.cmd']:
        shutil.copy2(ROOT/'tools'/name,executable.parent/name)
    with zipfile.ZipFile(executable.parent/'CoastalFoundation-Windows.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
        for name in ['CoastalFoundation.exe','MapBuilder.exe','MAP-BUILDER.md',ICON_NAME,'Install Desktop Shortcut.cmd','install_desktop_shortcut.ps1','Play Compatibility.cmd','README.md','ASSET-CREDITS.md','GODOT-LICENSE.txt','GODOT-COPYRIGHT.txt']:
            archive.write(executable.parent/name,name)
    state.update(game_key=build_key(),executable_hash=hashlib.sha256(executable.read_bytes()).hexdigest(),executable_path=str(executable))
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
    for name in ['validate','build','verify','verify-combat','verify-terrain','verify-goblins','verify-magic','verify-cores','verify-beta','verify-sea-dragon','verify-skills','verify-dash-uppercut','verify-unarmed','verify-dreadmore','verify-world-rise','verify-alpha2','verify-environment','verify-builder','capture','verify-windows','capture-windows','run','recipes-check']:
        command=commands.add_parser(name)
        if name=='verify-windows': command.add_argument('--suite',choices=['all','sea-dragon','combat-skills','dash-uppercut','unarmed','dreadmore','world-rise','alpha2'],default='all')
        if name in ['capture','capture-windows']:
            command.add_argument('--view',choices=['world-rise','world-rise-backdrop','dreadmore','mob-facing','alpha2','unarmed','dash-uppercut','combat-skills','sea-dragon','beta','all','world','characters','hero','standalone','combat','quest','progression','graphics','environment','potion','title','parry','camera','menus','home','knockback','menagery','terrain','builder','resin','queen','goblins','magic','hud','cores'],default='all')
            command.add_argument('--renderer',choices=['forward_plus','gl_compatibility'])
            command.add_argument('--art-profile',choices=['original','darkwood'])
            if name=='capture':
                command.add_argument('--draft',action='store_true',help='Source-only visual iteration; skips clearance gates and cannot build a release')
                command.add_argument('--model-only',action='store_true',help='Static heroine review before animation approval; requires --draft --view hero')
    asset_command=commands.add_parser('assets')
    asset_command.add_argument('--regenerate',action='store_true')
    recolor=commands.add_parser('recolor')
    recolor.add_argument('character',type=identifier)
    recolor.add_argument('colors',nargs='+')
    variant=commands.add_parser('variant')
    variant.add_argument('base',type=identifier)
    variant.add_argument('id',type=identifier)
    variant.add_argument('--name')
    variant.add_argument('--hair',choices=['bob','crop','headscarf'])
    variant.add_argument('--outfit',choices=['dress','tunic','workdress'])
    variant.add_argument('--equipment',choices=['none','greatsword'])
    variant.add_argument('--left-arm',choices=['human','prototype'])
    variant.add_argument('--footwear',choices=['boots','bare'])
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
    elif args.command in ['verify-combat','verify-terrain','verify-goblins','verify-magic','verify-cores','verify-beta','verify-sea-dragon','verify-skills','verify-dash-uppercut','verify-unarmed','verify-dreadmore','verify-world-rise','verify-alpha2','verify-environment']:
        validate()
        assets()
        audit_sword()
        import_game()
        suite='rise' if args.command=='verify-world-rise' else 'dreadmore' if args.command=='verify-dreadmore' else 'alpha2' if args.command=='verify-alpha2' else 'unarmed' if args.command=='verify-unarmed' else 'uppercut' if args.command=='verify-dash-uppercut' else 'skills' if args.command=='verify-skills' else 'sea_dragon' if args.command=='verify-sea-dragon' else 'beta' if args.command=='verify-beta' else 'environment' if args.command=='verify-environment' else 'core' if args.command=='verify-cores' else 'magic' if args.command=='verify-magic' else 'goblin' if args.command=='verify-goblins' else 'terrain' if args.command=='verify-terrain' else 'combat'
        output=run_process([toolchain()['godot'],'--headless','--path',str(GAME),'--script',f'res://scripts/focused_{suite}_checks.gd'],log=f'focused-{suite}.log')
        prefix='VERIFICATION_' if suite in ['sea_dragon','skills','uppercut','unarmed','dreadmore','rise','alpha2'] else 'BETA_CHECKS' if suite=='beta' else 'ENVIRONMENT_CHECKS' if suite=='environment' else 'CORE_CHECKS' if suite=='core' else 'MAGIC_CHECKS' if suite=='magic' else 'GOBLIN_CHECKS' if suite=='goblin' else 'TERRAIN_CHECKS' if suite=='terrain' else 'FOCUSED_COMBAT'
        print(next(line for line in output.splitlines() if line.startswith(prefix)))
    elif args.command in ['verify','capture']:
        validate()
        draft=args.command=='capture' and args.draft
        model_only=args.command=='capture' and args.model_only
        if model_only:
            if not draft or args.view!='hero': raise ValueError('--model-only requires --draft --view hero')
            run_process([toolchain()['blender'],'--background','--factory-startup','--disable-autoexec','--python-exit-code','1','--python',str(ROOT/'tools/prepare_character_detail.py'),'--','--model-only'],log='hero-model-only.log')
        else:
            assets()
        if not draft: audit_sword()
        import_game()
        if args.command=='verify':
            recipes_check()
            output=run_process([toolchain()['godot'],'--headless','--path',str(GAME),'--','--verify','--report',str(ROOT/'output/verification/integration-report.json')],log='integration.log')
            print(next(line for line in output.splitlines() if line.startswith('VERIFICATION_')))
        else:
            renderer=['--rendering-method',args.renderer] if args.renderer else []
            art=['--art-profile',args.art_profile] if args.art_profile else []
            directory=ROOT/('output/verification/draft-render' if draft else 'output/verification')
            run_process([toolchain()['godot'],'--path',str(GAME),*renderer,'--','--capture',str(directory),'--capture-view',args.view,*art,*(['--model-only'] if model_only else [])],rendered=True,log='draft-capture.log' if draft else 'capture.log')
            print(f'{"DRAFT (not release verification)" if draft else "RENDERED"}: {args.view} view in {directory}')
    elif args.command=='run':
        executable=build()
        subprocess.Popen([str(executable)],cwd=executable.parent)
    elif args.command=='verify-builder':
        executable=build().parent/'MapBuilder.exe'
        output=run_process([str(executable),'--headless','--','--builder-checks'],log='builder-checks.log')
        print(next(line for line in output.splitlines() if line.startswith('MAP_BUILDER_CHECKS')))
    elif args.command=='verify-windows':
        executable=build()
        output=run_process([str(executable),'--headless','--','--verify',*(['--suite',args.suite] if args.suite!='all' else []),'--report',str(ROOT/'output/verification/export-integration-report.json')],rendered=True,log='export-integration.log')
        print(next(line for line in output.splitlines() if line.startswith('VERIFICATION_')))
        run_process(['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(ROOT/'tools/clean_obsolete.ps1')],log='cleanup.log')
        print('PURGED: superseded releases, backups and stale previews')
    elif args.command=='capture-windows':
        executable=build()
        directory=ROOT/'output/verification/windows-render'
        capture_started=time.time()
        if args.view=='builder':
            directory.mkdir(parents=True,exist_ok=True)
            run_process([str(executable.parent/'MapBuilder.exe'),'--resolution','1366x768','--','--builder-capture',str(directory)],rendered=True,log='windows-capture.log')
        else:
            renderer=['--rendering-method',args.renderer] if args.renderer else []
            art=['--art-profile',args.art_profile] if args.art_profile else []
            run_process([str(executable),'--resolution','1366x768',*renderer,'--','--capture',str(directory),'--capture-view',args.view,*art],rendered=True,log='windows-capture.log')
        evidence_path=ROOT/'output/verification/current-render-evidence.json'
        key=read(ROOT/'output/build-cache.json')['game_key']
        evidence=read(evidence_path) if evidence_path.exists() else {}
        if evidence.get('game_key')!=key: evidence={'game_key':key,'release':read(GAME/'content/release.json')['version'],'files':[]}
        updated=[path.relative_to(directory).as_posix() for path in directory.rglob('*') if path.is_file() and path.stat().st_mtime>=capture_started-1]
        evidence['files']=sorted(set(evidence['files']+updated)); write(evidence_path,evidence)
        print(f'RENDERED WINDOWS: {args.view} view in {directory}')
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
        for key in ['hair','outfit','equipment','left_arm','footwear']:
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
