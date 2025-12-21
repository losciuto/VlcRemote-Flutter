@echo off
REM Script per avviare VLC con interfaccia RC per VLC Remote
REM Uso: start-vlc.bat [playlist.m3u] [porta]

setlocal

set PLAYLIST=%1
set PORT=%2

if "%PORT%"=="" set PORT=8000

if "%PLAYLIST%"=="" (
    echo ❌ Errore: Devi specificare un file playlist!
    echo.
    echo Uso: %0 ^<playlist.m3u^> [porta]
    echo.
    echo Esempio:
    echo   %0 C:\path\to\playlist.m3u
    echo   %0 C:\path\to\playlist.m3u 9000
    exit /b 1
)

if not exist "%PLAYLIST%" (
    echo ❌ Errore: File playlist non trovato: %PLAYLIST%
    exit /b 1
)

REM Trova l'IP locale
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4"') do set LOCAL_IP=%%a
set LOCAL_IP=%LOCAL_IP:~1%

echo 🎵 Avvio VLC Remote Server...
echo.
echo 📁 Playlist: %PLAYLIST%
echo 🌐 IP: %LOCAL_IP%
echo 🔌 Porta: %PORT%
echo.
echo 📱 Connetti l'app VLC Remote a: %LOCAL_IP%:%PORT%
echo.
echo ⏹️  Premi Ctrl+C per fermare VLC
echo.

REM Avvia VLC
"C:\Program Files\VideoLAN\VLC\vlc.exe" "%PLAYLIST%" --intf rc --rc-host "0.0.0.0:%PORT%"
