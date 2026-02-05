ZIGBEE2MQTT_BIN_VERSION = 1.41.0
ZIGBEE2MQTT_BIN_SOURCE  = zigbee2mqtt-$(ZIGBEE2MQTT_BIN_VERSION)-armv7.tar.gz
ZIGBEE2MQTT_BIN_SITE    = file://$(DL_DIR)

define ZIGBEE2MQTT_BIN_INSTALL_TARGET_CMDS
    # Ensure /opt exists
    mkdir -p $(TARGET_DIR)/opt

    # Extract tarball
    tar xf $(DL_DIR)/$(ZIGBEE2MQTT_BIN_SOURCE) -C $(TARGET_DIR)/opt/

    # Remove old zigbee2mqtt dir if overlay provided it
    rm -rf $(TARGET_DIR)/opt/zigbee2mqtt

    # Rename extracted folder
    mv $(TARGET_DIR)/opt/zigbee2mqtt-armv7 $(TARGET_DIR)/opt/zigbee2mqtt

    # ---- PRUNE NON-ARM MODULES (critical!) ----
    rm -rf \
        $(TARGET_DIR)/opt/zigbee2mqtt/node_modules/**/prebuilds/*x64* \
        $(TARGET_DIR)/opt/zigbee2mqtt/node_modules/**/prebuilds/*arm64* \
        $(TARGET_DIR)/opt/zigbee2mqtt/node_modules/**/prebuilds/android-* \
        $(TARGET_DIR)/opt/zigbee2mqtt/node_modules/@serialport/bindings-cpp/prebuilds/linux-x64 \
        $(TARGET_DIR)/opt/zigbee2mqtt/node_modules/@serialport/bindings-cpp/prebuilds/linux-arm64 \
        $(TARGET_DIR)/opt/zigbee2mqtt/node_modules/@serialport/bindings-cpp/prebuilds/android-arm64 \
        $(TARGET_DIR)/opt/zigbee2mqtt/node_modules/unix-dgram || true

    # Permissions
    chmod -R a+rX $(TARGET_DIR)/opt/zigbee2mqtt
endef

$(eval $(generic-package))