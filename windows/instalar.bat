@echo off
setlocal
cd /d "%~dp0"
echo.
echo === Cor do Teclado - Dell G15 (Windows) ===
echo.

python --version >nul 2>nul
if errorlevel 1 goto sempython

echo [1/2] Instalando a biblioteca hidapi...
python -m pip install --upgrade hidapi
if errorlevel 1 goto erropip

echo.
echo [2/2] Criando o atalho "Cor do Teclado" na Area de Trabalho...
set "ALVO=%~dp0g15_teclado_windows.py"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$py=(Get-Command pythonw -ErrorAction SilentlyContinue).Source; if(-not $py){$py=(Get-Command python).Source}; $q=[char]34; $s=(New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Desktop')+'\Cor do Teclado.lnk'); $s.TargetPath=$py; $s.Arguments=$q+$env:ALVO+$q; $s.WorkingDirectory=(Split-Path $env:ALVO); $s.Save()"
if errorlevel 1 goto erroatalho

echo.
echo Pronto! Feche o Alienware Command Center e abra o atalho "Cor do Teclado".
echo Se algo nao funcionar, rode no PowerShell:  python g15_teclado_windows.py --diagnostico
echo.
pause
exit /b 0

:sempython
echo O Python nao foi encontrado.
echo Instale o Python 3 (marque "Add Python to PATH" na instalacao) e rode este arquivo de novo.
start "" https://www.python.org/downloads/
pause
exit /b 1

:erropip
echo Nao consegui instalar a biblioteca hidapi. Confira a internet e tente de novo.
pause
exit /b 1

:erroatalho
echo Nao consegui criar o atalho, mas voce pode abrir o app com:  python g15_teclado_windows.py
pause
exit /b 1
