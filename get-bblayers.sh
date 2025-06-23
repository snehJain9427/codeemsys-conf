#!/bin/bash

# Exit on error
set -e

BUILD_DIR="$1"
CONF_DIR="$BUILD_DIR/conf"


EXCLUDE_LAYERS=("meta-selftest" "meta-skeleton" "meta-poky", "meta-openembedded")
OE_SUB_LAYERS=("meta-networking" "meta-python" "meta-oe" "meta-filesystem" "meta-multimedia")

# Create initial auto.conf
cat > "$CONF_DIR/bblayers.conf" <<EOF
LCONF_VERSION="6"

BBPATH="\${TOPDIR}"
BBFILES?=""

BBLAYERS = " \\
EOF

# Add meta layers except exclusions
get-meta-layers () {
    LAYERS=$(find "${BUILD_DIR}/../layers" -maxdepth 1 -type d -name "meta*")
    for layer in ${LAYERS}; do
        skip=false
        for exclude in "${EXCLUDE_LAYERS[@]}"; do
            if [[ "$layer" == *"$exclude"* ]]; then
                skip=true
                break
            fi
        done
        if ! $skip; then
            echo "  $(realpath "$layer") \\" >> "$CONF_DIR/bblayers.conf"
        fi
    done
}

# Add poky meta layers except exclusions
get-poky-meta-layers () {
    LAYERS=$(find "${BUILD_DIR}/../layers/poky" -maxdepth 1 -type d -name "meta*")
    for layer in ${LAYERS}; do
        skip=false
        for exclude in "${EXCLUDE_LAYERS[@]}"; do
            if [[ "$layer" == *"$exclude"* ]]; then
                skip=true
                break
            fi
        done
        if ! $skip; then
            echo "  $(realpath "$layer") \\" >> "$CONF_DIR/bblayers.conf"
        fi
    done
}

# Add selected OE layers only
get-openembedded-layers () {
    for sublayer in "${OE_SUB_LAYERS[@]}"; do
        layer=$(find "${BUILD_DIR}/../layers/poky/meta-openembedded" -maxdepth 1 -type d -name "$sublayer" 2>/dev/null)
        if [ -n "$layer" ]; then
            echo "  $(realpath "$layer") \\" >> "$CONF_DIR/bblayers.conf"
        fi
    done
}

# Run functions
get-meta-layers
get-poky-meta-layers
get-openembedded-layers

# Close BBLAYERS
echo '"' >> "$CONF_DIR/bblayers.conf"


