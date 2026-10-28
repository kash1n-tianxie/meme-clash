# BVN source-clock skill presentation

`skill-fx-bundles.json` maps all 40 meme-role skill bindings to 43 original source bundles. The source commit is `5DPLAY-Game-Studio/OpenBleachVsNaruto@4d7bc9913ec6b609ba521ff86b6066bff134a736`; upstream provenance and the retained source license are in `source_reference/open-bvn-playable/`.

This directory contains source-derived label/region/spawn metadata. It does not contain original Flash bitmap or audio bytes. `game/bvn_skill_fx.gd` draws new small procedural sword, claw, paper, basketball and water materials using actual source frames and world registrations. Gameplay events, HitVOs, independent object clocks, hitstop and shake remain owned by the source runtime.

All region and spawn intervals are relative to the original entry label. Branch labels retain their original absolute source frame. Renderers must use `source_absolute_frame`, not the current branch label's local progress. Independent objects use their own frozen donor/binding identity and child clock, never the owner's later move.

Ordinary J attacks are outside this renderer. It draws no actor copies and adds no logical ball, attacker, collision, damage or action timer.

The two original Naruto normal W+J children `kj2mc` (`元件/mc_0035`, 36 frames) and `kj2mc2` (`元件/mc_0034`, 42 frames) have a narrow feather-material renderer. This exception matches frozen normal-launcher provenance and does not add to the 40 skill bindings or draw the original clone bodies. Their actual child position, active bounds, clock and removal govern the presentation.
