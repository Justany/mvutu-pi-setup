#!/bin/bash
# remove-camera.sh
# Usage: sudo bash remove-camera.sh CAM-BC9749815

CONFIG_FILE="/etc/mediamtx/mediamtx.yml"
CAM_NAME="$1"

if [ -z "$CAM_NAME" ]; then
  echo "Usage: sudo bash remove-camera.sh CAM-NAME"
  exit 1
fi

if ! grep -q "^  $CAM_NAME:" "$CONFIG_FILE"; then
  echo "✗ $CAM_NAME absent de $CONFIG_FILE"
  exit 0
fi

# Sauvegarde
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak-$(date +%Y%m%d-%H%M%S)"

# Supprimer le bloc caméra (indentation 2 espaces)
sudo awk -v cam="  $CAM_NAME:" '
BEGIN {skip=0}
{
  if ($0 ~ cam) {skip=1}
  if (skip && $0 !~ /^  [A-Z0-9-]+:/ && $0 !~ /^paths:/) {next}
  if (skip && $0 ~ /^  [A-Z0-9-]+:/) {skip=0}
  if (!skip) print $0
}' "$CONFIG_FILE" | sudo tee "${CONFIG_FILE}.tmp" >/dev/null

sudo mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
sudo systemctl restart mediamtx && echo "✓ $CAM_NAME supprimée et service redémarré"