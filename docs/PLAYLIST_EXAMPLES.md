# Esempi di Playlist per VLC Remote

Questo file contiene esempi di come creare playlist per VLC.

## Formato M3U

Il formato M3U è il più semplice e supportato da VLC.

### Esempio Base

```m3u
#EXTM3U
#EXTINF:123,Artista - Titolo Canzone 1
/path/to/song1.mp3
#EXTINF:234,Artista - Titolo Canzone 2
/path/to/song2.mp3
#EXTINF:345,Artista - Titolo Canzone 3
/path/to/song3.mp3
```

### Esempio con Video

```m3u
#EXTM3U
#EXTINF:3600,Film 1
/path/to/movies/film1.mp4
#EXTINF:5400,Film 2
/path/to/movies/film2.mkv
#EXTINF:7200,Serie TV S01E01
/path/to/series/s01e01.mp4
```

### Esempio con URL Streaming

```m3u
#EXTM3U
#EXTINF:-1,Radio Stream
http://stream.example.com/radio
#EXTINF:-1,Video Stream
https://example.com/video/stream.m3u8
```

## Creare una Playlist

### Linux/macOS

```bash
# Crea playlist da una directory
find /path/to/music -name "*.mp3" > playlist.m3u

# Con informazioni estese
for file in /path/to/music/*.mp3; do
    echo "#EXTINF:-1,$(basename "$file" .mp3)"
    echo "$file"
done > playlist.m3u
```

### Windows PowerShell

```powershell
# Crea playlist da una directory
Get-ChildItem -Path "C:\Music" -Filter *.mp3 | 
    ForEach-Object { $_.FullName } | 
    Out-File -FilePath playlist.m3u -Encoding UTF8
```

### Con VLC

1. Apri VLC
2. Aggiungi i file alla playlist
3. Media → Salva Playlist come File...
4. Scegli formato M3U
5. Salva

## Playlist di Esempio

### Rock Classics
```m3u
#EXTM3U
#EXTINF:243,Queen - Bohemian Rhapsody
/music/rock/queen-bohemian_rhapsody.mp3
#EXTINF:312,Led Zeppelin - Stairway to Heaven
/music/rock/led_zeppelin-stairway_to_heaven.mp3
#EXTINF:256,AC/DC - Back in Black
/music/rock/acdc-back_in_black.mp3
```

### Chill Vibes
```m3u
#EXTM3U
#EXTINF:234,Lofi Hip Hop - Study Session
/music/lofi/study_session.mp3
#EXTINF:198,Ambient - Peaceful Morning
/music/ambient/peaceful_morning.mp3
#EXTINF:276,Jazz - Smooth Evening
/music/jazz/smooth_evening.mp3
```

### Film Night
```m3u
#EXTM3U
#EXTINF:7200,The Matrix (1999)
/movies/the_matrix_1999.mkv
#EXTINF:8100,Inception (2010)
/movies/inception_2010.mp4
#EXTINF:9000,Interstellar (2014)
/movies/interstellar_2014.mkv
```

## Formati Supportati

VLC supporta molti formati di file:

### Audio
- MP3, AAC, FLAC, WAV, OGG, WMA
- M4A, OPUS, APE, MPC

### Video
- MP4, MKV, AVI, MOV, WMV
- FLV, WEBM, MPG, MPEG, VOB

### Streaming
- HTTP, HTTPS, RTSP, RTMP
- HLS (m3u8), DASH

## Tips & Tricks

### Percorsi Relativi

Usa percorsi relativi per playlist portabili:

```m3u
#EXTM3U
#EXTINF:123,Song 1
./music/song1.mp3
#EXTINF:234,Song 2
./music/song2.mp3
```

### Playlist Ricorsiva

Includi tutte le sottodirectory:

```bash
find /path/to/music -type f \( -name "*.mp3" -o -name "*.flac" \) > playlist.m3u
```

### Ordinamento

Ordina alfabeticamente:

```bash
find /path/to/music -name "*.mp3" | sort > playlist.m3u
```

### Playlist Casuale

Ordine casuale:

```bash
find /path/to/music -name "*.mp3" | shuf > playlist.m3u
```

## Usare con VLC Remote

1. Crea la tua playlist (es. `mymusic.m3u`)
2. Avvia VLC con la playlist:
   ```bash
   vlc mymusic.m3u --intf rc --rc-host 0.0.0.0:8000
   ```
3. Connetti VLC Remote
4. Controlla la riproduzione!

## Playlist Online

Puoi anche usare playlist online:

```bash
vlc http://example.com/playlist.m3u --intf rc --rc-host 0.0.0.0:8000
```

## Troubleshooting

### File non trovati

- Usa percorsi assoluti
- Verifica che i file esistano
- Controlla i permessi

### Caratteri speciali

- Usa UTF-8 encoding
- Evita caratteri speciali nei nomi file
- Usa `"` per percorsi con spazi

### Performance

- Playlist grandi (>1000 elementi) possono essere lente
- Considera di dividere in playlist più piccole
- Usa SSD per file locali

---

Per maggiori informazioni, vedi la [documentazione VLC](https://wiki.videolan.org/Documentation:Playlist/).
