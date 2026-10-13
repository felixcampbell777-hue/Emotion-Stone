# Advanced Alpha personal heroine

v0.29.2 promotes the current saved personal skin from Beta into Alpha's Advanced Game presentation. It uses the already authored and verified heroine-beta.glb and beta-heroine.blend; the original personal file, separate anime alternative, saved Beta shirt, canonical models and clips are untouched. No downloads or Blender regeneration are required.

Choose Alpha, then Esc > Graphics & View > World art > Advanced. The animated heroine is the main Game profile; selecting Advanced enables first person. C cycles Follow / First person / Overhead. Inventory uses the same skin. Existing saves with Advanced and Game automatically render this heroine; their saved camera choice is retained until changed. Original graphics and Standalone static review remain available.

main.apply_character_art is the shared gameplay/inventory presentation entry point. It uses the retained canonical motion rig for the personal skin, preserving action clocks and Alpha damage, stamina and movement speed. Advanced Alpha now uses the same broad war sword as Beta, including its back anchor, hand fitting, true steel reach and energy materials. Original and static review retain the canonical sword. Hand fitting uses the correct weapon grip. Equipment sockets attach to the rendered rig so they remain visible when the canonical body is hidden. First-person arms and eye motion use that same rendered skin and actor clock; menus retain simulation and mouse-capture gating.

Full verification exercises profile changes, actual parry, inventory, map travel, Original restoration and private Alpha save/load. Native capture-windows --view camera --art-profile darkwood includes alpha-advanced-main-character, alpha-advanced-first-person-sword and alpha-advanced-first-person-parry; --view menus --art-profile darkwood checks the inventory. Only the manifest release remains after Windows verification and cleanup.



Final v0.29.2 evidence: source and packaged Windows reports each pass 1,336 checks, including the shared war sword and private saves. Native camera, menus and combat renders inspected. The Windows wrapper timed out after the pass report was written; normal packaged Advanced startup/exit separately returned code 0 and cleanup was completed manually. Only v0.29.2 remains; desktop launcher updated. Current report: output/verification/alpha-character-integration.json.
