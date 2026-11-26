# AGENTS.md

> ## 🚨 REQUIRED — READ BEFORE ANY CHANGE (CODE OR TEXT)
>
> **Every AI-generated function or code block—including tests—MUST have a
> comment immediately above it that says exactly: `AI-generated code
> (unreviewed by a human)`.**
>
> **Every AI-generated or agent-edited block of text—including documentation
> and this file—MUST have a comment immediately above it that says exactly:
> `AI-generated documentation (not reviewed by a human)`.**
>
> Keep each marker until a human has reviewed the content; do not put markers
> only at file level. Use `# ...` in Bash/Python/config and `<!-- ... -->`
> in Markdown. In Python, place the code marker above the `def`/`class` and the
> documentation marker above its docstring when both are generated.

## Clean code standards

Clean code is easy for everyone on the team to understand, read, change,
extend, and maintain.

### General principles

1. Follow standard conventions.
2. Keep it simple; reduce complexity wherever possible.
3. Leave the campground cleaner than you found it.
4. Find and fix root causes.

### Design principles

1. Keep configurable data at a high level.
2. Prefer polymorphism to `if`/`else` or `switch` statements.
3. Separate multithreading code.
4. Avoid overconfigurability.
5. Use dependency injection.
6. Follow the Law of Demeter: a component should know only its direct
   dependencies.

### Understandability

1. Be consistent; handle similar things in similar ways.
2. Use explanatory variables.
3. Encapsulate boundary conditions in one place.
4. Prefer dedicated value objects to primitive types.
5. Avoid logical dependencies between methods.
6. Prefer positive conditionals.

### Naming

1. Choose descriptive, unambiguous names.
2. Make meaningful distinctions.
3. Use pronounceable and searchable names.
4. Replace magic numbers with named constants.
5. Avoid encodings such as type prefixes.

### Functions

1. Keep functions small and focused on one task.
2. Use descriptive names.
3. Prefer fewer arguments.
4. Avoid side effects.
5. Avoid flag arguments; use separate functions for distinct behaviors.

### Comments

1. Prefer clear code over comments.
2. Avoid redundant or obvious comments.
3. Do not add noise.
4. Do not add comments to closing braces.
5. Remove commented-out code.
6. Use comments to explain intent, clarify code, or warn about consequences.

### Source structure

1. Separate concepts vertically.
2. Keep related code close together.
3. Declare variables near where they are used.
4. Keep dependent and similar functions close together.
5. Order functions from higher-level to lower-level operations.
6. Keep lines short.
7. Avoid horizontal alignment.
8. Use whitespace to group related and separate unrelated code.
9. Preserve consistent indentation.

### Objects and data structures

1. Hide internal structure.
2. Prefer data structures.
3. Avoid hybrids that mix object and data-structure behavior.
4. Keep components small and focused.
5. Limit the number of instance variables.
6. Base classes should know nothing about derived classes.
7. Prefer multiple focused functions to passing code into a function to select
   behavior.
8. Prefer non-static methods to static methods.

### Tests

1. Use one assertion per test.
2. Keep tests readable, fast, independent, and repeatable.

### Code smells

Watch for:

1. **Rigidity:** Small changes require many follow-up changes.
2. **Fragility:** A change breaks many unrelated parts.
3. **Immobility:** Reusing a component elsewhere requires excessive effort or
   risk.
4. Needless complexity.
5. Needless repetition.
6. Opacity: code that is difficult to understand.

Source: [Clean Code](https://gist.githubusercontent.com/wojteklu/73c6914cc446146b8b533c0988cf8d29/raw/c7a44d774fc3b09a0d5f0f58888550ba0ac694b9/clean_code.md)

## Documentation conventions

Document functions and non-obvious blocks with tagged `#` comment blocks
(docblocks). These conventions apply to every shell script in the repository,
including the files under `tests/`.

### File headers

Every script starts with its shebang followed by a tagged header comment that
describes the whole file. Use `@description` for its purpose and, when useful,
`@note` for terminology or context that applies throughout the file:

```sh
#!/usr/bin/env bash
# @description Config-resolution tests: environment, CLI, and
#              installed/legacy/repo fallback.
# @note  A "header" is ARCHIVE_HEADER: the prefix of the archive filename
#        before the timestamp and .tar.gz suffix.
```

Align wrapped lines under the text of their tag: continuations of
`@description` start under the description text, and continuations of `@note`
start under the note text.

`@file` must name the file it heads, and `@description` is required in every
file header. `@author`, `@created`, and `@modified` are optional metadata carried
by top-level scripts: keep them accurate, and update `@modified` to the current
date in `YYYY-MM-DD` form whenever you change that file. `@description` is the
only description tag; `@purpose` is legacy and should be renamed when found.

### Docblock format

Place the docblock immediately above the required
`AI-generated code (unreviewed by a human)` marker, so that marker stays on the
line directly above the function it covers.

```sh
# @description What the function does and why it exists.
# @param $1 What the first argument is.
# @return 0 on success; 1 on failure.
# AI-generated code (unreviewed by a human)
function_name() {
```

Use these tags:

1. `@description` — one or two sentences about intent, not a restatement of the
   function name. Say why the behavior matters when that is not obvious.
2. `@param $N` — one line per argument, including `$@` for forwarded arguments.
   Omit the tag when the function takes none.
3. `@return` — the exit status or printed value callers rely on. For a `test_*`
   function, note that the status comes from its final assertion.

Document every function with a docblock, including small logging helpers.
Describe printed values with `@return` rather than a separate `@output` tag, and
use `@description` in place of legacy `@purpose`.

### Explaining blocks of code

Use short `#` comments inside a function to explain *why* a non-obvious block
exists — for example, generated shim contents, environment overrides, scratch
isolation, or timestamp arithmetic. Prefer a docblock when the whole function
is the subject. Do not narrate each line, and do not add closing-brace comments.

### Test documentation

Give every `test_*` function a `@description` naming the behavior under test
and the observable assertion, plus a `@return` identifying the assertion as the
source of its status.

## Testing

Automated tests live in `tests/` and use a dependency-free Bash harness, so the
repository stays script-only and needs no installed test framework.

Run the whole suite, or a single test file:

```sh
bash tests/run.sh
bash tests/run.sh test_config.sh
```

Conventions:

1. Test files are `tests/test_*.sh`; each defines one or more `test_*` functions.
2. Make one observable assertion per test using the helpers in
   `tests/test-lib.sh`.
3. The harness gives every test a disposable scratch directory and local shims.
   Never point a test at the real `$HOME`, `/usr/local/bin`, a notification
   daemon, or an SSH server.
4. `tests/run.sh` exits non-zero when any assertion fails.
5. Keep the `AI-generated code (unreviewed by a human)` marker directly above
   every new function.
