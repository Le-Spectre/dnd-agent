# DND Agent

一个基于 Claude Cloud 的 D&D 5e 地下城主系统。支持中文规则查询、骰子投掷、角色创建、战斗管理等完整跑团功能。

## 功能

- **CLAUDE.md** — 核心 DM 人设、叙事风格和会话指令
- **dm-instructions/** — 战斗、角色创建、NPC、战利品、战役、施法的详细规则指导
- **roll.sh** — 骰子投掷脚本
- **.claude/skills/** — 交互式技能模块（见下方）

## 技能（Skills）

| 命令 | 说明 |
|------|------|
| `/new-game` | 开始新战役 |
| `/load` | 加载已有战役 |
| `/save` | 保存当前战役状态 |
| `/session` | 会话管理 |
| `/char` | 角色创建与管理 |
| `/roll` | 骰子投掷 |
| `/combat` | 战斗管理 |
| `/find` | 规则/法术/怪物速查 |
| `/organize` | 整理模组文件为 DM 友好格式 |

## 使用方法

1. 克隆本仓库
2. 在 [Claude Code](https://claude.ai/claude-code) 中打开
3. 输入战役指令开始游戏

### 基本指令

- `开始新战役 [名称]` — 开始新冒险
- `加载战役 [名称]` — 恢复已有战役
- `创建角色` — 引导角色创建
- `保存战役` / `结束会话` — 保存进度

战役数据存储在本地 `campaigns/` 文件夹中。

## 目录结构

```
├── CLAUDE.md                    # 核心 DM 指令
├── roll.sh                      # 骰子投掷脚本
├── dm-instructions/             # DM 规则指导
│   ├── combat-rules.md          # 战斗规则
│   ├── character-sheets.md      # 角色卡与创建
│   ├── spellcasting.md          # 施法
│   ├── npc-generation.md        # NPC 生成与扮演
│   ├── items-and-loot.md        # 物品与战利品
│   └── campaign-generation.md   # 战役生成
├── DND5e_chm_md/                # 中文 D&D 规则书
├── dnd-5e-srd/                  # 英文 SRD 规则参考
├── .claude/skills/              # 交互式技能
└── campaigns/                   # 战役存档（本地）
```

## 许可证

本项目不同来源的内容分别适用以下许可：

### DM 指令与 CLAUDE.md
MIT License — 由 [PinchOfData/claude-dungeon-master](https://github.com/PinchOfData/claude-dungeon-master) 基底项目衍生，包含二次开发与自定义技能。

### DND 5e SRD
Open Gaming License v1.0a — 系统参考文档版权归 Wizards of the Coast 所有。
dnd-5e-srd 的 Markdown/JSON 转换由 [Ben Morton](https://github.com/BTMorton/dnd-5e-srd) 提供（MIT License）。

### 中文规则书
DND5e_chm_md 来自 [Josanshuo/DND5e_chm](https://github.com/Josanshuo/DND5e_chm)（《5E不全书》），适用 GPL-3.0 License。
