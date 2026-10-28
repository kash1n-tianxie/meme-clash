# Rioの独立4フレーム素材

12枚の独立した透過PNG。各画像は1774×887px、4列×1行で、セルは443.5×887px。`rio_idle`、`rio_walk`、`rio_jump`、`rio_light`、`rio_heavy`、`rio_hurt`、`rio_block`、`rio_ko`、`rio_special1`、`rio_special2`、`rio_special3`、`rio_super`を収録。

密な複数行atlasから切り出した素材ではなく、元の独立clipを内蔵imagegenで編集した。全身・大刀・髪を同じ割合で縮小し、列の左右へ十分な透明余白を設けた。胴体の比率は保持し、ポーズごとの足・膝・腕・剣の動きは残した。写真編集やPython/Pillowでの画像加工・合成・切り抜き・保存はしていない。生成されたPNGをそのままコピーした。

48フレームを目視確認。全フレームの各列左右48px以内にalpha>192の主体ピクセルは0、alpha>38も0。ごく少数のalpha=1/255の生成ノイズが安全余白に残るが、見える輪郭や武器が隣接列に越える箇所はない。12枚とも真のアルファ透過を持ち、各clipの4フレーム画像ハッシュは全て異なる。

`rio-clip-calibration.json` に、clip全体で固定するbody単位の倍率・足線・横位置を記録。idleの立ち姿448pxを基準に倍率を算出した。武器の向きやしゃがみ・空中・倒れ姿勢のbboxで毎フレーム伸縮しない。ジャンプ、KO、対空技の立ち姿換算高さは関節比率からの目視推定で、実機で微調整する場合もclip全体の定数に限定する。

`rio-clip-qa.json` は寸法、透過ピクセル数、各セル領域、主体bboxとハッシュの検証結果。`rio-clip-padding-prompts.json` は余白修正の提示文とネイティブ出力元。原始生成の提示文は `assets/art/generation-prompts.json`、原始画像は `work/rio-clips-original` にある。
