#!/usr/bin/env lua

--- Main CLI application.
-- Reads configuration from environment variables and starts the P1-to-Homie bridge.
-- Does not support any CLI parameters.
--
-- For configureing the log, use LuaLogging environment variable prefix `"HOMIE_LOG_"`, see
-- "logLevel" in the example below.
-- @module homiehue
-- @usage
-- # configure parameters as environment variables
-- export P1_SOCAT_INPUT="/dev/ttyUSB0,b115200"   # default: "/dev/ttyUSB0,b115200"
-- export HOMIE_MQTT_URI="mqtt://synology"        # format: "mqtt(s)://user:pass@hostname:port"
-- export HOMIE_DOMAIN="homie"                    # default: "homie"
-- export HOMIE_DEVICE_ID="smartmeter"            # default: "smartmeter"
-- export HOMIE_DEVICE_NAME="P1 bridge"           # default: "P1-smartmeter reader"
-- export HOMIE_LOG_LOGLEVEL="info"               # default: "INFO"
--
-- # start the application
-- homiep1

local ll = require "logging"
local copas = require "copas"
require("logging.rsyslog").copas() -- ensure copas, if rsyslog is used
local logger = assert(require("logging.envconfig").set_default_logger("HOMIE_LOG"))


do -- set Copas errorhandler
  local lines = require("pl.stringx").lines

  copas.setErrorHandler(function(msg, co, skt)
    msg = copas.gettraceback(msg, co, skt)
    for line in lines(msg) do
      ll.defaultLogger():error(line)
    end
  end, true)
end


print("starting P1-to-Homie bridge")
logger:info("starting P1-to-Homie bridge")


local opts = {
  socat_input_stream = os.getenv("P1_SOCAT_INPUT") or "/dev/ttyUSB0,b115200",
  homie_domain = os.getenv("HOMIE_DOMAIN") or "homie",
  homie_mqtt_uri = assert(os.getenv("HOMIE_MQTT_URI"), "environment variable HOMIE_MQTT_URI not set"),
  homie_device_id = os.getenv("HOMIE_DEVICE_ID") or "smartmeter",
  homie_device_name = os.getenv("HOMIE_DEVICE_NAME") or "P1-smartmeter reader (DSMR)",
}

logger:info("P1_SOCAT_INPUT: %s", opts.socat_input_stream)
logger:info("HOMIE_DOMAIN: %s", opts.homie_domain)
logger:info("HOMIE_MQTT_URI: %s", opts.homie_mqtt_uri)
logger:info("HOMIE_DEVICE_ID: %s", opts.homie_device_id)
logger:info("HOMIE_DEVICE_NAME: %s", opts.homie_device_name)


copas(function()
  require("homie-p1")(opts)
end)

ll.defaultLogger():info("P1-to-Homie bridge exited")
