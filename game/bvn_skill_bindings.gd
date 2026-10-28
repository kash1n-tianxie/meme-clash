extends RefCounted
## SPDX-License-Identifier: GPL-3.0-or-later
## Forty meme skins bound to the pinned BVN move data, without replacement clocks.
const DATA_PATH := "res://assets/logic/bvn-skill-bindings-v022.json"
const STAGED_PATH := "res://assets/logic/bvn-skill-bindings-v034.json"
const Data = preload("res://game/data.gd")
const BASE := {"rio":"kenpachi","cat":"lee","worker":"aizen","chicken":"naruto","shark":"grimmjow","notify":"sakura","wojak":"sasuke_susanoo"}
const PERMISSION_COMMANDS := {"zhao1":"skill1","zhao3":"skill2","zhao2":"skill3","bisha":"super","bishaUP":"super_up","bishaSUPER":"super_down","skillAIR":"air_skill","bishaAIR":"air_super"}
const DEFAULT_LABELS := {"zhao1":"招1","zhao3":"招3","zhao2":"招2","bisha":"必杀","bishaUP":"上必杀","bishaSUPER":"超必杀","skillAIR":"跳招","bishaAIR":"空中必杀"}
static var _bindings: Dictionary = {}
static func _load() -> void:
	if not _bindings.is_empty(): return
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Dictionary: return
	for entry: Dictionary in parsed.get("bindings",[]):
		_bindings[str(entry.get("binding_id",""))]=entry
	if FileAccess.file_exists(STAGED_PATH):
		var staged: Variant = JSON.parse_string(FileAccess.get_file_as_string(STAGED_PATH))
		if staged is Dictionary:
			for entry: Dictionary in staged.get("bindings",[]):
				var id: String = str(entry.get("fighter_id",""))
				var key: String = str(entry.get("binding_id",""))
				if id not in Data.STAGED_V034_IDS or _bindings.has(key): continue
				var translated: Dictionary = entry.duplicate(true)
				var command: String = str(entry.get("command",""))
				translated["name_ja"] = Data.SKILL_NAMES_V034.get(id,{}).get(command,entry.get("name_ja",""))
				translated["use_ja"] = Data.SKILL_USES[id].get(command,"")
				_bindings[key] = translated
static func binding_for(fighter_id: String, command: String) -> Dictionary:
	_load()
	return _bindings.get(fighter_id+":"+command,{}).duplicate(true)
static func permission_binding(fighter_id: String,key: String,label: String) -> Dictionary:
	# Explicit alternate branch labels belong to the currently running source.
	if label!=str(DEFAULT_LABELS.get(key,"")): return {}
	if fighter_id in Data.STAGED_V034_IDS:
		# New fixed source forms retain their own zhao2/zhao3 entry labels.
		# Their command-to-permission-key routing is owned by Fighter.
		for command: String in PERMISSION_COMMANDS.values():
			var entry: Dictionary = binding_for(fighter_id,command)
			if str(entry.get("entry_label","")) == label and not entry.is_empty(): return entry
		return {}
	return binding_for(fighter_id,str(PERMISSION_COMMANDS.get(key,"")))
static func base_profile_id(fighter_id: String) -> String:
	return str(BASE.get(fighter_id,fighter_id))
static func all_bindings() -> Array:
	_load()
	return _bindings.values().duplicate(true)
