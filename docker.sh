#!/usr/bin/env bash

export P1_SOCAT_INPUT="/dev/ttyUSB0,b115200"
export HOMIE_MQTT_URI="mqtt://synology"
export HOMIE_DOMAIN="homie"
export HOMIE_DEVICE_ID="smartmeter"
export HOMIE_DEVICE_NAME="P1-smartmeter reader (DSMR)"
export HOMIE_LOG_LOGLEVEL="debug"


docker build --no-cache --progress plain --tag tieske/homiep1:dev .
docker image push tieske/homiep1:dev

# docker run -it --rm --privileged \
#     --device=/dev/ttyUSB0 \
#     -e P1_SOCAT_INPUT \
#     -e HOMIE_MQTT_URI \
#     -e HOMIE_MQTT_ID \
#     -e HOMIE_DOMAIN \
#     -e HOMIE_DEVICE_ID \
#     -e HOMIE_DEVICE_NAME \
#     -e HOMIE_LOG_LOGLEVEL \
#     tieske/homiep1:dev
