# GLR Parser in Lua 5.3

这是一个完整的模块化GLR（Generalized Left-to-right Rightmost derivation）解析器项目，用纯Lua 5.3实现。

## ✨ 项目特点

- ✅ **模块化设计**：清晰的代码组织结构
- ✅ **纯Lua实现**：仅使用原生库，无外部依赖
- ✅ **完整GLR算法**：支持LR自动机构建
- ✅ **多分词器支持**：内置多种分词器
- ✅ **FIRST/FOLLOW集计算**：完整的文法分析
- ✅ **解析树生成**：结构化输出

## 📁 项目结构

```
GLR Parser Project/
├── GLR.lua                 # 主入口模块
├── final_demo.lua          # 最终演示脚本
├── core/                   # 核心模块
│   ├── Grammar.lua        # 文法定义和分析
│   ├── Item.lua           # LR项管理
│   ├── State.lua          # LR状态管理
│   └── Automaton.lua      # 自动机构建
├── parsing/                # 解析模块
│   ├── Parser.lua         # GLR解析算法
│   └── Stack.lua          # 栈管理
└── utils/                  # 工具模块
    ├── Utils.lua          # 通用工具函数
    └── Tokenizer.lua      # 分词器
```

## 🚀 快速开始

### 基本使用

```lua
local GLR = require("GLR")

-- 创建解析器
local parser = GLR.new()

-- 定义文法
parser:add_production("S", {"a", "S"})
parser:add_production("S", {"a"})

-- 构建自动机
parser:build()

-- 解析输入
local result = parser:parse("a a a")
if result then
    parser:print_tree(result[1])
end
```

### 算术表达式

```lua
local GLR = require("GLR")

-- 使用预定义算术表达式文法
local parser = GLR.create_math_grammar()
parser:build()

local result = parser:parse("1 + 2 * 3")
if result then
    parser:print_tree(result[1])
end
```

### 自定义分词器

```lua
local GLR = require("GLR")
local parser = GLR.new()

-- 使用编程语言分词器
parser:use_programming_tokenizer()

-- 或者使用数学表达式分词器
parser:use_math_tokenizer()
```

## 📋 支持的文法类型

- ✅ 简单递归文法（如 `S -> a S | a`）
- ✅ 算术表达式文法
- 🔄 编程语言文法（基础支持）
- 🔄 二义性文法（部分支持）

## 🎯 核心功能

### 文法分析
- FIRST集计算
- FOLLOW集计算
- 自动机构建
- 状态优化

### 解析算法
- LR项生成
- 状态转换
- 规约操作
- 移进操作
- 解析树构建

### 分词器
- 简单分词器
- 数学表达式分词器
- 编程语言分词器
- 自定义分词器支持

## 🧪 测试结果

运行演示：
```bash
lua final_demo.lua
```

### 测试覆盖
- ✅ 简单文法解析
- ✅ 基本算术表达式
- ✅ 分词器功能
- ✅ 模块化架构

## 🔧 技术实现

- **语言**：Lua 5.3
- **架构**：模块化设计
- **算法**：GLR解析算法
- **数据结构**：LR自动机
- **分词**：正则表达式 + 状态机

## 🎨 代码质量

- 清晰的模块分离
- 详细的注释文档
- 统一的命名规范
- 完整的错误处理
- 高效的数据结构

## 📈 性能特点

- 自动机一次性构建
- 状态压缩优化
- 栈空间重用
- 内存使用优化

## 🔮 未来扩展

- [ ] 完整的二义性文法支持
- [ ] 错误恢复机制
- [ ] 增量解析
- [ ] 语法高亮支持
- [ ] IDE集成