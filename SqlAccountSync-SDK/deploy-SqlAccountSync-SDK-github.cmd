@echo off
setlocal EnableExtensions EnableDelayedExpansion
title SqlAccountSync SDK Deploy (GitHub)

REM =============================================================================
REM SqlAccountSync SDK Live -- deploy from GitHub branch sdk-conversion
REM Double-click OK -- auto-elevates. Collects .env FIRST (Notepad), then deploy.
REM
REM Runs as a Scheduled Task at user logon (NOT LocalSystem service) so SQL
REM Account COM / SQLAcc.BizApp works reliably.
REM
REM Required .env keys (runtime AWS auth = access keys below; no aws login):
REM   TENANT_CODE
REM   TENANT_BOOTSTRAP_API_URL
REM   AWS_REGION
REM   AWS_ACCESS_KEY_ID
REM   AWS_SECRET_ACCESS_KEY
REM Optional:
REM   SDK_SECRET_ID=proacc/tenant/{TENANT}/sdkConnections
REM   APP_MODE=dev|prod
REM =============================================================================

set "APP_NAME=SqlAccountSync"
set "TASK_NAME=SqlAccountSync-SDK"
set "EXE_NAME=SqlAccountSync.exe"
set "REPO_URL=https://github.com/JJasXS/multiDBSync.git"
set "GIT_BRANCH=sdk-jason.vers"
set "CSPROJ=src\SqlAccountSync\SqlAccountSync.csproj"

set "WORK_DIR=C:\Source\SqlAccountSync"
set "APP_DIR=C:\Apps\SqlAccountSync\publish"
set "HTTP_PORT=5030"
set "ENV_PREP=%TEMP%\SqlAccountSync-SDK.env.prepared"
set "ENV_BACKUP=%TEMP%\SqlAccountSync-SDK.env.backup"
set "FW_RULE_NAME=SqlAccountSync %HTTP_PORT%"
set "TASK_XML=%TEMP%\SqlAccountSync-SDK-task.xml"

REM --- Auto-elevate ---
net session >nul 2>&1
if errorlevel 1 (
  echo.
  echo This window is not Administrator.
  echo Requesting UAC elevation -- click YES...
  echo.
  (
    echo Set sh = CreateObject^("Shell.Application"^)
    echo sh.ShellExecute "cmd.exe", "/k cd /d ""%~dp0"" ^& call ""%~f0""", "%~dp0", "runas", 1
  ) > "%TEMP%\elevate_sqlaccountsync_sdk.vbs"
  wscript //nologo "%TEMP%\elevate_sqlaccountsync_sdk.vbs"
  if errorlevel 1 (
    echo ERROR: Could not request elevation.
    echo Right-click this file -^> Run as administrator
    pause
    exit /b 1
  )
  echo If no Admin window appeared, right-click and choose "Run as administrator".
  pause
  exit /b 0
)

cd /d "%~dp0"
echo.
echo [%DATE% %TIME%] SqlAccountSync SDK deploy GitHub (Administrator)
echo Branch: %GIT_BRANCH%
echo Script: %~f0
echo.

if not exist "C:\Temp" mkdir "C:\Temp"

echo ========== STEP 0 / ENV ==========
echo Fill these values, Save, then CLOSE Notepad:
echo   TENANT_CODE=...
echo   TENANT_BOOTSTRAP_API_URL=https://...execute-api.../proacc-tenant-config-api
echo   AWS_REGION=ap-southeast-1
echo   AWS_ACCESS_KEY_ID=...
echo   AWS_SECRET_ACCESS_KEY=...
echo   SDK_SECRET_ID=proacc/tenant/YOUR_TENANT/sdkConnections
echo   ASPNETCORE_URLS=http://0.0.0.0:%HTTP_PORT%
echo   APP_MODE=dev   ^(show OTP on login^)  or  APP_MODE=prod  ^(email OTP only^)
echo.

if exist "%APP_DIR%\.env" (
  copy /Y "%APP_DIR%\.env" "%ENV_PREP%" >nul
  echo Prefill: copied from %APP_DIR%\.env
) else if exist "%ENV_BACKUP%" (
  copy /Y "%ENV_BACKUP%" "%ENV_PREP%" >nul
  echo Prefill: copied from %ENV_BACKUP%
) else (
  (
    echo # SqlAccountSync SDK Live
    echo TENANT_CODE=
    echo TENANT_BOOTSTRAP_API_URL=
    echo AWS_REGION=ap-southeast-1
    echo AWS_ACCESS_KEY_ID=
    echo AWS_SECRET_ACCESS_KEY=
    echo SDK_SECRET_ID=
    echo ASPNETCORE_URLS=http://0.0.0.0:5030
    echo APP_MODE=dev
    echo.
    echo # Optional central Firebird control DB
    echo # CentralDb__Path=C:/SQLData/SqlAccountSync/SYNC.FDB
    echo # CENTRAL_FB_MASTERKEY=masterkey
  ) > "%ENV_PREP%"
  echo Prefill: new template created
)

REM Existing .env copies won't have new keys — append APP_MODE if missing
findstr /B /I /C:"APP_MODE=" "%ENV_PREP%" >nul 2>&1
if errorlevel 1 (
  echo.>> "%ENV_PREP%"
  echo # Login OTP: APP_MODE=dev shows code on page; prod = email only>> "%ENV_PREP%"
  echo APP_MODE=dev>> "%ENV_PREP%"
  echo Added missing APP_MODE=dev to .env prefill
)

notepad "%ENV_PREP%"

set "ENV_VALIDATOR=%~dp0validate-env.ps1"
if not exist "%ENV_VALIDATOR%" (
  echo ERROR: validate-env.ps1 not found next to this script.
  goto :fail
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%ENV_VALIDATOR%" -EnvPath "%ENV_PREP%"
if errorlevel 1 (
  echo .env is incomplete. Fix values and run again.
  goto :fail
)
copy /Y "%ENV_PREP%" "%ENV_BACKUP%" >nul
copy /Y "%ENV_PREP%" "C:\Temp\SqlAccountSync-SDK.env.backup" >nul

echo.
echo ========== STEP 0b / Windows user for scheduled task ==========
echo Using the Windows account that launched this elevated deploy ^(no typing needed^).
echo Do NOT use SQL Account ADMIN / email addresses — those are not Windows SIDs.
set "TASK_USER=%USERDOMAIN%\%USERNAME%"
if /I "%USERDOMAIN%"=="%COMPUTERNAME%" set "TASK_USER=%USERNAME%"
echo Using task user: %TASK_USER%
echo.

echo ========== PREFLIGHT: SQL Account COM ==========
reg query "HKCR\SQLAcc.BizApp\CLSID" >nul 2>&1
if errorlevel 1 (
  echo ERROR: SQLAcc.BizApp is not registered.
  echo Install SQL Account, or run: SQLACC.exe /regserver
  goto :fail
)
echo COM ProgID SQLAcc.BizApp: OK
echo AWS: using AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY from .env ^(no aws login^)

where git >nul 2>&1
if errorlevel 1 (
  winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
)
where dotnet >nul 2>&1
if errorlevel 1 (
  winget install --id Microsoft.DotNet.SDK.8 -e --source winget --accept-package-agreements --accept-source-agreements
)
set "PATH=%PATH%;%ProgramFiles%\Git\cmd;%ProgramFiles%\dotnet;%ProgramFiles(x86)%\dotnet"
set "DOTNET_EXE=%ProgramFiles%\dotnet\dotnet.exe"
if not exist "%DOTNET_EXE%" set "DOTNET_EXE=%ProgramFiles(x86)%\dotnet\dotnet.exe"
if not exist "%DOTNET_EXE%" (
  echo ERROR: dotnet.exe not found.
  goto :fail
)

echo [0/10] Firewall allow inbound TCP %HTTP_PORT%...
netsh advfirewall firewall show rule name="%FW_RULE_NAME%" >nul 2>&1
if errorlevel 1 (
  netsh advfirewall firewall add rule name="%FW_RULE_NAME%" dir=in action=allow protocol=TCP localport=%HTTP_PORT%
)

echo [1/10] Stop old Windows service ^(API mode^) if present...
sc query "%APP_NAME%" >nul 2>&1
if not errorlevel 1 (
  sc stop "%APP_NAME%" >nul 2>&1
  timeout /t 4 /nobreak >nul
  sc config "%APP_NAME%" start= disabled >nul 2>&1
  echo   Service %APP_NAME% stopped and disabled ^(SDK uses scheduled task instead^).
)
schtasks /End /TN "%TASK_NAME%" >nul 2>&1
taskkill /F /IM "%EXE_NAME%" >nul 2>&1

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
if not exist "C:\Source" mkdir "C:\Source"
if not exist "C:\Apps\SqlAccountSync" mkdir "C:\Apps\SqlAccountSync"
if not exist "%APP_DIR%" mkdir "%APP_DIR%"

echo [4/10] Clone GitHub branch %GIT_BRANCH%...
git clone --depth 1 -b %GIT_BRANCH% "%REPO_URL%" "%WORK_DIR%"
if errorlevel 1 (
  echo ERROR: git clone failed. Push branch %GIT_BRANCH% to GitHub first.
  goto :fail
)
if not exist "%WORK_DIR%\%CSPROJ%" (
  echo ERROR: clone missing %CSPROJ%
  goto :fail
)

echo [5/10] Publish self-contained win-x64...
pushd "%WORK_DIR%"
"%DOTNET_EXE%" publish "%CSPROJ%" -c Release -r win-x64 --self-contained true -o "%APP_DIR%" /p:RazorCompileOnBuild=true
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

echo [6/10] Install .env...
copy /Y "%ENV_PREP%" "%APP_DIR%\.env" >nul

echo [7/10] Register scheduled task %TASK_NAME% ^(At log on, highest privileges^)...
schtasks /Delete /TN "%TASK_NAME%" /F >nul 2>&1
(
  echo ^<?xml version="1.0" encoding="UTF-16"?^>
  echo ^<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task"^>
  echo   ^<RegistrationInfo^>^<Description^>SqlAccountSync SDK Live ^(COM^)^</Description^>^</RegistrationInfo^>
  echo   ^<Triggers^>^<LogonTrigger^>^<Enabled^>true^</Enabled^>^<UserId^>%TASK_USER%^</UserId^>^</LogonTrigger^>^</Triggers^>
  echo   ^<Principals^>^<Principal id="Author"^>^<UserId^>%TASK_USER%^</UserId^>^<LogonType^>InteractiveToken^</LogonType^>^<RunLevel^>HighestAvailable^</RunLevel^>^</Principal^>^</Principals^>
  echo   ^<Settings^>^<MultipleInstancesPolicy^>IgnoreNew^</MultipleInstancesPolicy^>^<DisallowStartIfOnBatteries^>false^</DisallowStartIfOnBatteries^>^<StopIfGoingOnBatteries^>false^</StopIfGoingOnBatteries^>^<AllowHardTerminate^>true^</AllowHardTerminate^>^<StartWhenAvailable^>true^</StartWhenAvailable^>^<RunOnlyIfNetworkAvailable^>false^</RunOnlyIfNetworkAvailable^>^<IdleSettings^>^<StopOnIdleEnd^>false^</StopOnIdleEnd^>^<RestartOnIdle^>false^</RestartOnIdle^>^</IdleSettings^>^<AllowStartOnDemand^>true^</AllowStartOnDemand^>^<Enabled^>true^</Enabled^>^<Hidden^>true^</Hidden^>^<RunOnlyIfIdle^>false^</RunOnlyIfIdle^>^<WakeToRun^>false^</WakeToRun^>^<ExecutionTimeLimit^>PT0S^</ExecutionTimeLimit^>^<Priority^>7^</Priority^>^<RestartOnFailure^>^<Interval^>PT1M^</Interval^>^<Count^>3^</Count^>^</RestartOnFailure^>^</Settings^>
  echo   ^<Actions Context="Author"^>^<Exec^>^<Command^>%APP_DIR%\%EXE_NAME%^</Command^>^<WorkingDirectory^>%APP_DIR%^</WorkingDirectory^>^</Exec^>^</Actions^>
  echo ^</Task^>
) > "%TASK_XML%"
schtasks /Create /TN "%TASK_NAME%" /XML "%TASK_XML%" /F
if errorlevel 1 (
  echo XML import failed; trying /RU /RL HIGHEST...
  schtasks /Create /TN "%TASK_NAME%" /TR "\"%APP_DIR%\%EXE_NAME%\"" /SC ONLOGON /RU "%TASK_USER%" /RL HIGHEST /F
  if errorlevel 1 (
    echo ERROR: could not create scheduled task.
    goto :fail
  )
)

echo [8/10] Start task now...
schtasks /Run /TN "%TASK_NAME%"
timeout /t 8 /nobreak >nul

echo [9/10] Cleanup clone...
cd /d C:\
if exist "%WORK_DIR%" rmdir /s /q "%WORK_DIR%"

echo [10/10] Verify...
echo.
echo ========== VERIFY ==========
schtasks /Query /TN "%TASK_NAME%" /V /FO LIST | findstr /I "TaskName Status Logon Mode Run As User Task To Run"
echo.
tasklist | findstr /I "%EXE_NAME%"
echo.
echo Listening on %HTTP_PORT%:
netstat -ano | findstr ":%HTTP_PORT%"
echo.
powershell -NoProfile -Command "try { (Invoke-WebRequest -UseBasicParsing http://127.0.0.1:%HTTP_PORT%/health).Content } catch { $_.Exception.Message }"
echo.
echo Browser: http://127.0.0.1:%HTTP_PORT%/
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
