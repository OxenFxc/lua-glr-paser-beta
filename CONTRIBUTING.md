# 贡献指南 (Contributing Guide)

感谢您有兴趣为本项目做出贡献！我们欢迎所有形式的贡献，包括错误修复、新功能、文档改进等。

## 如何贡献

1.  **Fork 本仓库**：点击 GitHub 页面右上角的 "Fork" 按钮。
2.  **克隆您的 Fork**：`git clone https://github.com/your-username/your-fork-url.git`
3.  **创建分支**：`git checkout -b feature/your-feature-name` 或 `fix/your-bug-fix`
4.  **提交更改**：确保您的代码符合本项目的代码风格，并通过所有测试。
5.  **提交 Pull Request (PR)**：将您的更改推送到您的 Fork，然后在原仓库提交 PR。

## 开发流程

### 环境设置

本项目依赖 Lua 5.3+。您可以使用 `setup_and_verify.sh` 脚本来设置环境并验证安装：

```bash
./setup_and_verify.sh
```

### 代码风格

- 请保持与现有代码一致的风格。
- 使用 4 个空格进行缩进。
- 变量命名请使用 `snake_case`。
- 请为复杂的逻辑添加注释。

### 测试

在提交 PR 之前，请务必运行测试以确保没有引入回归错误：

```bash
./setup_and_verify.sh
```

或者使用 CLI 手动测试：

```bash
lua run_parser.lua test_parser_features.lua
```

## 提交规范

- 提交信息应简洁明了。
- 如果修复了 Issue，请在提交信息中引用 Issue 编号（例如 `Fixes #123`）。

## 获取帮助

如果您有任何问题，请随时在 Issues 中提问。

再次感谢您的贡献！
