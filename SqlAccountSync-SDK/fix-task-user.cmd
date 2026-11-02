@echo off
net session >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b 0
)
set "TASK=SqlAccountSync-SDK"
set "EXE=C:\Apps\SqlAccountSync\publish\SqlAccountSync.exe"
set "USER=%USERDOMAIN%\%USERNAME%"
echo Creating %TASK% as %USER% ...
schtasks /Delete /TN "%TASK%" /F >nul 2>&1
schtasks /Create /TN "%TASK%" /TR "\"%EXE%\"" /SC ONLOGON /RU "%USER%" /RL HIGHEST /F
if errorlevel 1 (
  echo Domain form failed; trying local username %USERNAME% ...
  schtasks /Create /TN "%TASK%" /TR "\"%EXE%\"" /SC ONLOGON /RU "%USERNAME%" /RL HIGHEST /F
  if errorlevel 1 (
    echo FAILED
    pause
    exit /b 1
  )
)
schtasks /Run /TN "%TASK%"
timeout /t 6 /nobreak >nul
schtasks /Query /TN "%TASK%" /FO LIST | findstr /I "TaskName Status"
powershell -NoProfile -Command "try{(Invoke-WebRequest -UseBasicParsing http://127.0.0.1:5030/).StatusCode}catch{$_.Exception.Message}"
echo Done.
pause
