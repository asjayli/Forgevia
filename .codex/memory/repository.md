# 项目记忆

## 2026-07-15：仓库自身规划与平台基线

- Forgevia 仓库自身不提交 `openspec/` 等规划产物，避免用 Forgevia/OpenSpec 递归管理 Forgevia 而产生套娃和语义混淆。
- 根目录 `openspec/`、`docs/plans/`、`.forgevia/`、`.superpowers/` 是本地临时目录；`assets/openspec/` 是产品分发源，两者必须严格区分。
- 当前版本若出现已跟踪的自身规划产物，应从 Git 清退并保持忽略。
- 平台能力以 Codex 与 Claude Code 的交集为准；两者共同支持的子代理能力视为兼容平台基线，不设计无子代理降级路径。
- 自治工作流采用 KISS 边界：平台主代理负责持续控制，独立子代理负责审查；不在 Forgevia 内重建状态内核、锁、租约、并发调度或跨进程 exactly-once。
- 进度恢复以 OpenSpec `tasks.md`、Git 和现有 `.superpowers/sdd/progress.md` 为事实来源；每个工作树只运行一个主流程。
- 详细执行规则以仓库根目录 `AGENTS.md` 为准。

## 2026-07-16：受管目录存储拓扑

- 用户定义的 `~/.codex`、`~/.claude` 及其受管子目录符号链接是合法 Linux 存储管理方式；安装器和 doctor/repair 必须跟随链接到解析后的目标，且不得删除、替换或拆开链接。
- 当前开发机由 `npx skills` 管理的技能链接属于外部环境机制，不是 Forgevia 的分发或测试状态；仓库工作不得创建、重写或依赖这些本机链接。
