# 自然语言记账

## 职责

记账模块位于 `lib/accounting.dart`，负责本地账单数据结构、Floor 持久化、账单 Tool 接入和本月汇总逻辑。账单 UI 在 `lib/main.dart` 的 `LedgerPage`。

## 数据结构

`TransactionEntry` 映射到 `transactions` 表，字段包括：

- `id`：自增主键。
- `createdAtIso`：记录创建时间。
- `occurredAtIso`：实际收支时间。
- `type`：`expense` 或 `income`。
- `title`：收支标题。
- `amount`：金额，必须大于 0。
- `currency`：币种，空值默认 `CNY`。
- `category`：分类，空值默认 `其他`。
- `account`：账户，空字符串归一化为 `null`。
- `note`：备注，空字符串归一化为 `null`。
- `rawText`：用户原始输入。

`TransactionEntry.fromToolArgs()` 是 Tool 参数进入数据库前的统一校验和归一化入口。

## 数据库

- `AppDatabase` 当前版本为 2。
- `migration1To2` 创建 `transactions` 表。
- `TransactionDao` 提供新增、更新、删除和按发生时间倒序查询。
- `ExpenseLedger.open(path)` 使用 Floor 打开数据库，并注册迁移。
- Runner 当前数据库文件为应用 documents 目录下的 `expenses.db`。

修改 Entity、DAO 或迁移后必须重新生成 `lib/accounting.g.dart`：

```bash
fvm dart run build_runner build --delete-conflicting-outputs
```

## Tool 接入

`createRecordTransactionTool()` 暴露 `record_transaction`：

- 仅用于“用户明确要求记账”的收入或支出保存。
- 参数全部使用 named `required`，避免 Tool runtime 解析缺失参数。
- `account`、`note` 没有内容时由模型传空字符串，再由 `fromToolArgs()` 归一化为 `null`。
- 保存成功后返回类似 `已记账：餐饮/早餐 3 CNY` 的中文确认文案。

## 账单 UI

`LedgerPage` 是第二个 Tab：

- 进入账单 Tab 时 lazy load `ExpenseLedger`。
- 顶部 `_SummaryBar` 展示本月收入、本月支出、本月结余。
- 明细列表按发生时间倒序展示。
- 每条账单支持编辑和删除，删除前有确认弹窗。
- 编辑弹窗复用 `TransactionEntry.fromToolArgs()` 做金额、时间和空字段处理。

`MonthlySummary.fromEntries()` 只统计传入月份内的收入和支出，`balance = income - expense`。

## 测试覆盖

`test/accounting_test.dart` 覆盖：

- 详细支出记录字段构建。
- 默认类型、币种、分类、账户和备注归一化。
- 非法金额拒绝。
- 指定月份收入、支出和结余汇总。
