# Frontend task

- no `git add` / `commit` / `push` and no posting to GitLab without my explicit request. Exception: the `mr-ready` skill may `git add <its files>`, `commit`, plain `push` and post to the MR, but never `--force`/`--amend`/`rebase` and never resolve threads
- no `yarn build`. Verify with the binaries: `tsc --noEmit`, `eslint`, `jest`
- Jira: `jira issue view <KEY>`, not WebFetch (the page is behind auth)
- a subagent's report is a hypothesis. Demand "command + its output" from a subagent
- at a fork (unknown backend response shape, two UX options): `AskUserQuestion` before the first edit
- parallel subagents work on disjoint files, otherwise they overwrite each other
- chrome-devtools screenshots go to `./.tmp-shots/` inside the project (outside the workspace MCP answers `Access denied`). Measure geometry in the browser, don't compute it from CSS

## GitLab via glab

- reply to a thread: `glab api -X POST projects/<ns%2Frepo>/merge_requests/<iid>/discussions/<discussion_id>/notes -f body='…'`
- resolve a thread: `glab api -X PUT "projects/<ns%2Frepo>/merge_requests/<iid>/discussions/<discussion_id>?resolved=true"`. The flag is a query param, not a body
- a new thread on a file line is JSON only: `-H 'Content-Type: application/json' --input -` with `position{…}` and `diff_refs` from the MR. `-f position[...]` returns 201 but creates a thread with no line position
- `--input -` without `Content-Type: application/json`: PUT answers 415, POST silently creates no note even though stdout contains an `id`
- verify success via the `…/discussions` listing (a line thread has `notes[0].position`), not via the exit code
