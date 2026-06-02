class_name ImscScriptPlayer
extends RefCounted

signal on_start()
signal on_end()
signal on_node_before_enter(node_info: Dictionary)
signal on_node_evaluated(resume: Callable, inputs: Dictionary, options_inputs: Array, node_info: Dictionary)
signal on_node_enter(inputs: Dictionary, options_inputs: Array, node_info: Dictionary)
signal on_node_exit(node_info: Dictionary)
signal on_speech(speech: ImscScriptSpeech, node_info: Dictionary)
signal on_choice(option_index: int, node_info: Dictionary)
signal on_action(resume: Callable, action_type: String, subject: String, inputs: Dictionary, node_info: Dictionary)
signal on_variable_change(variable: String, new_value, old_value, frame_index: int)
signal on_error(error_message: String)
signal on_state_change(state: Dictionary)
signal on_load_script(resume: Callable, script_id: String)
signal on_sub_script_enter(frame: ImscScriptFrame)
signal on_sub_script_exit(frame: ImscScriptFrame)

signal _resume_triggered
signal _play_finished

var _frames: Array[ImscScriptFrame] = []
var _global_variables: Dictionary = {}
var _play_epoch: int = 0
var _paused: bool = false
var _custom_node_handlers: Dictionary = {}
var _resume_data = null
var _callscript_pending: Dictionary = {}

var is_running = false

var is_paused: bool:
	get:
		return is_running and _paused

var current_frame: ImscScriptFrame:
	get:
		return _frames[0] if _frames.size() > 0 else null

var frames: Array[ImscScriptFrame]:
	get:
		return _frames

var current_node_id:
	get:
		var f = current_frame
		if f == null:
			return null
		return f.current_node.id if f.current_node != null else null

var current_node:
	get:
		var f = current_frame
		if f == null or f.current_node == null:
			return null
		if f.graph.has("nodes") and f.graph.nodes.has(f.current_node.id):
			return f.graph.nodes[f.current_node.id]
		return null

var variables: Dictionary:
	get:
		var f = current_frame
		if f == null:
			return {}
		return f.variables

var globals: Dictionary:
	get:
		return _global_variables


func _init(graph: Dictionary, script_id: String = ""):
	var root_frame = _create_frame(
		script_id,
		graph,
		{}
	)
	_frames.push_front(root_frame)


func init_variables(vars: Dictionary):
	var frame = current_frame
	if frame == null:
		return
	var own_vars = frame.graph.get("variables", {}).get("own", {})
	for key in vars:
		if own_vars.has(key) and own_vars[key].get("kind", "global") == "global":
			_global_variables[key] = vars[key]
		else:
			frame.variables[key] = vars[key]


func _create_frame(script_id, graph: Dictionary, initial_vars: Dictionary) -> ImscScriptFrame:
	var frame = ImscScriptFrame.new(graph, script_id)
	var own_vars = graph.get("variables", {}).get("own", {})
	for varname in own_vars:
		var vardef = own_vars[varname]
		var kind = vardef.get("kind", "global")
		if kind == "global":
			if initial_vars.has(varname):
				_global_variables[varname] = initial_vars[varname]
			elif not _global_variables.has(varname):
				_global_variables[varname] = vardef.get("default", null)
		else:
			if initial_vars.has(varname):
				frame.variables[varname] = initial_vars[varname]
			elif vardef.has("default"):
				frame.variables[varname] = vardef.default
	return frame


func play(start_node_id = null):
	if is_running:
		end()
	_play_epoch += 1
	var play_epoch = _play_epoch
	_paused = false
	var node_id = start_node_id if start_node_id != null else current_frame.graph.get("start")
	if node_id == null or not current_frame.graph.nodes.has(node_id):
		_raise_error("Start node \"%s\" not found in graph" % node_id)
		return
		
	is_running = true
	on_start.emit()
	_enter_node(node_id, play_epoch)

	if not is_running:
		return # player already stopped
		
	await _play_finished


func resume():
	if not is_running or not _paused:
		return
	_paused = false
	_play_epoch += 1
	_process_current_node(_play_epoch)


func pause():
	_paused = true


func advance(option_index = null, resume_after = false):
	if not is_running or current_frame.current_node == null:
		return
	var cn = current_frame.current_node
	var node = current_frame.graph.nodes[cn.id]

	if resume_after:
		_paused = false

	if node.type == "speech":
		var next_id = null
		if option_index == null:
			if node.has("next") and node.next != null:
				next_id = node.next
			else:
				if not node.has("options") or node.options.size() == 0:
					return
				option_index = 0
		if option_index != null:
			if option_index < 0 or not node.has("options") or option_index >= node.options.size():
				return
			var chosen = node.options[option_index]
			on_choice.emit(option_index, {"node": node, "node_id": cn.id})
			next_id = chosen.next if chosen.has("next") else null
		goto(next_id)
	else:
		_process_current_node(_play_epoch)


func goto(node_id):
	if not is_running:
		return
	_exit_current_node()
	if node_id == null:
		_end_frame()
		return
	if not current_frame.graph.nodes.has(node_id):
		_raise_error("Node \"%s\" not found" % node_id)
		return
	_play_epoch += 1
	_enter_node(node_id, _play_epoch)


func end():
	if not is_running:
		return
	_exit_current_node()
	on_end.emit()
	is_running = false
	_play_finished.emit()


func set_variable(key: String, value, frame_index: int = 0):
	if frame_index >= _frames.size():
		return
	var frame = _frames[frame_index]
	var old = frame.variables.get(key, null)
	var own_vars = frame.graph.get("variables", {}).get("own", {})
	if own_vars.has(key):
		var vardef = own_vars[key]
		var kind = vardef.get("kind", "global")
		if kind == "global":
			_global_variables[key] = value
		else:
			frame.variables[key] = value
	else:
		frame.variables[key] = value

	on_variable_change.emit(key, value, old, frame_index)
	_emit_state_change()


func get_variable(key: String, frame_index: int = 0):
	if frame_index >= _frames.size():
		return null
	var frame = _frames[frame_index]
	if frame.variables.has(key):
		return frame.variables[key]
	var own_vars = frame.graph.get("variables", {}).get("own", {})
	if not own_vars.has(key) or own_vars[key].get("kind", "global") == "global":
		return _global_variables.get(key, null)
	return null


func _emit_state_change():
	if get_signal_connection_list("on_state_change").size() > 0:
		on_state_change.emit(serialize())


func serialize() -> Dictionary:
	var frame_list = []
	for f in _frames:
		frame_list.append({
			"script_id": f.script_id,
			"graph": f.graph,
			"current_node": f.current_node.duplicate() if f.current_node != null else null,
			"variables": f.variables.duplicate(),
			"node_outputs": f.node_outputs.duplicate(),
		})
	return {
		"frames": frame_list,
		"globals": _global_variables.duplicate()
	}


func load_state(state: Dictionary):
	if state.frames.size() == 0:
		push_error("No frames")
		return
	var first_node = state.frames[0].get("current_node")
	if first_node != null and not state.frames[0].graph.nodes.has(first_node.id):
		push_error("Cannot restore: node \"%s\" not found" % first_node.id)
		return
	pause()
	_frames = []
	for f in state.frames:
		var frame = ImscScriptFrame.new(f.graph, f.get("script_id"))
		frame.current_node = f.current_node.duplicate() if f.current_node != null else null
		frame.node_outputs = f.node_outputs.duplicate() if f.has("node_outputs") else {}
		frame.variables = f.variables.duplicate() if f.has("variables") else {}
		_frames.append(frame)
	_global_variables = state.globals.duplicate() if state.has("globals") else {}
	_paused = true
	_emit_state_change()


func inspect_graph(callback: Callable, start_node_id = null):
	var to_visit: Array = []
	var visited: Dictionary = {}
	if start_node_id != null:
		to_visit.push_back(start_node_id)
	elif current_frame.graph.has("start") and current_frame.graph.start != null:
		to_visit.push_back(current_frame.graph.start)
	while to_visit.size() > 0:
		var node_id = to_visit.pop_front()
		if node_id == null or visited.has(node_id):
			continue
		var node = current_frame.graph.nodes.get(node_id)
		if node == null:
			continue
		visited[node_id] = true
		var res = callback.call({"node": node, "node_id": node_id})
		if typeof(res) == TYPE_BOOL and not res:
			continue
		elif typeof(res) == TYPE_ARRAY:
			for nid in res:
				to_visit.push_back(nid)
		else:
			if node.has("next") and node.next != null:
				to_visit.push_back(node.next)
			if node.has("options") and node.options != null:
				for opt in node.options:
					if opt.has("next") and opt.next != null:
						to_visit.push_back(opt.next)


func register_custom_node(type_name: String, kind: String, handler: Callable):
	_custom_node_handlers[type_name] = {"kind": kind, "handler": handler}


func _process_current_node(play_epoch: int):
	var evaluated_node = current_frame.current_node
	if evaluated_node == null:
		return
	var node_id = evaluated_node.id
	var graph_node = current_frame.graph.nodes.get(node_id)
	if graph_node == null:
		return
	var node_type = graph_node.type

	match node_type:
		"start":
			goto(graph_node.next)

		"speech":
			_handle_speech_node(node_id, graph_node, evaluated_node.inputs, evaluated_node.options_inputs)

		"branch":
			var next_id = _handle_branch_node(node_id, graph_node, evaluated_node.inputs)
			goto(next_id)

		"setVar":
			_handle_set_var_node(node_id, graph_node, evaluated_node.inputs)
			goto(graph_node.next)

		"trigger":
			var resumed = _emit_trigger_and_get_resumed(node_id, graph_node, evaluated_node.inputs)
			if not resumed and get_signal_connection_list("on_action").size() > 0:
				await _resume_triggered
			if play_epoch != _play_epoch:
				return
			goto(_resolve_trigger_next(node_id, graph_node))

		"end":
			_end_frame()

		"callScript":
			var callscript_next = _handle_call_script_node(node_id, graph_node, evaluated_node.inputs)
			if callscript_next is Signal:
				await callscript_next
				callscript_next = _finish_call_script(node_id, graph_node, evaluated_node.inputs)
			if play_epoch != _play_epoch:
				return
			goto(callscript_next)

		_:
			if _custom_node_handlers.has(node_type):
				var custom = _custom_node_handlers[node_type]
				if custom.kind == "exec":
					var result = await custom.handler.call({
						"inputs": evaluated_node.inputs,
						"node": graph_node,
						"nodeId": node_id
					})
					if play_epoch != _play_epoch:
						return
					current_frame.node_outputs[node_id] = result.get("outputs", {}) if typeof(result) == TYPE_DICTIONARY else {}
					var next_id = graph_node.next
					if typeof(result) == TYPE_DICTIONARY and result.has("next"):
						next_id = result.next if result.next != null else next_id
					goto(next_id)
				else:
					push_error("Unexpected node type \"%s\" in flow" % node_type)
			else:
				push_error("Unexpected node type \"%s\" in flow" % node_type)


func _enter_node(node_id: String, play_epoch: int):
	if not is_running or play_epoch != _play_epoch:
		return
	var node = current_frame.graph.nodes.get(node_id) if current_frame.graph.nodes.has(node_id) else null
	if node == null:
		end()
		return

	on_node_before_enter.emit({"node": node, "node_id": node_id})
	if play_epoch != _play_epoch:
		return

	var vals = node.get("values", {})
	var options = node.get("options", [])
	var inputs = await _evaluate_vals(vals)
	var options_inputs = []
	for i in options.size():
		options_inputs.push_back(await _evaluate_vals(options[i].get("values", {})))

	var evaluator_resume = func(result):
		_resume_data = result
		_resume_triggered.emit()
	if get_signal_connection_list("on_node_evaluated").size() > 0:
		_resume_data = null
		on_node_evaluated.emit(evaluator_resume, inputs, options_inputs, {"node": node, "node_id": node_id})
		if _resume_data == null:
			await _resume_triggered
	if _resume_data != null:
		if typeof(_resume_data) == TYPE_DICTIONARY:
			if _resume_data.has("inputs"):
				inputs = _resume_data.inputs
			if _resume_data.has("options_inputs"):
				options_inputs = _resume_data.options_inputs

	if current_frame.current_node != null:
		return
	if play_epoch != _play_epoch:
		return

	current_frame.current_node = {
		"id": node_id,
		"subject": node.get("subject", null),
		"inputs": inputs,
		"options_inputs": options_inputs
	}
	_emit_state_change()
	on_node_enter.emit(inputs, options_inputs, {"node": node, "node_id": node_id})
	if _paused:
		return
	await _process_current_node(play_epoch)


func _exit_current_node():
	var node_info = current_frame.current_node
	if node_info == null:
		return
	var node = current_frame.graph.nodes.get(node_info.id)
	on_node_exit.emit({"node": node, "node_id": node_info.id})
	current_frame.current_node = null
	_emit_state_change()


func _end_frame():
	if _frames.size() > 1:
		var left_frame = _frames.pop_front()
		var node = current_frame.current_node
		var call_script_node = null
		if node != null:
			call_script_node = current_frame.graph.nodes.get(node.id)
		if call_script_node == null or not call_script_node.has("next") or call_script_node.next == null:
			end()
			return
		if current_frame.current_node != null:
			var outputs = {}
			var own_vars = left_frame.graph.get("variables", {}).get("own", {})
			for varname in own_vars:
				var kind = own_vars[varname].get("kind")
				if kind == "out" or kind == "in-out":
					outputs[varname] = left_frame.variables.get(varname, null)
			current_frame.node_outputs[current_frame.current_node.id] = outputs
		_emit_state_change()
		on_sub_script_exit.emit(left_frame)
		goto(call_script_node.next)
	else:
		end()


func _handle_speech_node(node_id: String, node: Dictionary, inputs: Dictionary, options_inputs: Array):
	var speech = ImscScriptSpeech.new(inputs)
	if inputs.has("character") and inputs.character != null:
		var asset = ImscScriptProps.cast_asset_prop_value_to_asset(inputs.character)
		if asset != null:
			speech.character = asset.get("Title", "")
		else:
			speech.character = ImscScriptProps.cast_asset_prop_value_to_string(inputs.character)
	if inputs.has("text") and inputs.text != null:
		speech.text = ImscScriptProps.cast_asset_prop_value_to_string(inputs.text)

	if node.has("options") and node.options.size() > 0:
		for i in node.options.size():
			var opt = node.options[i]
			var opt_vals = options_inputs[i] if i < options_inputs.size() else {}
			var opt_entry = ImscScriptSpeechOption.new(
				i,
				opt_vals,
				ImscScriptProps.cast_asset_prop_value_to_boolean(opt_vals.get("condition")) if opt_vals.has("condition") else null,
				ImscScriptProps.cast_asset_prop_value_to_string(opt_vals.get("text")) if opt_vals.has("text") else null,
				opt.next if opt.has("next") else null
			)
			speech.options.append(opt_entry)

	on_speech.emit(speech, {"node": node, "node_id": node_id})


func _handle_branch_node(_node_id: String, node: Dictionary, inputs: Dictionary):
	var condition = ImscScriptProps.cast_asset_prop_value_to_boolean(inputs.get("condition"))
	var chosen = node.options[0] if condition else node.options[1]
	return chosen.next if chosen.has("next") else null


func _handle_set_var_node(_node_id: String, node: Dictionary, inputs: Dictionary):
	var variable = ImscScriptProps.cast_asset_prop_value_to_string(inputs.get("variable"))
	set_variable(variable, inputs.get("value"))


func _emit_trigger_and_get_resumed(node_id: String, node: Dictionary, inputs: Dictionary) -> bool:
	_resume_data = null
	var resume = func(result):
		_resume_data = result
		_resume_triggered.emit()
	if get_signal_connection_list("on_action").size() > 0:
		on_action.emit(resume, "trigger", node.subject, inputs, {"node": node, "node_id": node_id})
	return _resume_data != null


func _resolve_trigger_next(node_id: String, node: Dictionary):
	if _resume_data != null and typeof(_resume_data) == TYPE_DICTIONARY:
		current_frame.node_outputs[node_id] = _resume_data.get("outputs", {})
		if _resume_data.has("next"):
			return _resume_data.next
	return node.get("next")


func _emit_function_and_get_resumed(node_id: String, node: Dictionary, inputs: Dictionary) -> bool:
	_resume_data = null
	var resume = func(result):
		_resume_data = result
		_resume_triggered.emit()
	if get_signal_connection_list("on_action").size() > 0:
		on_action.emit(resume, "function", node.subject, inputs, {"node": node, "node_id": node_id})
	return _resume_data != null


func _resolve_function_result(node_id: String, node: Dictionary) -> Dictionary:
	if _resume_data != null and typeof(_resume_data) == TYPE_DICTIONARY:
		return _resume_data.get("outputs", {})
	return {}


func _handle_call_script_node(node_id: String, node: Dictionary, inputs: Dictionary):
	var script_id = _extract_script_id(node)
	if script_id.is_empty():
		push_error("Subject of subscript call is not defined")
		return null
	_resume_data = null
	var resume = func(result):
		_resume_data = result
		_resume_triggered.emit()
	if get_signal_connection_list("on_load_script").size() > 0:
		on_load_script.emit(resume, script_id)
		if _resume_data == null:
			_callscript_pending = { "node_id": node_id, "script_id": script_id, "inputs": inputs }
			return _resume_triggered
	var loaded = _resume_data
	if loaded == null:
		push_error("Subscript is not found")
		return null
	return _create_script_subframe(node_id, script_id, inputs, loaded)


func _finish_call_script(node_id: String, node: Dictionary, inputs: Dictionary):
	var p = _callscript_pending
	_callscript_pending = {}
	var loaded = _resume_data
	if loaded == null:
		push_error("Subscript is not found")
		return null
	return _create_script_subframe(p.node_id, p.script_id, inputs, loaded)


func _extract_script_id(node: Dictionary) -> String:
	var subject_asset = ImscScriptProps.cast_asset_prop_value_to_asset(node.subject)
	if subject_asset != null:
		return subject_asset.AssetId
	return ImscScriptProps.cast_asset_prop_value_to_string(node.subject)


func _create_script_subframe(node_id: String, script_id: String, inputs: Dictionary, loaded: Dictionary):
	var initial = {}
	var own_vars = loaded.get("variables", {}).get("own", {})
	for varname in own_vars:
		var kind = own_vars[varname].get("kind")
		if kind == "in" or kind == "in-out":
			if inputs.has(varname):
				initial[varname] = inputs[varname]
	var sub_frame = _create_frame(script_id, loaded, initial)
	_frames.push_front(sub_frame)
	_emit_state_change()
	on_sub_script_enter.emit(sub_frame)
	return loaded.get("start")


func _evaluate_value(val, visited_pins = null):
	if typeof(val) == TYPE_DICTIONARY and val.has("get") and val.has("param"):
		var bind_node_id = val["get"]
		var bind_param = val["param"]
		if visited_pins == null:
			visited_pins = {}
		var pin_key = "%s-%s" % [bind_node_id, bind_param]
		if visited_pins.has(pin_key):
			push_error("Recursion detected")
			return null
		visited_pins[pin_key] = true
		var outputs = await _evaluate_node(bind_node_id, visited_pins)
		return outputs.get(bind_param, null)
	return val


func _evaluate_vals(vals: Dictionary) -> Dictionary:
	if vals.is_empty():
		return {}
	var result = {}
	for key in vals:
		result[key] = await _evaluate_value(vals[key])
	return result


func _evaluate_node(node_id: String, visited_pins = null) -> Dictionary:
	var node = current_frame.graph.nodes.get(node_id)
	if node == null:
		push_error("Node %s not found" % node_id)
		return {}

	var node_type = node.type
	match node_type:
		"constAsset", "constText", "constString", "constInteger", "constFloat", "constBoolean":
			return {"result": node.values.value}

		"getVar":
			var var_name = await _evaluate_value(node.values.variable)
			var val = get_variable(ImscScriptProps.cast_asset_prop_value_to_string(var_name))
			return {"result": val}

		"opAnd", "opOr", "opMod", "opDiv", "opMult", "opMinus", "opPlus", \
		"opMoreEqual", "opMore", "opLessEqual", "opLess", "opNotEqual", "opEqual":
			var arg1 = await _evaluate_value(node.values.arg1, visited_pins)
			var arg2 = await _evaluate_value(node.values.arg2, visited_pins)
			var result_val = null
			match node_type:
				"opAnd":
					result_val = bool(arg1) and bool(arg2)
				"opOr":
					result_val = bool(arg1) or bool(arg2)
				"opMod", "opDiv", "opMult", "opMinus", "opPlus":
					var a_num = ImscScriptProps.cast_asset_prop_value_to_float(arg1)
					var b_num = ImscScriptProps.cast_asset_prop_value_to_float(arg2)
					match node_type:
						"opMod":
							result_val = int(a_num) % int(b_num)
						"opDiv":
							if typeof(arg1) == TYPE_INT and typeof(arg2) == TYPE_INT:
								result_val = int(a_num) / int(b_num)
							else:
								result_val = a_num / b_num
						"opMult":
							result_val = a_num * b_num
						"opMinus":
							result_val = a_num - b_num
						"opPlus":
							result_val = a_num + b_num
				"opMoreEqual":
					result_val = ImscScriptProps.compare_asset_prop_values(arg1, arg2, true) >= 0
				"opMore":
					result_val = ImscScriptProps.compare_asset_prop_values(arg1, arg2, true) > 0
				"opLessEqual":
					result_val = ImscScriptProps.compare_asset_prop_values(arg1, arg2, true) <= 0
				"opLess":
					result_val = ImscScriptProps.compare_asset_prop_values(arg1, arg2, true) < 0
				"opNotEqual":
					result_val = ImscScriptProps.compare_asset_prop_values(arg1, arg2, true) != 0
				"opEqual":
					result_val = ImscScriptProps.compare_asset_prop_values(arg1, arg2, true) == 0
			return {"result": result_val}

		"opNot":
			var arg1 = await _evaluate_value(node.values.arg1, visited_pins)
			return {"result": not arg1}

		"callScript", "trigger":
			return current_frame.node_outputs.get(node_id, {}).duplicate()

		"function":
			var inputs = await _evaluate_vals(node.values)
			var resumed = _emit_function_and_get_resumed(node_id, node, inputs)
			if not resumed and get_signal_connection_list("on_action").size() > 0:
				await _resume_triggered
			return _resolve_function_result(node_id, node)

		_:
			if _custom_node_handlers.has(node_type):
				var custom = _custom_node_handlers[node_type]
				if custom.kind == "data":
					var inputs = await _evaluate_vals(node.get("values", {}))
					var result = await custom.handler.call({
						"inputs": inputs,
						"node": node,
						"nodeId": node_id
					})
					return result.get("outputs", {}) if typeof(result) == TYPE_DICTIONARY else {}
				else:
					return current_frame.node_outputs.get(node_id, {}).duplicate()
			return {}


func _raise_error(message: String):
	on_error.emit(message)
	_paused = true
