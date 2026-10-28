# Formal playable source → original meme articulated art

The source actor remains OpenBleachVsNaruto 3.4 at commit
`4d7bc9913ec6b609ba521ff86b6066bff134a736` (5DPLAY Game Studio and contributors,
GPL-3.0-or-later). The public XML/AS3 and verified source profile are preserved in
`source_reference/open-bvn-playable` and `assets/logic/bvn-playable-profiles.json`.

This table and these poses adapt the original meme artwork to those source events.
They do not transplant anime character images. They do not own command permissions,
damage, HitVO, source hit areas, gravity, source movement, branching or contact.
The source areas multiplied by the stage unit 1.6 remain the production collision;
`meme_hit_geometry.gd` can sample the visible prop/paw/shoe for visual diagnostics.
A tiny prop cannot expand an invisible damaging region in this art adapter.

The five mappings are Rio→Kenpachi, cat→Lee, worker→Aizen, chicken→Naruto,
shark→Grimmjow. All 214 current source labels have an explicit `source_visuals`
entry in their rig JSON. Unknown labels return `known:false`.

API:

- `Pixel.get_source_visual(id, current_visual_label, relative_source_frame)`
- `Pixel.get_source_visual_absolute(id, go_frame_entry_label, absolute_source_frame)`
- `Pixel.draw_fighter(canvas, id, art_clip, progress, facing, tint, body_height)`
- `Pixel.get_pose_state(id, art_clip, progress)`

The absolute lookup is important: the source actor preserves its goFrame entry name
as nextFrame crosses a visual label. Aizen's `砍4` starts at 236; the four preparatory
frames naturally continue into `砍4_QK` at 240. Visual lookup changes to `attack4`
without resetting the actual source actor. The two `砍5` hit segments stay in one
animation; endAct14 never closes the later actual hit before source frame15.

Each registration has `source_alignment` with source profile/commit, entry and
visual labels, absolute start index, first/last active frames, idle frame,
source hit intervals and release frames, and `pose_landmarks` for the purely visual
piecewise source-frame→art-phase map. `keyframe_phases`, used by the three long
confirmed/flurry branches, preserves exact separate source hit peaks instead of
forcing closely spaced bursts onto uniformly spaced visual keys.

49 new branches contain 551 authored articulated joint keys (not 551 AI-painted
full-body images). The original PNGs, source-part ownership, body anatomy and all
existing keyframes remain unchanged except the initial key of each J2/J3. Those
10 entry keys now match the actual first legal source setAttack frame. Rio's
previously fixed launcher, and worker's complete-alpha ground support fixes in
skill3/super_down are preserved byte-for-byte as pose arrays.

Pure checks: `tests/playable_art_all.gd` and `tests/playable_art_alignment.gd`.
They use retained source alpha > 0 with the real part affine transforms, source
frame fixtures, both facings, real original-pixel contact shapes, and the official
75–96 world-pixel body height. No cropped test bitmap hides below-floor pixels.
Native real-texture boards are produced by `work/playable-art/render_branches.gd`
using a fixed 2.5 camera scale, one character per sample, and three source frame
samples in both directions. Build/test screenshots are not production assets.

Source-size bridge regression: `tests/pixel_source_draw_size.gd` delegates the real
Fighter draw callbacks to the real PixelRenderer. A disabled-by-default draw observer
records the actual CanvasItem polygons and checks all submitted part scales, explicit
source height arguments, facing, and dash echoes. It runs with either the headless
or native display backend; the observer is cleared before teardown. The original
49 native boards were rendered by Root. Representative grip/seam checks passed;
raised blades cropped by the 900px board are not certified for complete extent.
The fixture supports `-- --id=rio --clip=super_confirm --full-extent` to produce a
1500px-tall full-sword board without changing production poses.
