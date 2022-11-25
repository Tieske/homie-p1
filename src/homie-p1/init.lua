--- Hue-to-Homie bridge.
--
-- This module instantiates a homie device acting as a bridge between the Philips
-- Hue API and Homie.
--
-- The module returns a single function that takes an options table. When called
-- it will construct a Homie device and add it to the Copas scheduler (without
-- running the scheduler).
-- @copyright Copyright (c) 2022-2022 Thijs Schreijer
-- @author Thijs Schreijer
-- @license MIT, see `LICENSE`.
-- @usage
-- local copas = require "copas"
-- local hmh = require "homie-hue"
--
-- hmh {
--   millheat_access_key = "xxxxxxxx",
--   millheat_secret_token = "xxxxxxxx",
--   millheat_username = "xxxxxxxx",
--   millheat_password = "xxxxxxxx",
--   millheat_poll_interval = 15,            -- default: 15 seconds
--   homie_mqtt_uri = "http://mqtthost:123", -- format: "mqtt(s)://user:pass@hostname:port"
--   homie_domain = "homie",                 -- default: "homie"
--   homie_device_id = "millheat",           -- default: "millheat"
--   homie_device_name = "M2H bridge",       -- default: "Millheat-to-Homie bridge"
-- }
--
-- copas.loop()

local copas = require "copas"
local copas_timer = require "copas.timer"
local Device = require "homie.device"
local slugify = require("homie.utils").slugify
local log = require("logging").defaultLogger()
local json = require "cjson.safe"
local now = require("socket").gettime


local Homie_P1 = {}
Homie_P1.__index = Homie_P1



-- Endless loop restarting socat. Any error to be dismissed.
local stream_open_command = "while : ; do socat %s stdout 2>/dev/null; done"
local socat_input_stream_default = "/dev/ttyUSB0,b115200"

local homie_device -- the Homie device, once created

-- explicitly list fields to in/exclude
local fields_to_exclude = {
  "mbus",
  "failure-log",
}
local fields_to_include = {

}

-- remove non-used fields from the data (in place).
-- will log a warning for unknown fields
local function check_received_fields(data)
  -- remove all fields that have been excluded
  for _, name in ipairs(fields_to_exclude) do
    data[name] = nil
  end

  -- remove the not-included fields from the list
  for fieldname in pairs(data) do
    if fields_to_include[fieldname] == nil then
print("field un known: ", fieldname)
      log:warn("received unknown field '%s' in the data, neither in- nor excluded on the device")
      data[fieldname] = nil
    end
  end
end


-- First datagram for the device, create a new device for it
local function create_device(datagram)

  homie_device = {
    uri = self.homie_mqtt_uri,
    domain = self.homie_domain,
    broker_state = nil, -- do not recover state from broker
    id = self.homie_device_id,
    homie = "4.0.0",
    extensions = "",
    name = self.homie_device_name,
    nodes = {}
  }

  for

  check_received_fields(data)
  error("not implemented")
end


-- update the data for a single meter within a device
local function update_single_meter(meter_data)
  check_received_fields(data)
  error("not implemented")
end


-- Handle a single device upate listed in a datagram
local function update_device(self, datagram)
  if not self.homie_device then
    create_device(meter_data)
  else
    -- handle meters individually
    for meter_id, meter_data in pairs(datagram) do
      update_single_meter(self, meter_id, meter_data)
    end
  end
end



return function(opts)
  local self = setmetatable(opts, Homie_P1)

  assert(type(opts.socat_input_stream) == "string", "Expected 'socat_input_stream' to be a string value")
  assert(os.execute("socat -h > /dev/null"), "failed to detect 'socat'")

  self.parser = require("homie-p1.copas").new {
    stream_open_command = stream_open_command:format(socat_input_stream),
    handler = function(datagram)
      return update_device(self, datagram)
    end,
  }
end
