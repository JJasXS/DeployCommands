@echo off
setlocal EnableExtensions EnableDelayedExpansion
title StudentPortal Deploy (GitLab)

REM =============================================================================
REM Music Tuition Portal -- full Windows deploy from GitLab
REM Double-click OK -- auto-elevates. Collects .env FIRST (Notepad), then deploy.
REM
REM Ports:
REM   5000  API + built website (this deploy). Open http://127.0.0.1:5000/
REM   5173  Vite dev page only (run.ps1). Not used by this service.
REM
REM Required .env keys:
REM   ASPNETCORE_URLS=http://0.0.0.0:5000
REM   VITE_API_URL=http://127.0.0.1:5000/api
REM   DatabaseProvider=Firebird
REM   SqlAccount__DatabasePath
REM   SqlAccount__DbUser
REM   SqlAccount__DbPassword
REM   Jwt__Secret
REM
REM Keep validate-env.ps1 and set-service-env.ps1 in the SAME folder as this .cmd
REM =============================================================================

REM ------------ EDIT FOR EACH CLIENT ------------
set "APP_NAME=StudentPortal"
set "EXE_NAME=MusicTuitionPortal.Api.exe"
set "REPO_URL=https://gitlabsvr.oneclickclouds.com/softwaredevelopment/StudentPortal.git"
set "GIT_BRANCH=main"
set "CSPROJ=backend\MusicTuitionPortal.Api\MusicTuitionPortal.Api.csproj"

set "WORK_DIR=C:\Source\StudentPortal"
set "APP_DIR=C:\Apps\StudentPortal\publish"
set "HTTP_PORT=5000"
set "ENV_PREP=%TEMP%\StudentPortal.env.prepared"
set "ENV_BACKUP=%TEMP%\StudentPortal.env.backup"
set "FW_RULE_NAME=StudentPortal %HTTP_PORT%"
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
  ) > "%TEMP%\elevate_studentportal_gl.vbs"
  wscript //nologo "%TEMP%\elevate_studentportal_gl.vbs"
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
echo [%DATE% %TIME%] StudentPortal deploy GitLab (Administrator)
echo Script: %~f0
echo Folder: %~dp0
echo.

if not exist "C:\Temp" mkdir "C:\Temp"

REM =============================================================================
REM STEP 0 -- Enter .env FIRST (Notepad). Deploy starts only after Save + Close.
REM =============================================================================
echo ========== STEP 0 / ENV ==========
echo Fill these values, Save, then CLOSE Notepad:
echo   ASPNETCORE_URLS=http://0.0.0.0:5000
echo   VITE_API_URL=http://127.0.0.1:5000/api
echo   SqlAccount__DatabasePath=C:\eStream\SQLAccounting\DB\PORTAL.FDB
echo   SqlAccount__DbPassword=...
echo   Jwt__Secret=...
echo.
echo Site after deploy: http://127.0.0.1:5000/
echo Swagger is off on the service. The page and /api are on port 5000.
echo.

if exist "%APP_DIR%\.env" (
  copy /Y "%APP_DIR%\.env" "%ENV_PREP%" >nul
  echo Prefill: copied from %APP_DIR%\.env
) else if exist "%ENV_BACKUP%" (
  copy /Y "%ENV_BACKUP%" "%ENV_PREP%" >nul
  echo Prefill: copied from %ENV_BACKUP%
) else (
  (
    echo # Music Tuition Portal - service listens on port 5000
    echo ASPNETCORE_ENVIRONMENT=Production
    echo ASPNETCORE_URLS=http://0.0.0.0:5000
    echo VITE_API_URL=http://127.0.0.1:5000/api
    echo VITE_APP_NAME=Harmony Music Center
    echo VITE_CENTRE_NAME=Harmony Music Center
    echo CentreName=Harmony Music Center
    echo Cors__AllowedOrigins=http://127.0.0.1:5000,http://localhost:5000
    echo DatabaseProvider=Firebird
    echo SqlAccount__DatabasePath=C:\eStream\SQLAccounting\DB\PORTAL.FDB
    echo SqlAccount__DbUser=SYSDBA
    echo SqlAccount__DbPassword=
    echo Jwt__Secret=
    echo Jwt__Issuer=MusicTuitionPortal
    echo Jwt__Audience=MusicTuitionPortalUsers
    echo Jwt__ExpiryHours=24
    echo Auth__BypassOtp=true
    echo Billplz__Sandbox=true
    echo Billplz__CallbackUrl=http://127.0.0.1:5000/api/payments/billplz/callback
    echo Billplz__RedirectUrl=http://127.0.0.1:5000/api/payments/billplz/redirect
    echo Billplz__FrontendReturnUrl=http://127.0.0.1:5000/parent/invoices
  ) > "%ENV_PREP%"
  echo Created a blank .env template.
)

echo Opening Notepad. Save, then CLOSE it to continue.
notepad "%ENV_PREP%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0validate-env.ps1" -Path "%ENV_PREP%"
if errorlevel 1 (
  echo.
  echo Fix the .env file and run this script again.
  pause
  exit /b 1
)
copy /Y "%ENV_PREP%" "%ENV_BACKUP%" >nul

REM =============================================================================
REM STEP 1 -- Tools
REM =============================================================================
echo.
echo ========== STEP 1 / TOOLS ==========
where git >nul 2>&1
if errorlevel 1 (
  echo Installing Git...
  winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
)
where git >nul 2>&1
if errorlevel 1 (
  set "PATH=%ProgramFiles%\Git\cmd;%PATH%"
)
where git >nul 2>&1
if errorlevel 1 (
  echo ERROR: Git not found. Close this window and open a new Admin window.
  pause
  exit /b 1
)

set "DOTNET=%ProgramFiles%\dotnet\dotnet.exe"
if not exist "%DOTNET%" set "DOTNET=%ProgramFiles(x86)%\dotnet\dotnet.exe"
"%DOTNET%" --list-sdks 2>nul | findstr /B "10." >nul
if errorlevel 1 (
  echo Installing .NET SDK 10...
  winget install --id Microsoft.DotNet.SDK.10 -e --accept-package-agreements --accept-source-agreements
)
if not exist "%DOTNET%" set "DOTNET=%ProgramFiles%\dotnet\dotnet.exe"
if not exist "%DOTNET%" (
  echo ERROR: dotnet.exe not found after SDK install.
  pause
  exit /b 1
)
set "PATH=%ProgramFiles%\dotnet;%PATH%"

where node >nul 2>&1
if errorlevel 1 (
  echo Installing Node.js...
  winget install --id OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements
)
where node >nul 2>&1
if errorlevel 1 (
  set "PATH=%ProgramFiles%\nodejs;%PATH%"
)
where node >nul 2>&1
if errorlevel 1 (
  echo ERROR: Node.js not found. Close this window and open a new Admin window.
  pause
  exit /b 1
)

echo Git, .NET 10, and Node.js are ready.

REM =============================================================================
REM STEP 2 -- Firewall
REM =============================================================================
echo.
echo ========== STEP 2 / FIREWALL ==========
netsh advfirewall firewall show rule name="%FW_RULE_NAME%" >nul 2>&1
if errorlevel 1 (
  netsh advfirewall firewall add rule name="%FW_RULE_NAME%" dir=in action=allow protocol=TCP localport=%HTTP_PORT%
)
echo Firewall allows TCP %HTTP_PORT%.

REM =============================================================================
REM STEP 3 -- Stop old service and free port 5000
REM =============================================================================
echo.
echo ========== STEP 3 / STOP ==========
sc query "%APP_NAME%" >nul 2>&1
if not errorlevel 1 (
  sc stop "%APP_NAME%" >nul 2>&1
  ping -n 4 127.0.0.1 >nul
  sc delete "%APP_NAME%" >nul 2>&1
  ping -n 3 127.0.0.1 >nul
)
taskkill /F /IM "%EXE_NAME%" >nul 2>&1
ping -n 2 127.0.0.1 >nul

for /f "tokens=5" %%P in ('netstat -ano ^| findstr ":%HTTP_PORT% " ^| findstr LISTENING') do (
  echo Port %HTTP_PORT% is in use by PID %%P. Stopping that process.
  taskkill /F /PID %%P >nul 2>&1
)
ping -n 2 127.0.0.1 >nul

REM =============================================================================
REM STEP 4 -- Clone
REM =============================================================================
echo.
echo ========== STEP 4 / CLONE ==========
if exist "%WORK_DIR%" rmdir /s /q "%WORK_DIR%"
mkdir "%WORK_DIR%"
git clone --branch "%GIT_BRANCH%" --depth 1 "%REPO_URL%" "%WORK_DIR%"
if errorlevel 1 (
  echo ERROR: git clone failed.
  pause
  exit /b 1
)
copy /Y "%ENV_PREP%" "%WORK_DIR%\.env" >nul

REM =============================================================================
REM STEP 5 -- Build the website, then publish the API
REM =============================================================================
echo.
echo ========== STEP 5 / BUILD ==========
pushd "%WORK_DIR%\frontend"
call npm ci
if errorlevel 1 (
  popd
  echo ERROR: npm ci failed.
  pause
  exit /b 1
)
call npm run build
if errorlevel 1 (
  popd
  echo ERROR: frontend build failed.
  pause
  exit /b 1
)
popd

if exist "%APP_DIR%" rmdir /s /q "%APP_DIR%"
mkdir "%APP_DIR%"
"%DOTNET%" publish "%WORK_DIR%\%CSPROJ%" -c Release -r win-x64 --self-contained true -o "%APP_DIR%"
if errorlevel 1 (
  echo ERROR: dotnet publish failed.
  pause
  exit /b 1
)
if not exist "%APP_DIR%\%EXE_NAME%" (
  echo ERROR: %EXE_NAME% was not published.
  pause
  exit /b 1
)

if exist "%APP_DIR%\wwwroot" rmdir /s /q "%APP_DIR%\wwwroot"
mkdir "%APP_DIR%\wwwroot"
xcopy /E /I /Y "%WORK_DIR%\frontend\dist\*" "%APP_DIR%\wwwroot\" >nul
if not exist "%APP_DIR%\wwwroot\index.html" (
  echo ERROR: frontend dist was not copied to wwwroot.
  pause
  exit /b 1
)
copy /Y "%ENV_PREP%" "%APP_DIR%\.env" >nul

REM =============================================================================
REM STEP 6 -- Windows service
REM =============================================================================
echo.
echo ========== STEP 6 / SERVICE ==========
sc create "%APP_NAME%" binPath= "%APP_DIR%\%EXE_NAME%" start= auto DisplayName= "Music Tuition Portal"
if errorlevel 1 (
  echo ERROR: sc create failed.
  pause
  exit /b 1
)
sc description "%APP_NAME%" "Music Tuition Portal on port %HTTP_PORT%"
sc failure "%APP_NAME%" reset= 86400 actions= restart/5000/restart/5000/restart/5000
sc config "%APP_NAME%" start= auto

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0set-service-env.ps1" -EnvPath "%ENV_PREP%" -ServiceName "%APP_NAME%"
if errorlevel 1 (
  echo ERROR: could not set service environment.
  pause
  exit /b 1
)

sc start "%APP_NAME%"
if errorlevel 1 (
  echo ERROR: service did not start. Check the .env database path and password.
  pause
  exit /b 1
)

echo Waiting for http://127.0.0.1:%HTTP_PORT%/ ...
ping -n 8 127.0.0.1 >nul
powershell -NoProfile -Command "try { (Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:%HTTP_PORT%/' -TimeoutSec 20).StatusCode } catch { if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { exit 1 } }"
if errorlevel 1 (
  echo WARN: the service is installed but the page did not answer yet.
  echo Check: sc query %APP_NAME%
) else (
  echo Page answered on port %HTTP_PORT%.
)

echo.
echo ========== CLEANUP ==========
if exist "%WORK_DIR%" rmdir /s /q "%WORK_DIR%"

echo.
echo Done.
echo   Site:    http://localhost:%HTTP_PORT%/
echo   API:     http://localhost:%HTTP_PORT%/api
echo   Service: %APP_NAME%
echo   Files:   %APP_DIR%
echo.
echo Opening http://localhost:%HTTP_PORT%/
start "" "http://localhost:%HTTP_PORT%/"
pause
endlocal
exit /b 0
