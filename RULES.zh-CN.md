## 项目记忆（.agent-memory/）

`.agent-memory/` 是所有在本项目里工作的 Agent（Claude Code、Codex……）共用的记忆。需要跨会话保留的项目事实和决策写在这里。工具私有记忆（Claude auto memory、Codex memories）只放用户个人偏好；两边对项目的说法冲突时，以 `.agent-memory/` 为准。

**放哪。** 从工作目录逐级向上找到 git 根目录，用找到的第一个 `.agent-memory/`，不要在下层再建一份。没有就在第一次出现值得保留的内容时，建在 git 根目录（非 git 项目建在打开的文件夹）。私有仓库：随代码提交。公开仓库：把 `.agent-memory/` 加进 `.gitignore`，绝不提交。

**什么放哪。** 每类信息只有一个归属。

| 文件 | 放什么 | 生命周期 |
|---|---|---|
| `handoff.md` | 工作现在到哪了：已完成、进行中、下一步、待确认 | 一段工作结束时整份重写。不要按日期追加小节，历史交给 git。 |
| `decisions/YYYY-MM-DD-标题.md` | 一个选择及理由 | 保留。被推翻时改 `status: superseded` 并填 `superseded_by`。 |
| `findings/YYYY-MM-DD-标题.md` | 验证过的事实、踩过的坑、调研结论 | 同 decisions。 |
| `INDEX.md` | 一句话用途、一句话现状、decisions 和 findings 目录 | 现状那一句直接替换，不要加行。目录只列记录。 |

记录开头写 frontmatter：`type`、`date`、`author`、`status`（active / superseded）、`superseded_by`。新增记录前先看已有记录是否该更新或作废；什么都不写也是合理结果。旧材料可以移到 `archive/`，它不会被自动加载。

**不要写。** 代码、git log、README、AGENTS.md / CLAUDE.md 里已有的（给 Agent 的长期规则写在那些文件里，不写在这里）。密钥。只和本轮对话有关的细节。易变状态（登录态、「正在等 X」、队列内容）：开工时现查。非写不可就标 `（截至 YYYY-MM-DD）`，转告用户前先重新核实。

**多人共用。** 改文件前先重新读最新内容，别的 Agent 可能刚改过。局部修改，不要凭记忆整份重写。在 frontmatter 和 handoff 抬头注明作者（`author: claude-code`、`codex`……）。

**检查。** 会话开始时会注入 INDEX、handoff 和 `memory-check` 的提示（超大小、断链、缺 status、handoff 过期）。顺手能修的就修。
