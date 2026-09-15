# NobodyWho Android Runner 文档索引

本目录记录 Runner 侧架构和模块职责。代码是实现细节的单一事实来源；文档负责说明当前设计、入口和验证边界。

## 模块文档

- [聊天与模型](chat.md)：应用入口、模型加载、文本/多模态切换、附件 Prompt Part、思考过程展示。
- [自然语言记账](accounting.md)：Floor 数据结构、`record_transaction` Tool、账单页 CRUD、本月统计。

## 维护规则

- 改动前先按功能域读对应文档，不默认通读整个 docs。
- UI 结构、用户可见行为、模块职责变化时，同步更新文档。
- 纯内部实现调整、变量改名、小 bugfix、测试补充，默认不需要更新文档。
- `lib/accounting.g.dart` 是 Floor 生成代码，不直接修改。

## 验证命令

```bash
fvm flutter analyze
fvm flutter test
```

涉及 Floor Entity、DAO 或迁移时，还需要：

```bash
fvm dart run build_runner build --delete-conflicting-outputs
```
