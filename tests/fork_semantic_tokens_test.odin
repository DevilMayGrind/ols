package tests

import "core:testing"

import test "src:testing"

@(test)
semantic_tokens_global_variables :: proc(t: ^testing.T) {
	packages := make([dynamic]test.Package, context.temp_allocator)

	append(&packages, test.Package{pkg = "my_package", source = `package my_package
		Pkg_Global: int
		PKG_CONST :: 1
		`})

	src := test.Source {
		main = `package test
		import "my_package"
		g: int
		K :: 3
		f :: proc(p: int) {
			a := g
			g = p
			b := my_package.Pkg_Global + my_package.PKG_CONST + K
		}
		`,
		packages = packages[:],
	}

	test.expect_semantic_tokens(t, &src, {
		{1, 10, 10, .Namespace, {}},                   // [0]  "my_package"
		{1, 2,  1,  .Variable,  {.GlobalScope}},       // [1]  g
		{0, 3,  3,  .Type,      {.ReadOnly}},          // [2]  int
		{1, 2,  1,  .Variable,  {.ReadOnly}},          // [3]  K
		{1, 2,  1,  .Function,  {.ReadOnly}},          // [4]  f
		{0, 10, 1,  .Parameter, {}},                   // [5]  p
		{0, 3,  3,  .Type,      {.ReadOnly}},          // [6]  int
		{1, 3,  1,  .Variable,  {}},                   // [7]  a
		{0, 5,  1,  .Variable,  {.GlobalScope}},       // [8]  g
		{1, 3,  1,  .Variable,  {.GlobalScope}},       // [9]  g = p
		{0, 4,  1,  .Parameter, {}},                   // [10] p
		{1, 3,  1,  .Variable,  {}},                   // [11] b
		{0, 5,  10, .Namespace, {.ReadOnly}},          // [12] my_package
		{0, 11, 10, .Variable,  {.GlobalScope}},       // [13] Pkg_Global
		{0, 13, 10, .Namespace, {.ReadOnly}},          // [14] my_package
		{0, 11, 9,  .Variable,  {.ReadOnly}},          // [15] PKG_CONST
		{0, 12, 1,  .Variable,  {.ReadOnly}},          // [16] K
	})
}

@(test)
semantic_tokens_global_variables_not_locals :: proc(t: ^testing.T) {
	src := test.Source {
		main = `package test
		S :: struct { x: int }
		s: S
		f :: proc() {
			arr: [2]int
			_ = arr
			_ = s.x
		}
		`,
	}

	test.expect_semantic_tokens(t, &src, {
		{1, 2,  1, .Struct,   {.ReadOnly}},    // [0]  S
		{0, 14, 1, .Property, {}},             // [1]  x
		{0, 3,  3, .Type,     {.ReadOnly}},    // [2]  int
		{1, 2,  1, .Variable, {.GlobalScope}}, // [3]  s
		{0, 3,  1, .Struct,   {.ReadOnly}},    // [4]  S
		{1, 2,  1, .Function, {.ReadOnly}},    // [5]  f
		{1, 3,  3, .Variable, {}},             // [6]  arr
		{0, 8,  3, .Type,     {.ReadOnly}},    // [7]  int
		{1, 7,  3, .Variable, {}},             // [8]  arr
		{1, 7,  1, .Variable, {.GlobalScope}}, // [9]  s
		{0, 2,  1, .Property, {}},             // [10] x
	})
}
