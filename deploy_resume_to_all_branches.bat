@echo off
REM ============================================
REM Deploy updated resume.md to all branches
REM ============================================

echo.
echo ╔════════════════════════════════════════╗
echo ║  部署 /resume 到所有分支              ║
echo ╚════════════════════════════════════════╝
echo.

REM Check if we're in the right directory
if not exist ".claude\commands\resume.md" (
    echo ❌ 錯誤：找不到 .claude\commands\resume.md
    echo 請確認您在專案根目錄執行此腳本
    pause
    exit /b 1
)

REM Save current branch
for /f "tokens=*" %%i in ('git branch --show-current') do set CURRENT_BRANCH=%%i
echo 📍 當前分支：%CURRENT_BRANCH%
echo.

REM Check for uncommitted changes
git diff --quiet
if errorlevel 1 (
    echo ⚠️  警告：您有未提交的變更
    echo.
    choice /C YN /M "要繼續部署嗎？(Y=是, N=否)"
    if errorlevel 2 exit /b 0
    echo.
)

REM First, commit on current branch (controller/r)
echo ═══════════════════════════════════════
echo 步驟 1/4: 在當前分支 commit
echo ═══════════════════════════════════════
git add .claude\commands\resume.md
git commit -m "feat: Update /resume with auto-sync strategy"
if errorlevel 1 (
    echo ⚠️  Commit 失敗或沒有變更
) else (
    echo ✅ 已在 %CURRENT_BRANCH% commit
)
echo.

REM Push current branch
git push origin %CURRENT_BRANCH%
if errorlevel 1 (
    echo ⚠️  Push 失敗
) else (
    echo ✅ 已推送到遠端
)
echo.

REM Deploy to master
echo ═══════════════════════════════════════
echo 步驟 2/4: 部署到 master
echo ═══════════════════════════════════════
git checkout master
if errorlevel 1 (
    echo ❌ 切換到 master 失敗
    goto restore_branch
)
git pull origin master
git checkout %CURRENT_BRANCH% -- .claude\commands\resume.md
git add .claude\commands\resume.md
git commit -m "feat: Update /resume with auto-sync strategy"
if errorlevel 1 (
    echo ⚠️  可能已經是最新版本
) else (
    git push origin master
    echo ✅ 已部署到 master
)
echo.

REM Deploy to develop
echo ═══════════════════════════════════════
echo 步驟 3/4: 部署到 develop
echo ═══════════════════════════════════════
git checkout develop
if errorlevel 1 (
    echo ❌ 切換到 develop 失敗
    goto restore_branch
)
git pull origin develop
git checkout %CURRENT_BRANCH% -- .claude\commands\resume.md
git add .claude\commands\resume.md
git commit -m "feat: Update /resume with auto-sync strategy"
if errorlevel 1 (
    echo ⚠️  可能已經是最新版本
) else (
    git push origin develop
    echo ✅ 已部署到 develop
)
echo.

REM Deploy to controller/pi
echo ═══════════════════════════════════════
echo 步驟 4/4: 部署到 controller/pi
echo ═══════════════════════════════════════
git checkout controller/pi
if errorlevel 1 (
    echo ❌ 切換到 controller/pi 失敗
    goto restore_branch
)
git pull origin controller/pi
git checkout %CURRENT_BRANCH% -- .claude\commands\resume.md
git add .claude\commands\resume.md
git commit -m "feat: Update /resume with auto-sync strategy"
if errorlevel 1 (
    echo ⚠️  可能已經是最新版本
) else (
    git push origin controller/pi
    echo ✅ 已部署到 controller/pi
)
echo.

:restore_branch
REM Restore original branch
echo ═══════════════════════════════════════
echo 恢復原始分支
echo ═══════════════════════════════════════
git checkout %CURRENT_BRANCH%
echo ✅ 已切換回 %CURRENT_BRANCH%
echo.

echo ╔════════════════════════════════════════╗
echo ║  ✅ 部署完成                          ║
echo ╚════════════════════════════════════════╝
echo.
echo 已更新的分支：
echo   • %CURRENT_BRANCH%
echo   • master
echo   • develop
echo   • controller/pi
echo.
echo 💡 現在所有分支都有最新的 /resume 指令
echo.
pause
