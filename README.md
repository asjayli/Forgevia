<div align="center">

# Forgevia

### 面向 Codex、Claude 的 Agent Coding 工作流整合方案

中文 | [English](README_EN.md)

</div>

把你的 agent 开发流程锻造成钢铁。

Forgevia 是一套面向 agent coding 的工作流整合方案。

## 职责范围

### Forgevia 做什么

- 把 OpenSpec、superpowers、代码评审与浏览器验证整合为一条从需求到归档的连贯工作流。
- 通过 `init` / `doctor` / `repair` 管理全局受管资源：技能、命令，以及对上游的受管覆盖文件。
- 提供显式命令编排：`draw` / `think` / `propose` / `implement` / `tasks` / `review` / `verify-web` / `archive`，并提供独立的 `openspec-sync-specs` 规格同步技能。

### Forgevia 不做什么

- 不替代 OpenSpec、superpowers 或 playwright-interactive，只负责编排，底层能力仍由它们提供。
- 不接管你的项目源码：仅在缺失时调用 `openspec init`，不修改业务代码。
- 不自动触发：仅在用户显式要求时工作，不会因为存在编码请求就自动介入。
- OpenSpec 固定安装经验证的 `1.6.0`；其他上游依赖按各自安装方式管理。版本不匹配时安装器会保护性跳过覆盖，而不是降级上游。

## Codex 安装方式

直接对 Codex 说：

```text
帮我安装，交互过程请使用中文：Fetch and follow instructions from https://raw.githubusercontent.com/asjayli/Forgevia/refs/heads/main/INSTALL.codex.md
```

## Claude 安装方式

直接对 Claude 说：

```text
帮我安装，交互过程请使用中文：Fetch and follow instructions from https://raw.githubusercontent.com/asjayli/Forgevia/refs/heads/main/INSTALL.claude.md
```

## 技能能力

- `forgevia`：Forgevia 工作流的总入口。
- `forgevia-init`：为当前项目准备 Forgevia 工作流环境。
- `forgevia-think`：在开发前梳理和澄清需求。
- `forgevia-propose`：将需求描述或指定文件转换为新的变更提案。
- `forgevia-implement`：针对指定的活跃变更执行结构化开发。
- `forgevia-tasks`：查看所有活跃变更下未完成的任务。
- `forgevia-review`：对当前工作发起一次聚焦评审。
- `forgevia-verify-web`：在浏览器中验证 Web 侧行为。
- `forgevia-draw`：为功能、链路或接口生成交互时序图。
- `openspec-sync-specs`：将指定 change 的 delta specs 同步至主规格，保持 change 活跃且不归档。
- `forgevia-archive`：归档一个已完成的活跃变更。
- `forgevia-doctor`：检查 Forgevia 环境是否健康。
- `forgevia-repair`：修复缺失或漂移的 Forgevia 受管资源。

## 如何使用

### 完整版链路

`forgevia` 是总入口。你只需要明确告诉 Forgevia 当前要执行哪个动作，它会把需求、开发、评审、验证和归档串成一条一致的流程。

每个命令启动后，Forgevia 会在该命令授权的目标与范围内自动完成常规步骤、独立审查、修复与复验，无需逐步确认；只有关键歧义、授权缺口、未授权外部副作用或无法收敛的阻塞才会中断。未明确要求的后续阶段、归档、推送或发布不会自动执行。

1. `Forgevia init`
   适合在新仓库开始使用时执行。它会检查当前项目是否已具备 Forgevia 工作流所需的基础文件；如果缺失，就补齐初始化内容。若这个仓库需要同时支持 Codex 和 Claude，建议按 `codex,claude` 初始化项目模板。
2. `Forgevia doctor`
   用于检查全局环境状态。它会告诉你当前安装的 Forgevia 资源是否正常、缺失，或者已经发生漂移。
3. `Forgevia repair`
   当 `doctor` 发现问题时使用。它会把缺失或漂移的 Forgevia 受管文件恢复到正确状态。
4. `Forgevia draw`
   适合在正式思考和开发前先做设计可视化。它可以围绕指定功能、接口或链路画出时序图、UML 图和泳道图 SVG 文件。生成的 `.mmd` 文件可以作为后续 `think` 的参考输入，同时也会渲染出可供开发参考的 SVG 矢量图，可直接用 Chrome 打开查看；当某个功能、接口或链路发生变化后，建议及时同步更新设计图、`.mmd` 和 SVG，让设计表达始终与实现保持一致。
5. `Forgevia think`
   在正式开发前先用它梳理需求。你可以直接说出一个模糊的想法，也可以提供更详细的说明，例如带上 `draw` 生成的 `.mmd` 流程图，或者直接输入完整的需求文档。输入越详细，后续分析和方案收敛通常会越准确。它会先形成需求复述与边界，由独立审查代理复核；审查通过后直接把结果沉淀为 `openspec/think/` 下的 Markdown 文件，无需等待用户确认。文件名会以当天日期开头，相同需求会按 `v2`、`v3` 持续迭代。
6. `Forgevia propose`
   用它把需求描述或指定文件生成成一个新的 change。你可以直接输入刚刚 `think` 之后你已经满意的结果，也可以跳过前一步，直接提供一份你认为已经足够完整、足够满意的 request，这个由你自己决定。输出会形成一个有名字的交付单元，包含清晰范围、说明文档和可执行任务拆分。
7. `Forgevia tasks`
   当你只想看还有哪些事情没做完时使用。它会列出当前活跃变更中的未完成任务，方便安排下一步。
8. `Forgevia implement <change>`
   用于执行一个明确命名的活跃变更。它会按任务驱动的方式推进开发，持续对齐目标，并要求遵守严格的测试优先开发节奏，而不是随意编码。
9. `Forgevia review`
   用于关键检查点发起评审。它会针对当前工作做聚焦审查，优先基于明确的提交范围，并按严重级别严格排序问题，让最高风险项先被处理。
10. `Forgevia verify-web`
   当改动涉及页面、浏览器行为、交互流程或视觉效果时使用。它会在真实浏览器里验证用户最终会看到的结果。
11. `openspec-sync-specs <change>`
   当需要在不归档的前提下把指定 change 的 delta specs 合并到主规格时使用。它只授权主规格同步，不授权归档、提交、推送或发布。
12. `Forgevia archive <change>`
   当实现、评审和验证都完成后使用。它会关闭该变更、同步最终文档状态，并让项目历史保持整洁。

### 简版链路

`draw -> think -> propose -> implement -> review -> verify-web（如需要）-> openspec-sync-specs（如需提前同步）-> archive`

Forgevia 把需求梳理、结构化开发、代码评审、效果验证和最终归档串成一条一致的交付流程。

### 中文 OpenSpec 严格校验

Forgevia 通过 `forgevia validate` 提供中文 OpenSpec 严格校验，用于在不修改源规格的前提下支持需求正文中的“必须、不得、禁止、应当”。它先校验中文强制词，再在临时副本中注入 `MUST` 并运行原生严格校验：

```bash
forgevia validate --root <项目根目录>
```

安装器会将平台无关的命令安装到 `~/.local/bin/forgevia`；确保该目录在 PATH 中后，可直接运行 `forgevia validate --root <项目根目录>`。当前命令分发器还支持 `init`、`tasks`、`draw`、`doctor` 和 `repair`。当 Codex 与 Claude 都已安装时，`doctor` 与 `repair` 会检查两个运行时；其他命令优先使用 Codex 运行时。适配器同时校验主规格和活跃变更，且只支持 `spec-driven` schema；不支持中文章节或标题，必须继续使用 `## Requirements`、`### Requirement:` 和 `#### Scenario:` 等 OpenSpec 结构关键字。

## 第三方资产与许可

- `playwright-interactive`：来源于上游，采用 Apache License 2.0（© Microsoft Corporation）。Forgevia 重新分发时保留了其 `LICENSE.txt` 与 `NOTICE.txt`。
- `mermaid-diagram-specialist`：Forgevia 原创技能。
- `superpowers` 与 `OpenSpec`：作为上游依赖分别安装，Forgevia 仅在其上叠加受管覆盖文件，详见 `INSTALL.claude.md` / `INSTALL.codex.md`。

## 上游依赖

Forgevia 在下列上游之上叠加受管定制。覆盖快照针对的版本与上游最新版本的差异，决定是否需要适配。

| 上游 | 用途 | Forgevia 基准 | 上游最新 | 地址 |
|------|------|---------------|----------|------|
| OpenSpec (`@fission-ai/openspec`) | spec-driven 变更工作流 CLI | override 针对并固定为 `1.6.0` | `1.6.0` | https://www.npmjs.com/package/@fission-ai/openspec |
| superpowers (`obra/superpowers`) | brainstorming / TDD / 计划 / 评审等技能框架 | 测试基准 `6.1.1` | `6.1.1` | https://github.com/obra/superpowers |
| playwright-interactive | 浏览器交互验证技能 | vendored（未追踪版本） | — | 见技能内 `LICENSE.txt` / `NOTICE.txt`（Apache-2.0，© Microsoft Corporation） |
| mermaid-cli (`mmdc`) | `forgevia-draw` 渲染 SVG 的运行时依赖 | 运行时工具 | — | https://github.com/mermaid-js/mermaid-cli |
| ripgrep (`rg`) | `forgevia-tasks` 扫描任务（可选，缺失回退 grep） | 运行时工具 | — | https://github.com/BurntSushi/ripgrep |

> 说明：Forgevia 对 OpenSpec 的覆盖是针对 `1.6.0` 的内容快照，安装器固定安装此版本。当本地 OpenSpec 版本与快照不一致时，安装器与 doctor 会保护性跳过覆盖，避免降级上游；升级时必须同步更新覆盖快照、安装版本和 `manifests/*.json` 中的 `overrideTargetVersion`。
