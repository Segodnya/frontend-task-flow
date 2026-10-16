# Deploy checklist for a change

Build the checklist from a diff. The diff source is passed in `$ARGUMENTS`.

Leave items 4, 6, 7 as `-`: the author fills them in. Fill items 1, 2, 3, 5 using the heuristics below.

## Step 1: determine the diff source

If `$ARGUMENTS` is empty, ask the user via `AskUserQuestion`:

- staged (`git diff --cached`)
- current branch vs master (`git diff $(git merge-base HEAD master)..HEAD`)
- commit range (also ask for `sha1..sha2`)

Default to staged if `git diff --cached --quiet` returns 1, which means there are staged changes.

If `$ARGUMENTS` is set, parse it by this table:

| Input | Command |
| --- | --- |
| `staged`, `cached` | `git diff --cached` |
| `<sha1>..<sha2>` | `git diff <sha1>..<sha2>` |
| `<feature> against <base>` (or `<feature> vs <base>`) | `git fetch origin <base>`, then `git diff $(git merge-base origin/<base> <feature>)..<feature>` |
| `<branch>` is the current branch, or is absent locally while `origin/<branch>` exists | this is a feature branch. Take the base from the open MR: `glab mr list --source-branch <branch> -F json`, field `target_branch`; then proceed as `<feature> against <base>`. If there is no MR, ask for the base via `AskUserQuestion` |
| `<branch>` is not the current branch (e.g. `master`, `develop`) | this is a base: `git diff $(git merge-base HEAD <branch>)..HEAD` |

Branch and base are given by name, without `origin/`. In commands substitute `origin/<base>` for the base so the result does not depend on local state. Write the final "range + base" pair as the first line of the answer, otherwise the reader won't know what went into the checklist.

Trap: `merge-base HEAD <branch>` gives the right answer only when `HEAD` is the feature branch and `<branch>` is the base. If the feature branch itself is passed while `HEAD` is on master, the range comes out empty or reversed. Don't treat that as "no changes". Redefine the base by the table above.

If the input matches nothing, ask again instead of guessing.

## Step 2: collect data from the diff

- `git diff --name-only <source>` gives the list of files (for items 3, 5).
- `git diff --stat <source>` gives the change summary (for item 1).
- `git log --format='%s' <source>` for a range or branch gives the commit messages (for item 1). Skip it for staged.

## Step 3: fill in the items

### Item 1: problem description

State it in one or two sentences from the user or business point of view. What did not work for the end user, or what task was being solved: which scenario was broken, what was missing, what is now possible.

Sources: commit messages, the task ID in the branch name (e.g. `feature/ARC-1211`), the diff itself. The code is how it was solved. Here write what was solved and why.

Bad: "Rewrote `TaskComposeView` to `class extends`, split it into two tabs".
Good: "When creating a meeting from a deal card, the slot time was not saved and the user lost data. Fixed the saving and separated the UI of a regular task and a meeting".

If the commits and the diff give no business meaning (a pure tech refactoring, a linter fix), say so: "Technical refactor/cleanup, does not change user behaviour".

### Item 2: test cases

Generate them from the affected functionality. Determine the area by paths (which screens, endpoints, workers), then write the sub-items:

- 2.1 Positive. The main scenario works: the screen opens, the method runs, the data is saved.
- 2.2 Negative. Errors are handled correctly: invalid data, API failure, timeout.
- 2.3 Destructive. What must not break: deletion, cancellation, double click, concurrent requests, large volumes.
- 2.4 Base functionality. Adjacent features and regression: neighbouring screens and methods that may be affected indirectly.

If the area is unclear, list the affected files and ask the author to clarify.

### Item 3: production environment changes

| Affected | What to write |
| --- | --- |
| `app/cli/mvc/commands/migrations/*.php` | Run migrations: `<file names>` |
| `app/libs/queue/workers/**`, `app/cli/scripts/workers/**` | Restart queue workers |
| `app/cli/scripts/**` (except workers) | Check cron/scripts: `<names>` |
| `app/config/**`, `.env*` | Sync configs: `<names>` |
| `private/**`, `_system/**` | Ask the author (system directories) |
| only `frontend/**` (JS/TS/SCSS/twig) | `-` |

If the paths match no category, write `-`.

### Item 5: rollback plan

The question is whether the changes are backward compatible, and what to do if they are rolled back from production.

Check the diff for signs of backward incompatibility:

- DB migrations (`app/cli/mvc/commands/migrations/*.php`): new columns, tables, indexes. After rollback the old code does not expect the new schema, and data written by the new code may be lost or unreadable. Write: "A reverse migration is required: `<names>`. Check whether data written after the migration will be lost."
- Data format change (API responses, JSON fields in the DB, queue message format): old consumers and clients won't read the new format. Write: "Clear the queue `<name>` before rollback" or "Rollback is safe only if the queue has no messages in the new format".
- Removal or rename of a public method, route, i18n key: external calls and cached translations will break. Write: "After rollback, reset the translation cache / check integrations with `<endpoint>`".
- Configs and env (`app/config/**`, `.env*`): the new variables must be removed. The old code ignores them, but secrets leak into logs. Write: "Roll back the config + reload nginx/php-fpm".
- Frontend only (`frontend/**`, no API or format changes): rollback is safe by restoring the previous build. Write: `No special handling, the changes are backward compatible.`
- Pure refactoring without contract changes: `No special handling, the changes are backward compatible.`

If you found several signs, list them one by one and name the specific files and fields.

## Step 4: output the checklist

Copy the template below with the filled items. Leave items 4, 6, 7 as `-`.

```text
1. Problem description, what was fixed: <filled>
2. Test cases, expected result and affected functionality:
2.1. Positive cases: <filled>
2.2. Negative cases: <filled>
2.3. Destructive cases: <filled>
2.4. Base functionality testing: <filled>
3. Required production environment changes (DB, workers, nginx, etc.): <filled>
4. Deploy specifics: -
5. Rollback plan: <filled>
6. Change type: -
7. Merge request: -
```
