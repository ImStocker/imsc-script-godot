class_name ImscScriptProps

enum AssetPropType {
	NULL,
	BOOLEAN,
	STRING,
	INTEGER,
	FLOAT,
	ARRAY,
	TEXT,
	FILE,
	BLOB,
	FORMULA,
	ASSET,
	ACCOUNT,
	SELECTION,
	ENUM,
	PROJECT,
	WORKSPACE,
	TIMESTAMP,
	TYPE,
}

static func get_asset_prop_type(v) -> int:
	if v == null:
		return AssetPropType.NULL
	var t = typeof(v)
	if t == TYPE_STRING:
		return AssetPropType.STRING
	if t == TYPE_BOOL:
		return AssetPropType.BOOLEAN
	if t == TYPE_INT:
		return AssetPropType.INTEGER
	if t == TYPE_FLOAT:
		return AssetPropType.FLOAT
	if t == TYPE_ARRAY:
		return AssetPropType.ARRAY
	if t == TYPE_DICTIONARY:
		if v.has("Ops") and typeof(v["Ops"]) == TYPE_ARRAY and v.has("Str") and typeof(v["Str"]) == TYPE_STRING:
			return AssetPropType.TEXT
		if v.has("FileId") and typeof(v["FileId"]) == TYPE_STRING and v.has("Title") and typeof(v["Title"]) == TYPE_STRING and v.has("Size") and typeof(v["Size"]) in [TYPE_INT, TYPE_FLOAT]:
			return AssetPropType.FILE
		if v.has("Ts") and typeof(v["Ts"]) in [TYPE_INT, TYPE_FLOAT] and v.has("Str") and typeof(v["Str"]) == TYPE_STRING:
			return AssetPropType.TIMESTAMP
		if v.has("Blob") and typeof(v["Blob"]) == TYPE_STRING and v.has("Type") and typeof(v["Type"]) == TYPE_STRING:
			return AssetPropType.BLOB
		if v.has("Enum") and typeof(v["Enum"]) == TYPE_STRING and v.has("Name") and typeof(v["Name"]) == TYPE_STRING:
			return AssetPropType.ENUM
		if v.has("F") and typeof(v["F"]) == TYPE_OBJECT:
			return AssetPropType.FORMULA
		if v.has("AssetId") and typeof(v["AssetId"]) == TYPE_STRING:
			return AssetPropType.ASSET
		if v.has("WorkspaceId") and typeof(v["WorkspaceId"]) == TYPE_STRING:
			return AssetPropType.WORKSPACE
		if v.has("ProjectId") and typeof(v["ProjectId"]) == TYPE_STRING:
			return AssetPropType.PROJECT
		if v.has("AccountId") and typeof(v["AccountId"]) == TYPE_STRING:
			return AssetPropType.ACCOUNT
		if v.has("Type") and typeof(v["Type"]) == TYPE_STRING:
			return AssetPropType.TYPE
		if v.has("Where") and typeof(v["Where"]) == TYPE_ARRAY:
			return AssetPropType.SELECTION
	return -1

static func cast_asset_prop_value_to_string(a) -> String:
	if a == null:
		return ""
	var t = get_asset_prop_type(a)
	match t:
		AssetPropType.NULL:
			return ""
		AssetPropType.TEXT:
			return a["Str"]
		AssetPropType.TIMESTAMP:
			return a["Str"]
		AssetPropType.INTEGER, AssetPropType.FLOAT, AssetPropType.STRING:
			return str(a)
		AssetPropType.BOOLEAN:
			return "1" if a else "0"
		AssetPropType.BLOB:
			return "[](#blob:%s:%s)" % [a["Type"], a["Blob"]]
		AssetPropType.FILE:
			var title = a["Title"] if a["Title"] else ""
			return "[%s](#file:%s)" % [title, a["FileId"]]
		AssetPropType.ACCOUNT:
			var name = a["Name"] if a["Name"] else ""
			return "[%s](#account:%s)" % [name, a["AccountId"]]
		AssetPropType.ARRAY:
			return "array[%s]" % a.size()
		AssetPropType.ASSET:
			var title = a["Title"] if a["Title"] else (a["Name"] if a.has("Name") and a["Name"] != null else "")
			var extra = ""
			if a.has("BlockId") and a["BlockId"] != null:
				extra += "#block:%s" % a["BlockId"]
				if a.has("Anchor") and a["Anchor"] != null:
					extra += "~anchor:%s" % a["Anchor"]
			return "[%s](#asset:%s%s)" % [title, a["AssetId"], extra]
		AssetPropType.WORKSPACE:
			var title = a["Title"] if a["Title"] else (a["Name"] if a.has("Name") and a["Name"] != null else "")
			return "[%s](#workspace:%s)" % [title, a["WorkspaceId"]]
		AssetPropType.PROJECT:
			var title = a["Title"] if a["Title"] else a["ProjectId"]
			return "[%s](#project:%s)" % [title, a["ProjectId"]]
		AssetPropType.FORMULA, AssetPropType.SELECTION:
			return JSON.stringify(a)
		AssetPropType.ENUM:
			return a["Name"]
		AssetPropType.TYPE:
			var ofval = a["Of"] if a.has("Of") else null
			var kind_str = (":" + a["Kind"]) if a.has("Kind") and a["Kind"] != null else ""
			var of_str = ("[" + cast_asset_prop_value_to_string(ofval) + "]") if ofval != null else ""
			return a["Type"] + kind_str + of_str
	return ""

static func cast_asset_prop_value_to_boolean(a) -> bool:
	if a == null:
		return false
	var t = typeof(a)
	if t == TYPE_BOOL:
		return a
	if t in [TYPE_INT, TYPE_FLOAT]:
		return a != 0
	if t == TYPE_STRING:
		return not a.is_empty()
	return true

static func cast_asset_prop_value_to_int(a) -> int:
	var t = typeof(a)
	if t == TYPE_INT:
		return a
	if t == TYPE_FLOAT:
		return roundi(a)
	if t == TYPE_BOOL:
		return 1 if a else 0
	if t == TYPE_DICTIONARY and a.has("Ts"):
		return roundi(a["Ts"])
	var s = cast_asset_prop_value_to_string(a)
	return s.to_int()

static func cast_asset_prop_value_to_float(a) -> float:
	var t = typeof(a)
	if t in [TYPE_FLOAT, TYPE_INT]:
		return float(a)
	if t == TYPE_DICTIONARY and a.has("Ts"):
		return a["Ts"]
	var s = cast_asset_prop_value_to_string(a)
	return s.to_float()

static func cast_asset_prop_value_to_asset(a):
	if a == null:
		return null
	if typeof(a) == TYPE_DICTIONARY and a.has("AssetId"):
		return a
	var val = a
	if typeof(a) == TYPE_DICTIONARY and a.has("Ops"):
		val = convert_asset_prop_value_text_ops_to_str(a["Ops"]).str
	var s = cast_asset_prop_value_to_string(val).strip_edges()
	if s.is_empty():
		return null
	var regex = RegEx.new()
	regex.compile("^\\[(.*?)\\]\\(#asset:(.*?)(?:#block:([^#~\\)]*)(?:~anchor:([^\\)]*))?)?\\)$")
	var m = regex.search(s)
	if m:
		return {
			"Title": m.get_string(1),
			"AssetId": m.get_string(2),
			"Name": null,
			"BlockId": m.get_string(3) if m.get_string(3) != "" else null,
			"Anchor": m.get_string(4) if m.get_string(4) != "" else null,
		}
	return null

static func cast_asset_prop_value_to_timestamp(a):
	if a == null:
		return null
	var t = get_asset_prop_type(a)
	if t == AssetPropType.TIMESTAMP:
		return a
	if t in [AssetPropType.INTEGER, AssetPropType.FLOAT]:
		var ms = float(a) * 1000.0
		var unix_sec = int(ms / 1000.0)
		var iso = Time.get_datetime_string_from_unix_time(unix_sec)
		return {"Str": iso, "Ts": ms / 1000.0}
	var s = cast_asset_prop_value_to_string(a)
	var parsed = Time.get_unix_time_from_datetime_string(s)
	if parsed == -1.0:
		return null
	return {"Str": s, "Ts": parsed}

static func cast_asset_prop_value_to_date(a) -> Dictionary:
	var ts = cast_asset_prop_value_to_timestamp(a)
	if ts == null:
		return {}
	return Time.get_datetime_dict_from_unix_time(int(ts["Ts"]))

static func cast_asset_prop_value_to_array(a) -> Array:
	return a if typeof(a) == TYPE_ARRAY else []

static func cast_asset_prop_value_to_enum(a):
	if a == null:
		return null
	if typeof(a) != TYPE_DICTIONARY or not a.has("Enum"):
		return null
	return a

static func cast_asset_prop_value_to_account(a):
	if a == null:
		return null
	if typeof(a) != TYPE_DICTIONARY or not a.has("AccountId"):
		return null
	return a

static func convert_asset_prop_value_text_ops_to_str(ops) -> Dictionary:
	var parts = []
	var plain = true
	for op in ops:
		if typeof(op) != TYPE_DICTIONARY:
			continue
		if not op.has("insert"):
			continue
		var insert = op["insert"]
		if typeof(insert) != TYPE_STRING:
			plain = false
			if typeof(insert) == TYPE_DICTIONARY:
				if insert.has("file"):
					var inline = false
					if typeof(insert.file) == TYPE_DICTIONARY and insert.file.has("inline"):
						inline = insert.file.inline
					parts.append(("!" if inline else "") + cast_asset_prop_value_to_string(insert.file.value))
				elif insert.has("task"):
					parts.append(cast_asset_prop_value_to_string(insert.task.value))
		else:
			var has_attr = op.has("attributes") and op["attributes"] != null
			if has_attr:
				plain = false
			if has_attr and typeof(op["attributes"]) == TYPE_DICTIONARY and op["attributes"].has("asset"):
				var asset_val = op["attributes"]["asset"]["value"]
				var esc_insert = insert.replace("[", "\\[").replace("]", "\\]")
				var extra = ""
				if asset_val.has("BlockId") and asset_val["BlockId"] != null:
					extra += "#block:%s" % asset_val["BlockId"]
					if asset_val.has("Anchor") and asset_val["Anchor"] != null:
						extra += "~anchor:%s" % asset_val["Anchor"]
				parts.append("[%s](#asset:%s%s)" % [esc_insert, asset_val["AssetId"], extra])
			else:
				parts.append(insert)
	return {"str": "".join(parts), "plain": plain}

static func _sort_keys(v):
	if typeof(v) == TYPE_DICTIONARY:
		var sorted = {}
		var keys = v.keys()
		keys.sort()
		for k in keys:
			sorted[k] = _sort_keys(v[k])
		return sorted
	if typeof(v) == TYPE_ARRAY:
		var arr = []
		for item in v:
			arr.append(_sort_keys(item))
		return arr
	return v


static func _json_compare(obj1, obj2) -> int:
	if obj1 == null and obj2 != null:
		return -1
	if obj1 != null and obj2 == null:
		return 1
	var json1 = JSON.stringify(_sort_keys(obj1))
	var json2 = JSON.stringify(_sort_keys(obj2))
	if json1 < json2:
		return -1
	if json1 > json2:
		return 1
	return 0

static func _compare_texts(ac, bc) -> int:
	var str_cmp = -1 if ac["Str"] < bc["Str"] else (1 if ac["Str"] > bc["Str"] else 0)
	if str_cmp != 0:
		return str_cmp
	if ac["Ops"].size() != bc["Ops"].size():
		return -1 if ac["Ops"].size() < bc["Ops"].size() else 1
	for i in ac["Ops"].size():
		var aop = ac["Ops"][i]
		var bop = bc["Ops"][i]
		if aop == null and bop != null:
			return -1
		if aop != null and bop == null:
			return 1
		if aop != null and bop != null:
			var a_has_ins = aop.has("insert")
			var b_has_ins = bop.has("insert")
			if not a_has_ins and b_has_ins:
				return -1
			if a_has_ins and not b_has_ins:
				return 1
			if a_has_ins and b_has_ins:
				if typeof(aop.insert) == TYPE_STRING and typeof(bop.insert) == TYPE_STRING:
					var ins_cmp = -1 if aop.insert < bop.insert else (1 if aop.insert > bop.insert else 0)
					if ins_cmp != 0:
						return ins_cmp
				else:
					var json_cmp = _json_compare(aop.insert, bop.insert)
					if json_cmp != 0:
						return json_cmp
		var a_has_attr = aop.has("attributes") and aop.attributes != null
		var b_has_attr = bop.has("attributes") and bop.attributes != null
		if not a_has_attr and b_has_attr:
			return -1
		if a_has_attr and not b_has_attr:
			return 1
		if a_has_attr and b_has_attr:
			var json_cmp = _json_compare(aop.attributes, bop.attributes)
			if json_cmp != 0:
				return json_cmp
	return 0

static func compare_asset_prop_values(a, b, exact = true) -> int:
	var an = a
	var bn = b
	if an == null and bn == null:
		return 0
	if an == bn:
		return 0
	if an == null:
		return -1
	if bn == null:
		return 1
	var a_type = get_asset_prop_type(an)
	var b_type = get_asset_prop_type(bn)
	if a_type == b_type:
		match a_type:
			AssetPropType.NULL, AssetPropType.INTEGER, AssetPropType.FLOAT, AssetPropType.BOOLEAN:
				if an == bn:
					return 0
				return -1 if an < bn else 1
			AssetPropType.STRING:
				return -1 if an < bn else (1 if an > bn else 0)
			AssetPropType.TIMESTAMP:
				return -1 if an["Str"] < bn["Str"] else (1 if an["Str"] > bn["Str"] else 0)
			AssetPropType.TEXT:
				return _compare_texts(an, bn)
			AssetPropType.BLOB:
				if an["Type"] == bn["Type"]:
					return -1 if an["Blob"] < bn["Blob"] else (1 if an["Blob"] > bn["Blob"] else 0)
				return -1 if an["Type"] < bn["Type"] else 1
			AssetPropType.FILE:
				if an["FileId"] == bn["FileId"]:
					return 0
				var scomp = -1 if an["Title"] < bn["Title"] else (1 if an["Title"] > bn["Title"] else 0)
				if scomp == 0:
					return -1 if an["FileId"] < bn["FileId"] else 1
				return scomp
			AssetPropType.ACCOUNT:
				if an["AccountId"] == bn["AccountId"]:
					return 0
				var scomp = -1 if an["Name"] < bn["Name"] else (1 if an["Name"] > bn["Name"] else 0)
				if scomp == 0:
					return -1 if an["AccountId"] < bn["AccountId"] else 1
				return scomp
			AssetPropType.ARRAY:
				if an.size() == bn.size():
					for i in an.size():
						if typeof(an[i]) != typeof(bn[i]):
							return -1 if typeof(an[i]) < typeof(bn[i]) else 1
						if an[i] != bn[i]:
							if typeof(an[i]) in [TYPE_INT, TYPE_FLOAT]:
								return an[i] - bn[i]
							return -1 if an[i] < bn[i] else 1
					return 0
				return an.size() - bn.size()
			AssetPropType.ASSET:
				if an["AssetId"] == bn["AssetId"]:
					return 0
				var scomp = -1 if an["Title"] < bn["Title"] else (1 if an["Title"] > bn["Title"] else 0)
				if scomp == 0:
					var an_name = an["Name"] if an.has("Name") and an["Name"] != null else ""
					var bn_name = bn["Name"] if bn.has("Name") and bn["Name"] != null else ""
					scomp = -1 if an_name < bn_name else (1 if an_name > bn_name else 0)
					if scomp == 0:
						return -1 if an["AssetId"] < bn["AssetId"] else 1
				return scomp
			AssetPropType.WORKSPACE:
				if an["WorkspaceId"] == bn["WorkspaceId"]:
					return 0
				var scomp = -1 if an["Title"] < bn["Title"] else (1 if an["Title"] > bn["Title"] else 0)
				if scomp == 0:
					var an_name = an["Name"] if an.has("Name") and an["Name"] != null else ""
					var bn_name = bn["Name"] if bn.has("Name") and bn["Name"] != null else ""
					scomp = -1 if an_name < bn_name else (1 if an_name > bn_name else 0)
					if scomp == 0:
						return -1 if an["WorkspaceId"] < bn["WorkspaceId"] else 1
				return scomp
			AssetPropType.PROJECT:
				if an["ProjectId"] == bn["ProjectId"]:
					return 0
				var scomp = -1 if an["Title"] < bn["Title"] else (1 if an["Title"] > bn["Title"] else 0)
				if scomp == 0:
					return -1 if an["ProjectId"] < bn["ProjectId"] else 1
				return scomp
			AssetPropType.FORMULA, AssetPropType.SELECTION:
				return _json_compare(an, bn)
			AssetPropType.ENUM:
				var mcomp = -1 if an["Enum"] < bn["Enum"] else (1 if an["Enum"] > bn["Enum"] else 0)
				if mcomp == 0:
					return -1 if an["Name"] < bn["Name"] else (1 if an["Name"] > bn["Name"] else 0)
				return mcomp
			AssetPropType.TYPE:
				var mcomp = -1 if an["Type"] < bn["Type"] else (1 if an["Type"] > bn["Type"] else 0)
				if mcomp == 0:
					var ak = an["Kind"] if an.has("Kind") else ""
					var bk = bn["Kind"] if bn.has("Kind") else ""
					mcomp = -1 if ak < bk else (1 if ak > bk else 0)
					if mcomp == 0:
						var aof = an["Of"] if an.has("Of") else null
						var bof = bn["Of"] if bn.has("Of") else null
						return compare_asset_prop_values(aof, bof)
				return mcomp
	var a_str = cast_asset_prop_value_to_string(an)
	var b_str = cast_asset_prop_value_to_string(bn)
	var comp = -1 if a_str < b_str else (1 if a_str > b_str else 0)
	if comp == 0 and exact:
		return -1
	return comp
