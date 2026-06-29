@echo off
setlocal
cd /d "%~dp0web"

where npm >nul 2>&1
if errorlevel 1 (
  echo [build_web] npm not found. Install Node.js first. >&2
  exit /b 1
)

if not exist node_modules (
  echo [build_web] npm install ...
  call npm install
)

echo [build_web] npm run build ...
call npm run build
echo [build_web] done -^> internal/web/dist
