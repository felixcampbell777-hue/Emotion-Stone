"""Encode actual Godot-rendered frame samples as a portable animated preview."""
import argparse
import json
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--frames',type=Path,default=ROOT/'output/verification/windows-render/heavy-cycle')
parser.add_argument('--output',type=Path,default=ROOT/'output/verification/windows-render/heavy-swing.gif')
args=parser.parse_args()
times=json.loads((args.frames/'timings.json').read_text())
frames=[]
durations=[]
for index,t in enumerate(times):
    with Image.open(args.frames/f'frame-{index:03d}.png') as image:
        frames.append(image.convert('RGB').convert('P',palette=Image.Palette.ADAPTIVE,colors=256))
    durations.append(max(20,(times[index+1]-t) if index+1<len(times) else 600))
args.output.parent.mkdir(parents=True,exist_ok=True)
frames[0].save(args.output,save_all=True,append_images=frames[1:],duration=durations,loop=0,disposal=2,optimize=False)
print(f'ENCODED {len(frames)} actual renderer frames: {args.output}')
