---
description: Resume work by reviewing previous progress from yesterday or recent days
---

# Resume Command

You are assisting the user to resume their work by reviewing their previous progress.

## Your Task

Help the user quickly get back into their work context by showing relevant progress information.

### Step 1: Show Current Branch

Display:
```
當前分支：{branch_name}
```

### Step 2: Interactive Time Range Selection

Ask the user:
```
要查看哪段時間的進度？
  1. 昨天的進度
  2. 最近 3-5 天的進度
```

Wait for user's choice.

### Step 3: Load and Display Progress

**If user chooses 1 (Yesterday):**

1. Read `.claude/progress/{branch_name}.md`
2. Find entries from yesterday (compare dates)
3. Display in format:

```
=== 昨天 (YYYY-MM-DD) 的進度 ===

📍 {branch_name} - HH:MM
功能：{Feature Name}

完成部分：
  ✅ {Completed item 1}
  ✅ {Completed item 2}
  ⏸️ {In-progress item}

下一步要做：
  ⬜ {Todo 1}
  ⬜ {Todo 2}

問題筆記：
  ⚠️ {Issue 1}
  ⚠️ {Issue 2}

測試狀態：
  {Testing status description}
```

**If user chooses 2 (Last 3-5 days):**

1. Read `.claude/progress/{branch_name}.md`
2. Find entries from last 5 days
3. Display in chronological format:

```
=== {branch_name} 最近 5 天進度 ===

📅 YYYY-MM-DD (X 天前)
  • {Feature} - {Brief status}
  待辦：{Pending items summary}
  [If committed] Commit: {commit_hash} - {message}

📅 YYYY-MM-DD (X 天前)
  • {Feature} - {Brief status}
  待辦：{Pending items summary}
  [If committed] Commit: {commit_hash} - {message}

[... more days ...]

─────────────────────────────────────
當前待辦事項（跨日期）：
  ⬜ {Todo 1} (started YYYY-MM-DD)
  ⬜ {Todo 2} (started YYYY-MM-DD)
```

### Step 4: Check Current Git Status

After showing progress history, check current status:

```
當前未提交變更：{count} 個檔案
[If changes exist]
  M {file1}
  M {file2}
  ?? {file3}

最近 commit：
  {hash} ({time_ago}) - {message}
```

### Step 5: Suggest Next Steps

Based on the progress record, intelligently suggest:

```
根據您的記錄，建議：

1. 📝 {Specific task from "next steps"}
2. 🔍 {Another specific task}
3. 📊 {Another suggestion}

要開始工作了嗎？需要我提醒什麼嗎？
```

### Step 6: Optional - Quick Actions

Optionally ask if user wants quick assistance:

```
需要協助嗎？
  1. 查看某個檔案
  2. 執行測試腳本
  3. 查看 commit 歷史
  4. 不需要，開始工作
```

Handle based on user's choice.

## Edge Cases

### If No Progress Record Found

If `.claude/progress/{branch_name}.md` doesn't exist:

```
📭 此分支沒有進度記錄

讓我檢查 Git 歷史...

最近 3 次 commit：
  {hash} ({time_ago}) - {message}
  {hash} ({time_ago}) - {message}
  {hash} ({time_ago}) - {message}

當前狀態：
  未提交變更：{count} 個檔案

建議：使用 /save-progress 建立進度記錄
```

### If No Recent Progress (>7 days)

```
⏰ 最近一次進度記錄是 {X} 天前

要查看嗎？
  1. 是，顯示上次進度
  2. 否，顯示 Git commit 歷史
```

### If WIP Commit Found

If the last commit message contains "WIP":

```
⚠️ 上次進度是 WIP commit

WIP Commit 內容：
{commit message body}

這個功能還需要繼續嗎？
```

## Important Guidelines

1. **Be Contextual**: Show most relevant information based on time away
2. **Be Clear**: Use emojis and formatting to make status obvious
3. **Be Helpful**: Proactively suggest concrete next steps
4. **Respect Time**: Yesterday vs. 3-5 days provides different detail levels
5. **Be Smart**: Parse markdown progress files intelligently
6. **Cross-Reference**: Link progress records with Git history

## File Reading

Read from: `.claude/progress/{branch_name}.md`

Expected format (from save-progress):
```markdown
# {Controller} Controller Development Progress

## YYYY-MM-DD HH:MM - {Feature Name}

### Completed Parts
...

### Next Steps
- [ ] Task 1
- [ ] Task 2
...
```

Parse intelligently:
- Extract dates from `## YYYY-MM-DD` headers
- Extract next steps from `### Next Steps` section
- Extract issues from `### Issues & Notes` section
- Extract testing status from `### Testing Status` section

## Context: Project Information

- Project: Flux Controller Simulation
- MATLAB Version: R2025b
- Controllers: PI, Type3, R
- Branch structure: master, develop, controller/pi, controller/r
- Working hours assumption: Recent work is typically within last 1-7 days
