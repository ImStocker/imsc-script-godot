extends Node


var _passed: int = 0
var _failed: int = 0
var _errors: Array[String] = []


func _ready():
	await _run_all()
	print("\n========================================")
	print("Results: %d passed, %d failed" % [_passed, _failed])
	if _errors.size() > 0:
		for e in _errors:
			print("  FAIL: ", e)
	get_tree().quit(_failed)


func assert_eq(got, expected, msg: String):
	if got != expected:
		_fail("%s — expected %s, got %s" % [msg, expected, got])
	else:
		_pass(msg)


func assert_true(cond, msg: String):
	if not cond:
		_fail("%s — expected true" % msg)
	else:
		_pass(msg)


func assert_null(got, msg: String):
	if got != null:
		_fail("%s — expected null, got %s" % [msg, got])
	else:
		_pass(msg)


func _pass(name: String):
	_passed += 1
	print("  PASS: ", name)


func _fail(name: String):
	_failed += 1
	_errors.append(name)
	print("  FAIL: ", name)


func _run_all():
	var tests = [
		_test_simple_speech_graph_and_ends,
		_test_trigger_node_receives_outputs,
		_test_branch_node_follows_condition,
		_test_set_var_node_modifies_variable,
		_test_function_node_max_two_values,
		_test_call_script_subgraph_outputs,
		_test_call_script_globals,
		_test_custom_exec_node_handler_outputs,
		_test_custom_exec_node_next_override,
		_test_custom_data_node_in_expression,
	]
	for t in tests:
		print("TEST: ", t.get_method())
		await t.call()


# ---------------------------------------------------------------------------
# 1. Simple speech graph
# ---------------------------------------------------------------------------
func _test_simple_speech_graph_and_ends():
	var graph = {
		start = "hello",
		nodes = {
			hello = {
				type = "speech",
				values = { character = "NPC", text = "Hi!" },
				next = "end"
			},
			end = { type = "end" }
		}
	}

	var state = { speeches = [], ended = false }
	var player = ImscScriptPlayer.new(graph)
	player.on_speech.connect(func(s, _ni):
		state.speeches.append(s)
		player.advance()
	)
	player.on_end.connect(func():
		state.ended = true
	)
	await player.play()

	assert_eq(state.speeches.size(), 1, "[speech] speech count")
	assert_eq(state.speeches[0].character, "NPC", "[speech] character")
	assert_eq(state.speeches[0].text, "Hi!", "[speech] text")
	assert_true(state.ended, "[speech] ended")


# ---------------------------------------------------------------------------
# 2. Trigger node with on_action resume
# ---------------------------------------------------------------------------
func _test_trigger_node_receives_outputs():
	var graph = {
		start = "trg",
		nodes = {
			trg = {
				type = "trigger",
				subject = "test",
				values = {},
				next = "saveResult"
			},
			saveResult = {
				type = "setVar",
				values = { variable = "myResult", value = { get = "trg", param = "result" } },
				next = "end"
			},
			end = { type = "end" }
		}
	}

	var state = { subject = "" }
	var player = ImscScriptPlayer.new(graph)
	player.on_action.connect(func(resume, action_type, subject, _inputs, _ni):
		state.subject = subject
		resume.call({ outputs = { result = 42 } })
	)
	await player.play()

	assert_eq(state.subject, "test", "[trigger] subject")
	assert_eq(player.get_variable("myResult"), 42, "[trigger] output propagated")


# ---------------------------------------------------------------------------
# 3. Branch node with condition
# ---------------------------------------------------------------------------
func _test_branch_node_follows_condition():
	var graph = {
		start = "branch",
		variables = {
			own = {
				flag = {
					default = true,
					name = "flag",
					type = { Type = "boolean" }
				}
			}
		},
		nodes = {
			branch = {
				type = "branch",
				values = { condition = { get = "getFlag", param = "result" } },
				options = [{ next = "a" }, { next = "b" }]
			},
			getFlag = {
				type = "getVar",
				values = { variable = "flag" }
			},
			a = {
				type = "speech",
				values = { text = "A" },
				next = "end"
			},
			b = {
				type = "speech",
				values = { text = "B" },
				next = "end"
			},
			end = { type = "end" }
		}
	}

	var state = { texts = [], ended = false }
	var player = ImscScriptPlayer.new(graph)
	player.on_speech.connect(func(s, _ni):
		state.texts.append(s.text)
		player.advance()
	)
	player.on_end.connect(func():
		state.ended = true
	)
	await player.play()

	assert_eq(state.texts.size(), 1, "[branch] speech count")
	assert_eq(state.texts[0], "A", "[branch] speech text")
	assert_true(state.ended, "[branch] ended")


# ---------------------------------------------------------------------------
# 4. setVar node
# ---------------------------------------------------------------------------
func _test_set_var_node_modifies_variable():
	var graph = {
		start = "set",
		nodes = {
			set = {
				type = "setVar",
				values = { variable = "myVar", value = 99 },
				next = "end"
			},
			end = { type = "end" }
		}
	}

	var state = { ended = false }
	var player = ImscScriptPlayer.new(graph)
	player.init_variables({
		"myVar": 25
	})
	player.on_end.connect(func():
		state.ended = true
	)
	await player.play()

	assert_true(state.ended, "[setVar] ended")
	assert_eq(player.get_variable("myVar"), 99, "[setVar] value")


# ---------------------------------------------------------------------------
# 5. Function node — max of two values
# ---------------------------------------------------------------------------
func _test_function_node_max_two_values():
	var graph = {
		start = "setResult",
		nodes = {
			constA = {
				type = "constInteger",
				values = { value = 10 }
			},
			constB = {
				type = "constInteger",
				values = { value = 25 }
			},
			maxFunc = {
				type = "function",
				subject = "max",
				values = {
					a = { get = "constA", param = "result" },
					b = { get = "constB", param = "result" }
				}
			},
			setResult = {
				type = "setVar",
				values = {
					variable = "result",
					value = { get = "maxFunc", param = "result" }
				},
				next = "end"
			},
			end = { type = "end" }
		}
	}

	var state = { ended = false }
	var player = ImscScriptPlayer.new(graph)
	player.on_action.connect(func(resume, _type, _subject, inputs, _ni):
		resume.call({ outputs = { result = max(inputs.a, inputs.b) } })
	)
	player.on_end.connect(func():
		state.ended = true
	)
	await player.play()

	assert_true(state.ended, "[function] ended")
	assert_eq(player.get_variable("result"), 25, "[function] result")


# ---------------------------------------------------------------------------
# 6. callScript sub-graph
# ---------------------------------------------------------------------------
func _test_call_script_subgraph_outputs():
	var sub_graph = {
		start = "start",
		variables = {
			own = {
				a = { name = "a", type = { Type = "integer" }, kind = "in" },
				b = { name = "b", type = { Type = "integer" }, kind = "in" },
				sum = { name = "sum", type = { Type = "integer" }, kind = "out" }
			}
		},
		nodes = {
			start = { type = "start", next = "setSum" },
			getA = { type = "getVar", values = { variable = "a" } },
			getB = { type = "getVar", values = { variable = "b" } },
			add = {
				type = "opPlus",
				values = {
					arg1 = { get = "getA", param = "result" },
					arg2 = { get = "getB", param = "result" }
				}
			},
			setSum = {
				type = "setVar",
				values = { variable = "sum", value = { get = "add", param = "result" } },
				next = "end"
			},
			end = { type = "end" }
		}
	}

	var graph = {
		start = "callCalc",
		nodes = {
			callCalc = {
				type = "callScript",
				subject = "adder",
				values = { a = 5, b = 3 },
				next = "readResult"
			},
			readResult = {
				type = "setVar",
				values = { variable = "result", value = { get = "callCalc", param = "sum" } },
				next = "end"
			},
			end = { type = "end" }
		}
	}

	var state = { ended = false }
	var player = ImscScriptPlayer.new(graph)
	player.on_load_script.connect(func(resume, script_id):
		resume.call(sub_graph if script_id == "adder" else null)
	)
	player.on_end.connect(func():
		state.ended = true
	)
	await player.play()

	assert_true(state.ended, "[callScript] ended")
	assert_eq(player.get_variable("result"), 8, "[callScript] result")


# ---------------------------------------------------------------------------
# 7. callScript — globals across frames
# ---------------------------------------------------------------------------
func _test_call_script_globals():
	var sub_graph = {
		start = "start",
		variables = {
			own = {
				amount = { name = "amount", type = { Type = "integer" }, kind = "in" },
				counter = { name = "counter", type = { Type = "integer" }, kind = "global" }
			}
		},
		nodes = {
			start = { type = "start", next = "setCounter" },
			getCounter = { type = "getVar", values = { variable = "counter" } },
			getAmount = { type = "getVar", values = { variable = "amount" } },
			add = {
				type = "opPlus",
				values = {
					arg1 = { get = "getCounter", param = "result" },
					arg2 = { get = "getAmount", param = "result" }
				}
			},
			setCounter = {
				type = "setVar",
				values = { variable = "counter", value = { get = "add", param = "result" } },
				next = "end"
			},
			end = { type = "end" }
		}
	}

	var graph = {
		start = "callInc",
		variables = {
			own = {
				counter = { name = "counter", type = { Type = "integer" } },
				result = { name = "result", type = { Type = "integer" }, kind = "local" }
			}
		},
		nodes = {
			callInc = {
				type = "callScript",
				subject = "increment",
				values = { amount = 5 },
				next = "saveCounter"
			},
			getCounter = { type = "getVar", values = { variable = "counter" } },
			saveCounter = {
				type = "setVar",
				values = { variable = "result", value = { get = "getCounter", param = "result" } },
				next = "end"
			},
			end = { type = "end" }
		}
	}

	var state = { ended = false }
	var player = ImscScriptPlayer.new(graph)
	player.on_load_script.connect(func(resume, script_id):
		resume.call(sub_graph if script_id == "increment" else null)
	)
	player.on_end.connect(func():
		state.ended = true
	)
	await player.play()

	assert_true(state.ended, "[callScript-globals] ended")
	assert_eq(player.get_variable("counter"), 5, "[callScript-globals] counter")
	assert_eq(player.get_variable("result"), 5, "[callScript-globals] result")


# ---------------------------------------------------------------------------
# 8. Custom exec node — handler outputs
# ---------------------------------------------------------------------------
func _test_custom_exec_node_handler_outputs():
	var graph = {
		start = "greet",
		nodes = {
			greet = {
				type = "makeGreeting",
				next = "save",
				values = { name = "Alice" }
			},
			save = {
				type = "setVar",
				values = { variable = "result", value = { get = "greet", param = "greeting" } },
				next = "end"
			},
			end = { type = "end" }
		}
	}

	var state = { ended = false }
	var player = ImscScriptPlayer.new(graph)
	player.register_custom_node("makeGreeting", "exec", func(args):
		return { outputs = { greeting = "Hello, %s!" % args.inputs.name } }
	)
	player.on_end.connect(func():
		state.ended = true
	)
	await player.play()

	assert_true(state.ended, "[custom-exec] ended")
	assert_eq(player.get_variable("result"), "Hello, Alice!", "[custom-exec] result")


# ---------------------------------------------------------------------------
# 9. Custom exec node — next override
# ---------------------------------------------------------------------------
func _test_custom_exec_node_next_override():
	var graph = {
		start = "decide",
		nodes = {
			decide = {
				type = "route",
				next = "skipped",
				values = { goTo = "target" }
			},
			skipped = {
				type = "setVar",
				values = { variable = "result", value = "wrong" },
				next = "end"
			},
			target = {
				type = "setVar",
				values = { variable = "result", value = "correct" },
				next = "end"
			},
			end = { type = "end" }
		}
	}

	var state = { ended = false }
	var player = ImscScriptPlayer.new(graph)
	player.register_custom_node("route", "exec", func(args):
		return { next = args.inputs.goTo }
	)
	player.on_end.connect(func():
		state.ended = true
	)
	await player.play()

	assert_true(state.ended, "[custom-next] ended")
	assert_eq(player.get_variable("result"), "correct", "[custom-next] result")


# ---------------------------------------------------------------------------
# 10. Custom data node in expression
# ---------------------------------------------------------------------------
func _test_custom_data_node_in_expression():
	var graph = {
		start = "setResult",
		nodes = {
			double = {
				type = "doubleValue",
				values = { value = 21 }
			},
			setResult = {
				type = "setVar",
				values = { variable = "result", value = { get = "double", param = "result" } },
				next = "end"
			},
			end = { type = "end" }
		}
	}

	var state = { ended = false }
	var player = ImscScriptPlayer.new(graph)
	player.register_custom_node("doubleValue", "data", func(args):
		return { outputs = { result = args.inputs.value * 2 } }
	)
	player.on_end.connect(func():
		state.ended = true
	)
	await player.play()

	assert_true(state.ended, "[custom-data] ended")
	assert_eq(player.get_variable("result"), 42, "[custom-data] result")
