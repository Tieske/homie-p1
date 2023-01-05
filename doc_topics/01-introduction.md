# 1. Introduction

This module was originally written to be executed on a Raspberry Pi, attached to
the P1 port of a smartmeter.

Note that the parser module has no external dependencies, it could be reused
elsewhere with little effort.

## 1.1 Installation

Assuming a Raspberry Pi;

```shell
sudo apt update
sudo apt install -y socat git liblua5.1-0-dev
wget https://luarocks.org/releases/luarocks-3.9.1.tar.gz
tar zxpf luarocks-3.9.1.tar.gz
cd luarocks-3.9.1
./configure && make && sudo make install
cd ..
rm -rf luarocks-3.9.1
rm luarocks-3.9.1.tar.gz

sudo luarocks install copas
sudo luarocks install penlight
# luamqtt fork to be used for now
sudo luarocks install Tieske/luamqtt --dev
# homie development branch for now
sudo luarocks install homie --dev
sudo luarocks install luabitop

git clone https://github.com/Tieske/homie-p1
cd homie-p1
sudo luarocks make
cd ..
rm -rf homie-p1

# while waiting for PR https://github.com/hishamhm/copas-async/pull/1
git clone https://github.com/Tieske/copas-async
cd homie-p1
git checkout updates
sudo luarocks make
cd ..
rm -rf copas-async
```

## 1.2 Daemonizing

Create the following systemd config file; `homiep1.service`:
```
[Unit]
Description=P1-Smartmeter to Homie bridge
After=network-online.target

[Service]
Environment="P1_SOCAT_INPUT=/dev/ttyUSB0,b115200"
Environment="HOMIE_MQTT_URI=mqtt://synology"
Environment="HOMIE_LOG_LOGLEVEL=debug"
ExecStart=/bin/bash /usr/local/bin/homiep1
StandardOutput=inherit
StandardError=inherit
Restart=always
User=pi

[Install]
WantedBy=multi-user.target
```

Then do:

- `cp homiep1.service /lib/systemd/system/` to copy it in place
- `sudo systemctl start homiep1.service` to start it
- `sudo systemctl status homiep1.service` to check status
- `sudo systemctl enable homiep1.service` to enable it on system start
