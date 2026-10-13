# Coastal Map Builder

Open **Coastal Map Builder** from the desktop. It runs offline without Godot, Blender or Codex installed.

## Create, select and transform

The left palette contains reusable pieces, including **Terrain surfaces**: Smooth hill, Bluff with walk-up and Overhang with walk-up. Choose a piece, then click the map to place it. For terrain, drag a rectangle to draw its footprint; a click uses the default size. Terrain creates an independent piece even when it overlaps another one. Placement returns to **Select & transform**. Hold Shift to repeat ordinary pieces.

Click an existing piece to edit it in **Selection**. Drag its body or label to move it. Selected terrain and rectangular zones show yellow edge and corner handles: drag outward to grow or inward to shrink. The opposite edge stays fixed. The cyan terrain edge marks the walk-up; dragging it changes ramp length (1–8m). Other edges resize the plateau without changing height. Rotated pieces resize in their own orientation. Edges snap at the gold map boundary instead of rejecting the drag. There is no extra margin or arbitrary plateau size cap.

Use **Objects** to select individual overlapping pieces, creatures, painted regions or transitions. **Area** edits boundaries, biome and START; **World** sets the world's name and starting area. The Area menu adds outdoor/cave areas or selects START. New worlds start with one empty outdoor area; **File > Open example** opens the optional cave demo.

Delete removes the selected piece; Ctrl+Z/Y undoes/redoes a whole drag. Escape returns to Select. Wheel zooms, middle-drag pans, right-drag orbits. View offers Top/Angled/Fit area.

## Terrain details

Height, width, plateau depth, ramp length, rotation and surface profile are editable in Selection. **Sculpt height** and hovering Up/Down change a patch's height; Shift uses 1m steps rather than .25m. Left/Right changes the profile. Overhangs retain space below their ledges and require at least 2.6m height. Terrain must fit inside its area, including the ramp; area coordinates range from -100 to 100 (at most 200m per axis). A steep bluff blocks movement; its walk-up permits ground travel.

## Transitions, creatures and paint

Choose Transition in Area tools & paint. Select its blue zone or label, then drag its yellow edges/corners to resize. Centre X/Z and Zone width/depth give precise values. Set Destination area, Landing X/Z, label and Press E behaviour independently. Add a return gate if needed. Drafts may contain disconnected areas; Play/Install requires reachable areas and walkable starts/landings.

Creatures use catalog E codes. Timed respawn begins when the creature dies and has no visible marker in game. Countdown pauses with menus and while away, and persists in custom saves. Green/Moss/Resin/Bramble slime arrivals can be tree drops with height 2–8m, trigger range 2–12m and shared ambush groups. Jungle biome and catalog canopy/root/vine/moss pieces are available.

Paint makes rectangular grass/path/cobble/sand/water zones, also resizable with handles. Later regions override earlier ones.

## Fragments and files

**Fragments** keeps named reusable sections locally outside release cleanup. Enter Fragment name, then Save current area as a new fragment. Select an entry to rename it with Rename selected, Open to edit, Add as area, or Stamp on map. Names support spaces and up to 80 characters. Save/Ctrl+S updates an opened fragment; Save draft as creates a separate world. Fragments preserve scenery, paint, terrain and creatures; external travel gates and story interactions are excluded. Each stamp gets fresh object IDs and independent ambush groups. Invalid stamps are rejected atomically; Ctrl+Z undoes an insertion.

**Save** stores an editable .coastworld.json draft; Ctrl+S updates its existing file. Check map reports errors. Play world installs and opens a valid custom world; Publish installs locally or exports. Custom packs and their saves are separate from the story and survive release cleanup. Drafts, fragments, installed worlds and custom saves live under user://world-drafts, world-fragments, worlds and world-saves.

Portable format is coastal_world version 1, at most 32 areas and 4 MB. IDs and the A–G catalog codes remain stable; changing area/creature IDs can invalidate old custom saves. Editable Blender sources remain independent of map editing.
