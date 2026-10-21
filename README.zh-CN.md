# agent-memory

给 Claude Code 和 Codex（以及任何能读文件的 Agent）共用的纯文件项目记忆。每个项目一个 `.agent-memory/` 目录，约 25 行规则，外加一个在记忆开始「腐烂」时提醒 Agent 的检查脚本。

[English](README.md)

## 为什么做

我在同一批项目里来回切换 Claude Code 和 Codex。两边各有私有记忆，互相看不见对方做过什么。共用一个 `.agent-memory/` 目录解决了这个问题。但在约 30 个项目里天天用了一个月后，它以另一种方式坏掉了：

- **只加不删。** 「同步更新当前状态」被理解成「加一行」。一个 handoff 涨到 56 KB、35 个日期小节；一个 INDEX 的「当前状态」有 31 条，而且每次会话都会注入。
- **过期状态被当成事实。** 「某网站掉登录了」「正在等某某」一天就过期，下一个 Agent 却当现状报给我。
- **同一条规则写在四处。** profile、handoff、decisions、CLAUDE.md 各有一份，改一处漏一处。
- **没有机械检查。** 全靠 Agent 自觉。
- **钩子逼着写。** Stop 钩子在文件改了而记忆没动时拦住 Agent，Agent 的应对就是每轮追加点东西。
- **两套记忆并行。** Codex 自带记忆（16 KB 摘要，背后 140 KB 以上）也记了项目事实，可能和共享目录互相矛盾。

第一版的规则更多。解决办法是更少：只规定东西放哪、什么时候作废，怎么想交给模型。

## 怎么工作

```
your-project/
└── .agent-memory/
    ├── INDEX.md       一句话用途、一句话现状、记录目录
    ├── handoff.md     工作现在到哪了；整份重写，不追加
    ├── decisions/     YYYY-MM-DD-标题.md，一个选择及理由，status: active|superseded
    └── findings/      YYYY-MM-DD-标题.md，验证过的事实和坑
```

| 组件 | 作用 |
|---|---|
| [`RULES.zh-CN.md`](RULES.zh-CN.md) / [`RULES.md`](RULES.md) | 全部规则。Claude Code 通过 `~/.claude/CLAUDE.md` 里的 `@import` 读取；Codex 由 `sync.sh` 复制进 `~/.codex/AGENTS.md`。 |
| `hooks/memory-session-start.sh` | SessionStart hook：找到最近的 `.agent-memory/`，注入 `INDEX.md` + `handoff.md`（附写入时间）+ 检查告警。 |
| `hooks/memory-check.sh` | 检查脚本，也可以手动跑。 |

`memory-check` 会提示：
- `handoff.md` 超过 6 KB、超过 7 天没写、或有 3 个以上日期标题（追加式的迹象）
- 「正在等 / 在跑」小节已超过 2 天
- `INDEX.md` 超过 8 KB，或「当前状态」超过 3 条
- `INDEX.md` 里的断链；没列进 `INDEX.md` 的记录
- 缺 `status` 的记录，或 `superseded_by` 指向不存在的文件
- 标了 `（截至 YYYY-MM-DD）` 且超过 3 天的事实

阈值可用环境变量调（`AGENT_MEMORY_MAX_HANDOFF`、`AGENT_MEMORY_MAX_INDEX`、`AGENT_MEMORY_STALE_DAYS`、`AGENT_MEMORY_VOLATILE_DAYS`）。告警从不阻断，Agent 在会话开始时看到，顺手修。

健康记忆的样例见 [`examples/demo-app/.agent-memory/`](examples/demo-app/.agent-memory/)。

## 设计取舍

1. **规则只说放哪、何时作废，不说怎么想。**
2. **每类信息只有一个归属。** 给 Agent 的长期规则放 `AGENTS.md` / `CLAUDE.md`，记忆里只放项目知识。
3. **handoff 是快照不是日志。** 直接覆盖，历史交给 git。
4. **易变状态不进记忆。** 登录态、队列、「正在等」开工时现查；非写不可就标日期，让检查脚本去催。
5. **decisions / findings 标作废而不删除**，保留推理链。
6. **机械检查、轻推提醒。** 会话开始时跑检查，比在提示词里加规则管用。
7. **不强制写。** 没有 Stop 钩子。过期问题留到下次会话开始时由检查脚本发现，而不是逼每一轮都写点什么。
8. **私有记忆只放偏好。** Claude auto memory 和 Codex memories 记用户的工作习惯；项目事实和决策只在 `.agent-memory/`，冲突时以它为准。
9. **纯文件，不要服务器。** 任何 Agent 都能读、能 diff、离线可用；私有仓库随代码提交，公开仓库加进 `.gitignore`。

## 借鉴了谁

大部分想法来自别人，这里只是把它们压缩成纯文件。

| 思想 | 来源 | 在这里的体现 |
|---|---|---|
| 常驻上下文的小层有硬大小上限，其余按需取 | [Letta / MemGPT](https://github.com/letta-ai/letta) 的 core / archival memory | 只注入 `INDEX.md` 和 `handoff.md`，各有上限；记录按需读；`archive/` 从不加载。 |
| 开局只加载一个短索引，主题文件按需读 | Claude Code auto memory（`MEMORY.md` + 主题文件） | `INDEX.md` 只列记录，不装内容。 |
| 热 / 温 / 冷分层并轮转 | [agent-work-mem](https://github.com/daystar7777/agent-work-mem) v2 | `archive/` 作冷层放旧 handoff；git 当完整日志。 |
| 每次写入都对照已有内容选 ADD / UPDATE / DELETE / NOOP | [mem0](https://github.com/mem0ai/mem0) | 规则：新增记录前先看是否该更新或作废已有记录；不写也行。 |
| 事实带有效时间，作废而不抹掉 | [Zep / Graphiti](https://github.com/getzep/graphiti) 的双时间边 | `（截至 YYYY-MM-DD）` 标记由检查脚本催过期；`status: superseded` + `superseded_by`。 |
| 不可变的决策记录带状态 | 架构决策记录 ADR（Michael Nygard） | `decisions/` 是简化版 ADR。 |
| 「活动上下文」只放当前状态，不是日志 | [Cline Memory Bank](https://docs.cline.bot/features/memory-bank) | `handoff.md` 整份重写。 |
| 不只检查代码，也检查记忆 | [ShareMemory](https://github.com/ycl-2004/ShareMemory) | `memory-check`。 |
| 一份权威指令文件，各工具文件指向它 | [AGENTS.md](https://agents.md) | 一份 `RULES.md`；Claude import，Codex 同步一份副本。 |

考虑过但没采用：由模型驱动的整理压缩（Codex memories、Generative Agents 式的 reflection）和向量检索（mem0、Letta archival）。规模大时有用，但需要模型或数据库参与；项目级别，git 历史加 `grep` 就够了。

## 和工具自带记忆怎么分工

Claude Code 和 Codex 各有自己的记忆。agent-memory 不关掉它们，只划分职责：
- **私有记忆**：用户的偏好和习惯，跨项目通用。
- **`.agent-memory/`**：项目事实、决策和当前状态。规则写明冲突时以它为准。

Codex memories 在 `~/.codex/config.toml` 里控制（改之前先备份）：

```toml
[memories]
use_memories = true        # 会话开始时注入 memory_summary.md
generate_memories = true   # 继续从结束的会话里学习
```

没有「只记偏好」的开关。如果发现 Codex 从自带记忆里复述过期的项目事实，可以设 `generate_memories = false` 冻结它，或 `use_memories = false` 不再注入。也可以在单个对话里用 `/memories`。

## 安装

需要 `bash`、`jq`，macOS 或 Linux。

```bash
git clone https://github.com/LeiZiKang/agent-memory
cd agent-memory
bin/install.sh --lang zh-CN     # 英文规则用 bin/install.sh
```

安装脚本可重复运行，改动的每个文件都会先备份（`*.bak-<时间戳>`），并移除旧版装的 Stop 钩子。它会：
1. 把规则和 hooks 复制到 `~/.config/agent-memory/`
2. Claude Code：在 `~/.claude/CLAUDE.md` 加 `@~/.config/agent-memory/RULES.md`，在 `~/.claude/settings.json` 加 SessionStart hook
3. Codex：把规则写进 `~/.codex/AGENTS.md` 的标记区间，在 `~/.codex/hooks.json` 加 SessionStart hook。Codex 会要求你信任新 hook：在 Codex 里运行 `/hooks`。不开 hook，Codex 照样遵守规则，只是开局不会自动注入记忆。

改了 `~/.config/agent-memory/RULES.md` 后运行 `~/.config/agent-memory/sync.sh` 同步给 Codex。

手动检查某个项目：

```bash
bash ~/.config/agent-memory/hooks/memory-check.sh path/to/project
```

### 卸载

```bash
bin/uninstall.sh          # 加 --purge 同时删除 ~/.config/agent-memory
```

会移除 hooks、`@import` 行和 `AGENTS.md` 里的规则块。项目里的 `.agent-memory/` 一律不动。

### 迁移旧的、膨胀的记忆

不会自动改写你的记忆。先跑 `memory-check`，再让 Agent：「把 handoff.md 重写成只有当前状态，INDEX 当前状态压成一行，修掉 memory-check 的告警。」项目不在 git 里的话，旧 handoff 内容可移到 `archive/`。

## 已有方案调研

动手前先找了能直接用的方案。要求：Claude Code 和 Codex 共用、纯文件放在仓库里、规则负担低。

| 项目 | 是什么 | 为什么没直接用 |
|---|---|---|
| [AGENTS.md](https://agents.md) | 跨工具的指令文件 | 放指令，不放不断变化的状态。agent-memory 用它把规则送给 Codex。 |
| Claude Code `CLAUDE.md` + auto memory | Claude 的指令和私有记忆 | Codex 读不到 Claude 的私有记忆。 |
| Codex memories | Codex 自动提取的记忆 | Codex 私有，Claude 读不到。 |
| [Cline Memory Bank](https://docs.cline.bot/features/memory-bank) | Cline 维护的 6 个 markdown 文件 | 绑定 Cline。它自己的文档也提醒 `activeContext.md` 只能放当前状态，正是我踩的坑。 |
| [Basic Memory](https://github.com/basicmachines-co/basic-memory) | 基于 MCP 的 markdown 知识图谱 | 需要跑 MCP 服务；更像个人知识库，而不是项目交接。 |
| [mem0 / OpenMemory MCP](https://github.com/mem0ai/mem0)、[Letta](https://github.com/letta-ai/letta) | 记忆服务 / Agent 框架 | 数据库和服务端，不是能在 diff 里审的文件。 |
| [agent-work-mem](https://github.com/daystar7777/agent-work-mem) | 厂商中立的 markdown 协议 | 目标最接近。协议约 30 KB，`work.log` 只追加：设计上就会膨胀。 |
| [ShareMemory](https://github.com/ycl-2004/ShareMemory) | 带 `AI_MEMORY/` 和检查器的 skill | 思路最接近，值得一看。按仓库安装、以 skill 调用；agent-memory 全局装一次，自动注入。 |

没有一个同时满足：全局安装、两边都自动注入、规则短、有机械检查。所以它保持很小：三个 hook 脚本加一份规则。

## 开发

```bash
bash tests/test.sh
```

欢迎 issue 和 PR，尤其是接入其他 Agent（Cursor、Gemini CLI、OpenCode）和检查脚本该抓的新失效模式。

## 许可

MIT，见 [LICENSE](LICENSE)。
