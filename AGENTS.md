# AGENTS.md

Notes for coding agents working in this repository.

## Context

- This is a **personal fork** of [ols](https://github.com/DanielGavin/ols), the Odin language server. Changes are not upstreamed, so don't open PRs or shape work for upstream review. Commit on local branches when asked.
- The owner uses **Neovim with blink.cmp**. Neovim runs the binary built here (`cmd = { '/home/alex/Projects/github/ols/ols' }` in `~/.config/nvim/lua/pack.lua`), so after changing server code, rebuild with `./build.sh` and restart the LSP (`:lsp restart`) to try it.

## Build and test

```sh
./build.sh                          # builds ./ols (LLVM codegen takes ~35s)
./build.sh test                     # full test suite (~1100 tests)
./build.sh single_test tests.<name> # one test; comma-separate several names
```

`build.sh test` runs from `tests/` with `-collection:src=../src`. To run tests by hand:

```sh
cd tests && odin test ../tests -collection:src=../src \
  -define:ODIN_TEST_FAIL_ON_BAD_MEMORY=true \
  -define:ODIN_TEST_NAMES=tests.foo,tests.bar
```

Test output is noisy with `[INFO]`/`[WARN]` lines. Filter with `grep -v "^\[INFO\|^\[WARN"`.

Editor diagnostics like `Unknown library collection: 'src'` are false positives: the editor's checker doesn't know the `src` collection. Trust `./build.sh` and the test run instead.

## Layout

- `src/server/` contains the LSP features:
  - `completion.odin`: completion, ranking and type matching
  - `analysis.odin`: type resolution (`resolve_type_expression`, `resolve_comp_literal`)
  - `position_context.odin`: what is under the cursor
  - `action*.odin`: code actions, registered in `action.odin` `get_code_actions`
  - `requests.odin`: parses config from `ols.json` / `init_options`
- `src/common/config.odin` holds the internal `Config`. `src/server/types.odin` holds `OlsConfig`, the JSON shape. When adding an option, update both, `requests.odin`, `README.md` and `misc/ols.schema.json`.
- `src/testing/testing.odin` has the test helpers. Tests live in `tests/*_test.odin`.

## Writing tests

- `{*}` in `test.Source.main` marks the cursor.
- Use `packages = ...` (a `[dynamic]test.Package`) for other packages, and `config = {...}` on the Source for feature flags. A zeroed `Config` is what tests get by default, so make new enum options' default value the zero value.
- Useful helpers:
  - `expect_completion_labels(t, &src, trigger, include, exclude)`
  - `expect_completion_label_order` (order matters)
  - `expect_completion_docs`
  - `expect_action(t, &src, {titles})`; pass `{}` to expect no actions
  - `expect_action_applied(t, &src, title, expected_full_text)`
- Write the test first and confirm it fails without the change.

## Odin gotchas

- `or_return` in a procedure with more than one **unnamed** result doesn't compile. Use `x, ok := f(); if !ok { return {}, false }`.
- `#+private file` files can define helpers with the same name as other files (e.g. `get_line_start_offset`).
- Before resolving a type expression that came from another package's symbol, call `reset_ast_context(ast_context)` and `set_ast_package_set_scoped(ast_context, symbol.pkg)`.

## Fork-specific features

- Struct and `bit_field` fields in composite literal completion are listed in **declaration order** (`CompletionResult.decl_index`).
- Code action **"fill remaining struct fields"** (`action_fill_struct_fields.odin`) inserts missing fields with type-based values. Pointers get the field name; other types get their zero value (`{}`, `0`, `false`, `""`, `nil`, the enum member whose value is 0). Neovim binds it to `<leader>cs`, matched by its exact title, so keep the title stable.
- Option **`completion_type_matching`**: `"rank"` (default), `"filter"` or `"none"`. It uses the expected type at procedure arguments and composite literal field values (`get_target_symbol`, `apply_completion_type_matching`, `symbol_types_differ` in `completion.odin`).

## Checking against a real editor

To check behaviour end to end, drive `./ols` over stdio with a small LSP client script. Send `initialize` (with `initializationOptions` for config), `didOpen`, then `textDocument/completion` or `textDocument/codeAction`. `vendor:sdl3` from the Odin root makes a good large real-world package to test against.
