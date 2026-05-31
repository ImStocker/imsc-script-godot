class_name ImscScriptSpeechOption
extends RefCounted

var index: int
var condition: bool
var text: String
var values: Dictionary
var next_node_id: String


func _init(p_index: int, p_values: Dictionary, p_condition = null, p_text = null, p_next_node_id = null):
	index = p_index
	values = p_values
	condition = p_condition if p_condition != null else false
	text = p_text if p_text != null else ""
	next_node_id = p_next_node_id if p_next_node_id != null else ""
