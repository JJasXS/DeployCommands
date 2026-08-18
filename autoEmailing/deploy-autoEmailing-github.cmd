@echo off
setlocal EnableExtensions EnableDelayedExpansion
title autoEmailing Deploy (GitHub)

REM =============================================================================
REM SQL Accounting Email Worker (autoEmailing) -- full Windows deploy from GitHub
REM Double-click OK -- auto-elevates. Collects .env FIRST (Notepad), then deploy.
REM
REM Required .env keys:
REM   TENANT_CODE
REM   TENANT_BOOTSTRAP_API_URL
REM
REM Optional (often useful):
REM   AWS_REGION / AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
REM   App__Schedule__SendTime / App__Schedule__TimeZone
REM
REM Keep validate-env.ps1 in the SAME folder as this .cmd
REM =============================================================================

REM ------------ EDIT FOR EACH CLIENT ------------
set "APP_NAME=SQL Accounting Email Worker"
set "EXE_NAME=SqlAccountingEmailWorker.exe"
set "REPO_URL=https://github.com/JJasXS/autoEmailing.git"
set "GIT_BRANCH=main"
set "CSPROJ=SqlAccountingEmailWorker.csproj"

set "WORK_DIR=C:\Services\autoEmailing"
set "APP_DIR=C:\Services\autoEmailing\publish"
set "ENV_PREP=%TEMP%\autoEmailing.env.prepared"
set "ENV_BACKUP=%TEMP%\autoEmailing.env.backup"
REM ----------------------------------------------

REM --- Auto-elevate (first window closes; a new Admin window opens) ---
net session >nul 2>&1
if errorlevel 1 (
  echo.
  echo This window is not Administrator.
  echo Requesting UAC elevation -- click YES...
  echo A NEW Admin window will open with cmd /k ^(stays open^).
  echo.
  (
    echo Set sh = CreateObject^("Shell.Application"^)
    echo sh.ShellExecute "cmd.exe", "/k cd /d ""%~dp0"" ^& call ""%~f0""", "%~dp0", "runas", 1
  ) > "%TEMP%\elevate_autoemailing.vbs"
  wscript //nologo "%TEMP%\elevate_autoemailing.vbs"
  if errorlevel 1 (
    echo.
    echo ERROR: Could not request elevation.
    echo Right-click this file -^> Run as administrator
    pause
    exit /b 1
  )
  echo.
  echo If no Admin window appeared, right-click this file and choose "Run as administrator".
  pause
  exit /b 0
)

cd /d "%~dp0"
echo.
echo [%DATE% %TIME%] autoEmailing deploy GitHub (Administrator)
echo Script: %~f0
echo Folder: %~dp0
echo.

if not exist "C:\Temp" mkdir "C:\Temp"
if not exist "C:\Services" mkdir "C:\Services"

REM =============================================================================
REM STEP 0 -- Enter .env FIRST (Notepad). Deploy starts only after Save + Close.
REM =============================================================================
echo ========== STEP 0 / ENV ==========
echo Fill TENANT_CODE and TENANT_BOOTSTRAP_API_URL, Save, then CLOSE Notepad.
echo Optional: AWS keys / schedule settings ^(see .env.example in the repo^).
echo.

if exist "%APP_DIR%\.env" (
  copy /Y "%APP_DIR%\.env" "%ENV_PREP%" >nul
  echo Prefill: copied from %APP_DIR%\.env
) else if exist "%WORK_DIR%\.env" (
  copy /Y "%WORK_DIR%\.env" "%ENV_PREP%" >nul
  echo Prefill: copied from %WORK_DIR%\.env
) else if exist "%ENV_BACKUP%" (
  copy /Y "%ENV_BACKUP%" "%ENV_PREP%" >nul
  echo Prefill: copied from %ENV_BACKUP%
) else if exist "C:\Temp\autoEmailing.env.backup" (
  copy /Y "C:\Temp\autoEmailing.env.backup" "%ENV_PREP%" >nul
  echo Prefill: copied from C:\Temp\autoEmailing.env.backup
) else (
  (
    echo # autoEmailing / SQL Accounting Email Worker
    echo TENANT_CODE=
    echo TENANT_BOOTSTRAP_API_URL=
    echo AWS_REGION=ap-southeast-1
    echo AWS_ACCESS_KEY_ID=
    echo AWS_SECRET_ACCESS_KEY=
    echo App__Schedule__SendTime=08:00
    echo App__Schedule__TimeZone=Asia/Kuala_Lumpur
  ) > "%ENV_PREP%"
  echo Prefill: new template created
)

echo.
echo Opening Notepad: %ENV_PREP%
echo After you Save and Close Notepad, deploy continues...
echo.
notepad "%ENV_PREP%"

set "ENV_VALIDATOR=%~dp0validate-env.ps1"
if not exist "%ENV_VALIDATOR%" set "ENV_VALIDATOR=C:\Temp\validate-autoEmailing-env.ps1"
if not exist "%ENV_VALIDATOR%" (
  echo ERROR: validate-env.ps1 not found next to this script or in C:\Temp.
  echo Put validate-env.ps1 in the SAME folder as this .cmd
  goto :fail
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%ENV_VALIDATOR%" -EnvPath "%ENV_PREP%"
if errorlevel 1 (
  echo.
  echo .env is incomplete. Fix TENANT_CODE and TENANT_BOOTSTRAP_API_URL, then run this script again.
  goto :fail
)

copy /Y "%ENV_PREP%" "%ENV_BACKUP%" >nul
copy /Y "%ENV_PREP%" "C:\Temp\autoEmailing.env.backup" >nul
echo Env saved. Starting deploy...
echo.

where git >nul 2>&1
if errorlevel 1 (
  echo Installing Git via winget...
  winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
)
where dotnet >nul 2>&1
if errorlevel 1 (
  echo Installing .NET SDK 10 via winget...
  winget install --id Microsoft.DotNet.SDK.10 -e --source winget --accept-package-agreements --accept-source-agreements
)
set "PATH=%PATH%;%ProgramFiles%\Git\cmd;%ProgramFiles%\dotnet;%ProgramFiles(x86)%\dotnet"
where git >nul 2>&1
if errorlevel 1 (
  echo ERROR: Git still not in PATH. Open a new Admin CMD and retry.
  goto :fail
)
where dotnet >nul 2>&1
if errorlevel 1 (
  echo ERROR: dotnet still not in PATH. Open a new Admin CMD and retry.
  goto :fail
)

echo [1/8] Stop / remove old service...
sc query "%APP_NAME%" >nul 2>&1
if not errorlevel 1 (
  sc stop "%APP_NAME%" >nul 2>&1
  timeout /t 5 /nobreak >nul
)
taskkill /F /IM "%EXE_NAME%" >nul 2>&1
sc delete "%APP_NAME%" >nul 2>&1
timeout /t 3 /nobreak >nul

echo [2/8] Wipe old source / publish folders...
if exist "%WORK_DIR%" rmdir /s /q "%WORK_DIR%"
timeout /t 1 /nobreak >nul
if not exist "C:\Services" mkdir "C:\Services"

echo [3/8] Clone GitHub branch %GIT_BRANCH%...
echo   URL: %REPO_URL%
git clone --depth 1 -b %GIT_BRANCH% "%REPO_URL%" "%WORK_DIR%"
if errorlevel 1 (
  echo ERROR: git clone failed.
  goto :fail
)
if not exist "%WORK_DIR%\%CSPROJ%" (
  echo ERROR: clone missing %CSPROJ%
  dir "%WORK_DIR%"
  goto :fail
)

echo [4/8] Publish self-contained win-x64...
pushd "%WORK_DIR%"
dotnet publish "%CSPROJ%" -c Release -r win-x64 --self-contained true -o "%APP_DIR%"
if errorlevel 1 (
  popd
  echo ERROR: dotnet publish failed.
  goto :fail
)
popd

if not exist "%APP_DIR%\%EXE_NAME%" (
  echo ERROR: %EXE_NAME% missing after publish.
  goto :fail
)

echo [5/8] Install prepared .env...
copy /Y "%ENV_PREP%" "%APP_DIR%\.env" >nul
copy /Y "%ENV_PREP%" "%WORK_DIR%\.env" >nul
if not exist "%APP_DIR%\.env" (
  echo ERROR: failed to write %APP_DIR%\.env
  goto :fail
)

echo [6/8] Register Windows Service...
sc create "%APP_NAME%" binPath= "\"%APP_DIR%\%EXE_NAME%\"" start= auto
if errorlevel 1 (
  echo ERROR: sc create failed.
  goto :fail
)
sc description "%APP_NAME%" "SQL Accounting scheduled email worker (autoEmailing)."
sc failure "%APP_NAME%" reset= 86400 actions= restart/60000/restart/60000/restart/60000 >nul 2>&1

echo [7/8] Start service...
sc start "%APP_NAME%"
timeout /t 6 /nobreak >nul

echo [8/8] Verify...
echo.
echo ========== VERIFY ==========
sc query "%APP_NAME%"
echo.
tasklist | findstr /I "%EXE_NAME%"
echo.
if exist "%APP_DIR%\%EXE_NAME%" (echo EXE: OK) else (echo EXE: MISSING)
if exist "%APP_DIR%\.env" (echo .env: OK) else (echo .env: MISSING)
echo.
echo Publish folder: %APP_DIR%
echo.
echo Done. Press any key to close.
pause
endlocal
exit /b 0

:fail
echo.
echo Deploy FAILED. Press any key to close.
pause
endlocal
exit /b 1
