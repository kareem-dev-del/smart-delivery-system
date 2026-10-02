@echo off
setlocal

set PROJECT_ROOT=C:\smart-delivery-system
set BACKEND_DIR=%PROJECT_ROOT%\backend
set PYTHON_EXE=%BACKEND_DIR%\.venv\Scripts\python.exe
set LOG_DIR=%PROJECT_ROOT%\logs

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

cd /d "%BACKEND_DIR%"

"%PYTHON_EXE%" manage.py expire_overdue_orders --limit 100 >> "%LOG_DIR%\expire_overdue_orders.log" 2>&1

exit /b %ERRORLEVEL%