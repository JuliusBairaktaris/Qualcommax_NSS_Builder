# Qualcommax_NSS_Builder

This project automates OpenWRT builds for the Xiaomi AX3600, focusing on full NSS support with minimal additional packages. It builds upon the `qualcommax-6.1-nss-wifi` branch from [qosmio/openwrt-ipq](https://github.com/qosmio/openwrt-ipq/tree/qualcommax-6.1-nss-wifi) and is inspired by [rodriguezst/ipq807x-openwrt-builder](https://github.com/rodriguezst/ipq807x-openwrt-builder).

## Features

The build includes:
- Full NSS support for enhanced networking.
- `luci` 
- Essential security and network management tools (`luci-app-banip`, `luci-app-sqm`, `sqm-scripts-nss`, `luci-ssl`).
- `wpad` (Full) for comprehensive wireless protocol support.

## Contributing

I welcome pull requests, especially for additional packages or essential features i missed. If you have improvements or suggestions, please feel free to contribute. 

