# Openly licensed heroine asset shortlist

Updated 2026-10-10. This replaces the paid-model recommendation: the user wants an open-source focus. Research only; no new assets downloaded, software installed, model edited, animation fitted or release replaced. The rejected draft is not approved. Playable v0.23.2 and Original remain intact.

## Recommended route

Use MPFB/MakeHuman as an adjustable anatomical foundation, combine it with selected authored hair/skin assets, and construct the ORIGINAL denim dress against the resulting body. This is the strongest no-cost component pipeline found, not a finished heroine or a guaranteed reference-quality result. The failed draft already used a CC0 anatomical mesh; changing the donor alone would not solve its generic face, ribbon hair or stiff clothing. The useful differences here are specific body/face controls, authored hair and mapped skin detail, reusable fitted garments and saved presets.

The visual target stays unchanged: realistic lean/strong proportions without bulk, warm freckles/brown eyes, SHOULDER-LENGTH chestnut hair, blue-gray collared denim shirt-dress with rolled cuffs, HIGH-WAISTED brown leather belt, knee-length pleated skirt, socks and compact lace boots. Use the latest clothing reference for fit/proportions/material quality and the earlier turnaround for original identity/costume.

For graphics, “openly licensed” is the precise criterion: editable assets under CC0 or CC-BY. Free-to-download stock licences, ripped game characters and non-commercial-only assets do not qualify. Software licences and exported-art licences are separate.

## Usable sources

| Component | Source and licence | Assessment / remaining work |
|---|---|---|
| Adjustable body and face | [MPFB](https://static.makehumancommunity.org/mpfb/index.html), [licence](https://static.makehumancommunity.org/about/license.html): open-source software; core art/output CC0 | Recommended anatomy foundation. Face/body sliders and saved presets support consistent later changes. Default output still needs visual design; it is not a finished likeness. |
| Skin and freckles | [MakeHuman Skins 01](https://static.makehumancommunity.org/assets/assetpacks/skins01.html), CC0 | Includes Margaret Toigo's `toigo_light_skin_female_freckles`. Inspect actual maps and lighting before selection; a texture cannot repair incorrect facial anatomy. |
| Authored hair | [MakeHuman Hair 02](https://static.makehumancommunity.org/assets/assetpacks/hair02.html), CC-BY | Elvaerwyn's `elvs_ashley_may_hair` is a plausible shoulder-length starting point. Thumbnail inspected: layered textured locks, unlike the prior repeated ribbons. Needs chestnut colour, reference fringe, fitting and density/length adjustment. Pack is described as mostly high-poly; optimize/bake as necessary. |
| Denim | [Poly Haven Denim Fabric 03](https://polyhaven.com/a/denim_fabric_03), CC0 | Light blue twill maps suitable as a material foundation; adjust tone/weave scale. Does not supply a collared dress, pleats, seams or garment fit. |
| Leather | [Poly Haven Fabric Leather 02](https://polyhaven.com/a/fabric_leather_02), CC0 | Material candidate for belt/boots; photographed upholstery seams must not tile conspicuously onto small accessories. Use appropriate mapped regions or another CC0 leather after inspection. |
| Clothing scaffolding | [MakeHuman Dress 01](https://static.makehumancommunity.org/assets/assetpacks/dress01.html), CC0 | Reusable fitting/topology examples, but no verified match to the original collared denim dress. Do not assemble mismatched garments and call it finished. |

[MPFB getting started](https://static.makehumancommunity.org/mpfb/docs/getting_started.html) specifies Blender 4.2 or newer and directs installation through Blender's official extension platform. Our Blender 4.5.3 meets that minimum; operation/export have not been tested in this project. [MPFB's licence](https://github.com/makehumancommunity/mpfb2/blob/master/LICENSE.md) separates GPL software from CC0 bundled assets/output. Community packs have their own individual licences: do not assume everything is CC0. [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/) permits adaptation and commercial use with attribution, licence links and change notices; retain the exact version/author from each downloaded asset.

### Actual hair thumbnail

![Elvaerwyn Ashley May hair, MakeHuman library preview](https://static.makehumancommunity.org/assets/assetpacks/elvs_ashley_may_hair.png)

This is an asset-library thumbnail, not a render of our heroine. `elvs_wavy_bob` was also inspected, but its thumbnail shows coarse sculpted masses rather than the requested surface finish. `elvs_keylth_hair` is substantially too long. None has yet been inspected as downloaded geometry or in Godot.

## Authored whole-character alternative: Sintel

![Blender Studio Sintel v2 official preview](https://studio.blender.org/files/public/thumbnail/ee/ee03d61a6d14ce79a988db5ea8192e7a/ee03d61a6d14ce79a988db5ea8192e7a.png)

[Blender Studio Sintel v2](https://studio.blender.org/characters/5d41a32b8307e9cd1023fa78/v2/) explicitly lists CC-BY 4.0 and Blender 3.4. Public preview was inspected in the browser. It shows authored eyes/face, layered hair and a lean coordinated body. Its face is more stylized than the requested RPG screenshot, hair is red/shorter, and the costume/boots differ. New denim clothing, identity changes, game optimization and a separately fitted combat rig would still be required. Existing film controls are not a drop-in replacement for our actor.

The current page requires login to download. No login/account or subscription was made; free access to that exact modern package is not confirmed. Web fetching returned 402 while the ordinary browser displayed its public listing. Do not treat its open licence as proof of unrestricted download access or bypass a gate. [The official legacy Sintel Lite article](https://durian.blender.org/news/sintel-lite/) advertises an old learning file; its current download availability and modern compatibility are unverified. Sintel is worth a visual comparison, not a selected runtime asset.

[Blender's CC0 Human Base Mesh bundle](https://www.blender.org/download/demo-files/) remains useful topology already present in the project, but it is not an alternative finished design. [Rain](https://studio.blender.org/characters/rain/v3/) is openly licensed with attribution, but its cartoon direction is not a demonstrated match to this brief. I found no finished, freely accessible open model in this research that already matches the heroine's full identity, costume and finish.

## Review sequence and low-cost maintenance

1. Resolve a coherent head/body design first. Compare actual static front, side, back and face renders against the assigned references; use realistic body proportions rather than inheriting the old rig size.
2. Fit one authored hairstyle and inspect its silhouette, fringe, scalp coverage and shading. Select skin detail with believable eye/lid geometry. Do not substitute higher resolution for correct shapes.
3. Build the denim garment with a high waist, proper sleeves/collar, pleat volume and compact boots. Open material maps supply surface detail; the garment needs authored geometry and UVs. [MPFB clothing documentation](https://static.makehumancommunity.org/mpfb/docs/assets/creating_clothes.html) supports fitted custom assets and notes that good appearance still takes involved work.
4. Store one canonical character preset, fitted garment/hair sources and a licence manifest. Keep material colours separate from geometry, export recipes reproducible and cached. Bake authoring-only skin/hair details into runtime-compatible maps; Blender node graphs are not automatically Godot materials.
5. Show a static Godot model with face close-up and body views for explicit USER APPROVAL. No animation fitting, new game release or replacement of current sources before that approval.
6. After approval, fit the existing combat motions, equipment sockets and blade/skirt clearance; then verify and replace the release while preserving Original.

Asset licence cost for the verified MPFB/MakeHuman/Poly Haven components: **$0**. This does not eliminate modeling effort. No paid character or service is part of the recommendation. No claim of achieved reference quality is made.

Only use official sources, record hashes/licences and scan downloaded files before future intake. Disable automatic script execution for downloaded Blender files. This turn downloaded no model package, texture archive, add-on or executable; no absolute virus-free claim is possible.
