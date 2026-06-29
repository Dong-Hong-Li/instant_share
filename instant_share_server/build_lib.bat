@echo off
setlocal
cd /d "%~dp0"

echo [build_lib] building web frontend ...
call build_web.bat
if errorlevel 1 exit /b 1

set OUT=..\assets\lib\instantshare.dll
if not exist "..\assets\lib" mkdir "..\assets\lib"

echo [build_lib] Windows amd64 ...
set CGO_ENABLED=1
go build -buildmode=c-shared -o "%OUT%" .\cmd\lib
if errorlevel 1 exit /b 1

if exist "..\assets\lib\instantshare.h" del /f "..\assets\lib\instantshare.h"
echo [build_lib] done -^> %OUT%
