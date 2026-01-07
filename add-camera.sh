#!/bin/bash
# Script interactif pour ajouter une caméra à MediaMTX
# Supporte EZVIZ, Hikvision et autres marques

CONFIG_FILE="/etc/mediamtx/mediamtx.yml"
SCRIPT_DIR="$(dirname "$0")"
EZVIZ_FILE="$SCRIPT_DIR/camera-models.json"
HIKVISION_FILE="$SCRIPT_DIR/hikvision-models.json"
VPS_IP="69.62.108.253"

# Vérifier jq
if ! command -v jq &> /dev/null; then
    echo "Installation de jq..."
    sudo apt-get install -y jq
fi

echo "=== MVUTU SECURITY - Ajout Caméra ==="
echo ""

# 0. Sélection de la marque
echo "[0/7] Sélectionner la marque:"
echo "  1) EZVIZ"
echo "  2) Hikvision"
echo "  3) Autre (saisie manuelle)"
echo ""
read -p "Choix [1]: " BRAND_CHOICE
BRAND_CHOICE=${BRAND_CHOICE:-1}

case $BRAND_CHOICE in
    1)
        BRAND="EZVIZ"
        MODELS_FILE="$EZVIZ_FILE"
        ;;
    2)
        BRAND="Hikvision"
        MODELS_FILE="$HIKVISION_FILE"
        ;;
    3)
        BRAND="Other"
        MODELS_FILE=""
        ;;
    *)
        BRAND="EZVIZ"
        MODELS_FILE="$EZVIZ_FILE"
        ;;
esac

echo "→ Marque: $BRAND"
echo ""

# Si autre marque, saisie manuelle complète
if [ "$BRAND" == "Other" ]; then
    # Saisie manuelle
    read -p "[1/7] Protocol [rtsp://]: " PROTOCOL
    PROTOCOL=${PROTOCOL:-rtsp://}
    
    read -p "[2/7] Username [admin]: " USERNAME
    USERNAME=${USERNAME:-admin}
    
    read -p "[3/7] Password: " PASSWORD
    if [ -z "$PASSWORD" ]; then
        echo "ERREUR: Password requis"
        exit 1
    fi
    
    read -p "[4/7] IP caméra: " CAM_IP
    if [ -z "$CAM_IP" ]; then
        echo "ERREUR: IP requise"
        exit 1
    fi
    
    read -p "[5/7] Port [554]: " CAM_PORT
    CAM_PORT=${CAM_PORT:-554}
    
    read -p "[6/7] Path RTSP (ex: /Streaming/Channels/101): " CAM_PATH
    if [ -z "$CAM_PATH" ]; then
        echo "ERREUR: Path requis"
        exit 1
    fi
    
    read -p "[7/7] Serial number: " SERIAL_NUMBER
    if [ -z "$SERIAL_NUMBER" ]; then
        echo "ERREUR: Serial number requis"
        exit 1
    fi
    
    SELECTED_MODEL="Manual"
else
    # Vérifier le fichier JSON
    if [ ! -f "$MODELS_FILE" ]; then
        echo "ERREUR: $MODELS_FILE non trouvé"
        exit 1
    fi
    
    if [ "$BRAND" == "EZVIZ" ]; then
        # EZVIZ: sélection modèle
        echo "[1/7] Sélectionner le modèle:"
        echo ""
        
        UNIQUE_MODELS=$(jq -r '[.models[].model] | unique | .[]' "$MODELS_FILE" | sort -f | uniq -i)
        MODEL_ARRAY=()
        i=1
        while IFS= read -r model; do
            MODEL_ARRAY+=("$model")
            echo "  $i) $model"
            ((i++))
        done <<< "$UNIQUE_MODELS"
        
        echo ""
        read -p "Numéro du modèle: " MODEL_CHOICE
        
        if [[ "$MODEL_CHOICE" =~ ^[0-9]+$ ]] && [ "$MODEL_CHOICE" -ge 1 ] && [ "$MODEL_CHOICE" -le "${#MODEL_ARRAY[@]}" ]; then
            SELECTED_MODEL="${MODEL_ARRAY[$((MODEL_CHOICE-1))]}"
        else
            echo "Choix invalide, utilisation de 'Other'"
            SELECTED_MODEL="Other"
        fi
        
        echo "→ Modèle: $SELECTED_MODEL"
        echo ""
        
        # Récupérer les paths
        PATHS=$(jq -r --arg model "$SELECTED_MODEL" '.models[] | select(.model == $model) | "\(.path):\(.port)"' "$MODELS_FILE" | sort -u)
        
    else
        # Hikvision: sélection modèle puis path
        echo "[1/7] Sélectionner le modèle Hikvision:"
        echo ""
        
        # Liste des modèles Hikvision
        HIK_MODELS=$(jq -r '.models[].model' "$MODELS_FILE")
        MODEL_ARRAY=()
        i=1
        while IFS= read -r model; do
            MODEL_ARRAY+=("$model")
            echo "  $i) $model"
            ((i++))
        done <<< "$HIK_MODELS"
        
        echo ""
        read -p "Numéro du modèle [1]: " MODEL_CHOICE
        MODEL_CHOICE=${MODEL_CHOICE:-1}
        
        if [[ "$MODEL_CHOICE" =~ ^[0-9]+$ ]] && [ "$MODEL_CHOICE" -ge 1 ] && [ "$MODEL_CHOICE" -le "${#MODEL_ARRAY[@]}" ]; then
            SELECTED_MODEL="${MODEL_ARRAY[$((MODEL_CHOICE-1))]}"
        else
            SELECTED_MODEL="${MODEL_ARRAY[0]}"
        fi
        
        echo "→ Modèle: $SELECTED_MODEL"
        echo ""
        
        # Récupérer les paths pour ce modèle
        echo "Paths disponibles pour $SELECTED_MODEL:"
        MODEL_PATHS=$(jq -r --arg model "$SELECTED_MODEL" '.models[] | select(.model == $model) | .paths[]' "$MODELS_FILE")
        PATH_ARRAY=()
        j=1
        while IFS= read -r path; do
            PATH_ARRAY+=("$path")
            echo "  $j) $path"
            ((j++))
        done <<< "$MODEL_PATHS"
        
        # Ajouter option path générique
        echo "  $j) [Autre path générique...]"
        
        echo ""
        read -p "Numéro du path [1]: " PATH_CHOICE
        PATH_CHOICE=${PATH_CHOICE:-1}
        
        if [ "$PATH_CHOICE" -eq "$j" ]; then
            # Afficher les paths génériques
            echo ""
            echo "Paths génériques:"
            GENERIC_PATHS=$(jq -r '.common_paths[] | "\(.name): \(.path)"' "$MODELS_FILE")
            GEN_ARRAY=()
            k=1
            while IFS= read -r gpath; do
                GEN_ARRAY+=("$gpath")
                echo "  $k) $gpath"
                ((k++))
            done <<< "$GENERIC_PATHS"
            
            read -p "Numéro du path générique [1]: " GEN_CHOICE
            GEN_CHOICE=${GEN_CHOICE:-1}
            
            if [[ "$GEN_CHOICE" =~ ^[0-9]+$ ]] && [ "$GEN_CHOICE" -ge 1 ] && [ "$GEN_CHOICE" -le "${#GEN_ARRAY[@]}" ]; then
                SELECTED_GEN="${GEN_ARRAY[$((GEN_CHOICE-1))]}"
                CAM_PATH=$(echo "$SELECTED_GEN" | sed 's/.*: //')
            else
                CAM_PATH="${GEN_ARRAY[0]}"
                CAM_PATH=$(echo "$CAM_PATH" | sed 's/.*: //')
            fi
        elif [[ "$PATH_CHOICE" =~ ^[0-9]+$ ]] && [ "$PATH_CHOICE" -ge 1 ] && [ "$PATH_CHOICE" -le "${#PATH_ARRAY[@]}" ]; then
            CAM_PATH="${PATH_ARRAY[$((PATH_CHOICE-1))]}"
        else
            CAM_PATH="${PATH_ARRAY[0]}"
        fi
        
        CAM_PORT=554
    fi
    
    # Si EZVIZ, sélectionner le path
    if [ "$BRAND" == "EZVIZ" ]; then
        PATH_COUNT=$(echo "$PATHS" | grep -c .)
        
        if [ "$PATH_COUNT" -gt 1 ]; then
            echo "Paths disponibles pour $SELECTED_MODEL:"
            PATH_ARRAY=()
            j=1
            while IFS= read -r path_port; do
                PATH_ARRAY+=("$path_port")
                echo "  $j) $path_port"
                ((j++))
            done <<< "$PATHS"
            
            read -p "Numéro du path [1]: " PATH_CHOICE
            PATH_CHOICE=${PATH_CHOICE:-1}
            
            if [[ "$PATH_CHOICE" =~ ^[0-9]+$ ]] && [ "$PATH_CHOICE" -ge 1 ] && [ "$PATH_CHOICE" -le "${#PATH_ARRAY[@]}" ]; then
                SELECTED_PATH_PORT="${PATH_ARRAY[$((PATH_CHOICE-1))]}"
            else
                SELECTED_PATH_PORT="${PATH_ARRAY[0]}"
            fi
        else
            SELECTED_PATH_PORT="$PATHS"
        fi
        
        CAM_PATH=$(echo "$SELECTED_PATH_PORT" | cut -d':' -f1)
        CAM_PORT=$(echo "$SELECTED_PATH_PORT" | cut -d':' -f2)
    fi
    
    CAM_PORT=${CAM_PORT:-554}
    
    echo "→ Path: $CAM_PATH (port $CAM_PORT)"
    echo ""
    
    # 2. Username
    read -p "[2/7] Username [admin]: " USERNAME
    USERNAME=${USERNAME:-admin}
    
    # 3. Password
    read -p "[3/7] Password: " PASSWORD
    if [ -z "$PASSWORD" ]; then
        echo "ERREUR: Password requis"
        exit 1
    fi
    
    # 4. IP caméra
    read -p "[4/7] IP caméra (ex: 192.168.100.50): " CAM_IP
    if [ -z "$CAM_IP" ]; then
        echo "ERREUR: IP requise"
        exit 1
    fi
    
    # 5. Serial number
    read -p "[5/7] Serial number: " SERIAL_NUMBER
    if [ -z "$SERIAL_NUMBER" ]; then
        echo "ERREUR: Serial number requis"
        exit 1
    fi
    
    # 6. Path personnalisé (optionnel)
    read -p "[6/7] Path personnalisé (laisser vide pour $CAM_PATH): " CUSTOM_PATH
    if [ -n "$CUSTOM_PATH" ]; then
        CAM_PATH="$CUSTOM_PATH"
        echo "→ Path personnalisé: $CAM_PATH"
    fi
fi

# Nom de la caméra basé sur le serial (UPPERCASE)
SERIAL_UPPER=$(echo "$SERIAL_NUMBER" | tr '[:lower:]' '[:upper:]')
CAM_NAME="CAM-${SERIAL_UPPER}"
echo "→ Nom: $CAM_NAME"

echo ""
echo "=== Récapitulatif ==="
echo "  Nom:      $CAM_NAME"
echo "  Serial:   $SERIAL_NUMBER"
echo "  Marque:   $BRAND"
echo "  Modèle:   $SELECTED_MODEL"
echo "  IP:       $CAM_IP"
echo "  Port:     $CAM_PORT"
echo "  Path:     $CAM_PATH"
echo "  Username: $USERNAME"
echo "  URL:      rtsp://$USERNAME:***@$CAM_IP:$CAM_PORT$CAM_PATH"
echo ""

read -p "Confirmer l'ajout? [O/n]: " CONFIRM
CONFIRM=${CONFIRM:-O}

if [[ ! "$CONFIRM" =~ ^[OoYy]$ ]]; then
    echo "Annulé."
    exit 0
fi

# Vérifier si la caméra existe déjà
if grep -q "^  $CAM_NAME:" "$CONFIG_FILE" 2>/dev/null; then
    echo "ERREUR: $CAM_NAME existe déjà"
    exit 1
fi

# Construire l'URL RTSP
RTSP_URL="rtsp://$USERNAME:$PASSWORD@$CAM_IP:$CAM_PORT$CAM_PATH"

# Ajouter la caméra
echo "Ajout de $CAM_NAME..."

# Trouver la ligne "paths:" et insérer après
sudo sed -i "/^paths:/a\\
  $CAM_NAME:\\
    source: $RTSP_URL\\
    sourceProtocol: tcp\\
    sourceOnDemand: false\\
    runOnReady: >\\
      ffmpeg -hide_banner -loglevel error\\
      -rtsp_transport tcp\\
      -i rtsp://localhost:8554/\$MTX_PATH\\
      -c:v libx264 -preset ultrafast -c:a copy\\
      -f rtsp\\
      rtsp://$VPS_IP:8554/\$MTX_PATH\\
    runOnReadyRestart: true\\
" "$CONFIG_FILE"

echo "Redémarrage MediaMTX..."
sudo systemctl restart mediamtx

sleep 2

echo ""
echo "✓ $CAM_NAME ajoutée avec succès!"
echo ""
echo "Endpoints:"
echo "  RTSP:   rtsp://$(hostname -I | awk '{print $1}'):8554/$CAM_NAME"
echo "  WebRTC: http://$(hostname -I | awk '{print $1}'):8889/$CAM_NAME"
echo "  HLS:    http://$(hostname -I | awk '{print $1}'):8888/$CAM_NAME"
