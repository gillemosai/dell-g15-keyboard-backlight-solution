@echo off
setlocal
echo Removendo o atalho "Cor do Teclado" da Area de Trabalho...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Remove-Item -ErrorAction SilentlyContinue ([Environment]::GetFolderPath('Desktop')+'\Cor do Teclado.lnk')"
echo.
echo Pronto. A cor gravada no teclado continua valendo ate voce escolher outra.
echo Para remover a biblioteca tambem, rode:  python -m pip uninstall hidapi
echo.
pause
