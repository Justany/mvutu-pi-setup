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

**Option 1 : Git Clone** (recommandé)

```bash
# Sur le Raspberry Pi
cd ~
git clone https://github.com/Justany/mvutu-pi-setup.git cctv-local
cd cctv-local
chmod +x install.sh
sudo ./install.sh
```

**Option 2 : SCP depuis Mac**

```bash
# Depuis ton Mac
scp -r /Users/apple/development/cctv-setup/new-implementations/pi-local/* justany@PI_IP:~/cctv-local/

# Sur le Pi
cd ~/cctv-local
chmod +x install.sh
sudo ./install.sh
```

**Note** : Utilise `~/cctv-local` au lieu de `/tmp` car `/tmp` est vidé au redémarrage.

## Ajouter une Caméra

**Utiliser le script interactif** (recommandé) :

```bash
cd ~/cctv-local
sudo bash add-camera.sh
```

Le script :

- Supporte EZVIZ, Hikvision et autres marques
- Détecte automatiquement le modèle de caméra
- Nomme les caméras en UPPERCASE (ex: `CAM-BC9740589`)
- Configure le transcodage H265→H264 automatiquement
- Force TCP pour éviter les erreurs de transport
- Push automatique vers le VPS

**Configuration manuelle** (si nécessaire) :

Éditer `/etc/mediamtx/mediamtx.yml` :

```yaml
paths:
  CAM-BC9740589:
    source: rtsp://admin:PASSWORD@192.168.100.XXX:554/Streaming/Channels/102
    sourceProtocol: tcp
    sourceOnDemand: false
    runOnReady: >
      ffmpeg -hide_banner -loglevel error
      -rtsp_transport tcp
      -i rtsp://localhost:8554/$MTX_PATH
      -c:v libx264 -preset ultrafast -c:a copy
      -rtsp_transport tcp
      -f rtsp
      rtsp://69.62.108.253:8554/$MTX_PATH
    runOnReadyRestart: true
```

**Important** :

- Les noms de caméras doivent être en UPPERCASE
- Le transcodage H264 est nécessaire pour la compatibilité VPS
- TCP est forcé sur l'entrée ET la sortie

## Endpoints

| Protocol   | URL                               | Usage               |
| ---------- | --------------------------------- | ------------------- |
| **RTSP**   | `rtsp://PI_IP:8554/CAM-BC9740589` | VLC, clients RTSP   |
| **WebRTC** | `http://PI_IP:8889/CAM-BC9740589` | Flutter Android TV  |
| **HLS**    | `http://PI_IP:8888/CAM-BC9740589` | Navigateur fallback |
| **API**    | `http://PI_IP:9997/v3/paths/list` | Monitoring          |

**Dashboard VPS** : `http://69.62.108.253:8090`

- Affiche toutes les caméras de tous les Pi
- Layout fixe 9 slots (1 gros + 8 petits)
- Chargement dynamique depuis l'API
- Statut live/offline en temps réel

## Flutter WebRTC

```dart
// WHEP endpoint pour WebRTC
final whepUrl = 'http://192.168.100.X:8889/CAM-BC9740589/whep';

// POST avec SDP offer
final response = await http.post(
  Uri.parse(whepUrl),
  headers: {'Content-Type': 'application/sdp'},
  body: localDescription.sdp,
);
// Réponse = SDP answer
```

**Note** : Utiliser le nom de caméra en UPPERCASE retourné par l'API

## Commandes

```bash
# Status
sudo systemctl status mediamtx

# Logs temps réel
sudo journalctl -u mediamtx -f

# Redémarrer
sudo systemctl restart mediamtx

# Lister les caméras
curl http://localhost:9997/v3/paths/list | jq '.items[].name'

# Tester un flux
ffplay rtsp://localhost:8554/CAM-BC9740589

# Ajouter une caméra
sudo bash add-camera.sh

# Tester l'installation
bash test.sh
```

## Dépannage

| Problème                           | Solution                                                     |
| ---------------------------------- | ------------------------------------------------------------ |
| Caméra ne se connecte pas          | Vérifier IP/credentials, ping caméra                         |
| WebRTC ne fonctionne pas           | Vérifier port 8889, firewall                                 |
| Push VPS échoue                    | Vérifier connectivité VPS, logs ffmpeg dans journalctl       |
| Erreur "461 Unsupported Transport" | Ajouter `-rtsp_transport tcp` dans runOnReady                |
| CPU élevé                          | Utiliser transcodage H264 avec preset ultrafast              |
| Dashboard ne montre pas la caméra  | Vérifier que le nom est en UPPERCASE, vider cache navigateur |

## Notes Importantes

- **Nommage** : Toujours utiliser UPPERCASE pour les noms de caméras (ex: `CAM-BC9740589`)
- **Transcodage** : H265→H264 nécessaire pour compatibilité VPS et dashboard
- **TCP** : Forcé sur entrée et sortie pour éviter les erreurs de transport
- **Auto-start** : MediaMTX démarre automatiquement au boot du Pi
- **Multi-Pi** : Même setup réutilisable sur tous les Pi, les caméras apparaissent automatiquement sur le dashboard VPS
