extends RefCounted
## Copyright (C) 2021-2024 5DPLAY Game Studio; Godot adaptation (C) 2026.
## SPDX-License-Identifier: GPL-3.0-or-later
## OpenBleachVsNaruto 4d7bc9913ec6b609ba521ff86b6066bff134a736.
## Executes extracted MovieClip frame scripts in their original order. Unknown
## conditions are deliberately not truthy. Battle supplies target-dependent IR.

const SETTERS := {
	"setJump":["jump","跳"], "setJumpQuick":["jumpQuick","跳"],
	"setJumpDown":["jumpDown","落"], "setDash":["dash","瞬步"],
	"setAttack":["attack","砍1"], "setSkill1":["skill1","砍技1"],
	"setSkill2":["skill2","砍技2"], "setZhao1":["zhao1","招1"],
	"setZhao2":["zhao2","招2"], "setZhao3":["zhao3","招3"],
	"setCatch1":["catch1","摔1"], "setCatch2":["catch2","摔2"],
	"setBisha":["bisha","必杀",100], "setBishaUP":["bishaUP","上必杀",100],
	"setBishaSUPER":["bishaSUPER","超必杀",300],
	"setAttackAIR":["attackAIR","跳砍"], "setSkillAIR":["skillAIR","跳招"],
	"setBishaAIR":["bishaAIR","空中必杀",100], "setTouchFloor":["touchFloor","落地",true]
}
const GROUND_SETTERS := ["setMove","setDefense","setJump","setJumpDown","setDash","setAttack","setSkill1","setSkill2","setZhao1","setZhao2","setZhao3","setCatch1","setCatch2","setBisha","setBishaUP","setBishaSUPER","setWankai"]
const AIR_SETTERS := ["setDash","setAttackAIR","setSkillAIR","setBishaAIR"]

## A frame event may redirect the actor synchronously. Never continue executing
## an obsolete frame after idle()/goFrame()/doAction(), even inside a sequence.
static func execute_event(actor: Variant, event: Dictionary) -> void:
	var generation: int=actor.source_generation
	var context: Dictionary={"locals":{},"returned":false,"generation":generation}
	if bool(event.get("blocked",false)):
		actor.source_note_unsupported(event,"blocked extraction")
		return
	var ast: Variant=event.get("ast",null)
	if ast is Dictionary and not ast.is_empty():
		_execute_node(actor,ast,event,context)
	else:
		for call: Dictionary in event.get("calls",[]):
			if actor.source_generation!=generation: break
			_execute_call(actor,call,event,context)

static func _execute_node(actor: Variant,node: Dictionary,event: Dictionary,context: Dictionary) -> void:
	if context["returned"] or actor.source_generation!=int(context["generation"]): return
	match str(node.get("kind","unsupported")):
		"sequence":
			for child: Variant in node.get("statements",node.get("children",node.get("body",[]))):
				if child is Dictionary: _execute_node(actor,child,event,context)
		"if":
			var value: Variant=_evaluate(actor,node.get("condition",node.get("test",{})),context)
			if value==null:
				actor.source_note_unsupported(node,"unresolved if")
				return
			var branch: Variant=node.get("then",node.get("consequent",{})) if bool(value) else node.get("else",node.get("alternate",{}))
			if branch is Dictionary: _execute_node(actor,branch,event,context)
			elif branch is Array:
				for child: Variant in branch:
					if child is Dictionary: _execute_node(actor,child,event,context)
		"return": context["returned"]=true
		"declare":
			var name: String=str(node.get("name",node.get("identifier","")))
			context["locals"][name]=_evaluate(actor,node.get("expression",node.get("value",node.get("initializer",null))),context)
		"assign":
			var name: String=str(node.get("name",node.get("target","")))
			var value: Variant=_evaluate(actor,node.get("expression",node.get("value",null)),context)
			if name.contains("."):
				_execute_call(actor,{"controller":"fighter","method":"assign","arguments":[name,value],"conditions":node.get("conditions",[]),"supported":node.get("supported",true)},event,context)
			else: context["locals"][name]=value
		"call": _execute_call(actor,node,event,context)
		"function_decl":
			# Callbacks are passed as IR to Battle, not executed at declaration time.
			context["locals"][str(node.get("name",""))]=node
		_:
			actor.source_note_unsupported(node,"unsupported script node")

static func _evaluate(actor: Variant,value: Variant,context: Dictionary) -> Variant:
	if value is Array:
		var values: Array=[]
		for item: Variant in value: values.append(_evaluate(actor,item,context))
		return values
	if not value is Dictionary: return value
	var node: Dictionary=value
	if not node.has("kind"):
		var literal_object: Dictionary={}
		for key: Variant in node: literal_object[key]=_evaluate(actor,node[key],context)
		return literal_object
	match str(node.get("kind","")):
		"literal": return node.get("value",null)
		"expression": return _evaluate(actor,node.get("expression",{}),context)
		"reference":
			var name: String=str(node.get("name",node.get("path","")))
			if context["locals"].has(name): return context["locals"][name]
		"unary":
			var operand: Variant=_evaluate(actor,node.get("operand",null),context)
			if operand==null: return null
			match str(node.get("operator","")):
				"!": return not bool(operand)
				"-": return -float(operand)
				"+": return float(operand)
		"binary":
			var left: Variant=_evaluate(actor,node.get("left",null),context)
			if left==null: return null
			var op: String=str(node.get("operator",""))
			if op=="&&" and not bool(left): return false
			if op=="||" and bool(left): return true
			var right: Variant=_evaluate(actor,node.get("right",null),context)
			if right==null: return null
			match op:
				"&&": return bool(left) and bool(right)
				"||": return bool(left) or bool(right)
				"==","===": return left==right
				"!=","!==": return left!=right
				"<": return left<right
				">": return left>right
				"<=": return left<=right
				">=": return left>=right
				"+": return left+right
				"-": return left-right
				"*": return left*right
				"/": return left/right if right!=0 else null
		"array":
			var result: Array=[]
			for item: Variant in node.get("items",node.get("elements",[])): result.append(_evaluate(actor,item,context))
			return result
	if actor.source_condition_resolver.is_valid(): return actor.source_condition_resolver.call(value,actor)
	return null

static func _execute_call(actor: Variant,call: Dictionary,event: Dictionary,context: Dictionary) -> void:
	if bool(call.get("blocked",false)) or not bool(call.get("supported",true)):
		actor.source_note_unsupported(call,"unsupported call")
		return
	for condition: Variant in call.get("conditions",[]):
		var expression: Variant=condition.get("expression",condition) if condition is Dictionary else condition
		var answer: Variant=_evaluate(actor,expression,context)
		if answer==null:
			actor.source_note_unsupported(call,"unresolved condition")
			return
		var accepted: bool=bool(answer)
		if condition is Dictionary and bool(condition.get("negated",false)): accepted=not accepted
		if not accepted: return
	var args: Array=[]
	for argument: Variant in call.get("arguments",call.get("args",[])):
		var resolved: Variant=_evaluate(actor,argument,context)
		if argument is Dictionary and argument.get("kind","")=="expression" and resolved==null:
			actor.source_note_unsupported(call,"unresolved argument")
			return
		args.append(resolved)
	var method: String=str(call.get("method",""))
	var controller: String=str(call.get("controller",""))
	if method=="moveTarget" and actor.has_method("source_end_act"): actor.source_move_target_active=not args.is_empty() and args[0]!=null
	if controller in ["$mc_ctrler","mc","mc_ctrler","_mc_ctrler"] and _local(actor,method,args): return
	if controller in ["$fighter_ctrler","fighter","fighter_ctrler","_fighter_ctrler"]:
		match method:
			"moveOnce":
				actor.position+=Vector2(float(_arg(args,0,0))*actor.facing,float(_arg(args,1,0)))*1.6
				return
			"setCross": actor.source_cross=bool(_arg(args,0,false)); return
	var forwarded: Dictionary=call.duplicate(true)
	forwarded["arguments"]=args
	forwarded["source_label"]=actor.source_label
	forwarded["source_frame"]=actor.source_frame
	forwarded["source_absolute_frame"]=actor.source_absolute_frame
	forwarded["action_serial"]=actor.action_serial
	forwarded["frame_event"]=event
	if actor.has_method("hits"): forwarded["source_object_instance_id"]=actor.get_instance_id()
	actor.source_event_requested.emit(forwarded)

static func _arg(args: Array,index: int,fallback: Variant) -> Variant:
	return args[index] if index<args.size() else fallback

## Local controller methods follow FighterMcCtrler.as:114-449 and 1069-1104.
## All velocities are converted once from source px/frame to world px/sec.
static func _local(actor: Variant,method: String,args: Array) -> bool:
	if SETTERS.has(method):
		var item: Array=SETTERS[method]
		actor.source_set_permission(str(item[0]),str(_arg(args,0,item[1])),_arg(args,1,item[2] if item.size()>2 else null))
		return true
	match method:
		"setAllAct":
			for setter: String in GROUND_SETTERS: _local(actor,setter,[])
		"setAirAllAct":
			for setter: String in AIR_SETTERS: _local(actor,setter,[])
			actor.source_permissions["airMove"]={"enabled":true}
		"setMove": _local(actor,"setMoveLeft",[]); _local(actor,"setMoveRight",[])
		"setMoveLeft": actor.source_set_permission("moveLEFT","走")
		"setMoveRight": actor.source_set_permission("moveRIGHT","走")
		"setDefense": actor.source_set_permission("defense","防御")
		"setAirMove": actor.source_permissions["airMove"]={"enabled":bool(_arg(args,0,false))}
		"setWankai":
			for pair: Array in [["wanKai","万解"],["wanKaiW","万解W"],["wanKaiS","万解S"]]: actor.source_set_permission(pair[0],pair[1],300)
		"setSteelBody": actor.source_steel=bool(_arg(args,0,false)); actor.source_super_steel=actor.source_steel and bool(_arg(args,1,false))
		"addQi": actor.hype=actor.BVNHit.add_qi(actor.hype,float(_arg(args,0,0)))
		"useQi":
			var cost: float=float(_arg(args,0,0))
			if actor.hype>=cost: actor.hype-=cost
		"setHurtAction": actor.source_hurt_action=str(_arg(args,0,"")); actor.source_runtime_state=16
		"setHitTarget": actor.source_hit_target={"checker":str(_arg(args,0,"")),"label":str(_arg(args,1,""))}
		"isApplyG": actor.bvn_apply_gravity=bool(_arg(args,0,true))
		"move","movePercent":
			var unit: float=actor.speed if method=="movePercent" else 48.0
			actor.velocity=Vector2(float(_arg(args,0,0))*actor.facing,float(_arg(args,1,0)))*unit
			if not actor.grounded and actor.velocity.x!=0: actor.source_permissions.erase("airMove")
		"stopMove": actor.velocity=Vector2.ZERO
		"hurtFly": actor.source_hurt_fly(float(_arg(args,0,0)),float(_arg(args,1,0)))
		"damping","dampingPercent":
			actor.bvn_damping=Vector2(float(_arg(args,0,0)),float(_arg(args,1,0)))*(actor.source_speed if method=="dampingPercent" else 1.0)
		"endAct": actor.source_end_act()
		"idle": actor.source_idle(str(_arg(args,0,"站立")))
		"loop","gotoAndPlay": actor.source_branch(str(_arg(args,0,"")))
		"gotoAndStop":
			actor.source_branch(str(_arg(args,0,"")))
			actor.source_playing=false
		"stop": actor.source_playing=false
		"dash":
			actor.velocity=Vector2(actor.speed*float(_arg(args,0,3))*actor.facing,0)
			actor.bvn_damping=Vector2.ZERO; actor.source_cross=true; actor.source_allow_be_hit=false
		"dashStop":
			actor.bvn_damping.x=absf(actor.velocity.x/48.0)*float(_arg(args,0,.5))
			actor.source_allow_be_hit=true; actor.source_cross=false; actor.source_runtime_state=0; actor.source_permissions.clear()
		_: return false
	return true
