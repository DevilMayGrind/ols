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
		zeta = zeta,
		alpha = alpha,
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
		a = a,
		c = c,
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
			b = b,
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
	f := Foo{a = 1, b = b, c = c}
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
	upload({buffer = nil{*}}, false)
}
`,
	}
	test.expect_action_applied(t, &source, TITLE, `package main
Region :: struct { buffer: rawptr, offset: u32, size: u32 }
upload :: proc(dst: Region, cycle: bool) {}
main :: proc() {
	upload({buffer = nil, offset = offset, size = size}, false)
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
		x = x,
		y = y,
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
