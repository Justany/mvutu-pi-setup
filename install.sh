#!/bin/bash
# Installation MediaMTX sur Raspberry Pi
# MVUTU Security - CCTV Local Proxy

set -e

echo "=== MVUTU SECURITY - Installation MediaMTX Pi Local ==="

# Variables
MEDIAMTX_VERSION="1.9.3"
ARCH=$(uname -m)
INSTALL_DIR="/opt/mediamtx"
CONFIG_DIR="/etc/mediamtx"

# Déterminer architecture
case $ARCH in
    armv7l|armv6l)
        MEDIAMTX_ARCH="armv7"
        ;;
    aarch64)
        MEDIAMTX_ARCH="arm64v8"
        ;;
    *)
        echo "Architecture non supportée: $ARCH"
        exit 1
        ;;
esac

echo "[1/6] Mise à jour système..."
sudo apt update && sudo apt upgrade -y

echo "[2/6] Installation dépendances..."
sudo apt install -y ffmpeg curl wget

echo "[3/6] Téléchargement MediaMTX v${MEDIAMTX_VERSION}..."
cd /tmp
wget -q "https://github.com/bluenviron/mediamtx/releases/download/v${MEDIAMTX_VERSION}/mediamtx_v${MEDIAMTX_VERSION}_linux_${MEDIAMTX_ARCH}.tar.gz"
tar xzf "mediamtx_v${MEDIAMTX_VERSION}_linux_${MEDIAMTX_ARCH}.tar.gz"

echo "[4/6] Installation binaire..."
sudo mkdir -p $INSTALL_DIR $CONFIG_DIR
sudo mv mediamtx $INSTALL_DIR/
sudo chmod +x $INSTALL_DIR/mediamtx

echo "[5/6] Copie configuration..."
if [ -f "./mediamtx.yml" ]; then
    sudo cp ./mediamtx.yml $CONFIG_DIR/
else
    echo "ATTENTION: mediamtx.yml non trouvé, copier manuellement vers $CONFIG_DIR/"
fi

echo "[6/6] Création service systemd..."
sudo tee /etc/systemd/system/mediamtx.service > /dev/null << 'EOF'
[Unit]
Description=MediaMTX RTSP/WebRTC Server
Documentation=https://github.com/bluenviron/mediamtx
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/mediamtx
ExecStart=/opt/mediamtx/mediamtx /etc/mediamtx/mediamtx.yml
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable mediamtx
sudo systemctl start mediamtx

echo ""
echo "=== Installation terminée ==="
echo ""
echo "Endpoints disponibles:"
echo "  RTSP:   rtsp://$(hostname -I | awk '{print $1}'):8554/cam1"
echo "  WebRTC: http://$(hostname -I | awk '{print $1}'):8889/cam1"
echo "  HLS:    http://$(hostname -I | awk '{print $1}'):8888/cam1"
echo "  API:    http://$(hostname -I | awk '{print $1}'):9997/v3/paths/list"
echo ""
echo "Commandes utiles:"
echo "  sudo systemctl status mediamtx"
echo "  sudo journalctl -u mediamtx -f"
echo "  sudo systemctl restart mediamtx"
