extends "res://addons/aerobeat-vendor-godot-unit-test/test.gd"

const FlowModeRunner := preload("res://addons/aerobeat-mode-flow/src/flow_mode_runner.gd")
const ModeDescriptor := preload("res://addons/aerobeat-mode-core/src/data_types/mode_descriptor.gd")
const ModeJudgementEvent := preload("res://addons/aerobeat-mode-core/src/data_types/mode_judgement_event.gd")
const ModeRunConfig := preload("res://addons/aerobeat-mode-core/src/data_types/mode_run_config.gd")
const ModeRunFragment := preload("res://addons/aerobeat-mode-core/src/data_types/mode_run_fragment.gd")
const ModeScoreDelta := preload("res://addons/aerobeat-mode-core/src/data_types/mode_score_delta.gd")
const ModeTickFrame := preload("res://addons/aerobeat-mode-core/src/data_types/mode_tick_frame.gd")

func test_descriptor_advertises_body_cell_and_flow_contracts() -> void:
	var descriptor: ModeDescriptor = FlowModeRunner.new().get_descriptor()

	assert_true(descriptor.is_valid())
	assert_eq(descriptor.mode_id, "flow")
	assert_has(descriptor.supported_input_contracts, "aerobeat.input.body_cell.v1")
	assert_has(descriptor.supported_input_contracts, "aerobeat.input.flow.v1")
	assert_has(descriptor.metadata.body_cell_events, "left_wrist_cell_entered")
	assert_has(descriptor.metadata.body_cell_events, "nose_cell_entered")

func test_left_and_right_wrist_notes_emit_mode_core_fragments() -> void:
	var runner := FlowModeRunner.new()
	runner.start(_config([
		_note("left_note", "left", 4, 1.0, false),
		_note("right_note", "right", 7, 2.0, false)
	]))

	var first := runner.tick(_frame(1.0, [_body_cell_input("left_wrist_cell_entered", 1.0, 4, -1)]))
	var second := runner.tick(_frame(2.0, [_body_cell_input("right_wrist_cell_entered", 2.0, 7, -1)]))

	assert_true(first[0] is ModeJudgementEvent)
	assert_true(first[1] is ModeScoreDelta)
	assert_eq(first[0].judgement, ModeJudgementEvent.RESULT_HIT)
	assert_eq(first[1].score_delta, 100)
	assert_eq(second[0].metadata.body_part, "right_wrist")
	assert_eq(second[1].combo_delta, 1)
	assert_true(second[2] is ModeRunFragment)
	assert_eq(second[2].fragment_type, ModeRunFragment.TYPE_COMPLETED)

func test_direction_required_note_rejects_wrong_direction() -> void:
	var runner := FlowModeRunner.new()
	runner.start(_config([
		_note("directional", "left", 6, 1.0, true, 3)
	]))

	var outputs := runner.tick(_frame(1.0, [_body_cell_input("left_wrist_cell_entered", 1.0, 6, 2)]))

	assert_eq(outputs[0].judgement, ModeJudgementEvent.RESULT_MISS)
	assert_eq(outputs[0].metadata.reason, "direction_mismatch")
	assert_eq(outputs[1].score_delta, 0)
	assert_eq(outputs[2].fragment_type, ModeRunFragment.TYPE_COMPLETED)

func test_directionless_note_accepts_ambiguous_direction() -> void:
	var runner := FlowModeRunner.new()
	runner.start(_config([
		_note("directionless", "right", 8, 1.0, false)
	]))

	var outputs := runner.tick(_frame(1.0, [_body_cell_input("right_wrist_cell_entered", 1.0, 8, -1)]))

	assert_eq(outputs[0].judgement, ModeJudgementEvent.RESULT_HIT)
	assert_eq(outputs[0].metadata.requires_direction, false)
	assert_eq(outputs[1].score_delta, 100)

func test_early_late_and_miss_use_timing_windows() -> void:
	var early_runner := FlowModeRunner.new()
	early_runner.start(_config([_note("early", "left", 1, 1.0, false)]))
	var early_outputs := early_runner.tick(_frame(0.70, [_body_cell_input("left_wrist_cell_entered", 0.70, 1, -1)]))

	var late_runner := FlowModeRunner.new()
	late_runner.start(_config([_note("late", "right", 2, 1.0, false)]))
	var late_outputs := late_runner.tick(_frame(1.25, [_body_cell_input("right_wrist_cell_entered", 1.25, 2, -1)]))

	var miss_runner := FlowModeRunner.new()
	miss_runner.start(_config([_note("miss", "left", 3, 1.0, false)]))
	var miss_outputs := miss_runner.tick(_frame(1.21, []))

	assert_eq(early_outputs[0].judgement, ModeJudgementEvent.RESULT_EARLY)
	assert_eq(late_outputs[0].judgement, ModeJudgementEvent.RESULT_LATE)
	assert_eq(miss_outputs[0].judgement, ModeJudgementEvent.RESULT_MISS)
	assert_eq(miss_outputs[0].metadata.reason, "expired")

func test_nose_obstacle_scores_clear_and_misses_contact() -> void:
	var clear_runner := FlowModeRunner.new()
	clear_runner.start(_config([
		_obstacle("clear", [4, 5, 8, 9], 1.0, 1.5)
	]))
	var clear_outputs := clear_runner.tick(_frame(1.51, [_body_cell_input("nose_cell_entered", 1.20, 0, -1)]))

	var contact_runner := FlowModeRunner.new()
	contact_runner.start(_config([
		_obstacle("contact", [4, 5, 8, 9], 1.0, 1.5)
	]))
	var contact_outputs := contact_runner.tick(_frame(1.2, [_body_cell_input("nose_cell_entered", 1.2, 5, -1)]))

	assert_eq(clear_outputs[0].judgement, ModeJudgementEvent.RESULT_HIT)
	assert_eq(clear_outputs[0].metadata.reason, "avoidance_clear")
	assert_eq(clear_outputs[1].score_delta, 100)
	assert_eq(contact_outputs[0].judgement, ModeJudgementEvent.RESULT_MISS)
	assert_eq(contact_outputs[0].metadata.reason, "obstacle_contact")

func test_squat_transitions_use_flow_input_surface() -> void:
	var runner := FlowModeRunner.new()
	runner.start(_config([
		_squat("down", "squat_enabled", 1.0),
		_squat("up", "squat_disabled", 2.0)
	]))

	var first := runner.tick(_frame(1.0, [_flow_input("squat_enabled", 1.0)]))
	var second := runner.tick(_frame(2.0, [_flow_input("squat_disabled", 2.0)]))

	assert_eq(first[0].judgement, ModeJudgementEvent.RESULT_HIT)
	assert_eq(second[0].judgement, ModeJudgementEvent.RESULT_HIT)
	assert_eq(second[2].summary.max_combo, 2)

func test_burst_arc_and_bomb_retain_flow_content_semantics_without_extra_input_events() -> void:
	var runner := FlowModeRunner.new()
	runner.start(_config([
		_burst("burst", "left", 1, 3, 1.0),
		_arc("arc", "right", 2, 0, 2.0),
		_bomb("bomb", [6], 3.0, 3.2)
	]))

	var first := runner.tick(_frame(1.0, [_body_cell_input("left_wrist_cell_entered", 1.0, 1, 3)]))
	var second := runner.tick(_frame(2.0, [_body_cell_input("right_wrist_cell_entered", 2.0, 2, 0)]))
	var third := runner.tick(_frame(3.21, []))

	assert_eq(first[0].metadata.object_type, "burst")
	assert_eq(second[0].metadata.object_type, "arc")
	assert_eq(third[0].metadata.object_type, "bomb")
	assert_eq(third[0].metadata.reason, "avoidance_clear")
	assert_eq(third[2].fragment_type, ModeRunFragment.TYPE_COMPLETED)

func test_cell_inputs_without_two_args_are_ignored() -> void:
	var runner := FlowModeRunner.new()
	runner.start(_config([_note("ignored", "left", 4, 1.0, false)]))

	var ignored := runner.tick(_frame(1.0, [{
		"contract": "aerobeat.input.body_cell.v1",
		"event": "left_wrist_cell_entered",
		"position_sec": 1.0,
		"args": [4]
	}]))
	var miss := runner.tick(_frame(1.21, []))

	assert_eq(ignored.size(), 0)
	assert_eq(miss[0].judgement, ModeJudgementEvent.RESULT_MISS)

func _config(targets: Array) -> ModeRunConfig:
	return ModeRunConfig.new({
		"mode_id": "flow",
		"chart_id": "fixture_chart",
		"chart_data": {
			"beats": targets
		}
	})

func _note(id: String, hand: String, placement: int, position_sec: float, requires_direction: bool, direction: int = -1) -> Dictionary:
	var note := _base_target(id, "note", position_sec)
	note.merge({
		"hand": hand,
		"placement": placement,
		"requiresDirection": requires_direction
	}, true)
	if requires_direction:
		note["direction"] = direction
	return note

func _burst(id: String, hand: String, placement: int, direction: int, position_sec: float) -> Dictionary:
	var burst := _base_target(id, "burst", position_sec)
	burst.merge({
		"hand": hand,
		"placement": placement,
		"direction": direction,
		"tailPlacement": placement + 1,
		"checkpointCount": 1,
		"end": position_sec + 0.25
	}, true)
	return burst

func _arc(id: String, hand: String, placement: int, direction: int, position_sec: float) -> Dictionary:
	var arc := _base_target(id, "arc", position_sec)
	arc.merge({
		"hand": hand,
		"startPlacement": placement,
		"endPlacement": placement + 1,
		"startDirection": direction,
		"endDirection": direction,
		"end": position_sec + 0.25
	}, true)
	return arc

func _bomb(id: String, cells: Array, position_sec: float, end_sec: float) -> Dictionary:
	var bomb := _base_target(id, "bomb", position_sec)
	bomb.merge({
		"cells": cells,
		"end": end_sec
	}, true)
	return bomb

func _obstacle(id: String, cells: Array, position_sec: float, end_sec: float) -> Dictionary:
	var obstacle := _base_target(id, "obstacle", position_sec)
	obstacle.merge({
		"cells": cells,
		"end": end_sec
	}, true)
	return obstacle

func _squat(id: String, event_name: String, position_sec: float) -> Dictionary:
	var squat := _base_target(id, "squat", position_sec)
	squat["event"] = event_name
	return squat

func _base_target(id: String, type: String, position_sec: float) -> Dictionary:
	return {
		"id": id,
		"type": type,
		"position_sec": position_sec,
		"early_window_sec": 0.18,
		"late_window_sec": 0.18
	}

func _body_cell_input(event_name: String, position_sec: float, cell: int, direction: int) -> Dictionary:
	return {
		"contract": "aerobeat.input.body_cell.v1",
		"event": event_name,
		"position_sec": position_sec,
		"args": [cell, direction]
	}

func _flow_input(event_name: String, position_sec: float) -> Dictionary:
	return {
		"contract": "aerobeat.input.flow.v1",
		"event": event_name,
		"position_sec": position_sec,
		"args": []
	}

func _frame(position_sec: float, inputs: Array) -> ModeTickFrame:
	return ModeTickFrame.new({
		"position_sec": position_sec,
		"delta_sec": 0.1,
		"input_events": inputs
	})
