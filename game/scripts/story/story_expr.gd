extends RefCounted
## Small, deterministic condition/effect evaluator for story data.
## Supports dotted flag names, integer/string/bool literals, arithmetic,
## comparisons, and/or/not, and parentheses. No function calls.

static var last_error := ""


class Parser:
	var src: String
	var pos: int = 0
	var flags: Dictionary
	var error: String = ""

	func _init(text: String, values: Dictionary) -> void:
		src = text
		flags = values

	func parse() -> Variant:
		_skip_ws()
		var value: Variant = _parse_or()
		_skip_ws()
		if error == "" and pos < src.length():
			_fail("unexpected '%s'" % src.substr(pos, 12))
		return value

	func _parse_or() -> Variant:
		var left: Variant = _parse_and()
		while error == "" and (_match_keyword("or") or _match_symbol("||")):
			var right: Variant = _parse_and()
			left = bool(left) or bool(right)
		return left

	func _parse_and() -> Variant:
		var left: Variant = _parse_not()
		while error == "" and (_match_keyword("and") or _match_symbol("&&")):
			var right: Variant = _parse_not()
			left = bool(left) and bool(right)
		return left

	func _parse_not() -> Variant:
		if _match_keyword("not") or _match_bang():
			var value: Variant = _parse_not()
			return not bool(value)
		return _parse_comparison()

	func _parse_comparison() -> Variant:
		var left: Variant = _parse_add()
		if error != "":
			return null
		for op in [">=", "<=", "==", "!=", ">", "<"]:
			if not _match_symbol(op):
				continue
			var right: Variant = _parse_add()
			if error != "":
				return null
			match op:
				"==":
					return left == right
				"!=":
					return left != right
				">=":
					if not _comparable(left, right):
						return _compare_error(left, right)
					return left >= right
				"<=":
					if not _comparable(left, right):
						return _compare_error(left, right)
					return left <= right
				">":
					if not _comparable(left, right):
						return _compare_error(left, right)
					return left > right
				"<":
					if not _comparable(left, right):
						return _compare_error(left, right)
					return left < right
		return left

	func _parse_add() -> Variant:
		var left: Variant = _parse_mul()
		while error == "":
			if _match_symbol("+"):
				var right: Variant = _parse_mul()
				if not _numeric(left) or not _numeric(right):
					_fail("'+' needs numbers")
					return null
				left = left + right
			elif _match_symbol("-"):
				var right: Variant = _parse_mul()
				if not _numeric(left) or not _numeric(right):
					_fail("'-' needs numbers")
					return null
				left = left - right
			else:
				break
		return left

	func _parse_mul() -> Variant:
		var left: Variant = _parse_unary()
		while error == "":
			if _match_symbol("*"):
				var right: Variant = _parse_unary()
				if not _numeric(left) or not _numeric(right):
					_fail("'*' needs numbers")
					return null
				left = left * right
			elif _match_symbol("/"):
				var right: Variant = _parse_unary()
				if not _numeric(left) or not _numeric(right):
					_fail("'/' needs numbers")
					return null
				if right == 0:
					_fail("division by zero")
					return null
				left = left / right
			elif _match_symbol("%"):
				var right: Variant = _parse_unary()
				if not _numeric(left) or not _numeric(right):
					_fail("'%' needs numbers")
					return null
				if right == 0:
					_fail("division by zero")
					return null
				left = left % right
			else:
				break
		return left

	func _parse_unary() -> Variant:
		if _match_symbol("-"):
			var value: Variant = _parse_unary()
			if not _numeric(value):
				_fail("unary '-' needs a number")
				return null
			return -value
		if _match_symbol("+"):
			var value: Variant = _parse_unary()
			if not _numeric(value):
				_fail("unary '+' needs a number")
				return null
			return value
		return _parse_primary()

	func _parse_primary() -> Variant:
		_skip_ws()
		if pos >= src.length():
			_fail("unexpected end of expression")
			return null
		var c := src[pos]
		if c == "(":
			pos += 1
			var value: Variant = _parse_or()
			_skip_ws()
			if not _match_symbol(")"):
				_fail("missing ')'")
			return value
		if c == "\"" or c == "'":
			return _parse_string(c)
		if c >= "0" and c <= "9":
			var start := pos
			while pos < src.length() and src[pos] >= "0" and src[pos] <= "9":
				pos += 1
			return int(src.substr(start, pos - start))
		if _is_ident_start(c):
			var name := _parse_name()
			if name == "true":
				return true
			if name == "false":
				return false
			if flags.has(name):
				return flags[name]
			_fail("unknown flag '%s'" % name)
			return null
		_fail("unexpected '%s'" % c)
		return null

	func _parse_string(quote: String) -> Variant:
		pos += 1
		var out := ""
		while pos < src.length():
			var c := src[pos]
			if c == "\\" and pos + 1 < src.length():
				pos += 1
				out += src[pos]
				pos += 1
				continue
			if c == quote:
				pos += 1
				return out
			out += c
			pos += 1
		_fail("unterminated string")
		return null

	func _parse_name() -> String:
		var start := pos
		while pos < src.length() and _is_ident_char(src[pos]):
			pos += 1
		return src.substr(start, pos - start)

	func _numeric(value: Variant) -> bool:
		var kind := typeof(value)
		return kind == TYPE_INT or kind == TYPE_FLOAT

	func _comparable(left: Variant, right: Variant) -> bool:
		if _numeric(left) and _numeric(right):
			return true
		return typeof(left) == TYPE_STRING and typeof(right) == TYPE_STRING

	func _is_ident_start(c: String) -> bool:
		return c == "_" or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z")

	func _is_ident_char(c: String) -> bool:
		return _is_ident_start(c) or (c >= "0" and c <= "9") or c == "."

	func _skip_ws() -> void:
		while pos < src.length():
			var c := src[pos]
			if c != " " and c != "\t" and c != "\r" and c != "\n":
				break
			pos += 1

	func _match_keyword(word: String) -> bool:
		_skip_ws()
		if src.substr(pos, word.length()) != word:
			return false
		var after := pos + word.length()
		if after < src.length() and _is_ident_char(src[after]):
			return false
		pos = after
		return true

	func _match_bang() -> bool:
		_skip_ws()
		if src.substr(pos, 2) == "!=":
			return false
		if src.substr(pos, 1) != "!":
			return false
		pos += 1
		return true

	func _match_symbol(symbol: String) -> bool:
		_skip_ws()
		if src.substr(pos, symbol.length()) != symbol:
			return false
		pos += symbol.length()
		return true

	func _compare_error(left: Variant, right: Variant) -> Variant:
		_fail("cannot compare %s and %s" % [type_string(typeof(left)), type_string(typeof(right))])
		return null

	func _fail(message: String) -> void:
		if error == "":
			error = "%s at %d" % [message, pos]


static func eval(source: String, flags: Dictionary) -> Variant:
	last_error = ""
	var parser := Parser.new(source, flags)
	var value: Variant = parser.parse()
	if parser.error != "":
		last_error = parser.error
		return null
	return value


static func assign(statement: String, flags: Dictionary) -> bool:
	last_error = ""
	var text := statement.strip_edges()
	var op := ""
	var index := text.find("+=")
	if index > 0:
		op = "+="
	else:
		index = text.find("-=")
		if index > 0:
			op = "-="
		else:
			index = text.find("=")
			if index <= 0:
				last_error = "effect needs an assignment: %s" % statement
				return false
			op = "="
	var name := text.substr(0, index).strip_edges()
	if not is_valid_name(name):
		last_error = "invalid flag name: %s" % name
		return false
	var rhs := text.substr(index + op.length()).strip_edges()
	var value: Variant = eval(rhs, flags)
	if last_error != "":
		return false
	if op == "=":
		flags[name] = value
		return true
	if not flags.has(name):
		last_error = "unknown flag: %s" % name
		return false
	var current: Variant = flags[name]
	if not _numeric(current) or not _numeric(value):
		last_error = "%s needs numbers: %s" % [op, name]
		return false
	flags[name] = current + value if op == "+=" else current - value
	return true


static func identifiers(source: String) -> PackedStringArray:
	var result := PackedStringArray()
	var regex := RegEx.new()
	regex.compile("[A-Za-z_][A-Za-z0-9_.]*")
	for found in regex.search_all(source):
		var name := found.get_string()
		if name in ["true", "false", "and", "or", "not"]:
			continue
		if not result.has(name):
			result.append(name)
	return result


static func is_valid_name(name: String) -> bool:
	if name.is_empty() or not _is_ident_start(name[0]):
		return false
	for index in range(1, name.length()):
		if not _is_ident_char(name[index]):
			return false
	return true


static func _is_ident_start(c: String) -> bool:
	return c == "_" or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z")


static func _is_ident_char(c: String) -> bool:
	return _is_ident_start(c) or (c >= "0" and c <= "9") or c == "."


static func _numeric(value: Variant) -> bool:
	var kind := typeof(value)
	return kind == TYPE_INT or kind == TYPE_FLOAT


static func _comparable(left: Variant, right: Variant) -> bool:
	if _numeric(left) and _numeric(right):
		return true
	return typeof(left) == TYPE_STRING and typeof(right) == TYPE_STRING
