creating arm bundle:
- run the script build_z2m_bundle_d.sh as follow:
    ./build_z2m_bundle.sh   -z ~/workplace/projects/tools/z2m_release   -b ~/workplace/projects/embedded-linux-with-buildroot/buildroot   -v 1.42.0   -n 18.20.1

- make zigbee2mqtt-bin-dirclean
- make

This mode will:
Pull ghcr.io/koenkk/zigbee2mqtt:
Create a temporary container
docker cp the precompiled Zigbee2MQTT folder /app to a temp directory
Remove node_modules (because Alpine/musl)
Continue with ARM build steps.

This method relies on Docker’s official release structure, where:

The final release image contains the prebuilt backend (dist/)
It copies dist/, index.js, package.json, and configuration files into /app in the final stage of the Dockerfile. 
The documentation also states that you can pull a “specific release version” tag on Zigbee2MQTT images, like 1.42.0.

Because of these guarantees, Docker extraction is the cleanest and most correct way to get a ready‑to‑bundle Zigbee2MQTT release, without TypeScript builds.