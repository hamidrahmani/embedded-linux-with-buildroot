# zigbee
- architecture: Zegbee nodes -> Zigbee Dongle → Zigbee2MQTT → MQTT Broker → REST API
## build your own precompiled Zigbee2MQTT bundle
- setup
    step1: on host create a folder and Clone Zigbee2MQTT
        mkdir   ~/workplace/projects/tools
        cd ~/workplace/projects/tools
        git clone https://github.com/Koenkk/zigbee2mqtt.git
        cd zigbee2mqtt
        git checkout 1.41.0
    step2: install Node.js on host
        sudo apt install nodejs npm
    step3: install all dependencies
        npm ci --production
    step4: create a portable runtime bundle
        - create a folder (to host bundle) and copy nodejs and dependencies into it
            mkdir zigbee2mqtt-armv7
            cp -r * zigbee2mqtt-armv7/ 
        - add ARM Node.js binary to the bundle (Download ARMv7 Node.js) 
            wget https://nodejs.org/dist/v18.17.1/node-v18.17.1-linux-armv7l.tar.xz
            tar xf node-v18.17.1-linux-armv7l.tar.xz
        - move Arm Node binary into the bundle folder
            mv node-v18.17.1-linux-armv7l zigbee2mqtt-armv7/node
    step5: create a tarball that Buildroot will download
        tar czf zigbee2mqtt-1.41.0-armv7.tar.gz zigbee2mqtt-armv7
    step6: host the tarball for Buildroot
        copy the tarball into buildroot/dl/  // or pthon3 -m http.server 8080
    step7: add MQTT Broker (Mosquitto) to Buildroot. Mosquitto is a broker, which allows zigbee to publish the sensor events.
        - configmenu --> Target Packages  --->   Networking Applications  --->      mosquitto  [*]  and   mosquitto clients  [*]
        - rebuilt
            make mosquitto-rebuild
            make
    step8: Add pre-compiled zigbee2mqtt binary Buildroot: zigbee2mqtt is a protocoll gateway to convert messages between zigbee and mqtt
        - create package: package/userdefinedapps/zigbee2mqtt-bin/
        - add Config.in
            config BR2_PACKAGE_ZIGBEE2MQTT_BIN
                bool "zigbee2mqtt (precompiled)"
        - add zigbee2mqtt-bin.mk
            ZIGBEE2MQTT_BIN_VERSION = 1.41.0
            ZIGBEE2MQTT_BIN_SOURCE = zigbee2mqtt-$(ZIGBEE2MQTT_BIN_VERSION)-armv7.tar.gz
            ZIGBEE2MQTT_BIN_SITE = file://$(DL_DIR) 
            // if in step 6 was hostet on http.server -->  ZIGBEE2MQTT_BIN_SITE = http://<vm-ip>:8080

            define ZIGBEE2MQTT_BIN_INSTALL_TARGET_CMDS
                mkdir -p $(TARGET_DIR)/opt/
                tar xf $(DL_DIR)/$(ZIGBEE2MQTT_BIN_SOURCE) -C $(TARGET_DIR)/opt/ --strip-components=1
            endef
            $(eval $(generic-package))       

        - register package in buildroot --> source "package/userdefinedapps/zigbee2mqtt-bin/Config.in"
        - add init script --> /etc/init.d/S70zigbee2mqtt
            #!/bin/sh
            /opt/zigbee2mqtt/zigbee2mqtt &
        - enable in buildroot --> make menuconfig --> Target packages --> zigbee2mqtt (precompiled) [*]
    step9: make
## build your own ARM precompiled Zigbee2MQTT bundle
- setup:
    step1: see above
    step2: see above
    step3: see above
    step4: create a portable runtime bundle zigbee2mqtt binary for arm
        - cd ~/workplace/projects/tools/zigbee2mqtt
        - start ARMv7 Docker container
            docker run --rm -it --platform=linux/arm/v7 \
                -v "$PWD":/work -w /work \
                node:18-bullseye bash 
        - run arm build commands
            rm -rf node_modules package-lock.json
            npm install --production
            node -p 'process.arch + " / " + process.platform' --> important is that "arm / linux" get shown
        - exit --> back to host from docker 
        - rebuild portable folder
            cd ~/workplace/projects/tools
            rm -rf zigbee2mqtt-armv7
            cp -r zigbee2mqtt zigbee2mqtt-armv7
        - add ARM Node.js runtime
            wget https://nodejs.org/dist/v18.17.1/node-v18.17.1-linux-armv7l.tar.xz
            tar xf node-v18.17.1-linux-armv7l.tar.xz
            mv node-v18.17.1-linux-armv7l zigbee2mqtt-armv7/node
        -build the Zigbee2MQTT frontend

    step5: see above
    step6: see above
    step7: see above
    step8: see above

## integrate pre-compiled Zigbee2MQTT bundle
- setup
    step1: Add MQTT Broker (Mosquitto) to Buildroot. Mosquitto is a broker, which allows zigbee to publish the sensor events.
        - configmenu --> Target Packages  --->   Networking Applications  --->      mosquitto  [*]  and   mosquitto clients  [*]
        - rebuilt
            make mosquitto-rebuild
            make
    step2: Add pre-compiled zigbee2mqtt binary Buildroot: zigbee2mqtt is a protocoll gateway to convert messages between zigbee and mqtt
        - create package: package/userdefinedapps/zigbee2mqtt-bin/
        - add Config.in
            config BR2_PACKAGE_ZIGBEE2MQTT_BIN
                bool "zigbee2mqtt (precompiled)"
        - add zigbee2mqtt-bin.mk
            ZIGBEE2MQTT_BIN_VERSION = 1.41.0
            ZIGBEE2MQTT_BIN_ARCH = armv7
            ZIGBEE2MQTT_BIN_SOURCE = zigbee2mqtt-$(ZIGBEE2MQTT_BIN_VERSION)-$(ZIGBEE2MQTT_BIN_ARCH).tar.gz
            ZIGBEE2MQTT_BIN_SITE = https://github.com/Koenkk/zigbee2mqtt/releases/download/$(ZIGBEE2MQTT_BIN_VERSION)

            define ZIGBEE2MQTT_BIN_INSTALL_TARGET_CMDS
                mkdir -p $(TARGET_DIR)/opt/zigbee2mqtt
                tar xf $(DL_DIR)/$(ZIGBEE2MQTT_BIN_SOURCE) -C $(TARGET_DIR)/opt/zigbee2mqtt --strip-components=1
            endef

            $(eval $(generic-package))       
        - register package in buildroot --> source "package/userdefinedapps/zigbee2mqtt-bin/Config.in"
        - add init script --> /etc/init.d/S50zigbee2mqtt
            #!/bin/sh
            /opt/zigbee2mqtt/zigbee2mqtt &
        - enable in buildroot --> make menuconfig --> Target packages --> zigbee2mqtt (precompiled) [*]

## compiling Zigbee2MQTT from code
- setup:
    step1: Add MQTT Broker (Mosquitto) to Buildroot. Mosquitto is a broker, which allows zigbee to publish the sensor events.
        - configmenu --> Target Packages  --->   Networking Applications  --->      mosquitto  [*]  and   mosquitto clients  [*]
        - rebuilt
            make mosquitto-rebuild
            make
    step2: Add Zigbee2MQTT (user package)to Buildroot: zigbee2mqtt is a protocoll gateway to convert messages between zigbee and mqtt
        - create package: package/zigbee2mqtt/
        - add Config.in
        - add zigbee2mqtt.mk
        - register package in buildroot --> source "package/userdefinedapps/zigbee2mqtt/Config.in"
        - reconfigure buildroot --> make menuconfig --> Target packages --> Zigbee2MQTT [*]
        - add startup script --> /etc/init.d/Szigbee2mqtt
    step3:
    - Configure Zigbee2MQTT --> Create /opt/zigbee2mqtt/data/configuration.yaml


## usig script "build_z2m_bundle.sh"
this script does:
- Builds ARM‑native node_modules using Docker (--platform=linux/arm/v7)
- Embeds the ARM Node.js runtime into the bundle (node/bin/node)
- Prunes non‑ARM prebuilds (x64/arm64/android) so Buildroot’s arch checks pass
- Creates a tarball: zigbee2mqtt-<version>-armv7.tar.gz
- Copies it to your Buildroot dl/ (if you provide the path)
- Prints the SHA256 line you can paste into a Buildroot .hash file

how-to-use:
Run it from your VM, where your Zigbee2MQTT repo lives and Docker works:
./build_z2m_bundle.sh \
  -z ~/workplace/projects/tools/zigbee2mqtt \
  -b ~/workplace/projects/embedded-linux-with-buildroot/buildroot \
  -v 1.41.0 \
  -n 18.17.1


## build your own precompiled Zigbee2MQTT bundle from officail site
in /tools folder
- get the tarball:
    wget https://github.com/Koenkk/zigbee2mqtt/archive/refs/tags/1.41.0.tar.gz -O zigbee2mqtt-src-1.41.0.tar.gz
- extract 
    tar xf zigbee2mqtt-src-1.41.0.tar.gz
    mv zigbee2mqtt-1.41.0 zigbee2mqtt_release
- go to folder zigbee2mqtt_release
    - ensure ownership is correct
        sudo chown -R vboxuser:vboxuser .
    rm -rf node_modules package-lock.json
    npm install      --include=dev
    npm run build

## Use the Official NPM Package (Prebuilt Bundle)
go to folder:
    cd ~/workplace/projects/tools
run:
    npm view zigbee2mqtt versions --json 
chose latest version and run:
    npm pack zigbee2mqtt@1.40.2
    mkdir z2m_release
    tar xf zigbee2mqtt-1.40.2.tgz -C z2m_release --strip-components=1

## extract 
docker pull ghcr.io/koenkk/zigbee2mqtt:1.41.0
docker create --name z2m ghcr.io/koenkk/zigbee2mqtt:1.41.0
docker cp z2m:/app ./z2m_release
docker rm z2m
rm -rf ./z2m_release/node_modules