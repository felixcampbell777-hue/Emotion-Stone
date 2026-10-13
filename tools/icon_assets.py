"""Package the generated launcher artwork into standard Windows icon sizes."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'game/assets/ui/launcher-icon-v1.png'
ICON_NAME='CoastalFoundation-v3.ico'

def prepare_icons():
    icon=ROOT/'output/windows'/ICON_NAME
    stamp=ROOT/'output/verification/icon-source.sha256'
    digest=hashlib.sha256(SOURCE.read_bytes()+Path(__file__).read_bytes()).hexdigest()
    if icon.exists() and stamp.exists() and stamp.read_text()==digest:
        return icon
    icon.parent.mkdir(parents=True,exist_ok=True)
    with Image.open(SOURCE) as source:
        image=source.convert('RGBA')
        if image.width!=image.height or image.getchannel('A').getextrema()[0]!=0:
            raise ValueError('Launcher artwork needs a square canvas and transparent outside pixels.')
        image.save(icon,format='ICO',sizes=[(s,s) for s in [16,20,24,32,40,48,64,96,128,256]])
    with Image.open(icon) as result:
        sizes=sorted(result.ico.sizes())
        if (16,16) not in sizes or (256,256) not in sizes:
            raise ValueError('Windows icon packaging omitted required sizes.')
    stamp.parent.mkdir(parents=True,exist_ok=True)
    stamp.write_text(digest)
    (stamp.parent/'icon-report.json').write_text(json.dumps({'source':str(SOURCE),'icon':str(icon),'sizes':sizes,'alpha_preserved':True},indent=2))
    print(f'ICON READY: {icon.name} ({len(sizes)} sizes)')
    return icon

if __name__=='__main__':
    prepare_icons()
