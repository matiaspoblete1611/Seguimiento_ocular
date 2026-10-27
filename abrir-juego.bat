@echo off
rem Abre el juego de seguimiento ocular en el navegador con la camara habilitada.
rem La camara solo funciona en http://localhost (o HTTPS), no con doble clic (file://).
rem No hace falta Python ni Node: el servidor es un script de PowerShell.

cd /d "%~dp0"

echo Iniciando servidor local en http://localhost:8788 ...
start "Servidor juego ocular" /min powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0servidor-local.ps1"

rem Espera breve para que el puerto quede escuchando.
timeout /t 2 /nobreak >nul

start "" "http://localhost:8788/juego-seguimiento-ocular.html"
