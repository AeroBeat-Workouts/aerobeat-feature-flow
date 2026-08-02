class_name FlowModeRunner
extends "res://addons/aerobeat-mode-core/src/interfaces/mode_runner.gd"

const ModeDescriptor := preload("res://addons/aerobeat-mode-core/src/data_types/mode_descriptor.gd")
const ModeJudgementEvent := preload("res://addons/aerobeat-mode-core/src/data_types/mode_judgement_event.gd")
const ModeRunConfig := preload("res://addons/aerobeat-mode-core/src/data_types/mode_run_config.gd")
const ModeRunFragment := preload("res://addons/aerobeat-mode-core/src/data_types/mode_run_fragment.gd")
const ModeScoreDelta := preload("res://addons/aerobeat-mode-core/src/data_types/mode_score_delta.gd")
const ModeTickFrame := preload("res://addons/aerobeat-mode-core/src/data_types/mode_tick_frame.gd")

const MODE_ID := "flow"
const CHART_CONTRACT := "aerobeat.flow.chart.v1"
const BODY_CELL_INPUT_CONTRACT := "aerobeat.input.body_cell.v1"
const FLOW_INPUT_CONTRACT := "aerobeat.input.flow.v1"

const DEFAULT_EARLY_WINDOW_SEC := 0.18
const DEFAULT_LATE_WINDOW_SEC := 0.18
const DEFAULT_HIT_SCORE := 100
const DEFAULT_GOOD_SCORE := 70
const DEFAULT_AVOID_SCORE := 100

const WRIST_EVENTS := [
	"left_wrist_cell_entered",
	"right_wrist_cell_entered"
]

const BODY_CELL_EVENTS := [
	"left_wrist_cell_entered",
	"right_wrist_cell_entered",
	"nose_cell_entered"
]

const FLOW_TRANSITION_EVENTS := [
	"squat_enabled",
	"squat_disabled"
]

const FLOW_OBJECT_TYPES := [
	"note",
	"burst",
	"bomb",
	"obstacle",
	"arc",
	"squat"
]

var _mode_id := MODE_ID
var _targets: Array[Dictionary] = []
var _target_ids := {}
var _started := false
var _completed := false
var _completion_emitted := false
var _score := 0
var _combo := 0
var _max_combo := 0
var _hits := 0
var _misses := 0

func get_descriptor() -> ModeDescriptor:
	return ModeDescriptor.new({
		"mode_id": MODE_ID,
		"display_name": "AeroBeat Flow",
		"display_key": "mode.flow.display_name",
		"supported_chart_contracts": [CHART_CONTRACT],
		"supported_input_contracts": [BODY_CELL_INPUT_CONTRACT, FLOW_INPUT_CONTRACT],
		"metadata": {
			"body_cell_events": BODY_CELL_EVENTS.duplicate(),
			"flow_transition_events": FLOW_TRANSITION_EVENTS.duplicate(),
			"flow_object_types": FLOW_OBJECT_TYPES.duplicate(),
			"direction_values": {
				"up": 0,
				"down": 1,
				"right": 2,
				"left": 3,
				"ambiguous": -1
			}
		}
	})

func start(config: ModeRunConfig) -> ModeRunFragment:
	_reset_state()
	_started = true
	if config != null and not config.mode_id.is_empty():
		_mode_id = config.mode_id
	if config != null:
		_load_targets(config.chart_data.get("targets", config.chart_data.get("beats", [])))
	return ModeRunFragment.new({
		"fragment_type": ModeRunFragment.TYPE_STARTED,
		"mode_id": _mode_id,
		"reason": "started",
		"summary": _summary()
	})

func tick(frame: ModeTickFrame) -> Array:
	if not _started or _completed:
		return []

	var outputs := []
	if frame != null:
		_load_targets(frame.chart_events)
		for input_event in frame.input_events:
			outputs.append_array(_judge_input(input_event))
		outputs.append_array(_judge_expired_targets(frame.position_sec))
		outputs.append_array(_judge_cleared_avoidance_targets(frame.position_sec))
		if _all_targets_judged():
			_completed = true

	if _completed and not _completion_emitted:
		_completion_emitted = true
		outputs.append(ModeRunFragment.new({
			"fragment_type": ModeRunFragment.TYPE_COMPLETED,
			"mode_id": _mode_id,
			"reason": "chart_complete",
			"summary": _summary()
		}))

	return outputs

func is_complete() -> bool:
	return _completed

func stop(reason: String = "") -> ModeRunFragment:
	if not _completed:
		_completed = true
	return ModeRunFragment.new({
		"fragment_type": ModeRunFragment.TYPE_STOPPED,
		"mode_id": _mode_id,
		"reason": reason,
		"summary": _summary()
	})

func _reset_state() -> void:
	_mode_id = MODE_ID
	_targets = []
	_target_ids = {}
	_started = false
	_completed = false
	_completion_emitted = false
	_score = 0
	_combo = 0
	_max_combo = 0
	_hits = 0
	_misses = 0

func _load_targets(raw_targets: Variant) -> void:
	if not raw_targets is Array:
		return
	for raw_target in raw_targets:
		if not raw_target is Dictionary:
			continue
		var target := _normalize_target(raw_target)
		if target.is_empty() or _target_ids.has(target.id):
			continue
		_targets.append(target)
		_target_ids[target.id] = true
	_targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.position_sec) < float(b.position_sec))

func _normalize_target(raw_target: Dictionary) -> Dictionary:
	var object_type := String(raw_target.get("object_type", raw_target.get("type", raw_target.get("event", "")))).strip_edges()
	match object_type:
		"note":
			return _normalize_wrist_target(raw_target, object_type, _placement_from(raw_target, "placement"), _direction_from(raw_target, "direction"), bool(raw_target.get("requiresDirection", raw_target.get("requires_direction", false))))
		"burst":
			return _normalize_wrist_target(raw_target, object_type, _placement_from(raw_target, "placement"), _direction_from(raw_target, "direction"), true)
		"arc":
			return _normalize_wrist_target(raw_target, object_type, _placement_from(raw_target, "startPlacement", "start_placement"), _direction_from(raw_target, "startDirection", "start_direction"), true)
		"bomb":
			return _normalize_avoidance_target(raw_target, object_type, "wrist")
		"obstacle":
			return _normalize_avoidance_target(raw_target, object_type, "nose")
		"squat", "squat_enabled", "squat_disabled":
			return _normalize_transition_target(raw_target, object_type)
		_:
			return {}

func _normalize_wrist_target(raw_target: Dictionary, object_type: String, placement: int, direction: int, requires_direction: bool) -> Dictionary:
	var hand := String(raw_target.get("hand", raw_target.get("side", ""))).strip_edges().to_lower()
	if hand != "left" and hand != "right":
		return {}
	if placement < 0 or placement > 11:
		return {}
	var position_sec := _position_from(raw_target)
	var id := _target_id(raw_target, "%s_%s_%d@%.3f" % [object_type, hand, placement, position_sec])
	var target := _base_target(raw_target, id, object_type, position_sec)
	target.merge({
		"event": "%s_wrist_cell_entered" % hand,
		"body_part": "%s_wrist" % hand,
		"placement": placement,
		"direction": direction,
		"requires_direction": requires_direction,
		"kind": "wrist_hit"
	}, true)
	return target

func _normalize_avoidance_target(raw_target: Dictionary, object_type: String, body_part: String) -> Dictionary:
	var position_sec := _position_from(raw_target)
	var end_sec := maxf(position_sec, float(raw_target.get("end_sec", raw_target.get("end_position_sec", raw_target.get("end", position_sec)))))
	var cells := _int_array(raw_target.get("cells", [raw_target.get("placement", -1)]))
	cells = cells.filter(func(cell: int) -> bool: return cell >= 0 and cell <= 11)
	if cells.is_empty():
		return {}
	var id := _target_id(raw_target, "%s_%s@%.3f" % [object_type, body_part, position_sec])
	var target := _base_target(raw_target, id, object_type, position_sec)
	target.merge({
		"event": "nose_cell_entered" if body_part == "nose" else "wrist_cell_entered",
		"body_part": body_part,
		"cells": cells,
		"end_sec": end_sec,
		"kind": "avoidance"
	}, true)
	return target

func _normalize_transition_target(raw_target: Dictionary, object_type: String) -> Dictionary:
	var event_name := String(raw_target.get("event", "")).strip_edges()
	if event_name.is_empty():
		event_name = object_type
	if not FLOW_TRANSITION_EVENTS.has(event_name):
		return {}
	var position_sec := _position_from(raw_target)
	var id := _target_id(raw_target, "%s@%.3f" % [event_name, position_sec])
	var target := _base_target(raw_target, id, "squat", position_sec)
	target.merge({
		"event": event_name,
		"body_part": "body",
		"kind": "transition"
	}, true)
	return target

func _base_target(raw_target: Dictionary, id: String, object_type: String, position_sec: float) -> Dictionary:
	return {
		"id": id,
		"object_type": object_type,
		"position_sec": position_sec,
		"early_window_sec": maxf(0.0, float(raw_target.get("early_window_sec", raw_target.get("window_before_sec", DEFAULT_EARLY_WINDOW_SEC)))),
		"late_window_sec": maxf(0.0, float(raw_target.get("late_window_sec", raw_target.get("window_after_sec", DEFAULT_LATE_WINDOW_SEC)))),
		"judged": false,
		"metadata": raw_target.get("metadata", {}).duplicate(true) if raw_target.get("metadata", {}) is Dictionary else {}
	}

func _judge_input(input_event: Dictionary) -> Array:
	var event_name := String(input_event.get("event", input_event.get("type", ""))).strip_edges()
	var input_position := float(input_event.get("position_sec", input_event.get("time_sec", input_event.get("time", 0.0))))
	if WRIST_EVENTS.has(event_name):
		return _judge_wrist_input(input_event, event_name, input_position)
	if event_name == "nose_cell_entered":
		return _judge_nose_input(input_event, input_position)
	if FLOW_TRANSITION_EVENTS.has(event_name):
		return _judge_transition_input(input_event, event_name, input_position)
	return []

func _judge_wrist_input(input_event: Dictionary, event_name: String, input_position: float) -> Array:
	var cell_direction := _cell_direction_args(input_event)
	if cell_direction.is_empty():
		return []

	var outputs := []
	for target in _targets:
		if bool(target.judged):
			continue
		if String(target.kind) == "avoidance" and String(target.body_part) == "wrist" and _position_inside(target, input_position) and target.cells.has(int(cell_direction.cell)):
			outputs.append_array(_apply_judgement(target.id, ModeJudgementEvent.RESULT_MISS, input_position, input_position - float(target.position_sec), 0.0, {"reason": "bomb_contact", "cell": int(cell_direction.cell), "direction": int(cell_direction.direction)}))
			continue
		if String(target.kind) != "wrist_hit" or target.event != event_name:
			continue
		if int(target.placement) != int(cell_direction.cell):
			continue
		outputs.append_array(_judge_timed_body_cell_target(target, input_position, int(cell_direction.direction)))
		break
	return outputs

func _judge_nose_input(input_event: Dictionary, input_position: float) -> Array:
	var cell_direction := _cell_direction_args(input_event)
	if cell_direction.is_empty():
		return []

	var outputs := []
	for target in _targets:
		if bool(target.judged):
			continue
		if String(target.kind) != "avoidance" or String(target.body_part) != "nose":
			continue
		if _position_inside(target, input_position) and target.cells.has(int(cell_direction.cell)):
			outputs.append_array(_apply_judgement(target.id, ModeJudgementEvent.RESULT_MISS, input_position, input_position - float(target.position_sec), 0.0, {"reason": "obstacle_contact", "cell": int(cell_direction.cell), "direction": int(cell_direction.direction)}))
	return outputs

func _judge_transition_input(input_event: Dictionary, event_name: String, input_position: float) -> Array:
	if not _is_no_arg_event(input_event):
		return []
	var target := _find_nearest_unjudged_transition_target(event_name, input_position)
	if target.is_empty():
		return []
	return _judge_timed_event_target(target, input_position, {})

func _judge_timed_body_cell_target(target: Dictionary, input_position: float, input_direction: int) -> Array:
	var extra_metadata := {
		"cell": int(target.placement),
		"input_direction": input_direction,
		"requires_direction": bool(target.requires_direction)
	}
	return _judge_timed_event_target(target, input_position, extra_metadata)

func _judge_timed_event_target(target: Dictionary, input_position: float, extra_metadata: Dictionary) -> Array:
	var offset := input_position - float(target.position_sec)
	var judgement := ModeJudgementEvent.RESULT_HIT
	if offset < -float(target.early_window_sec):
		judgement = ModeJudgementEvent.RESULT_EARLY
	elif offset > float(target.late_window_sec):
		judgement = ModeJudgementEvent.RESULT_LATE
	elif bool(target.get("requires_direction", false)):
		var input_direction := int(extra_metadata.get("input_direction", -1))
		if input_direction != int(target.direction):
			judgement = ModeJudgementEvent.RESULT_MISS
			extra_metadata["reason"] = "direction_mismatch"
	var accuracy := _accuracy_for(target, offset, judgement)
	return _apply_judgement(target.id, judgement, input_position, offset, accuracy, extra_metadata)

func _judge_expired_targets(position_sec: float) -> Array:
	var outputs := []
	for target in _targets:
		if bool(target.judged) or String(target.kind) == "avoidance":
			continue
		var miss_at := float(target.position_sec) + float(target.late_window_sec)
		if position_sec > miss_at:
			outputs.append_array(_apply_judgement(target.id, ModeJudgementEvent.RESULT_MISS, miss_at, float(target.late_window_sec), 0.0, {"reason": "expired"}))
	return outputs

func _judge_cleared_avoidance_targets(position_sec: float) -> Array:
	var outputs := []
	for target in _targets:
		if bool(target.judged) or String(target.kind) != "avoidance":
			continue
		var clear_at := float(target.end_sec)
		if position_sec > clear_at:
			outputs.append_array(_apply_judgement(target.id, ModeJudgementEvent.RESULT_HIT, clear_at, 0.0, 1.0, {"reason": "avoidance_clear"}))
	return outputs

func _apply_judgement(target_id: String, judgement: String, position_sec: float, offset_sec: float, accuracy: float, extra_metadata: Dictionary = {}) -> Array:
	var index := _target_index(target_id)
	if index < 0:
		return []
	var target := _targets[index]
	target.judged = true
	_targets[index] = target

	var hit := judgement == ModeJudgementEvent.RESULT_HIT
	var score_delta := 0
	var combo_delta := -_combo
	if hit:
		score_delta = DEFAULT_AVOID_SCORE if String(target.kind) == "avoidance" else (DEFAULT_HIT_SCORE if accuracy >= 0.999 else DEFAULT_GOOD_SCORE)
		combo_delta = 1
		_combo += 1
		_max_combo = maxi(_max_combo, _combo)
		_hits += 1
	else:
		_combo = 0
		_misses += 1
	_score += score_delta

	var metadata := {
		"object_type": target.object_type,
		"event": target.event,
		"body_part": target.body_part
	}
	metadata.merge(extra_metadata, true)
	var target_ref := _target_ref(target)
	var judgement_event := ModeJudgementEvent.new({
		"mode_id": _mode_id,
		"target_ref": target_ref,
		"position_sec": position_sec,
		"judgement": judgement,
		"timing_offset_sec": offset_sec,
		"accuracy": accuracy,
		"metadata": metadata
	})
	var score := ModeScoreDelta.new({
		"mode_id": _mode_id,
		"target_ref": target_ref,
		"position_sec": position_sec,
		"score_delta": score_delta,
		"combo_delta": combo_delta,
		"accuracy_delta": accuracy,
		"judgement": judgement,
		"metadata": metadata
	})
	return [judgement_event, score]

func _find_nearest_unjudged_transition_target(event_name: String, input_position: float) -> Dictionary:
	var best_index := -1
	var best_distance := INF
	for index in _targets.size():
		var target := _targets[index]
		if bool(target.judged) or String(target.kind) != "transition" or target.event != event_name:
			continue
		var distance: float = absf(input_position - float(target.position_sec))
		if distance < best_distance:
			best_index = index
			best_distance = distance
	if best_index < 0:
		return {}
	return _targets[best_index]

func _cell_direction_args(input_event: Dictionary) -> Dictionary:
	var args: Variant = input_event.get("args", [])
	if args is Array and args.size() >= 2:
		return {
			"cell": int(args[0]),
			"direction": int(args[1])
		}
	return {}

func _is_no_arg_event(input_event: Dictionary) -> bool:
	var args: Variant = input_event.get("args", [])
	return (not args is Array) or args.is_empty()

func _position_inside(target: Dictionary, position_sec: float) -> bool:
	return position_sec >= float(target.position_sec) and position_sec <= float(target.end_sec)

func _target_index(target_id: String) -> int:
	for index in _targets.size():
		if _targets[index].id == target_id:
			return index
	return -1

func _all_targets_judged() -> bool:
	return not _targets.is_empty() and _targets.all(func(target: Dictionary) -> bool: return bool(target.judged))

func _accuracy_for(target: Dictionary, offset_sec: float, judgement: String) -> float:
	if judgement != ModeJudgementEvent.RESULT_HIT:
		return 0.0
	if String(target.kind) == "avoidance":
		return 1.0
	var window := float(target.late_window_sec) if offset_sec >= 0.0 else float(target.early_window_sec)
	if window <= 0.0:
		return 1.0 if is_zero_approx(offset_sec) else 0.0
	return clampf(1.0 - (absf(offset_sec) / window), 0.0, 1.0)

func _target_ref(target: Dictionary) -> Dictionary:
	var result := {
		"id": target.id,
		"object_type": target.object_type,
		"position_sec": target.position_sec
	}
	if target.has("placement"):
		result["placement"] = target.placement
	if target.has("cells"):
		result["cells"] = target.cells.duplicate()
	return result

func _summary() -> Dictionary:
	return {
		"score": _score,
		"combo": _combo,
		"max_combo": _max_combo,
		"hits": _hits,
		"misses": _misses,
		"target_count": _targets.size(),
		"judged_count": _targets.filter(func(target: Dictionary) -> bool: return bool(target.judged)).size()
	}

func _position_from(raw_target: Dictionary) -> float:
	return float(raw_target.get("position_sec", raw_target.get("time_sec", raw_target.get("time", raw_target.get("beat", 0.0)))))

func _placement_from(raw_target: Dictionary, primary: String, fallback: String = "") -> int:
	if raw_target.has(primary):
		return int(raw_target[primary])
	if not fallback.is_empty() and raw_target.has(fallback):
		return int(raw_target[fallback])
	return int(raw_target.get("cell", -1))

func _direction_from(raw_target: Dictionary, primary: String, fallback: String = "") -> int:
	if raw_target.has(primary):
		return int(raw_target[primary])
	if not fallback.is_empty() and raw_target.has(fallback):
		return int(raw_target[fallback])
	return -1

func _target_id(raw_target: Dictionary, fallback: String) -> String:
	var id := String(raw_target.get("id", raw_target.get("target_id", ""))).strip_edges()
	return fallback if id.is_empty() else id

func _int_array(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if value is Array:
		for item in value:
			result.append(int(item))
	elif value is int:
		result.append(value)
	return result
