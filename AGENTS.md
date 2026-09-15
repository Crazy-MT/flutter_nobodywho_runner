## 仓库指南

### 项目结构与模块组织

这是 `nobodywho` 的 Flutter Android Runner 项目。

按功能域的详细设计文档在 docs/ 目录，索引见 docs/README.md。改动任何一个模块前，先读索引和对应那份文档。 不要默认通读 docs/ 下所有文档，除非任务本身是全局架构调整或横跨多个功能域。

Dart 源代码位于 `lib/` 目录：

- `main.dart`：包含应用 UI、聊天流程、模型选择以及附件处理。
- `accounting.dart`：包含 Floor 数据库、账本模型、汇总逻辑以及 `record_transaction` 工具的接入。
- `lib/accounting.g.dart`：由 Floor 自动生成。不要直接修改该文件，应通过修改源文件中的注解来调整生成代码。

测试代码位于 `test/`：

- `widget_test.dart`：用于 Widget/UI 行为测试。
- `accounting_test.dart`：用于账本相关逻辑测试。

运行时模型资源位于：

- `assets/`
- `assets/multimodal/`

这两个目录都已在 `pubspec.yaml` 中声明。

Android 原生相关文件位于 `android/`。

---

## 文档驱动开发

`docs/` 是项目架构、模块职责的单一事实来源；代码是具体实现的单一事实来源。改动前先读 [docs/README.md](./docs/README.md) 判断所属功能域，再读取对应文档建立上下文。

**何时同步更新文档**：改动涉及 UI 结构、用户可见行为、模块职责时，默认同步更新文档。纯内部实现调整、变量改名、小 bugfix、测试补充默认不触发。只有影响范围确实无法判断时，才停下来问用户。

**操作规则**：文档更新和代码改动放在同一次提交里。实现中发现原方案不合理，先回到文档改方案，再继续写代码。

## 规划文档

**非平凡功能 / 重构开工前，先在 `docs/plan/` 下留一份方案文档**，再动代码。是否需要 plan 按影响范围判断：新增功能入口性能热路径调整、需要分阶段落地的重构，都需要 plan；小 bugfix、UI 微调、文案 / 改名、类型修正、测试补充等不要求。

**文件命名**：`YYYY-MM-DD-NN-name.md`（`NN` 当日序号两位、从 `01` 起；`name` kebab-case）。例：`2026-04-17-01-merge-rebase.md`。

**必须包含**：Context（为什么做、要解决什么、预期结果）、进度总览（按 PR / 阶段拆分的状态表）、子任务清单（`- [ ]` / `- [x]`）、关键决策（做什么 / 不做什么 + 取舍理由）、验证方式（如何端到端跑一遍）。

**勾选状态随实施实时更新**，状态变化随主要 commit 一起提交。实施中发现原方案不合理，先回到 plan 改方案再写代码。Plan 文档功能落地后**不要删**，长期保留作为决策档案。

### 构建、测试与开发命令

使用 `.fvmrc` 中固定的 Flutter 版本：

```bash
fvm flutter pub get
fvm flutter analyze
fvm flutter test
fvm flutter run
```

修改 Entity、DAO 或数据库迁移后，需要重新运行 Floor 代码生成：

```bash
fvm dart run build_runner build --delete-conflicting-outputs
```

---

### 编码风格与命名规范

遵循 `analysis_options.yaml` 中配置的 `package:flutter_lints/flutter.yaml` 规范。

- Dart 使用 **2 个空格**缩进。
- 类和枚举使用 `UpperCamelCase`。
- 方法、变量和测试名称使用 `lowerCamelCase`。
- 私有符号使用下划线 `_` 开头。
- UI 辅助方法应尽量放在所属 Widget 附近，除非该方法会被多个地方复用。
- 如果生成代码出现错误，应优先通过修正源文件中的 import 或注解解决，而不是直接修改生成后的代码。

---

### 测试规范

使用 `flutter_test`。

- 纯业务逻辑使用普通的 `test()`。
- 涉及实际 Widget 渲染和 UI 行为的检查使用 `testWidgets()`。
- 以下内容应添加针对性的测试：
    - 金额解析
    - 交易默认值
    - 月度汇总
    - Prompt Part 构建
    - 新增的可见 Tab 或控件

在提交或交付修改之前，应运行：

```bash
flutter analyze
flutter test
```

确保静态分析和测试均通过。

---

### Commit 与 Pull Request 规范

当前 Git 历史使用简短、直接的中文 Commit 标题，例如：

```text
记账
Android runner
```

后续 Commit 也应保持简洁，并且每个 Commit 尽量只对应一个明确的改动。

Pull Request 应包含：

- 说明修改了哪些内容。
- 列出用于验证修改的命令。
- 说明是否对模型或数据库迁移产生影响。
- 如果涉及 UI 修改，应附上截图或录屏。

---

### Agent 专用说明

所有修改都应限制在当前 Runner checkout 中。

不要为了实现 Runner 功能而修改上游 Plugin/Example checkout。

保留与当前任务无关的未暂存修改，尤其不要影响：

- Asset 资源文件的已有修改。
- Lockfile 的已有修改。
