#!/bin/bash
# Désinstallation MediaMTX
set -e

echo "=== Désinstallation MediaMTX ==="
echo ""

# Arrêter et désactiver le service
echo "[1] Arrêt du service..."
sudo systemctl stop mediamtx 2>/dev/null || true
sudo systemctl disable mediamtx 2>/dev/null || true
echo "   ✓ Service arrêté"

# Supprimer le service systemd
echo "[2] Suppression du service systemd..."
sudo rm -f /etc/systemd/system/mediamtx.service
sudo systemctl daemon-reload
echo "   ✓ Service systemd supprimé"

# Supprimer les fichiers
echo "[3] Suppression des fichiers..."
sudo rm -rf /opt/mediamtx
sudo rm -rf /etc/mediamtx
echo "   ✓ Fichiers supprimés"

# Vérifier qu'il ne reste rien
echo "[4] Vérification..."
if [ ! -d "/opt/mediamtx" ] && [ ! -d "/etc/mediamtx" ]; then
    echo "   ✓ Désinstallation complète"
else
    echo "   ⚠ Certains fichiers restent"
fi

echo ""
echo "MediaMTX désinstallé avec succès."
echo ""
echo "Note: Les caméras configurées ont été supprimées."
echo "Pour réinstaller: sudo ./install.sh"
