@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Push ALL GitHub to GitLab

REM =============================================================================
REM Mirror ALL projects from GitHub onto GitLab (HTTPS).
REM Per-project scripts live in mirror\<Project>\push-github-to-gitlab.cmd
REM
REM WARNING: git push --mirror makes GitLab an EXACT copy of GitHub.
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

  echo.
  echo ---------- %%R ----------
  echo GitHub: !GH!
  echo GitLab: !GL!
  echo.

  echo [1/4] Heads before:
  git ls-remote --heads "!GH!"
  git ls-remote --heads "!GL!"
  echo.

  if exist "!TMPDIR!" rmdir /s /q "!TMPDIR!"

  echo [2/4] Clone --mirror...
  git clone --mirror "!GH!" "!TMPDIR!"
  if errorlevel 1 (
    echo ERROR: mirror clone failed for %%R
    goto :fail
  )

  echo [3/4] Push --mirror...
  pushd "!TMPDIR!"
  git remote set-url --push origin "!GL!"
  git push --mirror
  if errorlevel 1 (
    popd
    echo ERROR: mirror push failed for %%R
    goto :fail
  )
  popd

  echo [4/4] Cleanup...
  rmdir /s /q "!TMPDIR!"
  echo OK: %%R mirrored.
)

echo.
echo ========== ALL MIRRORS DONE ==========
pause
endlocal
exit /b 0

:fail
echo.
echo Mirror FAILED.
pause
endlocal
exit /b 1