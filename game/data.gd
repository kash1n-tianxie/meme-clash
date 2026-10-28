extends RefCounted

const TITLE = "ミーム大乱闘"
const VERSION = "0.39.0"
const ORDER = ["shark", "cat", "worker", "chicken", "rio"]
## Root opens each ID only after its complete source/art/native acceptance.
## ROSTER stores testable staged data; this whitelist owns formal selection.
const STAGED_V034_IDS: Array[String] = ["notify", "wojak"]
const ACCEPTED_V034_IDS: Array[String] = ["notify", "wojak"]
const ROSTER = {
	"shark": {
		"name": "トララレロ", "subtitle": "スニーカー・シャーク",
		"description": "三本脚とスニーカーで前へ！\n間合いを見て、打撃を使い分け。",
		"moves": ["スニーカー水圧", "三足つかみ落とし", "踏ん張り水爆"],
		"move_uses": ["少し退き、前方へ水圧を返す", "つかめた時だけ叩き落とす", "三足で踏み込み、周囲のガードを崩す"],
		"tactics": "W+Uはつかみ、S+Uは周囲のガード崩し。相手の位置に合わせて使い分け。",
		"chain": "前蹴り → 足替え → 中足キック", "sweep": "シューズ・ラッシュ", "launcher": "三足キック", "air_slam": "三足ダウンプレス",
		"super": "トラララ水圧砲", "color": Color("58b8ee"), "difficulty": 1
	},
	"cat": {
		"name": "ミーム猫", "subtitle": "表情で勝負する猫",
		"description": "ぴょんと跳んで、急に変顔！\n接近と着地の派生で勝負。",
		"moves": ["Huh？猫アッパー", "横っ走りツメ", "涙のねこ落とし"],
		"move_uses": ["近づきながら上へ引っかく", "地上を走ってガードを崩す", "跳ねて落下・着地で押し込む"],
		"tactics": "W+Iは頭上を迎撃。IとS+Iは体力も使うので、残り体力を見て選ぼう。",
		"chain": "左ねこパンチ → 右ねこパンチ → 両爪プレス", "sweep": "ねこ連打", "launcher": "びっくり突進", "air_slam": "肉球ダイブ",
		"super": "絶叫ぐるぐる", "color": Color("f6c955"), "difficulty": 2
	},
	"worker": {
		"name": "定時くん", "subtitle": "もう帰っていいですか",
		"description": "丁寧に構え、距離を見て反撃。\n独立攻撃も置いて、定時で退勤！",
		"moves": ["書類、お返しします", "書類タワー", "お引き取りください"],
		"move_uses": ["前方へ書類を押し返す", "独立した書類の山を置く", "近づいた相手を確認して押し返す"],
		"tactics": "W+Uの書類を置いて接近を誘う。W+Iは初段の命中から追撃する。",
		"chain": "手のひら押し → カバン打ち → 退勤ステップ", "sweep": "丁寧な反撃待ち", "launcher": "案件チェック", "air_slam": "決裁スタンプ",
		"super": "退勤承認", "color": Color("51bcae"), "difficulty": 2
	},
	"chicken": {
		"name": "クンチキン", "subtitle": "コートのダンス王",
		"description": "ボールで牽制、舞って接近。\nセンター分けは今日も完璧。",
		"moves": ["直球シュート", "リバウンドアタック", "ごり押し回転ボール"],
		"move_uses": ["速い直球を一つ投げる", "踏み込んで上へ肩で攻撃", "ゆっくり進む多段の回転球"],
		"tactics": "Uは速い単発、S+Uは遅い多段。Iの三連投は、間合いを変えて使おう。",
		"chain": "羽パンチ → 肩ステップ → ショルダー", "sweep": "コートの突進", "launcher": "分身ステップ", "air_slam": "ダンク・プレス",
		"super": "トリプルシュート", "color": Color("f69c44"), "difficulty": 1
	},
	"notify": {
		"name":"通知ちゃん", "subtitle":"未読が増えるほど、顔が変わる。", "age":24,
		"description":"二連の通知と三方向の未読で牽制。\n礼儀正しい笑顔の奥に、バッグの一撃。",
		"moves":["通知二連","既読、速っ！","未読三連"],
		"move_uses":["二回の通知を順に放つ","素早く踏み込み、拍撃から次の技へ","三方向へ未読を一枚ずつ放つ"],
		"tactics":"Uは二回、S+Uは三方向。IとS+Iの続きは、最初の接触を確認してから。",
		"chain":"通知チェック → バッグ払い → ちょっと待って！",
		"sweep":"バッグでひと払い", "launcher":"通知の間合い詰め", "air_slam":"前、見てなかった！",
		"super":"待って！", "color":Color("ea8d9d"), "difficulty":2,
		"source_profile":"sakura", "manifest":"res://assets/fighters/v034/notify.manifest.json",
		"normal_sfx":"v034_notify_bag_hit", "adult":true
	},
	"wojak": {
		"name":"ウォジャック", "subtitle":"言葉の代わりに、記号が飛ぶ。",
		"description":"真顔から飛び出す「？」「！」。\n言葉より大きな記号で押し返す。",
		"moves":["？、それで？","※追伸です","（いったん保留）"],
		"move_uses":["「？」で前方を抑える","接触を確認し「※」の追撃","「（ ）」で払い、次の技へ"],
		"tactics":"W+Uの追撃は接触を確認。空中Iは後退しながら放ち、落下攻撃には変わらない。",
		"chain":"？ → ！ → … → ※ → （ ）",
		"sweep":"（ ）で拒否", "launcher":"※間合いチェック", "air_slam":"…着地待ち",
		"super":"！異議あり", "color":Color("b6bdc6"), "difficulty":2,
		"source_profile":"sasuke_susanoo", "manifest":"res://assets/fighters/v034/wojak.manifest.json",
		"normal_sfx":"v034_wojak_push", "adult":true
	},
	"rio": {
		"name": "蒼刃リオ", "subtitle": "剣より小さい大剣使い", "age": 22,
		"description": "歩くのは苦手。でも振ると最強！\n22歳。重すぎる剣と、今日も格闘。",
		"moves": ["剣に引っぱられた！", "よいしょ斬り", "重すぎて反撃"],
		"move_uses": ["剣に引かれて前進・一部鋼体", "持ち上げて前上方へ攻撃", "構え中に被弾すると反撃"],
		"tactics": "S+Uで被弾を待って反撃。S+Iは初段が当たると乱舞。空振りの隙に注意。",
		"chain": "よろ斬り → 必死の返し → どっすん落刃", "sweep": "よいしょ横斬り", "launcher": "根性の間合い詰め", "air_slam": "重さにおまかせ",
		"super": "大剣、発進！", "color": Color("5b96ff"), "difficulty": 2
	}
}

## Binding order is shared with battle.set_key_bindings; physical keys are stored as integers.
const CONTROL_ACTIONS = ["left", "right", "up", "down", "attack", "jump", "dash", "skill", "super", "burst"]
const CONTROL_LABELS = ["左へ", "右へ", "上方向", "防御 / 下方向", "攻撃", "ジャンプ", "瞬歩", "スキル", "必殺", "ダメージ脱出"]
const DEFAULT_P1 = [KEY_A, KEY_D, KEY_W, KEY_S, KEY_J, KEY_K, KEY_L, KEY_U, KEY_I, KEY_O]
const DEFAULT_P2 = [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]
const TRAINING_RECIPES = {
	"normal_chain": {"name": "通常攻撃の入力練習", "input": "J → J → J", "hint": "最初の三入力を練習。一回ずつ押し、技ごとの許可中につなぐ。命中は保証されません。"},
	"launch_slam": {"name": "打ち上げから叩き落とす", "input": "J → WJ → K → 空中 U", "hint": "打ち上げが当たったらK。相手の高さまで跳んでから空中U。"},
	"air_chain": {"name": "空中入力の練習", "input": "K → 空中 J → 空中 U", "hint": "十分に跳んで、空中攻撃から空中スキルへ。許可中の入力で課題が進む操作練習です。命中・コンボは保証されません。"},
	"full_normal": {"name": "通常攻撃を最後まで", "input": "キャラクター別の通常攻撃", "hint": "相手に一段ずつ当て、技の許可中に押し直そう。段数はキャラクターで異なります。確定コンボの保証ではありません。"},
	"hit_confirm": {"name": "命中からの派生", "input": "キャラクター別の命中課題", "hint": "当たった時の追撃や次の入力を確認。自動派生・入力・条件はキャラクターごとに違います。"},
	"four_hit": {"name": "四段で締める", "input": "J → J → WJ → K → 空中 U", "hint": "浮かせた相手を追い、最後の一撃までつなごう。"},
	"sparring": {"name": "実戦練習", "input": "自由対戦・CPU", "hint": "CPUと対戦。気と体力は実戦と同じ。時間制限なし、KOで再開。"},
}

## Read-only descriptions for all forty implemented techniques.
const SKILL_USES = {
  "notify": {
    "skill1":"二回の通知を順に放つ", "skill3":"三方向へ未読を一枚ずつ放つ",
    "skill2":"素早く踏み込み、拍撃から次の技へ", "super":"接触した時だけ近身の重拍へ",
    "super_up":"相手の上へ移り、空中の攻撃につなぐ", "super_down":"接触と追撃の判定が続いた時だけ連打",
    "air_skill":"斜めに降下し、実際の着地で拍撃", "air_super":"空中から降下、触地後に叩き落とす"
  },
  "wojak": {
    "skill1":"「？」で前方を抑える", "skill3":"「（ ）」で払い、次の技へ",
    "skill2":"接触を確認し「※」の追撃", "super":"前へ出て「！」を放つ",
    "super_up":"相手の位置に「※」を置く", "super_down":"長い「…」から「!!」で締める",
    "air_skill":"短く浮き、着地で「…」", "air_super":"後退上昇から「？」を放つ"
  },
  "rio": {
    "skill1": "剣に引かれて前進・一部鋼体",
    "skill3": "構え中に被弾すると反撃",
    "skill2": "持ち上げて前上方へ攻撃",
    "super": "前へ進み、最後はガード崩し",
    "super_up": "接近して回転、多段で巻き込む",
    "super_down": "最初の命中で乱舞へ・空振りに注意",
    "air_skill": "急降下し、着地して落刃",
    "air_super": "相手の上から斜めに斬り込む"
  },
  "cat": {
    "skill1": "近づきながら上へ引っかく",
    "skill3": "跳ねて落下・着地で押し込む",
    "skill2": "地上を走ってガードを崩す",
    "super": "命中でつかみ回転・体力も消費",
    "super_up": "足を止め、頭上の二段を攻撃",
    "super_down": "多方向へ暴走・体力も消費",
    "air_skill": "近くの相手を蹴り、反発して離れる",
    "air_super": "真下へ落下・着地で大きく押す"
  },
  "worker": {
    "skill1": "前方へ書類を押し返す",
    "skill3": "近づいた相手を確認して押し返す",
    "skill2": "独立した書類の山を置く",
    "super": "相手の位置に連続で書類攻撃",
    "super_up": "命中すると瞬間移動の追撃",
    "super_down": "自分を中心に広い範囲を決裁",
    "air_skill": "相手へ寄り、空中でお辞儀",
    "air_super": "上から斜めにカバンで攻撃"
  },
  "chicken": {
    "skill1": "速い直球を一つ投げる",
    "skill3": "ゆっくり進む多段の回転球",
    "skill2": "踏み込んで上へ肩で攻撃",
    "super": "小球二つの後、大球を投げる",
    "super_up": "相手の横位置に固定の攻撃を置く",
    "super_down": "上昇して急降下・着地で大攻撃",
    "air_skill": "身を引いてから斜めに肩で降下",
    "air_super": "真下へ落ち、着地ダンク"
  },
  "shark": {
    "skill1": "少し退き、前方へ水圧を返す",
    "skill3": "三足で踏み込み、周囲のガードを崩す",
    "skill2": "つかめた時だけ叩き落とす",
    "super": "正面へ長く伸びる水圧",
    "super_up": "接近し、三足の水旋で巻き込む",
    "super_down": "上昇・急降下の後、着地で大波",
    "air_skill": "少し浮き直して近くを蹴る",
    "air_super": "斜め前へ飛び、着地で水しぶき"
  }
}

const SKILL_NAMES_V034: Dictionary = {
	"notify":{"skill1":"通知二連","skill3":"未読三連","skill2":"既読、速っ！","super":"待って！","super_up":"上から通知","super_down":"通知全部オフ","air_skill":"前見てない！","air_super":"通知叩き落とし"},
	"wojak":{"skill1":"？、それで？","skill3":"（いったん保留）","skill2":"※追伸です","super":"！異議あり","super_up":"※ここ重要","super_down":"!! 強制終了","air_skill":"…着地待ち","air_super":"？空から失礼"}
}

static func playable_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(ORDER)
	for id: String in STAGED_V034_IDS:
		if id in ACCEPTED_V034_IDS: ids.append(id)
	return ids

static func is_selectable(id: String) -> bool:
	return id in playable_ids()
