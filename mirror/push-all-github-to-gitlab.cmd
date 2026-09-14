@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Push ALL GitHub to GitLab

REM =============================================================================
REM Mirror ALL projects from GitHub onto GitLab (HTTPS).
REM Per-project scripts live in mirror\<Project>\push-github-to-gitlab.cmd
REM
REM WARNING: git push --mirror makes GitLab an EXACT copy of GitHub.
REM Keeps _tmp\<Repo>.git between runs — fetch is much faster than re-clone.
REM =============================================================================

cd /d "%~dp0"
if not exist "_tmp" mkdir "_tmp"

where git >nul 2>&1
if errorlevel 1 (
  echo ERROR: Git not found in PATH.
  pause
  exit /b 1
)

for %%R in (ProAccScanner autoEmailing ABS_System eQuotation ApprovalPO multiDBSync) do (
  set "REPO=%%R"
  set "GH=https://github.com/JJasXS/%%R.git"
  set "GL=https://gitlabsvr.oneclickclouds.com/softwaredevelopment/%%R.git"
  set "TMPDIR=%~dp0_tmp\%%R.git"
  set "DO_CLONE=1"

  echo.
  echo ---------- %%R ----------
  echo GitHub: !GH!
  echo GitLab: !GL!
  echo.

  call :remove_invalid_cache

  if exist "!TMPDIR!\HEAD" (
    echo [1/3] Fetch updates...
    pushd "!TMPDIR!"
    git remote set-url origin "!GH!"
    git fetch origin --prune
    if errorlevel 1 (
      popd
      echo WARN: fetch failed — rebuilding mirror cache...
      call :remove_invalid_cache
    ) else (
      popd
      set "DO_CLONE=0"
    )
  )

  if "!DO_CLONE!"=="1" (
    if exist "!TMPDIR!" (
      echo ERROR: Could not clear broken mirror cache at:
      echo   !TMPDIR!
      goto :fail
    )
    echo [1/3] Clone --mirror...
    git clone --mirror "!GH!" "!TMPDIR!"
    if errorlevel 1 (
      echo ERROR: mirror clone failed for %%R
      goto :fail
    )
  )

  echo [2/3] Push --mirror...
  pushd "!TMPDIR!"
  git remote set-url --push origin "!GL!"
  git push --mirror
  if errorlevel 1 (
    popd
    echo ERROR: mirror push failed for %%R
    goto :fail
  )
  popd

  echo [3/3] OK: %%R mirrored ^(cache kept^).
)

echo.
echo ========== ALL MIRRORS DONE ==========
pause
endlocal
exit /b 0

:remove_invalid_cache
if not exist "!TMPDIR!" exit /b 0
if exist "!TMPDIR!\HEAD" exit /b 0
echo Removing invalid mirror cache ^(no HEAD^) for !REPO!...
rmdir /s /q "!TMPDIR!" 2>nul
if not exist "!TMPDIR!" exit /b 0
set "BROKEN=%~dp0_tmp\!REPO!.broken.!RANDOM!"
echo WARN: cache folder locked — renaming to:
echo   !BROKEN!
move "!TMPDIR!" "!BROKEN!" >nul 2>&1
exit /b 0

:fail
echo.
echo Mirror FAILED.
pause
endlocal
exit /b 1
