"""Read library names only, with Blender auto-execution disabled."""
import bpy,json,os
path=os.path.join(os.environ['TEMP'],'heroine-bystedt-hair.blend')
with bpy.data.libraries.load(path,link=False) as (src,dst):
    info={'objects':list(src.objects),'collections':list(src.collections),'node_groups':list(src.node_groups)}
with open(os.path.join(os.environ['TEMP'],'heroine_bystedt_library.json'),'w') as f:json.dump(info,f,indent=2)
