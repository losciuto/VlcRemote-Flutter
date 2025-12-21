#!/bin/bash

# Script per avviare VLC con interfaccia RC per VLC Remote
# Uso: ./start-vlc.sh [playlist.m3u] [porta]

PLAYLIST="${1:-}"
PORT="${2:-8000}"

if [ -z "$PLAYLIST" ]; then
    echo "❌ Errore: Devi specificare un file playlist!"
    echo ""
    echo "Uso: $0 <playlist.m3u> [porta]"
    echo ""
    echo "Esempio:"
    echo "  $0 /path/to/playlist.m3u"
    echo "  $0 /path/to/playlist.m3u 9000"
    exit 1
fi

if [ ! -f "$PLAYLIST" ]; then
    echo "❌ Errore: File playlist non trovato: $PLAYLIST"
    exit 1
fi

# Trova l'IP locale
if command -v hostname &> /dev/null; then
    LOCAL_IP=$(hostname -I | awk '{print $1}')
elif command -v ipconfig &> /dev/null; then
    LOCAL_IP=$(ipconfig getifaddr en0)
else
    LOCAL_IP="<IP non rilevato>"
fi

echo "🎵 Avvio VLC Remote Server..."
echo ""
echo "📁 Playlist: $PLAYLIST"
echo "🌐 IP: $LOCAL_IP"
echo "🔌 Porta: $PORT"
echo ""
echo "📱 Connetti l'app VLC Remote a: $LOCAL_IP:$PORT"
echo ""
echo "⏹️  Premi Ctrl+C per fermare VLC"
echo ""

# Avvia VLC
vlc "$PLAYLIST" --intf rc --rc-host "0.0.0.0:$PORT"
