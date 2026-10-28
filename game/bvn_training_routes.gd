extends RefCounted
## SPDX-License-Identifier: GPL-3.0-or-later
## Teaching observations of pinned OpenBleachVsNaruto@4d7bc991 formal profiles.
## No command, hit, resource, permission, damage or combat clock is mutated here.
const Timeline=preload("res://game/bvn_playable_timeline.gd")
const COURSE_IDS := ["full_normal","hit_confirm"]
const CONFIRMS := {
	"rio":{"command":"super_down","key_slot":8,"modifiers":[3],"entry_label":"超必杀","hit_ids":["cbs1"],"branch_label":"超必杀_HIT","source_profile":"kenpachi","input_name":"下方向必殺","note":"最初の命中で自動追撃。ガードされた時は派生しません。"},
	"cat":{"command":"super","key_slot":8,"modifiers":[],"entry_label":"必杀","hit_ids":["bs"],"branch_label":"必杀_HIT","source_profile":"lee","input_name":"必殺","note":"最初の命中で自動追撃。追加入力は不要です。"},
	"worker":{"command":"super_up","key_slot":8,"modifiers":[2],"entry_label":"上必杀","hit_ids":["sbs1"],"branch_label":"上必杀_HIT","source_profile":"aizen","input_name":"上方向必殺","note":"最初の命中で自動追撃。相手の背後へ移動するので、防御の向きにも注意。"},
	"notify":{"command":"super","key_slot":8,"modifiers":[],"entry_label":"必杀","hit_ids":["bs1","bs"],"branch_label":"必杀_CHK","branch_hit":true,"source_profile":"sakura","input_name":"必殺","note":"接近判定だけでは成功になりません。追撃の実際の命中が必要で、ガードでは成功しません。"},
	"wojak":{"command":"skill2","key_slot":7,"modifiers":[2],"entry_label":"招2","hit_ids":["zh2"],"branch_label":"招2_HIT","source_profile":"sasuke_susanoo","input_name":"上方向技","note":"命中後の追撃を確認。ガードでも原作の派生は出ますが、この課題は実際の命中が必要です。"},
	"chicken":{"command":"sweep","key_slot":4,"modifiers":[3],"entry_label":"砍技1","hit_ids":["kj1"],"branch_label":"砍技1_CHK","source_profile":"naruto","input_name":"下方向攻撃","note":"接近すると追撃へ移行。追撃の実際の命中が必要で、ガードでは成功しません。"}
}
var route: Dictionary={}
var stage:=0
var status:="ready"
var message:=""
var moves: Array[String]=[]
var serials: Array[int]=[]
var pending_serial:=-1
var origin_serial:=-1
var last_contact_serial:=-1
var completed_serial:=-1

static func _proof(id: String,label: String,method: String,target: String="") -> Dictionary:
	var actor: Dictionary=Timeline.profile(id).get("actor",{})
	for event: Dictionary in actor.get("events",[]):
		for call: Dictionary in event.get("calls",[]):
			if call.get("method","")!=method: continue
			var args: Array=call.get("arguments",[])
			if not target.is_empty() and not target in args: continue
			var frame: int=int(event.get("frame",0))
			if not label.is_empty():
				var definition: Dictionary=Timeline.definition(id,label)
				var start: int=int(definition.get("source_start_frame",0))
				if frame<start or frame>=start+int(definition.get("frame_count",1)): continue
			return {"file":event.get("source_file",""),"line":event.get("source_line",0),"method":method,"frame":frame}
	if method=="setAttack" and target=="砍1": return {"file":"swf_source/#FighterTester/src/net/play5d/game/obvn/fighter/ctrler/FighterMcCtrler.as","line":287,"method":"setAttack","default_label":"砍1"}
	return {"file":actor.get("source_file",""),"line":0,"label":label}

## Only children actually declared by this accepted actor action are eligible.
## Spawn frame and registration remain source data; no combat rule is changed.
static func _normal_children(id: String,label: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var profile: Dictionary=Timeline.profile(id)
	for event: Dictionary in Timeline.definition(id,label).get("events",[]):
		for call: Dictionary in event.get("calls",[]):
			if not bool(call.get("supported",false)) or call.get("method","")!="addAttacker": continue
			var args: Array=call.get("arguments",[])
			if args.is_empty() or not args[0] is String: continue
			var birth: int=int(event.get("source_frame",-1))
			for instance: Dictionary in profile.get("actor",{}).get("instances",[]):
				if instance.get("instance_name","")!=args[0] or birth<int(instance.get("source_start",0)) or birth>=int(instance.get("source_end",0)): continue
				var symbol: String=str(instance.get("source_symbol",instance.get("library","")))
				var child: Dictionary=profile.get("children",{}).get(symbol,{})
				var names: Array[String]=[]
				for area: Dictionary in child.get("areas",[]):
					var hit_id: String=str(area.get("hit_id",""))
					if area.get("kind","")=="hit" and not hit_id.is_empty() and hit_id not in names: names.append(hit_id)
				if not names.is_empty(): result.append({"name":str(args[0]),"symbol":symbol,"birth":birth,"hit_ids":names,"source_file":child.get("source_file","")})
	return result

static func _normal_step(id: String,ordinal: int) -> Dictionary:
	var label: String=str(Timeline.profile(id).get("command_labels",{}).get("attack%d" % ordinal,""))
	var hit_ids: Array[String]=[]
	for area: Dictionary in Timeline.definition(id,label).get("areas",[]):
		var hit_id: String=str(area.get("hit_id",""))
		if area.get("kind","")=="hit" and not hit_id.is_empty() and not hit_id in hit_ids: hit_ids.append(hit_id)
	return {"id":"J%d" % ordinal,"kind":"hit","command":"attack%d" % ordinal,"key_slot":4,"modifiers":[],"entry_label":label,"hit_ids":hit_ids,"children":_normal_children(id,label),"branch_label":"","condition":"許可された次の通常攻撃を出し、相手に命中させる","source":_proof(id,"","setAttack",label)}

static func descriptor(id: String,recipe: String) -> Dictionary:
	if not recipe in COURSE_IDS: return {}
	var profile: Dictionary=Timeline.profile(id)
	if profile.is_empty(): return {}
	var result: Dictionary={"id":id,"recipe":recipe,"source_profile":profile.get("id",""),"steps":[],"completion":"","note":"","name":""}
	if recipe=="full_normal":
		var ordinal:=1
		while profile.get("command_labels",{}).has("attack%d" % ordinal):
			result["steps"].append(_normal_step(id,ordinal)); ordinal+=1
		result["name"]="通常攻撃・全段"
		result["completion"]="全段の命中成功！ 次の許可を見てつなげました"
		result["note"]="キャラクターごとの全段を命中させる課題です。全状況での確定コンボではありません。"
	elif id=="shark":
		result["steps"]=[_normal_step(id,1),_normal_step(id,2),{"id":"U","kind":"hit","command":"skill1","key_slot":7,"modifiers":[],"entry_label":"招1","hit_ids":["zh1"],"branch_label":"","condition":"二段目の命中を見て、技の許可中に入力して命中させる","source":_proof(id,"砍2","setZhao1")}]
		result["name"]="命中を見て技へ"
		result["completion"]="命中確認成功！ 二段目から技へつなげました"
		result["note"]="通常攻撃二段目の命中を見て技へ。空振りでも技の入力は可能ですが、この課題は命中が必要です。"
	else:
		var definition: Dictionary=CONFIRMS.get(id,{})
		if definition.is_empty(): return {}
		var step: Dictionary=definition.duplicate(true)
		var branch_hit: bool=id=="chicken" or bool(step.get("branch_hit",false))
		step["id"]="confirm_hit"; step["kind"]="branch_hit" if branch_hit else "hit"
		step["condition"]="接近追撃が相手に命中する" if branch_hit else "最初の一撃を相手に命中させる"
		step["source"]=_proof(id,step["entry_label"],"setHitTarget" if branch_hit else "justHitToPlay",step["branch_label"])
		result["steps"].append(step)
		if not branch_hit: result["steps"].append({"id":"source_branch","kind":"branch","command":"observe","key_slot":-1,"modifiers":[],"entry_label":step["entry_label"],"hit_ids":step["hit_ids"].duplicate(),"branch_label":step["branch_label"],"condition":"実際の命中後、同じ攻撃が自動追撃へ移行する","source":step["source"].duplicate()})
		result["name"]="命中を見て追撃"
		result["completion"]="命中確認成功！ 追撃への移行を確認しました"
		result["note"]=step["note"]
	result["total"]=result["steps"].size()
	return result

func configure(id: String,recipe: String) -> void:
	route=descriptor(id,recipe); stage=0; status="ready"; moves.clear(); serials.clear()
	pending_serial=-1; origin_serial=-1; last_contact_serial=-1; completed_serial=-1; message=""

func progress() -> Dictionary:
	return {"recipe":route.get("recipe",""),"stage":stage,"total":route.get("total",0),"status":status,"message":message,"steps":route.get("steps",[]).duplicate(true),"completion":route.get("completion",""),"source_profile":route.get("source_profile",""),"moves":moves.duplicate(),"serials":serials.duplicate(),"pending_serial":pending_serial,"completed_serial":completed_serial,"note":route.get("note","")}

func _update(text: String,success: bool=false) -> Dictionary:
	message=text
	return {"changed":true,"message":message,"success":success}

func _fail(text: String) -> Dictionary:
	status="failed"
	return _update(text)

func observe_action(move: String,label: String,serial: int) -> Dictionary:
	if route.is_empty(): return {}
	var steps: Array=route["steps"]
	var first: Dictionary=steps[0]
	# Source range-check branches can restart doAction with a fresh serial. Only
	# their declared continuation is eligible; no stale owner/object is accepted.
	if status=="running" and stage<steps.size() and steps[stage]["kind"]=="branch_hit" and label==steps[stage]["branch_label"]:
		pending_serial=serial; return {}
	if label==first["entry_label"] and move==first["command"]:
		stage=0; status="running"; moves.clear(); serials.clear(); pending_serial=serial; origin_serial=serial; last_contact_serial=-1; completed_serial=-1
		return _update("命中を確認しよう・ガードと空振りは成功になりません")
	if status=="running" and stage<steps.size():
		var next: Dictionary=steps[stage]
		if next["kind"]!="branch" and label==next["entry_label"] and move==next["command"]:
			pending_serial=serial
			return _update("%d/%d 命中済み・次の命中を確認" % [stage,steps.size()])
		return _fail("順番が違います・Rでリセット")
	return {}

## Independent hits may outlive an owner action. Teaching credits only the
## declared child of this same player and still-current accepted action, never
## the owner's new label, an enemy instance or an older spawn.
func _accepted_child(source: Dictionary,actor: Dictionary,next: Dictionary) -> bool:
	if source.get("source_type","")!="attacker": return false
	var birth: Dictionary=source.get("teaching_origin",{})
	var serial: int=int(source.get("serial",-1))
	if serial!=pending_serial or int(actor.get("serial",-1))!=pending_serial or int(birth.get("serial",-1))!=pending_serial: return false
	# Battle's lessons belong to P1; enemy contacts never enter this observer.
	if int(birth.get("owner_index",-1))!=0: return false
	if birth.get("action","")!=next["command"] or birth.get("label","")!=next["entry_label"]: return false
	var profile: String=str(route.get("source_profile",""))
	if source.get("source_profile_id","")!=profile or birth.get("donor_profile_id","")!=profile: return false
	var object_id: int=int(source.get("source_object_instance_id",0))
	if object_id==0: return false
	var object: Variant=instance_from_id(object_id)
	if not is_instance_valid(object) or object.get("owner_index")!=0 or bool(object.get("removed")): return false
	var world: Variant=object.get("world")
	if not is_instance_valid(world) or object not in world.get("objects"): return false
	var owner: Variant=object.get("owner")
	if not is_instance_valid(owner) or int(owner.get("action_serial"))!=pending_serial or str(owner.get("fighter_id"))!=str(route.get("id","")): return false
	if int(object.get("source_origin_serial"))!=pending_serial or str(object.get("source_profile_id"))!=profile: return false
	if str(object.get("source_origin_action"))!=next["command"] or str(object.get("source_origin_label"))!=next["entry_label"]: return false
	var symbol: String=str(object.get("child").get("source_symbol",""))
	for declaration: Dictionary in next.get("children",[]):
		if str(object.get("name"))!=declaration["name"] or symbol!=declaration["symbol"]: continue
		if int(birth.get("source_frame",-1))!=int(declaration["birth"]) or int(object.get("teaching_origin").get("source_frame",-1))!=int(declaration["birth"]): continue
		if str(source.get("source_name","")) in declaration["hit_ids"]: return true
	return false

func observe_contact(source: Dictionary,result: Dictionary,actor: Dictionary) -> Dictionary:
	if status!="running" or stage>=int(route.get("total",0)): return {}
	var serial: int=int(source.get("serial",-1))
	if serial!=pending_serial or serial==last_contact_serial: return {}
	var next: Dictionary=route["steps"][stage]
	if next["kind"]=="branch": return {}
	if source.get("source_type","fighter")!="fighter" or not source.get("teaching_origin",{}).is_empty():
		if not _accepted_child(source,actor,next): return {}
	else:
		if str(source.get("source_name","")) not in next["hit_ids"]: return {}
		var required_label: String=next["branch_label"] if next["kind"]=="branch_hit" else next["entry_label"]
		if str(source.get("source_label",""))!=required_label: return {}
	last_contact_serial=serial
	if result.get("blocked",false) or result.get("armor",false): return _fail("ガード・耐えられました。命中確認は不成立です・Rでリセット")
	if not result.get("hit",false) or float(result.get("damage",0))<=0: return _fail("命中を確認できません・Rでリセット")
	moves.append(next["command"]); serials.append(serial); stage+=1
	if stage==route["total"]:
		status="complete"; completed_serial=serial
		return _update(route["completion"],true)
	return _update("%d/%d 命中確認・%s" % [stage,route["total"],"追加入力なしで追撃を待とう" if route["steps"][stage]["kind"]=="branch" else "次の許可中に入力しよう"])

func observe_frame(actor: Dictionary) -> Dictionary:
	if status!="running" or stage>=int(route.get("total",0)): return {}
	var next: Dictionary=route["steps"][stage]
	if next["kind"]=="branch" and int(actor.get("serial",-1))==pending_serial and str(actor.get("label",""))==next["branch_label"] and not serials.is_empty():
		moves.append("source_branch"); serials.append(pending_serial); stage+=1; status="complete"; completed_serial=pending_serial
		return _update(route["completion"],true)
	if str(actor.get("state","")) in ["hurt","juggle","launch","slam","down","getup","ko"]: return _fail("攻撃が中断されました・Rでリセット")
	if int(actor.get("serial",-1))==pending_serial and not bool(actor.get("doing_action",false)):
		return _fail("命中・接続を確認できません。間合いと次の許可を見直そう・Rでリセット")
	return {}
