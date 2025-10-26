---
description: View comprehensive progress overview across all branches with todos
---

# Progress Log Command

You are assisting the user to view a comprehensive overview of work progress across all branches.

## Your Task

Provide an overview of all development branches and their progress status.

### Step 1: Scan All Branches

1. Get list of all local branches: `git branch`
2. For each branch, check if progress file exists: `.claude/progress/{branch_name}.md`
3. If exists, read the latest entry (most recent date)
4. Also get the latest commit info for each branch

### Step 2: Display Overview

Show summary of all branches:

```
=== 所有分支工作進度總覽 ===

📊 controller/pi
  最近更新：YYYY-MM-DD HH:MM
  狀態：{status emoji} {brief status}
  待辦：{count} 項

📊 controller/r
  最近更新：YYYY-MM-DD HH:MM
  狀態：{status emoji} {brief status}
  待辦：{count} 項

📊 develop
  最近更新：YYYY-MM-DD HH:MM
  狀態：{status emoji} {brief status}
  待辦：{count} 項

📊 master
  最近更新：YYYY-MM-DD (last commit)
  狀態：✅ 穩定
  待辦：{count} 項
```

Status emoji legend:
- ⏸️ 測試進行中
- ✅ 測試通過，待 commit
- ⬜ 未開始
- ❌ 有問題需要修復

### Step 3: Interactive Menu

Ask user what they want to see:

```
要查看哪個分支的詳細進度？
  1. controller/pi
  2. controller/r
  3. develop
  4. master
  5. 顯示所有待辦事項
  6. 退出
```

### Step 4: Handle User Choice

**If option 1-4 (Specific Branch):**

Show detailed progress for that branch:

```
=== {branch_name} 詳細進度 ===

📅 YYYY-MM-DD HH:MM
功能：{Feature Name}
完成：✅ {what was done}
測試：{testing status}
待辦：
  ⬜ {Task 1}
  ⬜ {Task 2}
問題：
  ⚠️ {Issue 1}
Commit: {hash} - {message}

📅 YYYY-MM-DD HH:MM
功能：{Another Feature}
完成：✅ {what was done}
...

[Show last 5-7 entries]

─────────────────────────────────────
當前狀態：
  未提交變更：{count} 個檔案
  最近 commit：{hash} ({time_ago}) - {message}
```

After showing, ask if user wants to see another branch or exit.

**If option 5 (All Todos):**

Show all pending tasks across all branches:

```
=== 所有分支待辦事項 ===

controller/pi ({count} 項)：
  ⬜ {Task 1} (started YYYY-MM-DD)
  ⬜ {Task 2} (started YYYY-MM-DD)

controller/r ({count} 項)：
  ⬜ {Task 1} (started YYYY-MM-DD)

develop ({count} 項)：
  ⬜ {Task 1} (started YYYY-MM-DD)

─────────────────────────────────────
Total: {total_count} 項待辦

按優先級排序：
  🔴 高優先級 ({count})
  🟡 中優先級 ({count})
  🟢 低優先級 ({count})
```

Note: Priority can be inferred from:
- Age of task (older = higher priority if still pending)
- Presence of ⚠️ or ❌ markers
- WIP commits (higher priority)

**If option 6 (Exit):**
```
感謝使用！使用 /resume 繼續工作 或 /save-progress 保存進度
```

## Additional Features

### Weekly Summary (Optional Trigger)

If user types `/progress-log week` or chooses from menu:

```
=== 本週工作總結 (MM/DD - MM/DD) ===

總 Commit 數：{count}
修改檔案：{count}
新增檔案：{count}

各分支活動：
  controller/pi: {commit_count} commits, {feature_count} features
  controller/r: {commit_count} commits, {feature_count} features
  develop: {commit_count} commits

主要完成：
  ✅ {Major feature 1}
  ✅ {Major feature 2}
  ✅ {Major feature 3}

待解決問題：
  ⚠️ {Issue 1}
  ⚠️ {Issue 2}
```

### Branch Comparison

If user wants to compare branches:

```
=== 分支比較 ===

controller/pi vs controller/r

共同待辦：
  ⬜ {Shared task}

PI 獨有：
  ⬜ {PI task 1}
  ⬜ {PI task 2}

R 獨有：
  ⬜ {R task 1}
```

## Edge Cases

### If No Progress Files Found

```
📭 沒有找到任何進度記錄

讓我檢查 Git 分支...

可用分支：
  • controller/pi (last commit: {time_ago})
  • controller/r (last commit: {time_ago})
  • develop (last commit: {time_ago})
  • master (last commit: {time_ago})

建議：在各分支使用 /save-progress 建立進度追蹤
```

### If Only One Branch Has Progress

```
📊 只有 {branch_name} 有進度記錄

其他分支沒有進度記錄，但有以下 Git 活動：
  • controller/r: last commit {time_ago}
  • develop: last commit {time_ago}

要查看 {branch_name} 的詳細進度嗎？
```

### If Branch Progress Is Old (>14 days)

```
⏰ {branch_name} 的進度記錄已超過 {days} 天

上次記錄：YYYY-MM-DD
功能：{last feature}

建議：如果仍在開發，使用 /resume 查看並更新進度
```

## Important Guidelines

1. **Be Comprehensive**: Show all branches, not just current one
2. **Be Organized**: Group information logically (by branch, by priority, by date)
3. **Be Visual**: Use emojis and formatting to make scanning easy
4. **Be Interactive**: Let user drill down into specific branches
5. **Be Smart**: Infer priorities and highlight important items
6. **Cross-Reference**: Link progress files with Git activity

## File Reading

Read from: `.claude/progress/*.md`

For each branch file:
- Parse all entries (by `## YYYY-MM-DD` headers)
- Extract latest status, todos, issues
- Count pending todos
- Determine overall status

## Data Aggregation

Aggregate across all branches:
- Total pending todos
- Common issues across branches
- Overall project health
- Activity patterns (which branch is most active)

## Context: Project Information

- Project: Flux Controller Simulation
- MATLAB Version: R2025b
- Controllers: PI, Type3, R
- Branch structure: master, develop, controller/pi, controller/r
- Typical workflow: User works on multiple controllers in parallel
- Purpose: Help user manage progress across multiple development streams
