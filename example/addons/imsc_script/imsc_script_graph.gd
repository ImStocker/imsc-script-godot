class_name ImscScriptGraph

# Node type constants
const NODE_START := "start"
const NODE_END := "end"
const NODE_SPEECH := "speech"
const NODE_TRIGGER := "trigger"
const NODE_FUNCTION := "function"
const NODE_SET_VAR := "setVar"
const NODE_GET_VAR := "getVar"
const NODE_BRANCH := "branch"
const NODE_CALL_SCRIPT := "callScript"
const NODE_CONST_ASSET := "constAsset"
const NODE_CONST_TEXT := "constText"
const NODE_CONST_STRING := "constString"
const NODE_CONST_INTEGER := "constInteger"
const NODE_CONST_FLOAT := "constFloat"
const NODE_CONST_BOOLEAN := "constBoolean"

# Operator nodes
const NODE_OP_AND := "opAnd"
const NODE_OP_OR := "opOr"
const NODE_OP_MOD := "opMod"
const NODE_OP_DIV := "opDiv"
const NODE_OP_MULT := "opMult"
const NODE_OP_MINUS := "opMinus"
const NODE_OP_PLUS := "opPlus"
const NODE_OP_MORE_EQUAL := "opMoreEqual"
const NODE_OP_MORE := "opMore"
const NODE_OP_LESS_EQUAL := "opLessEqual"
const NODE_OP_LESS := "opLess"
const NODE_OP_NOT_EQUAL := "opNotEqual"
const NODE_OP_EQUAL := "opEqual"
const NODE_OP_NOT := "opNot"

# Flow nodes (drive execution, have "next")
static func is_flow_node(type_name: String) -> bool:
	return type_name in [
		NODE_START, NODE_END, NODE_SPEECH, NODE_TRIGGER,
		NODE_SET_VAR, NODE_BRANCH, NODE_CALL_SCRIPT
	]

# Expression nodes (evaluated when referenced by a binding)
static func is_expression_node(type_name: String) -> bool:
	return type_name in [
		NODE_GET_VAR,
		NODE_CONST_ASSET, NODE_CONST_TEXT, NODE_CONST_STRING,
		NODE_CONST_INTEGER, NODE_CONST_FLOAT, NODE_CONST_BOOLEAN,
		NODE_OP_AND, NODE_OP_OR, NODE_OP_MOD, NODE_OP_DIV,
		NODE_OP_MULT, NODE_OP_MINUS, NODE_OP_PLUS,
		NODE_OP_MORE_EQUAL, NODE_OP_MORE, NODE_OP_LESS_EQUAL,
		NODE_OP_LESS, NODE_OP_NOT_EQUAL, NODE_OP_EQUAL,
		NODE_OP_NOT, NODE_FUNCTION,
	]

# Check if a value is a binding (reference to another node's output)
static func is_binding(val) -> bool:
	return typeof(val) == TYPE_DICTIONARY and val.has("get") and val.has("param")

# Variable kind constants
const VAR_GLOBAL := "global"
const VAR_LOCAL := "local"
const VAR_IN := "in"
const VAR_OUT := "out"
const VAR_IN_OUT := "in-out"
