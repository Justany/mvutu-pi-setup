# MediaMTX Local - Raspberry Pi

## Architecture

```
┌───────────────────────────────────────────────────────────────────────────┐
│                           RÉSEAU LOCAL                                    │
│  ┌──────────┐   RTSP      ┌─────────────────┐   WebRTC   ┌─────────────┐  │
│  │ Caméras  │ ───────►    │  Raspberry Pi   │ ─────────► │ Android TV  │  │
│  │ EZVIZ    │   :554      │   MediaMTX      │   :8889    │  (Flutter)  │  │
│  │ x4       │             │                 │            └─────────────┘  │
│  └──────────┘             │  :8554 RTSP     │                             │
│                           │  :8889 WebRTC   │                             │
│                           │  :8888 HLS      │                             │
│                           └────────┬────────┘                             │
└────────────────────────────────────┼──────────────────────────────────────┘
                                     │ FFmpeg push (runOnReady)
                                     ▼
                          ┌─────────────────────┐
                          │      VPS            │
                          │  69.62.108.253      │
                          │  MediaMTX :8554     │
                          │                     │
                          │  WebRTC → Salle     │
                          │  de contrôle        │
                          └─────────────────────┘
```

## Installation

```bash
# Sur le Raspberry Pi
cd /tmp
git clone <repo> ou scp les fichiers

cd pi-local
chmod +x install.sh
sudo ./install.sh
```

## Configuration Caméras

Éditer `/etc/mediamtx/mediamtx.yml` pour ajouter/modifier les caméras :

```yaml
paths:
  cam1:
    source: rtsp://admin:PASSWORD@192.168.100.XXX:554/Streaming/Channels/102
    sourceProtocol: tcp
    sourceOnDemand: false
    runOnReady: >
      ffmpeg -hide_banner -loglevel error
      -rtsp_transport tcp
      -i rtsp://localhost:8554/$MTX_PATH
      -c copy -f rtsp
      rtsp://69.62.108.253:8554/$MTX_PATH
    runOnReadyRestart: true
```

## Endpoints

| Protocol   | URL                               | Usage               |
| ---------- | --------------------------------- | ------------------- |
| **RTSP**   | `rtsp://PI_IP:8554/cam1`          | VLC, clients RTSP   |
| **WebRTC** | `http://PI_IP:8889/cam1`          | Flutter Android TV  |
| **HLS**    | `http://PI_IP:8888/cam1`          | Navigateur fallback |
| **API**    | `http://PI_IP:9997/v3/paths/list` | Monitoring          |

## Flutter WebRTC

```dart
// WHEP endpoint pour WebRTC
final whepUrl = 'http://192.168.100.X:8889/cam1/whep';

// POST avec SDP offer
final response = await http.post(
  Uri.parse(whepUrl),
  headers: {'Content-Type': 'application/sdp'},
  body: localDescription.sdp,
);
// Réponse = SDP answer
```

## Commandes

```bash
# Status
sudo systemctl status mediamtx

# Logs temps réel
sudo journalctl -u mediamtx -f

# Redémarrer
sudo systemctl restart mediamtx

# Tester un flux
ffplay rtsp://localhost:8554/cam1
```

## Dépannage

| Problème                  | Solution                                             |
| ------------------------- | ---------------------------------------------------- |
| Caméra ne se connecte pas | Vérifier IP/credentials, ping caméra                 |
| WebRTC ne fonctionne pas  | Vérifier port 8889, firewall                         |
| Push VPS échoue           | Vérifier connectivité VPS, ffmpeg installé           |
| CPU élevé                 | Réduire nombre de caméras, vérifier `sourceOnDemand` |
