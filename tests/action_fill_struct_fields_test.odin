package tests

import "core:testing"
import test "src:testing"

@(private = "file")
TITLE :: "fill remaining struct fields"

@(test)
action_fill_struct_fields_empty_inline :: proc(t: ^testing.T) {
	source := test.Source {
		main = `package main
Foo :: struct { zeta: int, alpha: int, _: int }
main :: proc() {
	f := Foo{{*}}
}
`,
	}
	test.expect_action_applied(t, &source, TITLE, `package main
Foo :: struct { zeta: int, alpha: int, _: int }
main :: proc() {
	f := Foo{
		zeta = 0,
		alpha = 0,
	}
}
`)
}

@(test)
action_fill_struct_fields_multiline_with_existing :: proc(t: ^testing.T) {
	source := test.Source {
		main = `package main
Foo :: struct { a: int, b: int, c: int }
main :: proc() {
	f := Foo{
		b = 1,
		{*}
	}
}
`,
	}
	test.expect_action_applied(t, &source, TITLE, `package main
Foo :: struct { a: int, b: int, c: int }
main :: proc() {
	f := Foo{
		b = 1,
		a = 0,
		c = 0,
	}
}
`)
}

@(test)
action_fill_struct_fields_multiline_missing_trailing_comma :: proc(t: ^testing.T) {
	source := test.Source {
		main = `package main
Foo :: struct { a: int, b: int }
main :: proc() {
	if true {
		f := Foo{
			a = 1{*}
		}
	}
}
`,
	}
	test.expect_action_applied(t, &source, TITLE, `package main
Foo :: struct { a: int, b: int }
main :: proc() {
	if true {
		f := Foo{
			a = 1,
			b = 0,
		}
	}
}
`)
}

@(test)
action_fill_struct_fields_single_line_with_existing :: proc(t: ^testing.T) {
	source := test.Source {
		main = `package main
Foo :: struct { a: int, b: int, c: int }
main :: proc() {
	f := Foo{a = 1{*}}
}
`,
	}
	test.expect_action_applied(t, &source, TITLE, `package main
Foo :: struct { a: int, b: int, c: int }
main :: proc() {
	f := Foo{a = 1, b = 0, c = 0}
}
`)
}

@(test)
action_fill_struct_fields_implicit_proc_arg :: proc(t: ^testing.T) {
	source := test.Source {
		main = `package main
Region :: struct { buffer: rawptr, offset: u32, size: u32 }
upload :: proc(dst: Region, cycle: bool) {}
main :: proc() {
	upload({offset = 1{*}}, false)
}
`,
	}
	test.expect_action_applied(t, &source, TITLE, `package main
Region :: struct { buffer: rawptr, offset: u32, size: u32 }
upload :: proc(dst: Region, cycle: bool) {}
main :: proc() {
	upload({offset = 1, buffer = buffer, size = 0}, false)
}
`)
}

@(test)
action_fill_struct_fields_bit_field :: proc(t: ^testing.T) {
	source := test.Source {
		main = `package main
Foo :: bit_field u8 { x: u8 | 4, y: u8 | 4 }
main :: proc() {
	f := Foo{
		{*}
	}
}
`,
	}
	test.expect_action_applied(t, &source, TITLE, `package main
Foo :: bit_field u8 { x: u8 | 4, y: u8 | 4 }
main :: proc() {
	f := Foo{
		x = 0,
		y = 0,
	}
}
`)
}

@(test)
action_fill_struct_fields_not_offered_when_complete :: proc(t: ^testing.T) {
	source := test.Source {
		main = `package main
Foo :: struct { a: int, b: int }
main :: proc() {
	f := Foo{a = 1, b = 2{*}}
}
`,
	}
	test.expect_action(t, &source, {})
}

@(test)
action_fill_struct_fields_not_offered_for_positional :: proc(t: ^testing.T) {
	source := test.Source {
		main = `package main
Foo :: struct { a: int, b: int }
main :: proc() {
	f := Foo{1{*}}
}
`,
	}
	test.expect_action(t, &source, {})
}

@(test)
action_fill_struct_fields_values_by_type :: proc(t: ^testing.T) {
	source := test.Source {
		main = `package main
Shader :: struct {}
Id :: distinct u32
Kind :: enum { Point, Line }
Starts_At_One :: enum { One = 1, Two }
Explicit_Zero :: enum { A = 2, B = 0 }
Value :: union { int, f32 }
Callback :: proc()
Info :: struct {
	shader:   ^Shader,
	many:     [^]u8,
	raw:      rawptr,
	inner:    Shader,
	arr:      [4]int,
	list:     []int,
	dyn:      [dynamic]int,
	lookup:   map[string]int,
	flags:    bit_set[Kind],
	kind:     Kind,
	one:      Starts_At_One,
	zero:     Explicit_Zero,
	value:    Value,
	maybe:    Maybe(int),
	callback: Callback,
	id:       Id,
	count:    int,
	scale:    f32,
	enabled:  bool,
	label:    string,
	cname:    cstring,
	data:     any,
	type:     typeid,
}
main :: proc() {
	info := Info{
		{*}
	}
}
`,
	}
	test.expect_action_applied(t, &source, TITLE, `package main
Shader :: struct {}
Id :: distinct u32
Kind :: enum { Point, Line }
Starts_At_One :: enum { One = 1, Two }
Explicit_Zero :: enum { A = 2, B = 0 }
Value :: union { int, f32 }
Callback :: proc()
Info :: struct {
	shader:   ^Shader,
	many:     [^]u8,
	raw:      rawptr,
	inner:    Shader,
	arr:      [4]int,
	list:     []int,
	dyn:      [dynamic]int,
	lookup:   map[string]int,
	flags:    bit_set[Kind],
	kind:     Kind,
	one:      Starts_At_One,
	zero:     Explicit_Zero,
	value:    Value,
	maybe:    Maybe(int),
	callback: Callback,
	id:       Id,
	count:    int,
	scale:    f32,
	enabled:  bool,
	label:    string,
	cname:    cstring,
	data:     any,
	type:     typeid,
}
main :: proc() {
	info := Info{
		shader = shader,
		many = many,
		raw = raw,
		inner = {},
		arr = {},
		list = {},
		dyn = {},
		lookup = {},
		flags = {},
		kind = .Point,
		one = {},
		zero = .B,
		value = nil,
		maybe = nil,
		callback = nil,
		id = 0,
		count = 0,
		scale = 0,
		enabled = false,
		label = "",
		cname = "",
		data = nil,
		type = nil,
	}
}
`)
}
