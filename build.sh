#!/bin/bash
set -xe
shopt -s extglob

BUILD_DIR=workdir

# From https://stackoverflow.com/a/48808214
args=("$@")
for ((i=0; i<"${#args[@]}"; ++i)); do
    case ${args[i]} in
        -b) BUILD_DIR=${args[i+1]}; unset args[i]; unset args[i+1]; break;;
    esac
done

[ -d build ] || git clone https://gitlab.com/ubports/community-ports/halium-generic-adaptation-build-tools build

HERE=$(pwd)
SCRIPT="$(dirname "$(realpath "$0")")"/build
if [ ! -d "$SCRIPT" ]; then
    SCRIPT="$(dirname "$SCRIPT")"
fi
TMPDOWN="$BUILD_DIR/downloads"
mkdir -p "$TMPDOWN"

source deviceinfo
source "$SCRIPT/common_functions.sh"
source "$SCRIPT/setup_repositories.sh" "${TMPDOWN}"

KERNEL_DIR="$(basename "${deviceinfo_kernel_source}")"
KERNEL_DIR="${KERNEL_DIR%.*}"
echo $KERNEL_DIR

cd "$TMPDOWN/$KERNEL_DIR"

BRANCH="kernel/13/fp5"
DTS_BRANCH="kernel/13/fp5"
GERRIT_URL="https://gerrit-public.fairphone.software"
PLATFORM_VENDOR_URL="${GERRIT_URL}/platform/vendor"

# Clone kernel subfolder repositories
[ -d techpack/audio ] || git clone -b ${BRANCH} ${PLATFORM_VENDOR_URL}/opensource/audio-kernel techpack/audio
[ -d techpack/camera ] || git clone -b ${BRANCH} ${PLATFORM_VENDOR_URL}/opensource/camera-kernel techpack/camera
[ -d techpack/dataipa ] || git clone -b ${BRANCH} ${PLATFORM_VENDOR_URL}/opensource/dataipa techpack/dataipa
[ -d techpack/display ] || git clone -b ${BRANCH} ${PLATFORM_VENDOR_URL}/opensource/display-drivers techpack/display
[ -d techpack/video ] || git clone -b ${BRANCH} ${PLATFORM_VENDOR_URL}/opensource/video-driver techpack/video
[ -d drivers/staging/wlan-qc/fw-api ] || git clone -b ${BRANCH} ${PLATFORM_VENDOR_URL}/qcom-opensource/wlan/fw-api drivers/staging/wlan-qc/fw-api
[ -d drivers/staging/wlan-qc/qca-wifi-host-cmn ] || git clone -b ${BRANCH} ${PLATFORM_VENDOR_URL}/qcom-opensource/wlan/qca-wifi-host-cmn drivers/staging/wlan-qc/qca-wifi-host-cmn
[ -d drivers/staging/wlan-qc/qcacld-3.0 ] || git clone -b ${BRANCH} ${PLATFORM_VENDOR_URL}/qcom-opensource/wlan/qcacld-3.0 drivers/staging/wlan-qc/qcacld-3.0
[ -d arch/arm64/boot/dts/vendor ] || git clone -b ${DTS_BRANCH} ${GERRIT_URL}/kernel/msm-extra/devicetree arch/arm64/boot/dts/vendor

# Generate fp5_ALLYES_GKI.config from fp5_GKI.config
./scripts/gki/fragment_allyesconfig.sh arch/arm64/configs/vendor/fp5_GKI.config arch/arm64/configs/vendor/fp5_ALLYES_GKI.config

# *** NEW: Create Droidian config fragment ***
echo "Creating Droidian kernel config fragment..."
cat > arch/arm64/configs/vendor/droidian.config << 'DROIDIAN_EOF'
# Droidian required kernel options
CONFIG_DEVTMPFS=y
CONFIG_VT=y
CONFIG_NAMESPACES=y
CONFIG_MODULES=y
CONFIG_DEVPTS_MULTIPLE_INSTANCES=y
CONFIG_USB_CONFIGFS_RNDIS=y
CONFIG_USB_CONFIGFS_RMNET_BAM=y
CONFIG_USB_CONFIGFS_MASS_STORAGE=y
CONFIG_INIT_STACK_ALL_ZERO=y
CONFIG_ANDROID_PARANOID_NETWORK=n
CONFIG_ANDROID_BINDERFS=n

# Namespace support
CONFIG_SYSVIPC=y
CONFIG_PID_NS=y
CONFIG_IPC_NS=y
CONFIG_UTS_NS=y


# Waydroid support
CONFIG_SW_SYNC_USER=y
CONFIG_NET_CLS_CGROUP=y
CONFIG_CGROUP_NET_CLASSID=y
CONFIG_VETH=y
CONFIG_NETFILTER_XT_TARGET_CHECKSUM=y
CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder,anbox-binder,anbox-hwbinder,anbox-vndbinder"

# Debug support
CONFIG_PSTORE=y
CONFIG_PSTORE_CONSOLE=y
CONFIG_PSTORE_RAM=y
CONFIG_PSTORE_RAM_ANNOTATION_APPEND=y

DROIDIAN_EOF
echo "Droidian config fragment created at arch/arm64/configs/vendor/droidian.config"

# Workaround for symlinks in techpack folder
mkdir -p "../../kernel"
ln -sf "$(pwd)" "../../kernel/msm-5.4"

echo "=== Kernel configuration setup complete ==="
echo "Created Droidian config fragment at: arch/arm64/configs/vendor/droidian.config"
echo "Configuration includes:"
echo "- Basic Droidian requirements"
echo "- Bluetooth support"
echo "- Waydroid support"
echo "- Namespace support"

cd "$HERE"

./build/build.sh "${args[@]}" -b "$BUILD_DIR"
