#!/usr/bin/env lua

package.path = "./?/init.lua;"..package.path

local copas = require("copas")
local P1 = require("homie-p1.copas")

-- Endless loop restarting socat. Any error to be dismissed.
local stream_open_command = "while : ; do socat /dev/ttyUSB0,b115200 stdout 2>/dev/null; done"


copas(function()
  local reader = P1.new {
    stream_open_command = stream_open_command,
    handler = function(datagram)
      print("P1 datagram: ", require("pl.pretty").write(datagram))
    end
  }
end)
