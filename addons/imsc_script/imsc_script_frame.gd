class_name ImscScriptFrame
extends RefCounted

var current_node
var script_id: String
var node_outputs: Dictionary
var variables: Dictionary
var graph: Dictionary


func _init(p_graph: Dictionary, p_script_id: String = ""):
	graph = p_graph
	script_id = p_script_id
	current_node = null
	node_outputs = {}
	variables = {}
