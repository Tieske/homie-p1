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


-- properties in the datagram dataset to skip
local skip_props = {
  description = true,
  ["device-type"] = true,
  ["equipment-identifier"] = true,
  mbus = true,
  timestamp = true,
  type = true,
  ["failure-log"] = true,
  ["text-message"] = true,
}


-- First datagram for the device, create a new device for it, and start.
function Homie_P1:create_device(datagram)

  local dev = {
    uri = self.homie_mqtt_uri,
    domain = self.homie_domain,
    broker_state = nil, -- do not recover state from broker
    id = self.homie_device_id,
    homie = "4.0.0",
    extensions = "",
    name = self.homie_device_name,
    nodes = {}
  }

  -- handle meters individually
  for meter_id, meter_data in pairs(datagram) do

    -- create and add the node
    local node = {}
    dev.nodes[meter_data.type] = node

    -- populate the node
    node.name = meter_data.type
    node.type = ("%s smartmeter (%s), serial %s"):format(
      meter_data.type,
      (meter_data.mbus and ("slave, mbus: "..meter_data.mbus) or "master"),
      meter_id
    )
    local props = {}
    node.properties = props

    -- populate node properties
    for name, data in pairs(meter_data) do
      if not skip_props[name] then
        local prop = {}
        props[name] = prop

        prop.name = data.description
        prop.settable = false
        prop.retained = true
        prop.datatype = "float"
        prop.unit = data.unit
        prop.format = nil
        prop.default = data.value
      end
    end -- properties

  end -- nodes

  self.homie_device = Device.new(dev)
  self.homie_device:start()
end


-- update the data for a single meter within a device
function Homie_P1:update_single_meter(meter_data)

  local node = self.homie_device.nodes[meter_data.type]

  for name, data in pairs(meter_data) do
    if not skip_props[name] then
      local prop = node.properties[name]
      prop:set(data.value)
    end
  end
end


-- Handle a single device upate listed in a datagram
function Homie_P1:update_device(datagram)
  if not self.homie_device then
    self:create_device(datagram)
  else
    -- update in a new thread, so any failures will be logged, but won't
    -- stop future updates
    copas.addthread(function()
      -- handle meters individually
      for meter_id, meter_data in pairs(datagram) do
        self:update_single_meter(meter_id, meter_data)
      end
    end)
  end
end



return function(opts)
  local self = setmetatable(opts, Homie_P1)

  assert(type(opts.socat_input_stream) == "string", "Expected 'socat_input_stream' to be a string value")
  assert(os.execute("socat -h > /dev/null"), "failed to detect 'socat'")

  self.parser = require("homie-p1.copas").new {
    stream_open_command = stream_open_command:format(opts.socat_input_stream),
    handler = function(datagram)
      return self:update_device(datagram)
    end,
  }
end
