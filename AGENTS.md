# XLSXir Maintainer Instructions

XLSXir is an Elixir library for reading values from XLSX files. It extracts ZIP
parts, parses XML with Erlsom SAX handlers, and exposes worksheet data through
ETS tables or a row stream. It does not evaluate formulas or reproduce Excel's
presentation layer.

## Development

Fetch the locked dependencies, compile, and run tests with:

```sh
mix deps.get
mix compile
mix test
```

Run focused tests while developing, then the complete suite:

```sh
mix test test/xlsxir_test.exs
mix test test/xlsxir_test.exs:10
mix test
```

There is currently no `.formatter.exs` defining inputs. Format only the files
being changed, using explicit paths, and inspect the diff for unrelated churn:

```sh
mix format path/to/changed_file.ex
mix format --check-formatted path/to/changed_file.ex
```

Do not perform repository-wide formatting as part of an unrelated fix. Use
other project-specific quality checks when they are already configured; do not
silently introduce new tools or stricter gates.

Documentation generation is configured through ExDoc. When checking it, use a
fresh output directory outside tracked `doc/`, for example:

```sh
mix docs --output /tmp/xlsxir-docs-review
```

## Toolchain and Recorded Baseline

The baseline recorded on 2026-09-16 is historical evidence, not a guarantee for
future revisions. Recheck relevant commands after changes.

- `mix.exs` declares Elixir `~> 1.9` (`>= 1.9.0` and `< 2.0.0`).
- No explicit OTP requirement or exact toolchain pin is configured.
- `.travis.yml` lists Elixir 1.4.5 through 1.8.0, below the declared minimum.
  Do not treat that matrix as the current support policy.
- On Elixir 1.20.4 / OTP 29, locked dependency fetching and compilation passed;
  all 76 tests passed (42 doctests and 34 explicit tests).
- Compilation emitted unused `Logger` requires and a `ParseWorkbook` struct
  update warning, plus extensive dependency warnings.
- Locked Earmark 1.3.1 was reported retired. Erlsom 1.5.0 emitted warnings for
  removed OTP APIs, including `httpd_util:hexlist_to_integer/1` and
  `http_uri:parse/1`. Passing tests do not establish that every such path works.
- ExDoc 0.19.3 failed during documentation generation in
  `ExDoc.Retriever.get_impls/1`, with an `ArgumentError` from `Keyword.keys/1`.
- No Credo, Dialyzer, formatter gate, coverage threshold, or custom quality-check
  alias was configured.
- In the Codex sandbox, Mix initially failed to acquire its TCP filesystem lock
  with `:eperm`. Approved execution outside the sandbox succeeded. Treat this as
  an environment restriction; follow the tool's approval mechanism rather than
  changing project code or disabling locking.

Preserve the declared Elixir support range until the maintainer approves a
change. Ask for a toolchain/support decision before raising the minimum or
establishing an OTP matrix. Do not assume the locally installed runtime is the
minimum supported version. Report which versions were actually tested.

## General Principles

- Maintain backwards compatibility unless explicitly instructed otherwise.
- Do not change the public API without discussing it first.
- Prefer clear, idiomatic Elixir compatible with the approved support range.
- Avoid adding dependencies unless clearly justified.
- Add tests for every bug fix. Prefer regression tests that fail before the fix.
- Prefer small, focused changes over broad refactoring.
- Do not perform unrelated cleanup while fixing an issue.
- Explain significant architectural changes before implementing them.
- Preserve observable behavior unless a behavior change is explicitly approved.
- Preserve existing user changes and keep source, dependency, documentation,
  and formatting changes scoped to the requested work.
- Do not commit generated files unless they are intentionally tracked and their
  update is part of the task. `doc/` is tracked but contains stale generated
  documentation; do not regenerate it incidentally.
- Keep `CODEX_WORKFLOW.md` ignored; do not force-add it.

## Architecture and Ownership

- `Xlsxir` is the public facade and application entry point.
- `XlsxFile` coordinates extraction, metadata, worksheet selection, streaming,
  timing, and cleanup; `Unzip` handles archive discovery and extraction.
- `XmlFile` abstracts memory versus disk input; `SaxParser` drives Erlsom with
  10,000-byte chunks and closes its input handle.
- `ParseString`, `ParseStyle`, and `ParseWorkbook` prepare lookup tables.
- `ParseWorksheet` converts cells and stores rows; `StreamWorksheet` delegates
  cell handling but emits rows through a request/reply protocol.
- `ConvertDate` and `ConvertDateTime` interpret Excel serial values.
- `StateManager` is the supervised owner of all public ETS tables. ETS tables
  are not processes. Result tables survive caller exit and require `close/1`.
  A StateManager failure destroys its tables.
- `SaxError` also serves as intentional early-stop control flow for `peek`.

Before changing resource management, trace successful completion, partial
initialization, exceptions, stream early termination, parser failure, and caller
exit. Do not assume process exit cleans tables owned by StateManager.

## Investigation Before Implementation

For non-trivial changes:

1. Investigate existing behavior and read relevant documentation and tests.
2. Identify the relevant modules and code paths.
3. Reproduce the issue where possible.
4. Explain the root cause, distinguishing verified behavior from hypotheses.
5. Propose an implementation and identify compatibility risks.
6. Identify tests that should be added or changed.
7. Wait for approval before significant architectural or public behavior changes
   unless the maintainer has already explicitly authorized that change.

Routine implementation details within an approved scope do not require repeated
approval. Investigation findings are not authorization to fix unrelated issues.

## Tests

For bug fixes:

1. Reproduce the bug.
2. Add a regression test demonstrating the problem before the fix when practical.
3. Implement the smallest reasonable fix.
4. Run focused tests.
5. Run the complete test suite, including doctests.
6. Report commands, runtime versions, warnings, and unrelated failures.

Do not weaken or remove tests merely to make a change pass without explaining
why the existing expectation is incorrect. Do not claim checks passed when they
were skipped or blocked.

Use `on_exit` or equivalent reliable cleanup for ETS tables and temporary
resources in new tests. Use isolated temporary directories where practical.
Do not assume test-process exit releases StateManager-owned tables.

For file-format fixes, prefer a small fixture or generated XML/archive that
isolates the problem. Record fixture provenance when relevant and never include
private workbook data. Test memory and file extraction, and streaming versus
materialized results, when the affected behavior spans those paths.

Do not equate boundary-address tests with load tests: the existing maximum-row
fixture contains one cell at row 1,048,576, not one million populated rows.
Use bounded tests for parser failures so regressions cannot wait indefinitely.

## Public API and Compatibility

Treat documented/public functions, return values, errors, options, structs,
resource lifetimes, and observable behavior as compatibility-sensitive. Internal
modules are also documented; do not assume a public `def` is unused externally.

Before changing public behavior:

1. Identify existing documented and implemented behavior; documentation may be
   stale, so reconcile discrepancies explicitly.
2. Search tests and usage examples.
3. Explain the compatibility impact, including callers relying on existing bugs.
4. Determine whether the change requires a major version or migration guidance.
5. Wait for maintainer approval if compatibility may be affected and that change
   has not already been authorized.

Pay particular attention to these existing contracts and discrepancies:

- `multi_extract` returns a list for all sheets and a tuple for one sheet. Its
  fourth argument is ignored; options occupy the fifth position.
- `extract` is deprecated in prose but remains used internally and in tests.
- Sheet indices are zero-based; row numbers are one-based. `get_mda` uses
  zero-based map indices. Cell references use Excel coordinate notation.
- Values include `nil`, strings, numbers, booleans, date/time tuples, and
  `NaiveDateTime`. Formula results are cached values, and error cells are strings.
- Stored rows are `{row_number, [[cell_reference, value], ...]}`; worksheet
  metadata is `{:info, :worksheet_name, name}`. Query patterns depend on tuple
  arity, and row counts assume one metadata entry.
- Empty rows are omitted. `get_list` compresses row gaps; `get_mda` preserves
  row-number gaps. Counts describe stored rows/cells, including nil placeholders.
- Materialized extraction fills internal column gaps; streaming currently does
  not. Trailing padding is an explicit mutating operation.
- Extraction defaults to memory; streaming defaults to disk. Both prepare shared
  metadata and extract all discovered sheets, even for a single requested sheet.
- Errors are not uniformly tagged tuples: some paths raise, and parser-process
  failure can leave a stream waiting without a response.

## XLSX Format Risks

The following are investigation targets, not permission to change behavior:

- Worksheet discovery assumes `xl/worksheets/sheetN.xml`; selection and naming
  conflate filename numbers, sheet indices, and workbook sheet IDs. Workbook
  relationships are not resolved, and all-sheet sorting is lexical.
- Gap filling assumes valid ascending references. Rows starting at `AA` expose a
  leading-padding bug; duplicate/backward references can make forward filling
  fail to terminate.
- `peek` stops when a nonempty row number equals the limit, rather than after a
  count of emitted rows. Sparse rows can bypass the stop condition.
- Worksheet character events overwrite prior text rather than accumulating it.
  Check chunk boundaries, rich inline runs, and SAX end-event tuple shapes.
- Style classification uses built-in ID lists and regex heuristics; quoted
  literals, colors, locale markers, and elapsed-time formats need care.
- Workbook `date1904` is ignored. Integer and fractional date paths disagree near
  the 1900 boundary, and numeric spelling can affect the output type.
- Missing shared strings/styles, invalid lookup indices, empty sheets, cached
  formula results, metadata attributes, namespaces, and producer-specific XML
  deserve explicit cases when relevant.
- ZIP validation is not full OOXML validation. Large archives, sparse wide rows,
  and eager shared metadata can have substantial resource costs.
- Exceptional cleanup, streaming failure propagation, and timer arithmetic have
  known weaknesses; keep fixes independently reviewable.

## Pull Requests

When analyzing an existing PR:

1. Read its description, full discussion, and diff.
2. Explain the problem it attempts to solve.
3. Determine whether the problem still exists on the current default branch.
   Verify the branch name and freshness; do not assume it is named `main`.
4. Review the implementation and identify compatibility concerns.
5. Determine whether the implementation has become stale.
6. Run relevant tests where practical and identify missing tests.
7. Explain whether the original implementation can reasonably be adapted or
   whether a fresh implementation would be clearer.
8. Do not merge, close, comment on, or otherwise modify the PR on GitHub without
   explicit maintainer approval.

## Issues

When analyzing an issue:

1. Read the complete issue and discussion.
2. Determine what behavior is reported or requested.
3. Check relevance against the current default branch, stating the revision used.
4. Reproduce or verify bugs where possible.
5. Identify the root cause or relevant implementation area.
6. Identify related issues or PRs.
7. Propose an implementation or resolution and regression tests.
8. Do not close, comment on, or otherwise modify the issue without explicit
   maintainer approval.

## Git and GitHub Safety

Unless explicitly instructed, do not:

- Push branches or create/update remote pull requests.
- Merge or close pull requests or issues.
- Post GitHub comments or other messages.
- Create releases or publish packages.
- Force-push or rewrite shared history.
- Delete branches or modify repository settings.

Local branches and local commits may be created when requested. Read-only GitHub
investigation does not authorize remote mutations. Preserve uncommitted user
work; never reset or overwrite it to obtain a clean baseline.

## Dependencies

Before adding or upgrading dependencies:

1. Explain why the dependency or upgrade is needed.
2. For additions, consider whether existing dependencies or the standard library
   can reasonably provide the functionality.
3. Consider compatibility with the declared/approved Elixir and OTP policy.
4. Identify potentially breaking changes and relevant upstream release notes.
5. Avoid unnecessary dependency and lockfile churn.

For baseline checks, fetch the locked dependencies rather than upgrading them.
Keep runtime dependency changes separate from documentation-tool upgrades where
practical. Do not treat an old or retired dependency as permission to replace it
during unrelated work. Report dependency failures separately from project bugs.

## Reporting Completed Work

### Maintenance Plan and Session Handoff

`plan.md` is the local source of truth for maintenance progress and the next
action. It is intentionally ignored by Git. Keep it ignored; do not force-add
it. The backlog report contains investigation evidence, not live completion state.

At the start of maintenance work, read `plan.md`, especially "Current progress
and resume point", the relevant phase, and recent activity entries. Check the
working tree and reconcile recorded state with actual files/revisions before
continuing. Do not repeat completed work unless new changes, failures, or stale
evidence justify revalidation. If the plan is missing in a fresh checkout, say
so and reconstruct only verifiable state from available records; never infer
that tasks were completed or approved.

Update the plan immediately after completing each work item, recording a
decision, or encountering a blocker; also update it before ending a maintenance
turn or handing work off. Do not wait until an entire phase is finished.

1. Update the relevant checkbox, phase status, and any affected backlog routing
   row. For table-only work, record item status explicitly in that row. Use the
   phase ID plus issue/PR number or task description to identify the work.
2. Mark a checkbox complete only when its stated work and validation are done.
   Use `not started`, `in progress`, `awaiting approval`, `blocked`, `deferred`,
   or `complete` for explicit status. Keep partial, blocked, and deferred work
   unchecked and explain what remains. Complete a phase only when its exit
   criteria are met; an approved deferral is not a completed fix.
3. Append a dated activity entry with task ID, result, changed files or revision,
   validation commands/results, unresolved warnings, and related item links.
   Record approvals with their exact scope and source; a proposed plan is not
   an approval. Preserve previous entries and record corrections explicitly.
4. Update "Current progress and resume point": last completed item, current
   work, blockers/decisions, and one concrete next action. Include enough context
   to resume without the chat history. Replace stale next actions rather than
   leaving contradictory instructions.
5. Distinguish local implementation, validated changes, merged changes, and
   published fixes. Record verified GitHub actions only after they occur; local
   work does not mean a PR was merged or an issue was closed.
6. Keep durable evidence or summaries in the project records. `/tmp` paths may
   be useful supplementary evidence but must not be the only way to understand
   the result. Do not record secrets, tokens, or private workbook contents.

Updating progress is authorized as part of the ongoing maintenance workflow;
it does not authorize new code changes or GitHub mutations. Preserve user edits
to the plan, and reconcile its status summary, checkboxes, routing rows, and
activity log before reporting completion. Mention the updated resume point in
the final response when maintenance progress changes.

### Completion Report

Explain what changed, why, the affected behavior, and any remaining compatibility
risks. List validation commands and their results, including warnings, skipped
checks, and environment restrictions. Separate existing failures from new ones.
Do not silently repair unrelated baseline problems.
