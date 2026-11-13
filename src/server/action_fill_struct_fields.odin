#+private file

package server

import "core:odin/ast"
import "core:strconv"
import "core:strings"

import "src:common"

FILL_STRUCT_FIELDS_TITLE :: "fill remaining struct fields"

Missing_Field :: struct {
	name:  string,
	value: string,
}

// Fields of the literal's struct/bit_field type that are not yet set, in declaration order.
get_missing_comp_lit_fields :: proc(
	ast_context: ^AstContext,
	position_context: ^DocumentPositionContext,
	config: ^common.Config,
) -> (
	[]Missing_Field,
	bool,
) {
	comp_lit := position_context.comp_lit

	// Positional elements can't be mixed with named fields
	for elem in comp_lit.elems {
		if _, ok := elem.derived.(^ast.Field_Value); !ok {
			return {}, false
		}
	}

	reset_ast_context(ast_context)
	symbol, ok := resolve_comp_literal(ast_context, position_context)
	if !ok {
		return {}, false
	}

	names: []string
	types: []^ast.Expr
	#partial switch v in symbol.value {
	case SymbolStructValue:
		names, types = v.names, v.types
	case SymbolBitFieldValue:
		names, types = v.names, v.types
	case:
		return {}, false
	}

	missing := make([dynamic]Missing_Field, 0, len(names), context.temp_allocator)
	for name, i in names {
		if name == "" || name == "_" {
			continue
		}
		if is_struct_field_hidden(name, symbol, ast_context, config) {
			continue
		}
		if field_exists_in_comp_lit(comp_lit, name) {
			continue
		}
		type_expr := types[i] if i < len(types) else nil
		append(&missing, Missing_Field{name = name, value = get_field_fill_value(ast_context, symbol.pkg, name, type_expr)})
	}

	return missing[:], len(missing) > 0
}

// Value to fill a field with: pointers get the field name (assumed to be a variable of the same name),
// everything else gets its zero value. Falls back to the field name when the type can't be resolved.
get_field_fill_value :: proc(ast_context: ^AstContext, pkg: string, name: string, type_expr: ^ast.Expr) -> string {
	if type_expr == nil {
		return name
	}

	#partial switch t in type_expr.derived {
	case ^ast.Pointer_Type, ^ast.Multi_Pointer_Type:
		return name
	case ^ast.Proc_Type, ^ast.Union_Type:
		return "nil"
	case ^ast.Call_Expr:
		// Maybe(T) is a union
		if ident, ok := t.expr.derived.(^ast.Ident); ok && ident.name == "Maybe" {
			return "nil"
		}
	case ^ast.Struct_Type,
	     ^ast.Array_Type,
	     ^ast.Dynamic_Array_Type,
	     ^ast.Map_Type,
	     ^ast.Bit_Set_Type,
	     ^ast.Bit_Field_Type,
	     ^ast.Matrix_Type:
		return "{}"
	}

	reset_ast_context(ast_context)
	set_ast_package_set_scoped(ast_context, pkg)
	symbol, ok := resolve_type_expression(ast_context, type_expr)
	if !ok {
		return name
	}

	if symbol.pointers > 0 {
		return name
	}

	switch v in symbol.value {
	case SymbolMultiPointerValue:
		return name
	case SymbolStructValue,
	     SymbolFixedArrayValue,
	     SymbolSliceValue,
	     SymbolDynamicArrayValue,
	     SymbolMapValue,
	     SymbolBitSetValue,
	     SymbolBitFieldValue,
	     SymbolMatrixValue:
		return "{}"
	case SymbolUnionValue, SymbolProcedureValue, SymbolProcedureGroupValue:
		return "nil"
	case SymbolEnumValue:
		return get_enum_zero_value(v)
	case SymbolBasicValue:
		if v.ident == nil {
			return name
		}
		return get_basic_zero_value(v.ident.name, name)
	case SymbolUntypedValue:
		#partial switch v.type {
		case .String:
			return `""`
		case .Bool:
			return "false"
		}
		return "0"
	case SymbolPackageValue, SymbolGenericValue, SymbolAggregateValue, SymbolPolyTypeValue, SymbolLabelValue:
		return name
	}

	return name
}

get_basic_zero_value :: proc(type_name: string, field_name: string) -> string {
	switch type_name {
	case "bool", "b8", "b16", "b32", "b64":
		return "false"
	case "string", "cstring", "string16", "cstring16":
		return `""`
	case "rawptr":
		return field_name
	case "any", "typeid":
		return "nil"
	case "int", "uint", "uintptr", "rune",
	     "i8", "i16", "i32", "i64", "i128",
	     "u8", "u16", "u32", "u64", "u128",
	     "i16le", "i32le", "i64le", "i128le", "u16le", "u32le", "u64le", "u128le",
	     "i16be", "i32be", "i64be", "i128be", "u16be", "u32be", "u64be", "u128be",
	     "f16", "f32", "f64", "f16le", "f32le", "f64le", "f16be", "f32be", "f64be",
	     "complex32", "complex64", "complex128",
	     "quaternion64", "quaternion128", "quaternion256":
		return "0"
	}
	return field_name
}

// The member whose value is 0, i.e. `.A`, or `{}` when no member is known to be 0.
get_enum_zero_value :: proc(v: SymbolEnumValue) -> string {
	counter: i64 = 0
	known := true
	for name, i in v.names {
		value := v.values[i] if i < len(v.values) else nil
		if value != nil {
			known = false
			if lit, ok := value.derived.(^ast.Basic_Lit); ok && lit.tok.kind == .Integer {
				if n, ok := strconv.parse_i64(lit.tok.text); ok {
					counter = n
					known = true
				}
			}
		}
		if known && counter == 0 {
			return strings.concatenate({".", name}, context.temp_allocator)
		}
		counter += 1
	}
	return "{}"
}

offset_to_position :: proc(src: string, offset: int) -> common.Position {
	return common.get_relative_token_position(offset, transmute([]u8)src, 0)
}

insert_edit :: proc(src: string, offset: int, text: string) -> TextEdit {
	position := offset_to_position(src, offset)
	return TextEdit{range = {start = position, end = position}, newText = text}
}

create_fill_struct_fields_edits :: proc(src: string, comp_lit: ^ast.Comp_Lit, missing: []Missing_Field) -> []TextEdit {
	edits := make([dynamic]TextEdit, 0, 2, context.temp_allocator)

	open := comp_lit.open.offset
	close := comp_lit.close.offset
	has_elems := len(comp_lit.elems) > 0
	last_end := has_elems ? comp_lit.elems[len(comp_lit.elems) - 1].end.offset : open + 1
	trailing := src[last_end:close]
	needs_comma := has_elems && !strings.contains(trailing, ",")

	// Single line literal that already has fields: append inline, `Foo{a = 1, b = b, c = c}`
	if has_elems && !strings.contains(src[open:close], "\n") {
		b := strings.builder_make(context.temp_allocator)
		if needs_comma {
			strings.write_string(&b, ", ")
		} else if !strings.has_suffix(trailing, " ") {
			strings.write_string(&b, " ")
		}
		for field, i in missing {
			if i > 0 {
				strings.write_string(&b, ", ")
			}
			strings.write_string(&b, field.name)
			strings.write_string(&b, " = ")
			strings.write_string(&b, field.value)
		}
		append(&edits, insert_edit(src, close, strings.to_string(b)))
		return edits[:]
	}

	// Otherwise one field per line
	base_indent := get_line_indentation(src, open)
	field_indent: string
	if has_elems && get_line_start_offset(src, comp_lit.elems[0].pos.offset) != get_line_start_offset(src, open) {
		field_indent = get_line_indentation(src, comp_lit.elems[0].pos.offset)
	} else {
		unit := "\t"
		if base_indent != "" && !strings.contains(base_indent, "\t") {
			unit = "    "
		}
		field_indent = strings.concatenate({base_indent, unit}, context.temp_allocator)
	}

	lines := strings.builder_make(context.temp_allocator)
	for field in missing {
		strings.write_string(&lines, field_indent)
		strings.write_string(&lines, field.name)
		strings.write_string(&lines, " = ")
		strings.write_string(&lines, field.value)
		strings.write_string(&lines, ",\n")
	}

	close_line_start := get_line_start_offset(src, close)
	close_on_own_line := strings.trim_space(src[close_line_start:close]) == "" && close_line_start > last_end

	if close_on_own_line {
		if needs_comma {
			append(&edits, insert_edit(src, last_end, ","))
		}
		// Replace blank lines between the last field (or the opening brace) and the closing brace
		start := close_line_start
		if newline := strings.index_byte(src[last_end:close_line_start], '\n'); newline != -1 {
			after_line := last_end + newline + 1
			if strings.trim_space(src[after_line:close_line_start]) == "" {
				start = after_line
			}
		}
		append(
			&edits,
			TextEdit {
				range = {start = offset_to_position(src, start), end = offset_to_position(src, close_line_start)},
				newText = strings.to_string(lines),
			},
		)
	} else {
		b := strings.builder_make(context.temp_allocator)
		if needs_comma {
			strings.write_string(&b, ",")
		}
		strings.write_string(&b, "\n")
		strings.write_string(&b, strings.to_string(lines))
		strings.write_string(&b, base_indent)

		// Drop whitespace-only filler in an empty literal, i.e. `Foo{ }`
		start := close
		if !has_elems && strings.trim_space(trailing) == "" {
			start = open + 1
		}
		append(
			&edits,
			TextEdit {
				range = {start = offset_to_position(src, start), end = offset_to_position(src, close)},
				newText = strings.to_string(b),
			},
		)
	}

	return edits[:]
}

// Get the offset of the start of the line containing the given offset
get_line_start_offset :: proc(src: string, offset: int) -> int {
	line_start := offset
	for line_start > 0 && src[line_start - 1] != '\n' {
		line_start -= 1
	}
	return line_start
}

@(private = "package")
add_fill_struct_fields_action :: proc(
	ast_context: ^AstContext,
	position_context: ^DocumentPositionContext,
	uri: string,
	config: ^common.Config,
	actions: ^[dynamic]CodeAction,
) {
	if position_context.comp_lit == nil {
		return
	}

	missing, ok := get_missing_comp_lit_fields(ast_context, position_context, config)
	if !ok {
		return
	}

	workspaceEdit: WorkspaceEdit
	workspaceEdit.changes = make(map[string][]TextEdit, 0, context.temp_allocator)
	workspaceEdit.changes[uri] = create_fill_struct_fields_edits(
		position_context.file.src,
		position_context.comp_lit,
		missing,
	)
	append(
		actions,
		CodeAction{kind = "refactor.rewrite", title = FILL_STRUCT_FIELDS_TITLE, edit = workspaceEdit},
	)
}
