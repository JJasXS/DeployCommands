@echo off
setlocal EnableExtensions EnableDelayedExpansion
title ABS System Deploy (GitHub)

REM =============================================================================
REM ABS System (e-Booking) -- full Windows deploy from GitHub
REM Double-click OK -- auto-elevates. Collects .env FIRST (Notepad), then deploy.
REM
REM Required .env keys:
REM   TENANT_CODE
REM   TENANT_BOOTSTRAP_API_URL
REM   AWS_REGION
REM   AWS_ACCESS_KEY_ID
REM   AWS_SECRET_ACCESS_KEY
REM
REM Keep validate-env.ps1 in the SAME folder as this .cmd
REM =============================================================================

REM ------------ EDIT FOR EACH CLIENT ------------
set "APP_NAME=ABS_System"
set "EXE_NAME=ABS_System.exe"
set "REPO_URL=https://github.com/JJasXS/ABS_System.git"
set "GIT_BRANCH=fix-from-old"
set "CSPROJ=ABS_System.csproj"

set "WORK_DIR=C:\ABS_System"
set "APP_DIR=C:\Apps\ABS_System\publish"
set "HTTP_PORT=8080"
set "ENV_PREP=%TEMP%\ABS_System.env.prepared"
set "ENV_BACKUP=%TEMP%\ABS_System.env.backup"
set "FW_RULE_NAME=ABS System %HTTP_PORT%"
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
  ) > "%TEMP%\elevate_abs_system.vbs"
  wscript //nologo "%TEMP%\elevate_abs_system.vbs"
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
echo [%DATE% %TIME%] ABS System deploy GitHub (Administrator)
echo Script: %~f0
echo Folder: %~dp0
echo.

if not exist "C:\Temp" mkdir "C:\Temp"

REM =============================================================================
REM STEP 0 -- Enter .env FIRST (Notepad). Deploy starts only after Save + Close.
REM =============================================================================
echo ========== STEP 0 / ENV ==========
echo Fill these values, Save, then CLOSE Notepad:
echo   TENANT_CODE=...
echo   TENANT_BOOTSTRAP_API_URL=https://...execute-api.../proacc-tenant-config-api
echo   AWS_REGION=ap-southeast-1
echo   AWS_ACCESS_KEY_ID=...
echo   AWS_SECRET_ACCESS_KEY=...
echo.
echo Tip: AWS keys are usually the same for every client; only TENANT_CODE changes.
echo.

if exist "%APP_DIR%\.env" (
  copy /Y "%APP_DIR%\.env" "%ENV_PREP%" >nul
  echo Prefill: copied from %APP_DIR%\.env
) else if exist "%ENV_BACKUP%" (
  copy /Y "%ENV_BACKUP%" "%ENV_PREP%" >nul
  echo Prefill: copied from %ENV_BACKUP%
) else if exist "C:\Temp\ABS_System.env.backup" (
  copy /Y "C:\Temp\ABS_System.env.backup" "%ENV_PREP%" >nul
  echo Prefill: copied from C:\Temp\ABS_System.env.backup
) else (
  (
    echo # ABS System / e-Booking - tenant API URL no longer defaults in appsettings.json
    echo TENANT_CODE=
    echo TENANT_BOOTSTRAP_API_URL=
    echo AWS_REGION=ap-southeast-1
    echo AWS_ACCESS_KEY_ID=
    echo AWS_SECRET_ACCESS_KEY=
  ) > "%ENV_PREP%"
  echo Prefill: new template created
)

echo.
echo Opening Notepad: %ENV_PREP%
echo After you Save and Close Notepad, deploy continues...
echo.
notepad "%ENV_PREP%"

set "ENV_VALIDATOR=%~dp0validate-env.ps1"
if not exist "%ENV_VALIDATOR%" set "ENV_VALIDATOR=C:\Temp\validate-ABS-env.ps1"
if not exist "%ENV_VALIDATOR%" (
  echo ERROR: validate-env.ps1 not found next to this script or in C:\Temp.
  echo Put validate-env.ps1 in the SAME folder as this .cmd
  goto :fail
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%ENV_VALIDATOR%" -EnvPath "%ENV_PREP%"
if errorlevel 1 (
  echo.
  echo .env is incomplete. Fix the 4 values and run this script again.
  goto :fail
)

copy /Y "%ENV_PREP%" "%ENV_BACKUP%" >nul
copy /Y "%ENV_PREP%" "C:\Temp\ABS_System.env.backup" >nul
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

echo [0/10] Firewall allow inbound TCP %HTTP_PORT%...
netsh advfirewall firewall show rule name="%FW_RULE_NAME%" >nul 2>&1
if errorlevel 1 (
  netsh advfirewall firewall add rule name="%FW_RULE_NAME%" dir=in action=allow protocol=TCP localport=%HTTP_PORT%
) else (
  echo   Rule already exists: %FW_RULE_NAME%
)

echo [1/10] Stop / remove old service...
sc query "%APP_NAME%" >nul 2>&1
if not errorlevel 1 (
  sc stop "%APP_NAME%" >nul 2>&1
  timeout /t 5 /nobreak >nul
)
taskkill /F /IM "%EXE_NAME%" >nul 2>&1
sc delete "%APP_NAME%" >nul 2>&1
timeout /t 3 /nobreak >nul

echo [2/10] Free port %HTTP_PORT%...
for /f "tokens=5" %%P in ('netstat -ano ^| findstr ":%HTTP_PORT%" ^| findstr LISTENING') do (
  echo   Ending PID %%P
  taskkill /F /PID %%P >nul 2>&1
)
timeout /t 2 /nobreak >nul

echo [3/10] Wipe old source / publish folders...
if exist "%WORK_DIR%" rmdir /s /q "%WORK_DIR%"
if exist "%APP_DIR%" rmdir /s /q "%APP_DIR%"
timeout /t 1 /nobreak >nul
if not exist "C:\Apps\ABS_System" mkdir "C:\Apps\ABS_System"
if not exist "%APP_DIR%" mkdir "%APP_DIR%"

echo [4/10] Clone GitHub branch %GIT_BRANCH%...
echo   URL: %REPO_URL%
git clone --depth 1 -b %GIT_BRANCH% "%REPO_URL%" "%WORK_DIR%"
if errorlevel 1 (
  echo ERROR: git clone failed.
  goto :fail
)
if not exist "%WORK_DIR%\%CSPROJ%" (
  echo ERROR: clone missing %CSPROJ%
  echo The cloned repo is probably the WRONG project. Folder contents:
  dir "%WORK_DIR%"
  goto :fail
)

echo [5/10] Clean + publish self-contained win-x64...
pushd "%WORK_DIR%"
dotnet clean "%CSPROJ%" -c Release >nul
if exist bin rmdir /s /q bin
if exist obj rmdir /s /q obj
dotnet restore "%CSPROJ%"
if errorlevel 1 (
  popd
  echo ERROR: dotnet restore failed.
  goto :fail
)
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

echo [6/10] Install prepared .env + cleanup logos...
copy /Y "%ENV_PREP%" "%APP_DIR%\.env" >nul
if not exist "%APP_DIR%\.env" (
  echo ERROR: failed to write %APP_DIR%\.env
  goto :fail
)
del /q "%APP_DIR%\wwwroot\images\somore_logo*.png" 2>nul

echo [7/10] Register Windows Service...
sc create "%APP_NAME%" binPath= "\"%APP_DIR%\%EXE_NAME%\"" start= auto
if errorlevel 1 (
  echo ERROR: sc create failed.
  goto :fail
)
sc description "%APP_NAME%" "ABS System Background Service"
sc failure "%APP_NAME%" reset= 86400 actions= restart/60000/restart/60000/restart/60000 >nul 2>&1

echo [8/10] Start service...
sc start "%APP_NAME%"
timeout /t 6 /nobreak >nul

echo [9/10] Cleanup clone...
cd /d C:\
if exist "%WORK_DIR%" rmdir /s /q "%WORK_DIR%"

echo [10/10] Verify...
echo.
echo ========== VERIFY ==========
sc query "%APP_NAME%"
echo.
tasklist | findstr /I "%EXE_NAME%"
echo.
echo Listening on %HTTP_PORT%:
netstat -ano | findstr ":%HTTP_PORT%"
echo.
dir "%APP_DIR%\*.exe"
echo.
if exist "%APP_DIR%\%EXE_NAME%" (echo EXE: OK) else (echo EXE: MISSING)
if exist "%APP_DIR%\.env" (echo .env: OK) else (echo .env: MISSING)
echo.
echo Browser: http://127.0.0.1:%HTTP_PORT%/
echo.
start "" "http://127.0.0.1:%HTTP_PORT%/"
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
