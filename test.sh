#!/bin/bash
# Test de l'installation MediaMTX

PI_IP=$(hostname -I | awk '{print $1}')
VPS_IP="69.62.108.253"

echo "=== Test MediaMTX Local ==="
echo ""

# Test service
echo "[1] Service MediaMTX..."
if systemctl is-active --quiet mediamtx; then
    echo "   ✓ Service actif"
else
    echo "   ✗ Service inactif"
    exit 1
fi

# Test API
echo "[2] API MediaMTX..."
API_RESPONSE=$(curl -s "http://localhost:9997/v3/paths/list" 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "   ✓ API accessible"
    PATHS=$(echo $API_RESPONSE | grep -o '"name"' | wc -l)
    echo "   → $PATHS paths configurés"
else
    echo "   ✗ API inaccessible"
fi

# Test RTSP local
echo "[3] RTSP local (cam1)..."
RTSP_TEST=$(timeout 5 ffprobe -v error -show_entries format=duration -of default=nw=1 "rtsp://localhost:8554/cam1" 2>&1)
if echo "$RTSP_TEST" | grep -q "error"; then
    echo "   ✗ RTSP cam1 non disponible"
else
    echo "   ✓ RTSP cam1 accessible"
fi

# Test WebRTC endpoint
echo "[4] WebRTC endpoint..."
WEBRTC_TEST=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8889/cam1" 2>/dev/null)
if [ "$WEBRTC_TEST" = "200" ]; then
    echo "   ✓ WebRTC endpoint OK"
else
    echo "   → WebRTC endpoint code: $WEBRTC_TEST"
fi

# Test connectivité VPS
echo "[5] Connectivité VPS ($VPS_IP)..."
if ping -c 1 -W 2 $VPS_IP > /dev/null 2>&1; then
    echo "   ✓ VPS accessible"
else
    echo "   ✗ VPS inaccessible"
fi

echo ""
echo "=== Endpoints ==="
echo "RTSP:   rtsp://$PI_IP:8554/cam1"
echo "WebRTC: http://$PI_IP:8889/cam1"
echo "HLS:    http://$PI_IP:8888/cam1"
echo "API:    http://$PI_IP:9997/v3/paths/list"
