# Current meme battle art — v0.16

Five identities retain their distinct original styles: photographic three-shoe shark, natural gray-white tabby, flat Japanese office little person, plush yellow chicken with center-part hair/overalls/ball, and adult Rio22 with blue twintails, opaque bikini and ankle-length swim skirt/heavy sword. The home/selection use their separate HD2D illustration rigs; battle renders the anatomical parts through a320×240 nearest-filtered world beneath HD text. No moving full-body portrait replaces articulated combat.

## Current inventory

| ID | Named skeletal clips | Joint keys | Pinned source visual labels |
| --- | ---: | ---: | ---: |
| rio | 37 | 449 | 40 |
| cat | 43 | 503 | 46 |
| shark | 36 | 432 | 41 |
| worker | 40 | 481 | 44 |
| chicken | 38 | 446 | 43 |

These are skeletal poses over the original part PNGs, not independently painted full-body frames. Source actors retain their own frame/permission/HitVO/rectangle authority. Previous NPC alpha-geometry descriptions in the archived v0.12 README are historical, not current gameplay collision.

## This pass

Only air_hurt/down/getup for each of five fighters changed:12/16/20 skeletal keys per clip,240 total. Flying victims keep a distinct struck silhouette. Cat curls its paws, chicken folds wings/short legs, worker lies with its briefcase, shark spreads its three shoes, Rio folds skirt panels while gripping the sword. Getup starts at down's final pose and returns to idle. Rio's final weapon angle matches the actual renderer's idle floor clamp; the retained original blade's faint lower fringe crosses the floor by less than1 native pixel at the last few recovery samples and idle. No alpha threshold was weakened to hide that residual.

Original source PNG bytes, all other clips, source_visuals, body dimensions, part sizes and rendering remain unchanged. Fighter's presentation samples recovery by the real source idle frame, reaching the standing pose in the last visible source frame; it does not alter recovery permission or source timing. The pool background now retains1312×736 painting aspect on the official map while keeping its authored floor UV aligned to the live floor.

## API and evidence

Production Pixel.draw_fighter keeps a fixed body-height scale and local foot origin. Pixel.get_pose_state and the optional draw observer expose actual submitted part polygons without replacing rendering. Shapes/effects remain separate from physical contacts, and only real dash uses a limited trail.

v016-reaction-art-scope.json records scoped alpha/continuity/source-byte checks and the exact residual. Native reaction boards are pure renderer photographs; actual source hurt/down/getup photographs are separately driven by physical WorkerU with documented initial positions. Sampling is finite; neither key counts nor alpha checks establish subjective SF6 quality or manual review of every animation frame.

The original generation prompts and v0.7/v0.12 source-part QA reports are retained with their historic scope. The previous README is archived at 验证记录/pixel-art-README-v0.12.md.
