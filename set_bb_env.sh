#!/bin/bash

# Ensure /bin/sh points to bash
if [[ ! $(readlink -f "$(which sh)") =~ bash ]]; then
    echo ""
    echo "### ERROR: /bin/sh must point to bash. ###"
    echo ""
    echo "Run the following command to fix:"
    echo "sudo ln -sf /bin/bash /bin/sh"
    echo ""
    return 1
fi

# Ensure SHELL is set to bash
if [[ ! $SHELL =~ bash ]]; then
    echo ""
    echo "### ERROR: Your default shell must be bash. ###"
    echo ""
    echo "Run the following command to fix:"
    echo "chsh -s /bin/bash"
    echo ""
    return 1
fi

# Set umask so default permissions are 755 for dirs and 644 for files
umask 022

# Get the absolute path of this script
THIS_SCRIPT=$(readlink -f "${BASH_SOURCE[0]}")
echo "Script path        : ${THIS_SCRIPT}"

# Get the directory containing this script
scriptdir="$(dirname "${THIS_SCRIPT}")"
echo "Script directory   : ${scriptdir}"

# Set workspace path (one level above script directory)
WS="${scriptdir}/.."
echo "Workspace path     : ${WS}"
echo ""

# Print usage
usage () {
    cat << EOF
Usage:
    MACHINE=<MACHINE_NAME> source ${THIS_SCRIPT} [BUILDDIR]
EOF
}

# Optional configuration message
conf_note () {
    cat << EOF
### Environment ready to configure BitBake ###
EOF
}

# Function to initialize build environment using Yocto's setup script
init_build_env () {
    conf_note
    BB_ENV_PASSTHROUGH_ADDITIONS="DEBUG_BUILD PREBUILT_SRC_DIR"
    . "${WS}/layers/poky/oe-init-build-env" "${BUILDDIR}"
    
    # Clean up environment variables after sourcing
    unset MACHINE WS usage conf_note PREBUILT_SRC_DIR TEMPLATECONF THIS_SCRIPT
    unset DISTROTABLE DISTROLAYERS MACHINETABLE MACHINELAYERS ITEM IMGCHOICE IMAGEINFO EXTRALAYERS
}

# If more than one argument is given, print usage and exit
if [ $# -gt 1 ]; then
    usage
    return 1
fi

# Determine BUILDDIR based on input or default
if [ $# -eq 1 ]; then
    BUILDDIR="${WS}/$1"
else
    echo "No build directory provided, using default 'build_codeemsys'."
    BUILDDIR="${WS}/build-codeemsys"
fi

# If build directory exists and has valid config files, use it
if [ -f "${BUILDDIR}/conf/local.conf" ] &&
   [ -f "${BUILDDIR}/conf/auto.conf" ] &&
   [ -f "${BUILDDIR}/conf/bblayers.conf" ]; then
    echo "Using existing build directory: ${BUILDDIR}"
    init_build_env
    return
fi

# Try to find a suitable terminal UI tool
read uitool <<< "$(which whiptail dialog 2>/dev/null)"

# Find available machines in the meta-raspberrypi layer
MACHLAYERS=$(find layers/meta-raspberrypi -name "*.conf" -path "*/conf/machine/*" | \
    sed -e 's/\.conf//g' -e 's|layers/||g' | \
    awk -F '/conf/machine/' '{print $NF "(" $1 ")"}')

# If machines are found and MACHINE is not already set
if [ -n "${MACHLAYERS}" ] && [ -z "${MACHINE}" ]; then
    for item in ${MACHLAYERS}; do
        MACHINETABLE="${MACHINETABLE} $(echo "${item}" | cut -d '(' -f1) $(echo "${item}" | cut -d '(' -f2 | cut -d ')' -f1)"
    done

    MACHINETABLE="${MACHINETABLE} Show-All-Machines From-All-BSP-Layers"

    # Prompt user to select a machine
    MACHINE=$($uitool --title "Preferred Machines" --menu \
        "Please choose a machine" 0 0 20 \
        ${MACHINETABLE} 3>&1 1>&2 2>&3)

    if [ "${MACHINE}" == "Show-All-Machines" ] || [ -z "${MACHINE}" ]; then
        echo "No machine selected."
        return 1
    fi

    echo "Selected machine   : ${MACHINE}"
fi

# Create the build directory if not already present
mkdir -p "${BUILDDIR}/conf"

# Generate bblayers.conf using the helper script
bash "${scriptdir}/get-bblayers.sh" "${BUILDDIR}"

# Initialize Yocto build environment
init_build_env

