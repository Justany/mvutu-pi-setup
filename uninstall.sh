#!/bin/bash
# Désinstallation MediaMTX
set -e

echo "=== Désinstallation MediaMTX ==="

sudo systemctl stop mediamtx 2>/dev/null || true
sudo systemctl disable mediamtx 2>/dev/null || true
sudo rm -f /etc/systemd/system/mediamtx.service
sudo systemctl daemon-reload

sudo rm -rf /opt/mediamtx
sudo rm -rf /etc/mediamtx

echo "MediaMTX désinstallé."
