package tests

import "core:testing"

import test "src:testing"

@(test)
ast_completion_comp_lit_struct_fields_declaration_order :: proc(t: ^testing.T) {
	source := test.Source {
		main = `package test
		Foo :: struct {
			zeta:  int,
			alpha: int,
			mid:   int,
		}
		main :: proc() {
			f := Foo{
				{*}
			}
		}
		`,
	}
	test.expect_completion_label_order(t, &source, "", {"zeta", "alpha", "mid"})
}

@(test)
ast_completion_comp_lit_struct_fields_declaration_order_after_field :: proc(t: ^testing.T) {
	source := test.Source {
		main = `package test
		Foo :: struct {
			zeta:  int,
			alpha: int,
			mid:   int,
			beta:  int,
		}
		main :: proc() {
			f := Foo{
				alpha = 1,
				{*}
			}
		}
		`,
	}
	test.expect_completion_label_order(t, &source, "", {"zeta", "mid", "beta"})
}

@(test)
ast_completion_comp_lit_bit_field_fields_declaration_order :: proc(t: ^testing.T) {
	source := test.Source {
		main = `package test
		Foo :: bit_field u8 {
			zeta:  u8 | 2,
			alpha: u8 | 3,
			mid:   u8 | 3,
		}
		main :: proc() {
			f := Foo{
				{*}
			}
		}
		`,
	}
	test.expect_completion_label_order(t, &source, "", {"zeta", "alpha", "mid"})
}

@(test)
ast_completion_ranks_type_matching_proc_arg_first :: proc(t: ^testing.T) {
	source := test.Source {
		main = `package test
		Device :: struct { id: int }
		Other :: struct { id: int }
		use_device :: proc(device: ^Device, size: int) {}
		main :: proc() {
			aa_other: ^Other
			aa_int: int
			zz_device: ^Device
			use_device({*})
		}
		`,
	}
	test.expect_completion_label_order(t, &source, "", {"zz_device", "aa_int", "aa_other"})
}

@(test)
ast_completion_ranks_type_matching_proc_arg_first_second_param :: proc(t: ^testing.T) {
	source := test.Source {
		main = `package test
		Device :: struct { id: int }
		use_device :: proc(device: ^Device, size: int) {}
		main :: proc() {
			aa_device: ^Device
			zz_size: int
			use_device(aa_device, {*})
		}
		`,
	}
	test.expect_completion_label_order(t, &source, "", {"zz_size", "aa_device"})
}

@(test)
ast_completion_ranks_proc_returning_matching_type_first :: proc(t: ^testing.T) {
	source := test.Source {
		main = `package test
		Device :: struct { id: int }
		aa_make_int :: proc() -> int { return 0 }
		zz_make_device :: proc() -> ^Device { return nil }
		use_device :: proc(device: ^Device) {}
		main :: proc() {
			use_device({*})
		}
		`,
	}
	test.expect_completion_label_order(t, &source, "", {"zz_make_device", "aa_make_int"})
}

@(test)
ast_completion_ranks_type_matching_comp_lit_field_value_first :: proc(t: ^testing.T) {
	source := test.Source {
		main = `package test
		Device :: struct { id: int }
		Info :: struct { device: ^Device, size: int }
		main :: proc() {
			aa_int: int
			zz_device: ^Device
			info := Info{device = {*}}
		}
		`,
	}
	test.expect_completion_label_order(t, &source, "", {"zz_device", "aa_int"})
}

@(test)
ast_completion_type_matching_filter_drops_mismatches :: proc(t: ^testing.T) {
	source := test.Source {
		main = `package test
		Device :: struct { id: int }
		use_device :: proc(device: ^Device) {}
		make_device :: proc() -> ^Device { return nil }
		make_int :: proc() -> int { return 0 }
		main :: proc() {
			aa_int: int
			zz_device: ^Device
			use_device({*})
		}
		`,
		config = {completion_type_matching = .Filter},
	}
	test.expect_completion_labels(t, &source, "", {"zz_device", "make_device"}, {"aa_int", "make_int", "Device"})
}

@(test)
ast_completion_type_matching_filter_keeps_all_when_nothing_matches :: proc(t: ^testing.T) {
	source := test.Source {
		main = `package test
		Device :: struct { id: int }
		use_device :: proc(device: ^Device) {}
		main :: proc() {
			aa_int: int
			use_device({*})
		}
		`,
		config = {completion_type_matching = .Filter},
	}
	test.expect_completion_labels(t, &source, "", {"aa_int"})
}

@(test)
ast_completion_type_matching_none_keeps_name_order :: proc(t: ^testing.T) {
	source := test.Source {
		main = `package test
		Device :: struct { id: int }
		use_device :: proc(device: ^Device) {}
		main :: proc() {
			aa_int: int
			zz_device: ^Device
			use_device({*})
		}
		`,
		config = {completion_type_matching = .None},
	}
	test.expect_completion_label_order(t, &source, "", {"aa_int", "zz_device"})
}

@(test)
ast_completion_type_matching_untyped_constants :: proc(t: ^testing.T) {
	source := test.Source {
		main = `package test
		AA_NUMBER :: 8
		ZZ_FLAG :: true
		set_flag :: proc(flag: bool) {}
		main :: proc() {
			set_flag({*})
		}
		`,
		config = {completion_type_matching = .Filter},
	}
	test.expect_completion_labels(t, &source, "", {"ZZ_FLAG"}, {"AA_NUMBER"})
}
