@echo off
setlocal
set "TASK_PYTHON=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
if exist "%TASK_PYTHON%" (
  "%TASK_PYTHON%" -u "%~dp0platform_cli.py" %*
) else (
  py -3 -u "%~dp0platform_cli.py" %*
)
