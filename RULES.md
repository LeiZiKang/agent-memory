## Project memory (.agent-memory/)

`.agent-memory/` is the shared memory of every agent that works in a project (Claude Code, Codex, ...). Project facts and decisions that must outlive a session go there. Tool-private memory (Claude auto memory, Codex memories) is for the user's personal preferences only; when the two disagree about the project, `.agent-memory/` wins.

**Where.** Walk up from the working directory to the git root and use the first `.agent-memory/` you find; never make a second one below it. If there is none, create it at the git root (or the open folder) the first time something is worth keeping. Private repo: commit it. Public repo: add `.agent-memory/` to `.gitignore` and never commit it.

**What goes where.** Each fact has exactly one home.

| File | Holds | Lifecycle |
|---|---|---|
| `handoff.md` | Where the work stands now: done, in progress, next step, open questions | Rewrite the whole file when a stretch of work ends. Never append dated sections; git has the history. |
| `decisions/YYYY-MM-DD-title.md` | A choice and the reason for it | Keep. When overturned, set `status: superseded` and `superseded_by`. |
| `findings/YYYY-MM-DD-title.md` | Verified facts, gotchas, research results | Same as decisions. |
| `INDEX.md` | One-line purpose, one-line current state, list of decisions and findings | Replace the state line, don't add more. List records only. |

Records start with frontmatter: `type`, `date`, `author`, `status` (active / superseded), `superseded_by`. Before adding a record, check whether an existing one should be updated or superseded instead; writing nothing is a valid outcome. Old material can go to `archive/`, which is never loaded automatically.

**Keep out.** Anything the code, git log, README or AGENTS.md / CLAUDE.md already says (standing rules for agents belong in those files, not here). Secrets. Details that only matter to this conversation. Volatile state such as logins, "waiting for X", queue contents: check it live instead. If you must record it, stamp it `(as of YYYY-MM-DD)` and re-check before telling the user it is true.

**Sharing.** Re-read a file right before you edit it; another agent may have changed it. Edit in place, don't regenerate from memory. Put your name (`author: claude-code`, `codex`, ...) in frontmatter and the handoff header.

**Checks.** Session start injects INDEX, handoff and any `memory-check` warnings (size, broken links, missing status, stale handoff). Fix what you can in passing.
