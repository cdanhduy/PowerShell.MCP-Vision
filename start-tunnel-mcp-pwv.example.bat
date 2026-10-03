@echo off
setlocal
cd /d "%~dp0"

echo ======================================================
echo OpenAI Secure MCP Tunnel - MCP PWM Vision
echo ======================================================
echo.

where pwsh.exe >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0debug-run-powershell-mcp-tunnel-vision.example.ps1"
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0debug-run-powershell-mcp-tunnel-vision.example.ps1"
)

set EXITCODE=%ERRORLEVEL%
if NOT "%EXITCODE%"=="0" (
    echo.
    echo ======================================================
    echo Tunnel failed or exited with code %EXITCODE%.
    echo Review the message above.
    echo ======================================================
    echo.
    pause
)

endlocal & exit /b %EXITCODE%