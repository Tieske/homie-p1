#!/usr/bin/env lua

package.path = "./?/init.lua;"..package.path

local copas = require("copas")
local P1 = require("homie-p1.copas")
local log = require("homie-p1.log")
-- Endless loop restarting socat. Any error to be dismissed.
local stream_open_command = "while : ; do socat $s stdout 2>/dev/null; done"
local socat_input_stream = "/dev/ttyUSB0,b115200"

local device_list = {} -- Homie devices indexed by the smartmeter ID

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
    if fields_to_include[fieldname] ~= nil then
      log:warn("received unknown field '%s' in the data, neither in- nor excluded on the device")
      data[fieldname] = nil
    end
  end
end


-- First datagram for a device, create a new device for it
local function create_device(data)
  check_received_fields(data)
  error("not implemented")
end


-- update an existing device with newly received data from the meter
local function update_device_data(device, data)
  check_received_fields(data)
  error("not implemented")
end


-- Handle a single device upate listed in a datagram
local function update_device(id, data)
  local device = device_list[id]
  if device then
    update_device_data(device, data)
  else
    create_device(data)
  end
end


-- Handle a single incoming datagram
local function datagram_handler(datagram)
  for device_id, device_data in pairs(datagram) do
    update_device(device_id, device_data)
  end
end


copas(function()
  P1.new {
    stream_open_command = stream_open_command:format(socat_input_stream),
    handler = datagram_handler,
  }
end)
