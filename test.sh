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
    
    # Lister les caméras avec jq si disponible
    if command -v jq &> /dev/null; then
        CAMERAS=$(echo $API_RESPONSE | jq -r '.items[].name' 2>/dev/null)
        if [ ! -z "$CAMERAS" ]; then
            echo "   → Caméras configurées:"
            echo "$CAMERAS" | while read cam; do
                echo "      - $cam"
            done
        else
            echo "   → Aucune caméra configurée"
        fi
    else
        PATHS=$(echo $API_RESPONSE | grep -o '"name"' | wc -l)
        echo "   → $PATHS paths configurés"
    fi
else
    echo "   ✗ API inaccessible"
fi

# Test première caméra si elle existe
FIRST_CAM=$(curl -s "http://localhost:9997/v3/paths/list" 2>/dev/null | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ ! -z "$FIRST_CAM" ]; then
    echo "[3] Test RTSP ($FIRST_CAM)..."
    if command -v ffprobe &> /dev/null; then
        RTSP_TEST=$(timeout 5 ffprobe -v error -show_entries format=duration -of default=nw=1 "rtsp://localhost:8554/$FIRST_CAM" 2>&1)
        if echo "$RTSP_TEST" | grep -q "error"; then
            echo "   ✗ RTSP non disponible"
        else
            echo "   ✓ RTSP accessible"
        fi
    else
        echo "   → ffprobe non installé, skip test RTSP"
    fi

    echo "[4] Test WebRTC endpoint..."
    WEBRTC_TEST=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8889/$FIRST_CAM" 2>/dev/null)
    if [ "$WEBRTC_TEST" = "200" ]; then
        echo "   ✓ WebRTC endpoint OK"
    else
        echo "   → WebRTC endpoint code: $WEBRTC_TEST"
    fi
else
    echo "[3] Aucune caméra configurée - skip tests flux"
fi

# Test connectivité VPS
echo "[5] Connectivité VPS ($VPS_IP)..."
if ping -c 1 -W 2 $VPS_IP > /dev/null 2>&1; then
    echo "   ✓ VPS accessible"
    
    # Test push vers VPS si caméra existe
    if [ ! -z "$FIRST_CAM" ]; then
        echo "[6] Test push VPS..."
        VPS_STATUS=$(curl -s "http://$VPS_IP:9997/v3/paths/list" 2>/dev/null | grep -o "\"$FIRST_CAM\"")
        if [ ! -z "$VPS_STATUS" ]; then
            echo "   ✓ Caméra visible sur VPS"
        else
            echo "   → Caméra pas encore sur VPS (vérifier logs ffmpeg)"
        fi
    fi
else
    echo "   ✗ VPS inaccessible"
fi

echo ""
echo "=== Endpoints ==="
if [ ! -z "$FIRST_CAM" ]; then
    echo "RTSP:   rtsp://$PI_IP:8554/$FIRST_CAM"
    echo "WebRTC: http://$PI_IP:8889/$FIRST_CAM"
    echo "HLS:    http://$PI_IP:8888/$FIRST_CAM"
fi
echo "API:    http://$PI_IP:9997/v3/paths/list"
echo "Dashboard VPS: http://$VPS_IP:8090"
