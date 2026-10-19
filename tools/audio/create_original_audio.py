#!/usr/bin/env python3
"""Reproducible original World Rise sound design. No external recordings/models.
All resulting recordings and composition are dedicated to CC0-1.0.
"""
from pathlib import Path
import array, hashlib, json, math, random, wave
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'game/assets/audio/original'
OUT.mkdir(parents=True,exist_ok=True)
RATE=22050
TAU=2*math.pi
rng=random.Random(2140414)
records=[]
catalog_path=ROOT/'game/content/world_rise/audio_events.json'
selection={p for e in json.loads(catalog_path.read_text())['events'].values() for p in e['clips']} if catalog_path.exists() else None
def save(name,data,loop=False):
    if selection is not None and 'res://assets/audio/original/'+name+'.wav' not in selection:return
    peak=max(abs(x) for x in data) or 1
    data=[x*min(1,.76/peak) for x in data]
    path=OUT/(name+'.wav')
    with wave.open(str(path),'wb') as w:
        w.setparams((1,2,RATE,0,'NONE','not compressed'))
        w.writeframes(array.array('h',(int(max(-1,min(1,x))*32767) for x in data)).tobytes())
    if not (OUT/(name+'.wav.import')).exists():(OUT/(name+'.wav.import')).write_text('[remap]\nimporter="wav"\ntype="AudioStreamWAV"\n\n[deps]\nsource_file="res://assets/audio/original/'+name+'.wav"\n\n[params]\nforce/8_bit=false\nforce/mono=true\nforce/max_rate=false\nedit/trim=false\nedit/normalize=false\nedit/loop_mode='+('1' if loop else '0')+'\nedit/loop_begin=0\nedit/loop_end=-1\ncompress/mode=0\n')
    records.append(dict(file=str(path.relative_to(ROOT)),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),license='CC0-1.0',author='World Rise contributors',source='tools/audio/create_original_audio.py',original=True,loop=loop))
def sound(name,kind,duration=.35,pitch=150,variant=0):
    r=random.Random(name+str(variant));data=[];low=0.;last=0
    for i in range(int(RATE*duration)):
        t=i/RATE; p=t/duration;n=r.uniform(-1,1);low=.89*low+.11*n;high=n-last;last=n
        env=(1-math.exp(-t*800))*math.exp(-p*7)
        tone=math.sin(TAU*(pitch*t+pitch*.03*(1-math.exp(-t*20))))
        if kind=='step': v=(low*1.3+tone*.35+high*.12)*env
        elif kind=='metal':v=sum(math.sin(TAU*pitch*f*t)*math.exp(-p*(2+j)) for j,f in enumerate([1,2.76,4.12,6.19]))*.18*env+high*.1*env
        elif kind=='swish':v=(high*.3+low*.4)*math.sin(math.pi*p)**2
        elif kind=='gel':v=(math.sin(TAU*(pitch*t+5*math.sin(t*18)))+low*.8)*env*.45
        elif kind=='voice':v=(tone*.45+math.sin(TAU*pitch*2*t)*.2+low*.3)*math.sin(math.pi*p)**2*(.6+.4*math.sin(t*32))
        elif kind=='ui':v=(math.sin(TAU*pitch*t)+.25*math.sin(TAU*pitch*1.5*t))*.3*env
        else:v=(low*1.5+tone*.4+high*.25)*env
        data.append(v)
    save(name,data)
for surface,pitch in [('grass',95),('dirt',115),('stone',180),('wood',240),('metal',350),('mud',65),('water',90)]:
    for v in range(4): sound('step_'+surface+'_'+str(v),'gel' if surface in ['mud','water'] else 'metal' if surface=='metal' else 'step',.23 if surface!='water' else .38,pitch*(1+v*.035),v)
for kind,pitch in [('flesh',100),('gel',65),('stone',160),('metal',540),('wood',220)]:
    for v in range(3):sound('hit_'+kind+'_'+str(v),'metal' if kind=='metal' else 'gel' if kind=='gel' else 'impact',.4,pitch*(1+v*.045),v)
for name,kind,duration,pitch in [
('swing_light','swish',.22,150),('swing_heavy','swish',.48,85),('thrust','swish',.27,190),('draw','metal',.42,310),('sheathe','metal',.3,260),('parry','metal',.62,670),('jump','step',.18,140),('land','impact',.36,75),('dodge','swish',.38,110),('dash','swish',.55,160),('hurt','voice',.3,155),('death','voice',1.1,100),('denied','ui',.15,180),
('bow_nock','wood',.19,240),('bow_draw','swish',.7,180),('bow_release','metal',.28,410),('arrow_flight','swish',.4,700),('spear','swish',.38,120),('rapier','swish',.17,320),('arrow_pickup','wood',.2,220),
('wolf_tell','voice',.75,105),('wolf_bite','voice',.24,170),('wolf_pain','voice',.35,150),('wolf_death','voice',.85,85),('wolf_howl','voice',2.1,240),('boar_tell','voice',.5,75),('boar_charge','voice',.8,90),('boar_pain','voice',.27,105),('boar_death','voice',.8,65),
('slime_tell','gel',.65,65),('slime_leap','gel',.42,120),('slime_land','gel',.5,50),('slime_death','gel',.7,40),('slime_split','gel',1.,65),('resin_launch','gel',.42,90),('resin_sticky','gel',.6,55),
('elder_form','impact',2.1,45),('elder_tell','voice',.95,48),('elder_sweep','swish',.7,80),('elder_slam','impact',1.1,48),('elder_rush','impact',.75,65),('stone_throw','swish',.4,110),('boss_death','impact',2.,52),
('water_enter','gel',.65,70),('water_exit','gel',.45,100),('drown','gel',1.4,45),('water_cast','gel',.9,160),('water_hit','gel',.6,90),('fire','swish',.8,100),('wind','swish',.7,120),
('ui_focus','ui',.055,600),('ui_confirm','ui',.14,780),('ui_back','ui',.12,440),('ui_open','ui',.2,520),('ui_close','ui',.16,380),('coin','metal',.3,1500),('pickup','ui',.2,940),('drink','gel',.6,160),('craft','metal',.5,750),('rest','ui',1.2,330),('travel','ui',1.4,440),('discover','ui',.9,660),('level','ui',1.1,880),('quest','ui',.7,550)]: sound(name,kind,duration,pitch)
# Original modal ambient compositions; no adapted melodies or sample libraries.
for name,notes in [('music_reach',[50,57,60,53]),('music_fen',[45,52,55,48]),('music_combat',[38,41,43,36]),('music_vault',[33,40,36,43]),('music_title',[50,53,57,60])]:
    duration=16.;data=[]
    for i in range(int(RATE*duration)):
        t=i/RATE;chord=int(t/4)%4;root=notes[chord];ct=t%4
        v=0.
        for semi in [0,7,12]:
            f=440*2**((root+semi-69)/12)
            e=math.sin(math.pi*ct/4)**2
            v+=.1*e*(math.sin(TAU*f*t)+.25*math.sin(TAU*2*f*t))
        beat=t%1
        v+=.035*math.exp(-beat*9)*math.sin(TAU*(440*2**((root+19-69)/12))*t)
        data.append(v)
    save(name,data,True)
for name,base in [('amb_wind',42),('amb_forest',210),('amb_night',880),('amb_fen',70),('amb_cave',33),('amb_water',100),('amb_guild',160),('amb_underwater',35),('amb_fire',95)]:
    duration=8.;data=[];r=random.Random(name);low=0.
    for i in range(int(RATE*duration)):
        t=i/RATE;low=.97*low+.03*r.uniform(-1,1)
        v=low*.9 + .025*math.sin(TAU*base*t)*(1+.4*math.sin(TAU*t/8))
        if name in ['amb_forest','amb_night','amb_fen']:
            pulse=max(0,math.sin(TAU*t/(2 if name=='amb_forest' else 1)))**14
            v+=.12*pulse*math.sin(TAU*(base*3*t+.8*math.sin(TAU*t*6)))
        data.append(v)
    # Equal-power wrap crossfade: identical start/end value, no discontinuity.
    n=int(RATE*.35)
    for j in range(n):
        w=j/(n-1);data[-n+j]=data[-n+j]*(1-w)+data[j]*w
    save(name,data,True)
OUT.mkdir(parents=True,exist_ok=True)
manifest={'version':1,'license':'CC0-1.0','copyright':'Original sound designs and compositions created for World Rise; contributors dedicate these recordings and compositions to CC0.','generator':'tools/audio/create_original_audio.py','sample_rate':RATE,'files':records}
(ROOT/'art/library/audio/original-audio-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(f'Generated {len(records)} original audio files')
