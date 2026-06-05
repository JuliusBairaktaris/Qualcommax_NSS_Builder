#
# NSS variant fragment for the Xiaomi AX3600.
# Appended to devices/xiaomi_ax3600/config by prepare-build.sh.
# Enables IPQ807x Network Subsystem hardware offload (qosmio openwrt-ipq + nss-packages).
#

## NSS hardware offload
CONFIG_ATH11K_NSS_SUPPORT=y
CONFIG_ATH11K_NSS_MESH_SUPPORT=y
CONFIG_PACKAGE_MAC80211_NSS_SUPPORT=y
CONFIG_PACKAGE_kmod-qca-nss-drv=y
CONFIG_PACKAGE_kmod-qca-nss-drv-bridge-mgr=y
CONFIG_PACKAGE_kmod-qca-nss-ecm=y
CONFIG_PACKAGE_kmod-qca-nss-drv-pppoe=y
CONFIG_PACKAGE_kmod-qca-nss-drv-vlan-mgr=y
CONFIG_PACKAGE_kmod-qca-mcs=y
CONFIG_NSS_FIRMWARE_VERSION_12_5=y

## NSS-optimised SQM (from the sqm-scripts-nss feed)
CONFIG_PACKAGE_sqm-scripts-nss=y
