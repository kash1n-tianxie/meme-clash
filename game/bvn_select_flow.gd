# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2021-2026, 5DPLAY Game Studio.
# ActionScript algorithms translated and adapted to Godot on 2026-10-08.
# Upstream: 5DPLAY-Game-Studio/BleachVsNaruto
# Commit: 891f5776dbdf3cbf40919e27aa8d6e77a5f66c97
# Original authors include 5DPLAY Game Studio / weijian.
# This program is free software under GPL version 3 or, at your option, any later version.
# It is provided WITHOUT ANY WARRANTY; see LICENSE-BVN.txt for the complete license.
# See BVN_SELECT_PORT.md for exact source files/lines and the Godot-only adaptations.
extends RefCounted

const UPSTREAM_COMMIT := "891f5776dbdf3cbf40919e27aa8d6e77a5f66c97"
# SelectFlowAction.as:29-43. Keep the upstream numeric action values.
const NONE := 0
const INIT_FIGHTER := 1
const ENABLE_P2_WITH_P1_INPUT := 2
const FADOUT_ASSIST := 3
const FADOUT_MAP := 4
const START_ARCADE := 5
const START_MUSOU := 6
const SELECT_FINISH := 7

var mode := "cpu"
var roster: Array[String] = []
var selected: Array[String] = ["", ""]
var select_times: Array[int] = [0, 0]
var enabled: Array[bool] = [true, false]
var active_player := 0
var current_step := 0
var _both_finished := false
var _submitted := false
var _generation := 0
var _serial := 0
var _pending: Dictionary = {}
var _history: Array[Dictionary] = []

# VsCpuSelectFlow.as:31-47 / VsPeopleSelectFlow.as:31-47.
func create_p2_select_vo() -> bool:
	return true

func init_both_selecters() -> bool:
	return mode == "local"

func should_wait_both_players() -> bool:
	return mode == "local"

# Direct translation of VsCpuSelectFlow.as:52-67 and VsPeopleSelectFlow.as:52-63.
# The table includes the original assist and map phases, even though this game
# explicitly skips those unavailable phases in its one-fighter adapter below.
static func resolve_next_step(selection_mode: String, step: int) -> Dictionary:
	if selection_mode == "local":
		match step:
			0: return {"action": INIT_FIGHTER, "next_step": 1}
			1: return {"action": FADOUT_ASSIST, "next_step": 3}
			3: return {"action": FADOUT_MAP, "next_step": 5}
			5: return {"action": SELECT_FINISH, "next_step": -1}
	else:
		match step:
			0: return {"action": INIT_FIGHTER, "next_step": 1}
			1: return {"action": ENABLE_P2_WITH_P1_INPUT, "next_step": 2}
			2: return {"action": FADOUT_ASSIST, "next_step": 3}
			3: return {"action": ENABLE_P2_WITH_P1_INPUT, "next_step": 4}
			4: return {"action": FADOUT_MAP, "next_step": 5}
			5: return {"action": SELECT_FINISH, "next_step": -1}
	return {"action": NONE, "next_step": -1}

func reset(selection_mode: String, ids: Array, first: String = "", second: String = "") -> void:
	mode = selection_mode if selection_mode in ["cpu", "local", "training"] else "cpu"
	roster.assign(ids)
	_generation += 1
	_pending.clear()
	_history.clear()
	current_step = 0
	select_times.assign([0, 0])
	enabled.assign([true, init_both_selecters()])
	selected.assign([first if roster.has(first) else str(roster[0]) if not roster.is_empty() else "", second if roster.has(second) else str(roster[-1]) if not roster.is_empty() else ""])
	active_player = 0
	_both_finished = false
	_submitted = false
	_advance()

# SelecterItemUI.as:60-61, specialized to the current game's one fighter per side.
func select_finish(player: int) -> bool:
	return player in [0, 1] and select_times[player] >= 1

# SelectFighterListCtrl.as:490-505: pointer confirmation prioritizes enabled P1,
# then enabled P2. Explicit P2 keyboard input can select independently in local mode.
func pointer_player() -> int:
	if enabled[0]:
		return 0
	if enabled[1]:
		return 1
	return -1

func preview(id: String, player: int = -1, reopen: bool = false) -> bool:
	if player < 0:
		player = pointer_player()
	if player not in [0, 1] or not roster.has(id) or not _pending.is_empty() or _submitted:
		return false
	if reopen and player == 1 and select_finish(0) and select_finish(1):
		_reopen_opponent()
	if not enabled[player]:
		return false
	selected[player] = id
	active_player = player
	return true

# SelecterItemUI.as:149-172: commit slot, increment count, disable selector.
# The caller acknowledges the Godot animation's completion using this ticket.
func begin_confirmation(id: String, player: int = -1) -> Dictionary:
	if player < 0:
		player = pointer_player()
	if player not in [0, 1] or not enabled[player] or not _pending.is_empty() or _submitted or not roster.has(id):
		return {}
	var previous := selected[player]
	selected[player] = id
	select_times[player] += 1
	enabled[player] = false
	_serial += 1
	_pending = {"serial": _serial, "generation": _generation, "player": player, "previous": previous}
	return _pending.duplicate()

# SelecterItemUI.as:180-186 and SelectFighterStage.as:527-544.
# Flash addFrameScript is replaced by an explicit completion callback; the ready
# gate and its one-shot _twoPlayerSelectFin equivalent are translated here.
func complete_confirmation(ticket: Dictionary) -> bool:
	if _pending.is_empty() or ticket.get("serial", -1) != _pending.serial or ticket.get("generation", -1) != _generation:
		return false
	var player := int(_pending.player)
	_pending.clear()
	if select_finish(player):
		if should_wait_both_players():
			var other := 1 - player
			if select_finish(other) and not _both_finished:
				_both_finished = true
				_advance()
				_skip_unavailable_phases()
			else:
				active_player = other
		else:
			_advance()
			if player == 1:
				_skip_unavailable_phases()
	else:
		enabled[player] = true
	return true

func cancel_pending() -> void:
	if not _pending.is_empty():
		var player := int(_pending.player)
		selected[player] = str(_pending.previous)
		select_times[player] = maxi(select_times[player] - 1, 0)
		enabled[player] = true
	_pending.clear()
	_generation += 1

func cancel_selection() -> void:
	reset(mode, roster.duplicate(), selected[0], selected[1])

func is_ready() -> bool:
	return select_finish(0) and select_finish(1) and current_step == 5 and _pending.is_empty() and not _submitted

func consume_start() -> Dictionary:
	if not is_ready():
		return {}
	_submitted = true
	var action := _advance()
	return {"p1": selected[0], "p2": selected[1], "mode": mode, "action": int(action.action)}

func snapshot() -> Dictionary:
	return {"mode": mode, "p1": selected[0], "p2": selected[1], "p1_locked": select_finish(0), "p2_locked": select_finish(1), "enabled": enabled.duplicate(), "active_player": active_player, "step": current_step, "ready": is_ready(), "confirming": not _pending.is_empty(), "submitted": _submitted, "history": _history.duplicate(true), "upstream_commit": UPSTREAM_COMMIT}

func _advance(skipped: bool = false, reason: String = "") -> Dictionary:
	# SelectFighterStage.as:204-207: only non-negative nextStep changes the step.
	var action := resolve_next_step(mode, current_step)
	var previous := current_step
	if int(action.next_step) >= 0:
		current_step = int(action.next_step)
	_history.append({"from_step": previous, "action": int(action.action), "step": current_step, "skipped": skipped, "reason": reason})
	if int(action.action) == ENABLE_P2_WITH_P1_INPUT and not skipped:
		enabled[1] = true
		active_player = 1
	return action

func _skip_unavailable_phases() -> void:
	# Godot adaptation: this game has no assist roster or map-picker yet. Preserve
	# and record every original action, but keep the existing explicit Start button.
	# The selected default stage is supplied by the unchanged match setup.
	while current_step < 5:
		_advance(true, "no_assist_slot" if current_step < 4 else "default_stage")
	active_player = 1

func _reopen_opponent() -> void:
	select_times[1] = 0
	enabled[1] = true
	_both_finished = false
	current_step = 1 if should_wait_both_players() else 2
	active_player = 1

# SelectFighterCursorCtrl.as:412-436: nearest item in a sparse row visits
# x, x+1, x-1, x+2, x-2. Bounded iteration avoids recursive all-empty grids.
static func _nearest_in_row(start_x: int, row: int, count: int, columns: int, blocked: Array) -> int:
	var k := 0
	for _attempt: int in range(columns * 2 + 1):
		var x := start_x + k
		var index := row * columns + x
		if x >= 0 and x < columns and index < count and not blocked.has(index):
			return index
		if k == 0:
			k = 1
		elif k > 0:
			k *= -1
		else:
			k = -k + 1
	return -1

# SelectFighterCursorCtrl.as:56-151: wrap an out-of-grid cursor, skip unavailable
# horizontal cells and pick the nearest column when a destination row is sparse.
static func grid_neighbor(index: int, direction: Vector2i, count: int, columns: int = 3, blocked: Array = []) -> int:
	if count <= 0 or columns <= 0:
		return -1
	index = clampi(index, 0, count - 1)
	var row := index / columns
	var column := index % columns
	if direction.x != 0:
		for offset: int in range(1, columns + 1):
			var x := posmod(column + signi(direction.x) * offset, columns)
			var candidate := row * columns + x
			if candidate < count and not blocked.has(candidate):
				return candidate
	elif direction.y != 0:
		var row_count := ceili(float(count) / float(columns))
		for offset: int in range(1, row_count + 1):
			var target_row := posmod(row + signi(direction.y) * offset, row_count)
			var candidate := _nearest_in_row(column, target_row, count, columns, blocked)
			if candidate >= 0:
				return candidate
	return index
