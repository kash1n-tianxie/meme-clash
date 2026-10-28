extends RefCounted
## Observe accepted inputs and real contacts. Never inject HP/Qi/hits/branches.
var route: Dictionary={}
var stage:=0
var status:="ready"
var message:=""
var moves: Array[String]=[]
var pending_serial:=-1
var completed_serial:=-1
var seen_hits: Dictionary={}

static func descriptor(id: String,recipe: String) -> Dictionary:
	if recipe!="hit_confirm": return {}
	var command: String="super_down" if id=="rio" else "super"
	var names: Dictionary={"rio":"大剣、暴走します！","cat":"コメント欄ねこパンチ","worker":"定時です","chicken":"ひとりアリウープ","shark":"ワン、ツー、トララ！"}
	var note: String="最初の一撃を当てて追撃を確認。ガードと空振りでは追撃しません。"
	if id=="worker": note="Iで構えて正面の打撃を待つ。練習相手がJで攻撃。反撃が成立した時だけ追撃。"
	if id=="chicken": note="ボールを持ってI。離れている間は回収を待とう。命中時だけダンクへ。"
	return {"recipe":recipe,"id":id,"name":"命中からの派生","source_profile":"authored-v0.20","total":2,"note":note,"completion":"実際の命中と追撃を確認！","steps":[{"id":"entry","kind":"hit","command":command,"key_slot":8,"modifiers":[3] if id=="rio" else [],"condition":names.get(id,"必殺")+"を成立させる"},{"id":"follow","kind":"branch","command":"observe","key_slot":-1,"modifiers":[],"condition":"追撃が相手に命中する"}]}

func configure(id: String,recipe: String) -> void:
	route=descriptor(id,recipe); stage=0; status="ready"; message=""; moves.clear(); seen_hits.clear(); pending_serial=-1; completed_serial=-1

func progress() -> Dictionary:
	return {"recipe":route.get("recipe",""),"stage":stage,"total":2,"status":status,"message":message,"steps":route.get("steps",[]),"completion":route.get("completion",""),"source_profile":"authored-v0.20","moves":moves.duplicate(),"pending_serial":pending_serial,"completed_serial":completed_serial,"note":route.get("note","")}

func _update(value: String,success: bool=false) -> Dictionary:
	message=value; return {"message":value,"success":success,"changed":true}

func observe_action(move: String,_label: String,serial: int) -> Dictionary:
	if route.is_empty(): return {}
	if move==route["steps"][0]["command"]:
		stage=0; status="running"; pending_serial=serial; seen_hits.clear(); moves.clear()
		return _update("正面の攻撃を待とう" if route["id"]=="worker" else "最初の一撃を命中させよう")
	return {}

func observe_contact(source: Dictionary,result: Dictionary,_actor: Dictionary) -> Dictionary:
	if status!="running" or not source.get("authored_hit",false) or int(source.get("serial",-2))!=pending_serial: return {}
	var hit_id: String=str(source.get("source_name",""))
	if seen_hits.has(hit_id): return {}
	seen_hits[hit_id]=true
	if result.get("blocked",false) or result.get("armor",false):
		status="failed"; return _update("ガード・耐えられました。Rで再挑戦")
	if not result.get("hit",false) or float(result.get("damage",0))<=0: return {}
	stage+=1; moves.append(str(source.get("move","")))
	if stage>=2:
		status="complete"; completed_serial=pending_serial; return _update(route["completion"],true)
	return _update("命中を確認・実際の追撃を待とう")

func observe_frame(actor: Dictionary) -> Dictionary:
	if status!="running": return {}
	if str(actor.get("state","")) in ["hurt","juggle","launch","slam","down","getup","ko"]:
		status="failed"; return _update("攻撃が中断されました。Rで再挑戦")
	if int(actor.get("serial",-2))==pending_serial and not bool(actor.get("doing_action",false)):
		status="failed"; return _update("空振り・反撃不成立。Rで再挑戦")
	return {}
