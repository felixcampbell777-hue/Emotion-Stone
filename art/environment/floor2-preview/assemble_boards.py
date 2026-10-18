from PIL import Image,ImageDraw,ImageFont,ImageOps
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
FONT=Path('C:/Windows/Fonts/segoeui.ttf');BOLD=Path('C:/Windows/Fonts/segoeuib.ttf')
def font(n,bold=False):return ImageFont.truetype(str(BOLD if bold else FONT),n)
def text(draw,xy,value,n=24,fill='#e3e9df',bold=False):draw.text(xy,value,font=font(n,bold),fill=fill)
board=Image.new('RGB',(1800,1140),'#17211d');draw=ImageDraw.Draw(board)
text(draw,(30,16),'FLOOR 2 / EXISTING MODEL TEMPLATES',35,bold=True)
text(draw,(30,60),'Actual local assets. Neutral studio previews; not the final swamp scene.',22,fill='#b6c7b3')
items=[('twisted-tree','01  Twisted tree','Shape template - needs darker swamp materials'),('dead-tree','02  Dead tree','Bare shoreline silhouette / flooded woodland'),('shore-grass','03  Tall wispy grass','Shoreline template - adapt into reed clumps'),('fern','04  Scanned fern','Detailed island undergrowth'),('moss-rock','05  Moss-covered rock','Banks, submerged rocks and small landmarks'),('stump','06  Scanned stump','Rotting woodland / shoreline detail')]
for i,(file,title,desc) in enumerate(items):
 x=(i%3)*600;y=105+(i//3)*500
 board.paste(Image.open(OUT/(file+'.png')).convert('RGB'),(x,y));text(draw,(x+18,y+435),title,26,bold=True);text(draw,(x+18,y+470),desc,20,fill='#b6c7b3')
text(draw,(30,1110),'Sources: existing Quaternius CC0 nature kit + Poly Haven CC0 scans. No new downloads.',20,fill='#b6c7b3')
board.save(OUT/'model-templates.jpg',quality=92)
tex=Image.new('RGB',(1800,1060),'#17211d');draw=ImageDraw.Draw(tex)
text(draw,(30,16),'FLOOR 2 / TEXTURES + WATER COLOUR TARGETS',35,bold=True)
text(draw,(30,60),'Texture tiles below are actual existing albedo maps, shown before any swamp-specific treatment.',22,fill='#b6c7b3')
base=ROOT/'game/assets/environment/polyhaven_cc0';nature=ROOT/'art/environment/source/quaternius_stylized_nature_cc0/glTF'
items=[('Forest soil',base/'forest_ground_04/albedo.jpg','Island soil base - darken and add wetness'),('Leaf litter',base/'forest_leaves_02/albedo.jpg','Raised banks and leaf-covered island interiors'),('Low green ground cover',base/'leafy_grass/albedo.jpg','Ground vegetation mixed with exposed soil'),('Dead-tree bark',nature/'Bark_DeadTree.png','Existing tree template bark'),('Twisted-tree bark',nature/'Bark_TwistedTree.png','Existing tree template bark'),('Mossy stone',base/'models/rock_moss_set_01_b_rock_moss_set_01_diff_2k.jpg','UV atlas - see the wrapped rock in the model board')]
manifest=[]
for i,(title,path,desc) in enumerate(items):
 x=(i%3)*600;y=105+(i//3)*350
 tex.paste(ImageOps.fit(Image.open(path).convert('RGB'),(580,260)),(x+10,y));text(draw,(x+18,y+267),title,26,bold=True);text(draw,(x+18,y+304),desc,20,fill='#b6c7b3');manifest.append({'title':title,'source':str(path.relative_to(ROOT))})
text(draw,(30,817),'PROPOSED WATER COLOURS / shader not built yet',25,bold=True)
for i,(title,color,desc) in enumerate([('Shallow water','#879269','Slow, wadeable edges'),('Deeper shallows','#5c744a','Stronger slowdown'),('Drowning depth','#203d2d','Clear dark-green boundary')]):
 x=20+i*600;draw.rounded_rectangle((x,862,x+560,945),radius=12,fill=color);text(draw,(x+15,950),title,25,bold=True);text(draw,(x+15,987),desc,21,fill='#b6c7b3')
tex.save(OUT/'textures-and-water.jpg',quality=92)
(OUT/'sources.json').write_text(json.dumps({'purpose':'Asset selection review only. No floor implementation.','textures':manifest,'model_sources':['Quaternius local CC0 nature kit','Poly Haven local CC0 scans'],'water':'Proposed flat colour palette, not an existing water texture or completed shader.'},indent=2)+'\n')
print('ASSET BOARDS READY')

for name in ['twisted-tree','dead-tree','shore-grass','fern','moss-rock','stump']:(OUT/(name+'.png')).unlink(missing_ok=True)
