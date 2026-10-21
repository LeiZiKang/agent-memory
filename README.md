# agent-memory

Shared, plain-file project memory for Claude Code and Codex (and any agent that reads files). One `.agent-memory/` folder per project, ~25 lines of rules, and a linter that tells agents when the memory is rotting.

[简体中文](README.zh-CN.md)

## Why

I switch between Claude Code and Codex on the same projects. Each has its own private memory, so each one starts blind to what the other did. A shared `.agent-memory/` folder fixed that. After a month of daily use across ~30 projects, it broke in a different way:

- **Append-only growth.** "Update the current state" was read as "add a line". One handoff reached 56 KB with 35 dated sections; one INDEX had 31 "current state" bullets, injected into every session.
- **Stale state presented as fact.** "Logged out of site X", "waiting for Y" went stale in a day, and the next agent reported them to me as current.
- **The same rule in four places.** Rules copied into the profile, handoff, decisions and CLAUDE.md drifted apart.
- **No mechanical check.** Everything depended on agents behaving.
- **A hook that forced writes.** A Stop hook blocked the agent whenever files changed but memory didn't. Agents complied by appending something every turn.
- **Two parallel memories.** Codex's own memories (a 16 KB summary, 140+ KB behind it) held project facts too, and could contradict the shared folder.

The first version had more rules. The fix was fewer: say where things live and when they die, and leave the thinking to the model.

## How it works

```
your-project/
└── .agent-memory/
    ├── INDEX.md       one-line purpose, one-line current state, list of records
    ├── handoff.md     where the work stands now; rewritten whole, never appended
    ├── decisions/     YYYY-MM-DD-title.md, one choice + why, status: active|superseded
    └── findings/      YYYY-MM-DD-title.md, verified facts and gotchas
```

| Piece | What it does |
|---|---|
| [`RULES.md`](RULES.md) | The whole rule set. Claude Code reads it through an `@import` in `~/.claude/CLAUDE.md`; Codex gets a copy inside `~/.codex/AGENTS.md` (`sync.sh`). |
| `hooks/memory-session-start.sh` | SessionStart hook: finds the nearest `.agent-memory/`, injects `INDEX.md` + `handoff.md` (with its age) + linter warnings. |
| `hooks/memory-check.sh` | The linter. Also runnable by hand. |

`memory-check` warns about:
- `handoff.md` over 6 KB, older than 7 days, or with 3+ dated headings (append-only smell)
- a "waiting / running" section that is 2+ days old
- `INDEX.md` over 8 KB, or more than 3 current-state bullets
- links in `INDEX.md` that point nowhere; records not listed in `INDEX.md`
- records without `status`, or `superseded_by` pointing at a missing file
- facts stamped `(as of YYYY-MM-DD)` older than 3 days

Limits are env vars (`AGENT_MEMORY_MAX_HANDOFF`, `AGENT_MEMORY_MAX_INDEX`, `AGENT_MEMORY_STALE_DAYS`, `AGENT_MEMORY_VOLATILE_DAYS`). Warnings never block; the agent sees them at session start and fixes what it can.

See [`examples/demo-app/.agent-memory/`](examples/demo-app/.agent-memory/) for a small, healthy memory.

## Design choices

1. **Rules say where and when, not how.** Where a fact lives, when it gets rewritten or superseded, what stays out. No templates for how to think.
2. **One home per fact.** Standing rules for agents go in `AGENTS.md` / `CLAUDE.md`. Memory holds project knowledge only.
3. **The handoff is a snapshot, not a log.** Overwrite it. Git keeps history.
4. **Volatile state stays out.** Logins, queues, "waiting for": check them live. If you must write one, stamp the date and let the linter nag.
5. **Supersede, don't delete** decisions and findings, so the reasoning trail stays.
6. **Check mechanically, nudge softly.** A linter at session start beats more rules in the prompt.
7. **No forced writes.** There is no Stop hook. Staleness is caught at the next session start instead of by making every turn write something.
8. **Private memory is for preferences.** Claude auto memory and Codex memories keep how the user likes to work; project facts and decisions live only in `.agent-memory/`, which wins on conflict.
9. **Plain files, no server.** Readable by any agent, diffable, works offline, lives in git (private repos) or `.gitignore` (public repos).

## Ideas borrowed

Most of this is other people's ideas, cut down to plain files.

| Idea | From | How it shows up here |
|---|---|---|
| Small always-in-context tier with hard size limits; everything else fetched on demand | [Letta / MemGPT](https://github.com/letta-ai/letta) core vs. archival memory | Only `INDEX.md` and `handoff.md` are injected, each capped; records are read when relevant; `archive/` is never loaded. |
| A short index loaded at start, topic files read on demand | Claude Code auto memory (`MEMORY.md` + topic files) | `INDEX.md` lists records instead of containing them. |
| Hot / warm / cold tiers with rotation | [agent-work-mem](https://github.com/daystar7777/agent-work-mem) v2 | `archive/` as the cold tier for old handoff text; git as the full log. |
| On every write, choose ADD / UPDATE / DELETE / NOOP against what exists | [mem0](https://github.com/mem0ai/mem0) | Rule: before adding a record, check whether one should be updated or superseded; writing nothing is fine. |
| Facts carry validity time and get invalidated, not erased | [Zep / Graphiti](https://github.com/getzep/graphiti) bi-temporal edges | `(as of YYYY-MM-DD)` stamps the linter ages out; `status: superseded` + `superseded_by`. |
| Immutable decision records with a status | Architecture Decision Records (Michael Nygard) | `decisions/` is ADR-lite. |
| "Active context" is current state, not a log | [Cline Memory Bank](https://docs.cline.bot/features/memory-bank) | `handoff.md` is rewritten whole. |
| Lint the memory, not just the code | [ShareMemory](https://github.com/ycl-2004/ShareMemory) | `memory-check`. |
| One canonical instruction file, tool files point at it | [AGENTS.md](https://agents.md) | One `RULES.md`; Claude imports it, Codex gets a synced copy. |

Considered and left out: LLM-driven consolidation passes (Codex memories, Generative Agents-style reflection) and vector search (mem0, Letta archival). Both are useful at scale, but need a model or a database in the loop; at project scale, git history plus `grep` is enough.

## Working with tool-private memory

Claude Code and Codex each keep their own memory. agent-memory doesn't turn them off; it gives them a lane:
- **Private memory:** the user's preferences and habits, which are the same across projects.
- **`.agent-memory/`:** project facts, decisions and current state. The rules say it wins on conflict.

Codex memories are controlled in `~/.codex/config.toml` (back the file up first):

```toml
[memories]
use_memories = true        # inject memory_summary.md at session start
generate_memories = true   # keep learning from finished threads
```

There is no "preferences only" switch. If you see Codex repeating stale project facts from its own memory, set `generate_memories = false` to freeze it, or `use_memories = false` to stop injecting it. You can also use `/memories` for a single chat.

## Install

Requires `bash`, `jq`, macOS or Linux.

```bash
git clone https://github.com/LeiZiKang/agent-memory
cd agent-memory
bin/install.sh            # or: bin/install.sh --lang zh-CN
```

The installer is idempotent and backs up every file it touches (`*.bak-<timestamp>`). It also removes the Stop hook that earlier versions installed. It:
1. copies rules and hooks to `~/.config/agent-memory/`
2. Claude Code: adds `@~/.config/agent-memory/RULES.md` to `~/.claude/CLAUDE.md` and a SessionStart hook to `~/.claude/settings.json`
3. Codex: writes the rules into `~/.codex/AGENTS.md` between markers and adds the SessionStart hook to `~/.codex/hooks.json`. Codex asks you to trust new hooks: run `/hooks` in Codex. Without hooks Codex still follows the rules; it just doesn't get the memory injected at start.

After editing `~/.config/agent-memory/RULES.md`, run `~/.config/agent-memory/sync.sh` to refresh Codex's copy.

Check a project by hand:

```bash
bash ~/.config/agent-memory/hooks/memory-check.sh path/to/project
```

### Uninstall

```bash
bin/uninstall.sh          # add --purge to delete ~/.config/agent-memory
```

Removes the hooks, the `@import` line and the `AGENTS.md` block. Project `.agent-memory/` folders are never touched.

### Migrating an older, bloated memory

Nothing rewrites your memory automatically. Run `memory-check`, then ask an agent: "Rewrite handoff.md as the current state only, cut INDEX current state to one line, and fix the memory-check warnings." Move old handoff text to `archive/` if the project isn't in git.

## Prior art

I looked for something to adopt before building this. Requirement: shared by Claude Code and Codex, plain files in the repo, little rule overhead.

| Project | What it is | Why not just use it |
|---|---|---|
| [AGENTS.md](https://agents.md) | Cross-tool instruction file | Instructions, not evolving state. agent-memory uses it as the channel to Codex. |
| Claude Code `CLAUDE.md` + auto memory | Claude's instructions and private memory | Codex can't read Claude's private memory. |
| Codex memories | Codex's auto-extracted memory | Private to Codex; Claude can't read it. |
| [Cline Memory Bank](https://docs.cline.bot/features/memory-bank) | Six markdown files kept by Cline | Cline-specific. Its own docs warn that `activeContext.md` must stay current-only, the failure mode I hit. |
| [Basic Memory](https://github.com/basicmachines-co/basic-memory) | Markdown knowledge graph over MCP | Needs an MCP server; a personal knowledge base more than a per-repo handoff. |
| [mem0 / OpenMemory MCP](https://github.com/mem0ai/mem0), [Letta](https://github.com/letta-ai/letta) | Memory services / agent frameworks | Databases and servers, not files you review in a diff. |
| [agent-work-mem](https://github.com/daystar7777/agent-work-mem) | Vendor-neutral markdown protocol | Closest in goal. ~30 KB protocol and an append-only `work.log`: growth by design. |
| [ShareMemory](https://github.com/ycl-2004/ShareMemory) | Skill with `AI_MEMORY/` and a linter | Closest in spirit, and worth a look. Installed per repo and invoked as a skill; agent-memory installs once globally and injects memory automatically. |

None combined global install, automatic injection for both agents, a short rule set and a linter, so this stays small: three hook scripts and one rules file.

## Development

```bash
bash tests/test.sh
```

Issues and PRs welcome, especially for other agents (Cursor, Gemini CLI, OpenCode) and new failure modes the linter should catch.

## License

MIT. See [LICENSE](LICENSE).
