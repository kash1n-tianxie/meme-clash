Visual v18 HD character masters — 2026-10-08

Approved references (machine-specific locations omitted from the public source):
Original references are used for identity, lighting and illustration direction only.

Files:
shark.png — 1536×1024 RGBA; exactly three blue-white shoes.
cat.png — 1024×1536 RGBA; one natural gray-white tabby with two raised paws.
worker.png — 1024×1536 RGBA; original round-head short-body bowing blue-shirt meme.
chicken.png — 1024×1536 RGBA; middle-part yellow chick, gray bib trousers and basketball.
rio.png — 1254×1254 RGBA; explicitly age22 adult, blue twin ponytails, opaque blue/navy bikini top, ankle swim skirt and heavy broad sword.

Generation:
Five independent built-in image_gen requests; four independent background-extraction edit requests.
Selected cleaned candidates for shark/cat/worker. Chicken remains the first original: its cleanup candidate expanded a wing to the right canvas edge. Rio remains the first original.
Native generated PNGs are copied unchanged. No manual image cropping, alpha thresholding, despeckling, resizing, recoloring or pixel edits were performed.
generation-prompts.json records first/selected native files, original prompts and reference roles.
background-cleanup-prompts.json records the four exact background edit prompts.

Metadata:
metadata.json is version1 with portraits, source/canvas/full_body_rect/source_rect compatible with the existing UI/HUD schema. Existing assets/art/portraits.json was not changed.
full_body_rect measures alpha>38/255 plus three source pixels for contain layout; original texture keeps its soft alpha.
alpha_bbox separately reports every alpha>0 pixel, including negligible alpha1 noise.
joints and semantic_regions are manually fitted source-coordinate guides for the animation agent. Left/right means image left/right, before mirroring.
Hidden hip/knee positions under skirt and briefcase are inferred weighting guides, not measured bones.
These masters are single illustrations, not generated animation-frame sequences.

Transparency verification:
alpha-qa.json reports real PNG modes, canvas sizes, alpha threshold bounding boxes, canvas-edge values and25 outside-cloud samples.
All25 sampled visible RGB cloud patches have alpha0. Exact RGBA compositing over warm cream [255,248,232] leaves those25 destination pixels identical to the background. RGB-only previews can display hidden background colors.
Cat has one alpha1 canvas-corner micro-point; explicitly retained and reported. All five have no strong alpha (>38) on canvas edges and complete main silhouettes.
Root's actual Godot warm-pool compositing screenshot remains the scene-level visual acceptance check; numeric samples do not certify every scene pixel.
No Godot GPU run, Desktop copy, animation-code, UI-code, pixel-rig or old-master modification was performed in this asset task.

Root integration additions:
pool_home.png — native1672×941, separately rendered pool/home background.
pool_stage.png — native1448×1086, 4:3 illustration beneath transparent pixel actor/effects viewport.
title_logo.png — native1774×887 transparent brush lettering; live UI uses independent contain texture.
background-generation-prompts.json and logo-generation-prompt.json retain exact built-in image_gen prompts.
Root handles final Desktop integration, screenshot/movie evidence and current mesh/UI tests; the asset-task scope above refers only to the art agent.
