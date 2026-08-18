@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Push SqlAccountSync GitHub to GitLab

REM =============================================================================
REM Mirror SqlAccountSync from GitHub onto GitLab (HTTPS).
REM
REM NOTE: the GitHub/GitLab repository name for this project is multiDBSync.
REM
REM WARNING: git push --mirror makes GitLab an EXACT copy of GitHub.
REM          Branches that exist only on GitLab will be deleted.
REM
REM Uses HTTPS (port 443). SSH git@... is often blocked behind Cloudflare.
REM =============================================================================

set "PROJECT=SqlAccountSync"
set "REPO=multiDBSync"
set "GH=https://github.com/JJasXS/%REPO%.git"
set "GL=https://gitlabsvr.oneclickclouds.com/softwaredevelopment/%REPO%.git"
set "TMPDIR=%~dp0_tmp\%REPO%.git"

cd /d "%~dp0"
if not exist "_tmp" mkdir "_tmp"

where git >nul 2>&1
if errorlevel 1 (
  echo ERROR: Git not found in PATH.
  pause
  exit /b 1
)

echo.
echo ========== GitHub -^> GitLab: %PROJECT% / %REPO% ==========
echo GitHub: %GH%
echo GitLab: %GL%
echo.

echo [1/4] GitHub heads before:
git ls-remote --heads "%GH%"
echo.
echo [1/4] GitLab heads before:
git ls-remote --heads "%GL%"
if errorlevel 1 (
  echo NOTE: GitLab repo does not exist yet, or is not accessible yet.
  echo       If this is the first mirror run, the next push may create it automatically.
)
echo.

if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%"

echo [2/4] Clone --mirror from GitHub...
git clone --mirror "%GH%" "%TMPDIR%"
if errorlevel 1 (
  echo ERROR: mirror clone failed for %PROJECT%
  goto :fail
)

echo [3/4] Push --mirror to GitLab...
pushd "%TMPDIR%"
git remote set-url --push origin "%GL%"
git push --mirror
if errorlevel 1 (
  popd
  echo ERROR: mirror push failed for %PROJECT%
  goto :fail
)
popd

echo [4/4] Cleanup temp clone...
rmdir /s /q "%TMPDIR%"

echo.
echo GitLab heads after:
git ls-remote --heads "%GL%"
echo.
echo OK: %PROJECT% mirrored.
echo.
pause
endlocal
exit /b 0

:fail
echo.
echo Mirror FAILED for %PROJECT%.
pause
endlocal
exit /b 1
