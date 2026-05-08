---
name: new-game
description: 开始新的D&D 5e战役
triggers: /new-game
---

# D&D 新战役创建

## 触发条件
- 用户输入 `/new-game`
- 用户说 "开始新游戏"、"新战役"、"new campaign" 等

## 功能

1. **收集战役信息**
   - 如果玩家提供了模组文件夹，则先阅读模组文件，尤其是README.md了解模组结构
   - 询问战役名称（若用户未提供）
   - 询问玩家角色信息（已有角色或新建）
   - 了解游戏风格偏好（黑暗/光明、战斗/RP比例等）

2. **创建战役结构**
   ```
   campaigns/[战役名]/
   └── state.md          # 初始状态文件
   ```

3. **生成开场**
   - 根据用户偏好或者模组文件，生成一个有吸引力的开场hook
   - 建立第一个场景

## 状态更新
- 创建后更新 `state.md`：session #1、地点、可用任务、初始状态

## 输出语言
简体中文

## 参考文件
- `dm-instructions/campaign-generation.md` - 战役创建指南
- `dm-instructions/character-sheets.md` - 角色管理
