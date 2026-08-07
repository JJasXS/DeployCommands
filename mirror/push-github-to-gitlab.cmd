@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Push GitHub code to GitLab

REM =============================================================================
REM Mirror selected GitHub repos onto GitLab (HTTPS).
REM
REM WARNING: git push --mirror makes GitLab an EXACT copy of GitHub.
REM          Branches that exist only on GitLab will be deleted.
REM
REM Uses HTTPS (port 443). SSH git@... is often blocked behind Cloudflare.
REM =============================================================================

cd /d "%~dp0"
if not exist "_tmp" mkdir "_tmp"

where git >nul 2>&1
if errorlevel 1 (
  echo ERROR: Git not found in PATH.
  pause
  exit /b 1
)

echo.
echo ========== GitHub -^> GitLab mirror ==========
echo.
echo  1^) ProAccScanner
echo  2^) autoEmailing
echo  3^) ABS_System
echo  4^) eQuotation
echo  5^) ApprovalPO
echo  A^) ALL
echo  Q^) Quit
echo.
set /p "CHOICE=Select project: "

if /I "%CHOICE%"=="Q" exit /b 0
if /I "%CHOICE%"=="1" goto :one_ProAccScanner
if /I "%CHOICE%"=="2" goto :one_autoEmailing
if /I "%CHOICE%"=="3" goto :one_ABS_System
if /I "%CHOICE%"=="4" goto :one_eQuotation
if /I "%CHOICE%"=="5" goto :one_ApprovalPO
if /I "%CHOICE%"=="A" goto :all
echo Invalid choice.
pause
exit /b 1

:all
call :mirror ProAccScanner
if errorlevel 1 goto :fail
call :mirror autoEmailing
if errorlevel 1 goto :fail
call :mirror ABS_System
if errorlevel 1 goto :fail
call :mirror eQuotation
if errorlevel 1 goto :fail
call :mirror ApprovalPO
if errorlevel 1 goto :fail
goto :done

:one_ProAccScanner
call :mirror ProAccScanner
if errorlevel 1 goto :fail
goto :done

:one_autoEmailing
call :mirror autoEmailing
if errorlevel 1 goto :fail
goto :done

:one_ABS_System
call :mirror ABS_System
if errorlevel 1 goto :fail
goto :done

:one_eQuotation
call :mirror eQuotation
if errorlevel 1 goto :fail
goto :done

:one_ApprovalPO
call :mirror ApprovalPO
if errorlevel 1 goto :fail
goto :done

:mirror
set "REPO=%~1"
set "GH=https://github.com/JJasXS/%REPO%.git"
set "GL=https://gitlabsvr.oneclickclouds.com/softwaredevelopment/%REPO%.git"
set "TMPDIR=%~dp0_tmp\%REPO%.git"

echo.
echo ---------- %REPO% ----------
echo GitHub: %GH%
echo GitLab: %GL%
echo.

echo [1/4] GitHub heads before:
git ls-remote --heads "%GH%"
echo.
echo [1/4] GitLab heads before:
git ls-remote --heads "%GL%"
echo.

if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%"

echo [2/4] Clone --mirror from GitHub...
git clone --mirror "%GH%" "%TMPDIR%"
if errorlevel 1 (
  echo ERROR: mirror clone failed for %REPO%
  exit /b 1
)

echo [3/4] Push --mirror to GitLab...
pushd "%TMPDIR%"
git remote set-url --push origin "%GL%"
git push --mirror
if errorlevel 1 (
  popd
  echo ERROR: mirror push failed for %REPO%
  exit /b 1
)
popd

echo [4/4] Cleanup temp clone...
rmdir /s /q "%TMPDIR%"

echo.
echo GitLab heads after:
git ls-remote --heads "%GL%"
echo.
echo OK: %REPO% mirrored.
exit /b 0

:done
echo.
echo ========== ALL SELECTED MIRRORS DONE ==========
pause
endlocal
exit /b 0

:fail
echo.
echo Mirror FAILED.
pause
endlocal
exit /b 1
