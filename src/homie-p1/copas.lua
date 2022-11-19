--- This module does something.
--
-- Explain some basics, or the design.
--
-- @copyright Copyright (c) 2022-2022 Thijs Schreijer
-- @author Thijs Schreijer
-- @license MIT, see `LICENSE.md`.

local M = {}
M._VERSION = "0.0.1"
M._COPYRIGHT = "Copyright (c) 2022-2022 Thijs Schreijer"
M._DESCRIPTION = "Homie device to read P1 smartmeter data (DSMR)"


local copas = require("copas")
local async = require("copas.async")
local Parser = require("homie-p1.parser")
local Queue = require("copas.queue")


--- Logger is set on the module table, to be able to override it.
-- Default is the LuaLogging default logger (if loaded), or a no-op function.
-- Per client overrides can be given in `P1.new`.
-- @field P1.log
M.log = require "homie-p1.log"


function M.new(opts)

  local self = {
    exiting = false,
    queue = Queue.new({ name = "P1 datagram queue"}),
    log = opts.log or M.log,
    stream_open_command = assert(opts.stream_open_command, "expected opts.stream_open_command to be a string")
  }
  self.queue:add_worker(assert(opts.handler, "expected opts.handler to be a function"))

  -- instructs reader to exit
  function self.stop()
    self.exiting = true
  end

  -- Stream reader and parser
  self.worker = copas.addnamedthread("P1-reader/parser", function()
    local log = self.log
    while not self.exiting do
      local parser = Parser.new()
      -- start an async OS thread to read the stream
      local stream, err = async.io_popen(self.stream_open_command, "r")
      if not stream then
        log:error("failed opening stream: %s", err)
        copas.sleep(2)
      else
        -- go in loop reading data
        while not self.exiting do
          local line, err = stream:read()
          if not line then
            log:error("failed reading from stream: %s", tostring(err))
            copas.sleep(2)
            break -- exit inner loop to recreate stream and parser

          else
            -- we have a line
            local datagram, err = parser:push_line(line)
            if datagram then -- datagram is complete, deliver it
              self.queue:push(datagram)

            else
              if err ~= "incomplete" then -- incomplete means datagram needs more lines
                log:error("failed parsing data: %s", tostring(err))
                break -- exit inner loop to recreate stream and parser
              end
            end
          end
        end
      end
      -- close stream
      local a,b,c = stream:close()
      if not self.exiting then
        log:error("read process exited: %s, %s, %s", tostring(a), tostring(b), tostring(c))
      end
    end
    self.worker = nil
  end)

end

return M
