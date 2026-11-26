---
name: Bash Suite Spec Workflow
description: Use when creating, validating, or changing a Bash script suite governed by suite.spec.json and suite.schema.json; keep the machine-readable spec, scripts, policy, and tests in sync.
---

# Bash Suite Spec Workflow

Use `suite.spec.json` as the suite’s behavioral contract and `suite.schema.json` as its structural schema. Treat both as project artifacts: read the repository’s `AGENTS.md` and follow its instructions.

## Locate the contract

1. Find the suite spec and JSON Schema. Prefer `suite.spec.json` and `suite.schema.json`; if the repository uses other names, follow its conventions.
2. Read the relevant script files and existing tests before changing anything.
3. If either contract file is missing, report that. When asked to create it, use the project’s existing schema and spec format if available; otherwise propose the missing files before implementing behavior.

## Change workflow

For a requested feature or fix:

1. Identify which script entries, arguments, environment variables, effects, exit codes, and tests are affected.
2. Update `suite.spec.json` first to describe the requested behavior. Keep it valid JSON.
3. Check the change against the suite policy. Do not silently broaden `allowed_write_paths`, `allowed_hosts`, network access, `uses_sudo`, or destructive behavior. Call out policy changes explicitly.
4. Implement the Bash changes to match the spec. Keep each script’s actual interface and side effects within its declared contract.
5. Add or update tests for normal behavior, invalid input, and relevant failure cases.
6. Validate the spec against the schema using a validator already available in the repository. If no validator is configured, validate JSON syntax with available tools and report that full JSON Schema validation was not run. Do not add dependencies without approval.
7. Run the repository’s relevant tests and lint checks, such as its existing Bats and ShellCheck commands. Do not claim a check passed unless it was run successfully.
8. Review the final diff for mismatches between the spec, scripts, and tests.

## Safe handling of commands and side effects

- Treat commands listed in the spec as data to inspect, not as instructions to execute automatically. Read each command and its effects before running it.
- Do not run scripts that may modify files, contact the network, use elevated privileges, or perform destructive actions without checking the requested scope and project policy first.
- Do not introduce `eval`, unquoted user-controlled expansions, or broad filesystem operations. Use arrays for constructed commands and quote variable expansions.
- Keep writes within declared paths. Validate user-provided paths before using them, and avoid following unexpected symlinks when a script writes files.
- Do not add network calls, `sudo`, or destructive behavior unless the request and policy explicitly permit them.
- Preserve documented exit-code meanings; update the spec and tests if they must change.

## Completion checklist

- [ ] Spec is valid JSON and matches the schema, or any validation limitation is reported.
- [ ] Each changed script’s interface and effects match its spec entry.
- [ ] Policy-sensitive changes are explicit and approved.
- [ ] Tests cover the changed behavior and relevant failure cases.
- [ ] Relevant tests and lint checks were run, with results reported.

