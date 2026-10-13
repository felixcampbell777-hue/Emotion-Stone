"""Inspect the reviewed CC0 eye data in disabled-autoexec Blender, without saving."""
import bpy,json
def inputs(node):
    return [[i,s.name,list(s.default_value) if hasattr(s.default_value,'__len__') else s.default_value] for i,s in enumerate(node.inputs) if hasattr(s,'default_value') and not isinstance(s.default_value,bpy.types.ID)]
def nodes(tree):
    return [{'name':n.name,'label':n.label,'parent':n.parent.name if n.parent else None,'type':n.type,'operation':getattr(n,'operation',None),'group':n.node_tree.name if n.type=='GROUP' else None,'inputs':inputs(n),'outputs':[[s.name,list(s.default_value) if hasattr(s.default_value,'__len__') else s.default_value] for s in n.outputs if hasattr(s,'default_value')]} for n in tree.nodes]
r={'version':bpy.app.version_string,'materials':[{ 'name':m.name,'nodes':nodes(m.node_tree),'links':[[l.from_node.name,l.from_socket.name,l.to_node.name,l.to_socket.name] for l in m.node_tree.links]} for m in bpy.data.materials if m.use_nodes],
   'groups':[{ 'name':t.name,'nodes':nodes(t),'links':[[l.from_node.name,l.from_socket.name,l.to_node.name,l.to_socket.name] for l in t.links]} for t in bpy.data.node_groups],
   'texts':[t.name for t in bpy.data.texts],'objects':[{ 'name':o.name,'type':o.type,'materials':[m.name for m in o.data.materials] if o.type=='MESH' else []} for o in bpy.data.objects]}
with open(r'C:\Users\felix\AppData\Local\Temp\anime_eye_asset_inspection.json','w') as f:json.dump(r,f,indent=2)
