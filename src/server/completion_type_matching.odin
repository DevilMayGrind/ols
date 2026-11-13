package server

import "core:odin/ast"
import "core:strings"

import "src:common"

// Added to the score of completion results whose type matches the expected type
// (procedure argument or composite literal field value), so they sort first.
TYPE_MATCH_SCORE :: 10

Completion_Type_Match :: enum {
	Unknown, // can't tell, i.e. keywords, packages, generic procedures
	Match,
	Mismatch,
}

// Ranks results of the target type first and, in .Filter mode, drops results known to be of another type.
// Filtering is skipped when nothing matches, so the list never goes empty because of it.
apply_completion_type_matching :: proc(
	ast_context: ^AstContext,
	results: []CompletionResult,
	target: Symbol,
	mode: common.CompletionTypeMatching,
) -> []CompletionResult {
	matches := make([]Completion_Type_Match, len(results), context.temp_allocator)
	match_count := 0
	for &result, i in results {
		matches[i] = get_completion_result_type_match(ast_context, result, target)
		if matches[i] == .Match {
			result.score += TYPE_MATCH_SCORE
			match_count += 1
		}
	}

	if mode != .Filter || match_count == 0 {
		return results
	}

	kept := make([dynamic]CompletionResult, 0, len(results), context.temp_allocator)
	for result, i in results {
		if matches[i] != .Mismatch {
			append(&kept, result)
		}
	}
	return kept[:]
}

get_completion_result_type_match :: proc(
	ast_context: ^AstContext,
	result: CompletionResult,
	target: Symbol,
) -> Completion_Type_Match {
	if _, ok := result.completion_item.?; ok {
		return .Unknown
	}
	if result.snippet.insert != "" {
		return .Unknown
	}

	symbol := result.symbol

	#partial switch symbol.type {
	case .Keyword:
		#partial switch _ in symbol.value {
		case SymbolUntypedValue:
		// `true`, `false` and constants defined from them are untyped values and can be compared
		case SymbolBasicValue:
			// A basic type name, i.e. `u32` or `ID :: distinct u32`; only useful for casts
			return .Mismatch
		case:
			return .Unknown
		}
	case .Package, .Unresolved:
		return .Unknown
	case .Struct, .Enum, .Union, .Type_Function, .Type:
		// Type names are only useful for casts
		return .Mismatch
	}

	#partial switch v in symbol.value {
	case nil:
		return .Unknown
	case SymbolProcedureGroupValue, SymbolGenericValue, SymbolPolyTypeValue:
		return .Unknown
	case SymbolProcedureValue:
		if symbol.type != .Function {
			break // a variable of procedure type
		}
		if v.generic {
			return .Unknown
		}
		// Match by the first return value, which also covers `f() or_return`
		if len(v.return_types) == 0 {
			return .Mismatch
		}
		if v.return_types[0].type == nil {
			return .Unknown
		}
		reset_ast_context(ast_context)
		set_ast_package_set_scoped(ast_context, symbol.pkg)
		return_symbol, ok := resolve_type_expression(ast_context, v.return_types[0].type)
		if !ok {
			return .Unknown
		}
		symbol = return_symbol
	}

	return .Mismatch if symbol_types_differ(target, symbol) else .Match
}

// Expected type of the value being written in a composite literal field, i.e. `Info{device = |}`
get_comp_lit_field_value_target :: proc(
	ast_context: ^AstContext,
	position_context: ^DocumentPositionContext,
) -> (
	Symbol,
	bool,
) {
	comp_lit := position_context.comp_lit
	field_value := position_context.field_value
	if comp_lit == nil || field_value == nil || field_value.field == nil {
		return {}, false
	}

	// A call nested inside the literal's value takes precedence, i.e. `Info{size = len(|)}`
	if position_context.call != nil && position_context.call.pos.offset > comp_lit.pos.offset {
		return {}, false
	}

	is_elem := false
	for elem in comp_lit.elems {
		if elem == field_value {
			is_elem = true
			break
		}
	}
	if !is_elem || position_context.position <= field_value.field.end.offset {
		return {}, false
	}

	ident, ok := field_value.field.derived.(^ast.Ident)
	if !ok {
		return {}, false
	}

	reset_ast_context(ast_context)
	comp_symbol, comp_ok := resolve_comp_literal(ast_context, position_context)
	if !comp_ok {
		return {}, false
	}

	names: []string
	types: []^ast.Expr
	#partial switch v in comp_symbol.value {
	case SymbolStructValue:
		names, types = v.names, v.types
	case SymbolBitFieldValue:
		names, types = v.names, v.types
	case:
		return {}, false
	}

	for name, i in names {
		if name == ident.name && i < len(types) {
			reset_ast_context(ast_context)
			set_ast_package_set_scoped(ast_context, comp_symbol.pkg)
			return resolve_type_expression(ast_context, types[i])
		}
	}
	return {}, false
}

// Like find_position_in_call_param, but also handles an empty argument list, `f(|)`,
// and a cursor after a trailing comma, `f(a, |)`, which starts the next argument.
get_call_param_index_at_cursor :: proc(position_context: ^DocumentPositionContext, call: ^ast.Call_Expr) -> (int, bool) {
	position := position_context.position
	if position <= call.open.offset || (call.close.offset > call.open.offset && position > call.close.offset) {
		return 0, false
	}

	before := 0
	last_end := call.open.offset + 1
	for arg, i in call.args {
		if position_in_node(arg, position) {
			return i, true
		}
		if arg.end.offset <= position {
			before += 1
			last_end = arg.end.offset
		}
	}

	if before == 0 {
		return 0, true
	}

	src := position_context.file.src
	if last_end <= position && position <= len(src) && strings.contains(src[last_end:position], ",") {
		return before, true
	}
	return before - 1, true
}
