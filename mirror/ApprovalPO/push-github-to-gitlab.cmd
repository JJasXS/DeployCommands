@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Push ApprovalPO GitHub to GitLab

REM =============================================================================
REM Mirror ApprovalPO from GitHub onto GitLab (HTTPS).
REM
REM WARNING: git push --mirror makes GitLab an EXACT copy of GitHub.
REM          Branches that exist only on GitLab will be deleted.
REM
REM Uses HTTPS (port 443). SSH git@... is often blocked behind Cloudflare.
REM Keeps _tmp\ApprovalPO.git between runs — fetch is ~2s vs ~2min full clone.
REM If the cache folder is locked/corrupt, uses ApprovalPO.git.new instead.
REM =============================================================================

set "REPO=ApprovalPO"
set "GH=https://github.com/JJasXS/%REPO%.git"
set "GL=https://gitlabsvr.oneclickclouds.com/softwaredevelopment/%REPO%.git"
set "TMPDIR=%~dp0_tmp\%REPO%.git"
set "TMPNEW=%TMPDIR%.new"
set "CACHE=%TMPDIR%"

cd /d "%~dp0"
if not exist "_tmp" mkdir "_tmp"

where git >nul 2>&1
if errorlevel 1 (
  echo ERROR: Git not found in PATH.
  pause
  exit /b 1
)

call :pick_cache

echo.
echo ========== GitHub -^> GitLab: %REPO% ==========
echo GitHub: %GH%
echo GitLab: %GL%
echo Mirror cache: !CACHE!
echo.

if exist "!CACHE!\HEAD" (
  echo [1/3] Fetch updates from GitHub...
  pushd "!CACHE!"
  git remote set-url origin "%GH%"
  git fetch origin --prune
  if errorlevel 1 (
    popd
    echo WARN: fetch failed — rebuilding mirror cache...
    call :remove_invalid_cache
    call :pick_cache
    goto :clone_fresh
  )
  popd
  goto :push_mirror
)

:clone_fresh
if exist "!CACHE!\HEAD" goto :push_mirror

if exist "%TMPDIR%" (
  echo WARN: old cache folder is broken or locked — cloning to:
  echo   !TMPNEW!
  if exist "!TMPNEW!" call :remove_dir "!TMPNEW!"
  git clone --mirror "%GH%" "!TMPNEW!"
  if errorlevel 1 (
    echo ERROR: mirror clone failed for %REPO%
    goto :fail
  )
  set "CACHE=!TMPNEW!"
  if not exist "!CACHE!\HEAD" (
    echo ERROR: fresh mirror cache missing HEAD at !CACHE!
    goto :fail
  )
  echo NOTE: Using !CACHE! because %TMPDIR% could not be replaced.
  echo       You may delete the old folder manually when no git process is running.
  goto :push_mirror
)

echo [1/3] Clone --mirror from GitHub ^(first run or cache reset^)...
git clone --mirror "%GH%" "%TMPDIR%"
if errorlevel 1 (
  echo ERROR: mirror clone failed for %REPO%
  goto :fail
)
set "CACHE=%TMPDIR%"

:push_mirror
echo [2/3] Push --mirror to GitLab...
pushd "!CACHE!"
git remote set-url --push origin "%GL%"
git push --mirror
if errorlevel 1 (
  popd
  echo ERROR: mirror push failed for %REPO%
  goto :fail
)
popd

echo [3/3] Done ^(mirror cache kept for next run^).
echo.
echo GitLab heads:
git ls-remote --heads "%GL%"
echo.
echo OK: %REPO% mirrored.
echo.
pause
endlocal
exit /b 0

:pick_cache
set "CACHE=%TMPDIR%"
if exist "%TMPDIR%\HEAD" exit /b 0
if exist "!TMPNEW!\HEAD" set "CACHE=!TMPNEW!"
exit /b 0

:remove_invalid_cache
if exist "%TMPDIR%\HEAD" exit /b 0
call :remove_dir "%TMPDIR%"
exit /b 0

:remove_dir
if not exist "%~1" exit /b 0
echo Removing invalid mirror cache ^(no HEAD^): %~1
rmdir /s /q "%~1" 2>nul
if not exist "%~1" exit /b 0
set "BROKEN=%~1.broken.%RANDOM%"
echo WARN: folder locked — renaming to !BROKEN!
move "%~1" "!BROKEN!" >nul 2>&1
exit /b 0

:fail
echo.
echo Mirror FAILED for %REPO%.
pause
endlocal
exit /b 1
