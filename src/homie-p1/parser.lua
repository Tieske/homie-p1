--- This module does something.
--
-- Explain some basics, or the design.
--
-- @copyright Copyright (c) 2022-2022 Thijs Schreijer
-- @author Thijs Schreijer
-- @license MIT, see `LICENSE.md`.

local M = {}
local LF = string.char(tonumber("0A",16))
local CR = string.char(tonumber("0D",16))
local CRLF = CR..LF

local stringx = require "pl.stringx"
local log = require("logging").defaultLogger()



-- Parses a string with numeric value and optional unit separated by '*'
-- @param str the string to parse
-- @return value (number), unit (string), not that unit can be nil if
-- it wasn't in the input
local function parse_number_unit(str)
  local value, _, unit = stringx.partition(str, "*")
  if unit == "" then unit = nil end
  return tonumber(value), unit
end


-- Parses a number metric into the data table
-- @param self the definition from the metrics table below
-- @param data the 'data' table as exported
local function parse_number(self, data, elements)
  local v = {
    description = self.description,
    -- name = self.name,
  }
  local val, unit = parse_number_unit(elements[1])
  v.value = val
  v.unit = unit or self.unit
  data[self.name or self.description] = v
end


-- Parses an octet string value into a normal string.
-- @param str the octet string to parse
-- @return string value
local function convert_octet_string(str)
  local val = ""
  for i = 1, #str, 2 do
    val = val .. string.char(tonumber(str:sub(i, i+1),16))
  end
  return val
end


-- Parses a octet string metric into the data table
-- @param self the definition from the metrics table below
-- @param data the 'data' table as exported
local function parse_octet_string(self, data, elements)
  local v = {
    description = self.description,
    -- name = self.name,
    value = convert_octet_string(elements[1])
  }
  data[self.name or self.description] = v
end


-- Parses a timestamp string into a UTC based epoch timestamp.
-- @param str the timestamp value to parse
-- @return number, timestamp in seconds since epoch
local function parse_timestamp(str) -- TODO: check time conversions to UTC
  return os.time({
    year = tonumber(str:sub(1,2)) + 2000,
    month = tonumber(str:sub(3,4)),
    day = tonumber(str:sub(5,6)),
    hour = tonumber(str:sub(7,8)),
    min = tonumber(str:sub(9,10)),
    sec = tonumber(str:sub(11,12)),
    isdst = (str:sub(13,13) == "S")
  })
end


-- Parses a failure log metric into the data table
-- @param self the definition from the metrics table below
-- @param data the 'data' table as exported
local function parse_failure_log(self, data, elements)
  local v = {
    description = self.description,
    -- name = self.name,
  }
  local count = tonumber(elements[1])
  for i = 1, count do
    local timestamp = parse_timestamp(elements[1 + i*2])
    local value, unit = parse_number_unit(elements[1 + i*2 + 1])
    v[#v+1] = {
      timestamp = timestamp,
      value = value,
      unit = unit,
    }
  end
  data[self.name or self.description] = v
end


-- Gets the subdevice table based on the mbus id.
-- @param self the definition from the metrics table below
-- @param data the 'data' table as exported
local function get_subdevice(self, data, values)
  local n = tonumber(values[1])
  local subdevice = data[n]
  if not subdevice then
    subdevice = { mbus = n }
    data[n] = subdevice
  end
  return subdevice
end

local metrics do
  metrics = {
    {
      description = "Version information for P1 output",
      id = "1-3:0.2.8.255",
    }, {
      name = "timestamp",
      description = "Date-time stamp of the P1 message",
      id = "0-0:1.0.0.255",
      parse = function(self, data, elements)
        data[self.name] = parse_timestamp(elements[1])
      end,
    }, {
      name = "equipment-identifier",
      description = "Equipment identifier",
      id = "0-0:96.1.1.255",
      parse = function(self, data, elements)
        data[self.name] = convert_octet_string(elements[1])
      end,
    }, {
      name = "delivered-t1",
      -- description = "Meter Reading electricity received (Tariff 1) in 0,001 kWh",
      description = "Meter reading electricity received (Tariff 1)",
      id = "1-0:1.8.1.255",
      parse = parse_number,
    }, {
      name = "delivered-t2",
      -- description = "Meter Reading electricity received (Tariff 2) in 0,001 kWh",
      description = "Meter reading electricity received (Tariff 2)",
      id = "1-0:1.8.2.255",
      parse = parse_number,
    }, {
      name = "delivered",
      -- description = "Meter Reading electricity received (T1+T2) in 0,001 kWh",
      description = "Meter reading electricity received (T1+T2)",
      id = "ignore",
      calc = function(self, data)
        local t1 = data["delivered-t1"]
        local t2 = data["delivered-t2"]
        data[self.name] = {
          description = self.description,
          unit = t1.unit,
          value = t1.value + t2.value
        }
      end,
    }, {
      name = "returned-t1",
      -- description = "Meter Reading electricity returned (Tariff 1) in 0,001 kWh",
      description = "Meter reading electricity returned (Tariff 1)",
      id = "1-0:2.8.1.255",
      parse = parse_number,
    }, {
      name = "returned-t2",
      -- description = "Meter Reading electricity returned (Tariff 2) in 0,001 kWh",
      description = "Meter reading electricity returned (Tariff 2)",
      id = "1-0:2.8.2.255",
      parse = parse_number,
    }, {
      name = "returned",
      -- description = "Meter Reading electricity returned (T1+T2) in 0,001 kWh",
      description = "Meter reading electricity returned (T1+T2)",
      id = "ignore",
      calc = function(self, data)
        local t1 = data["returned-t1"]
        local t2 = data["returned-t2"]
        data[self.name] = {
          description = self.description,
          unit = t1.unit,
          value = t1.value + t2.value
        }
      end,
    }, {
      description = "Tariff indicator electricity",
      id = "0-0:96.14.0.255",
    }, {
      name = "power-in",
      -- description = "Actual electricity power received (+P) in 1 Watt resolution",
      description = "Instantaneous electricity power received",
      id = "1-0:1.7.0.255",
      parse = parse_number,
    }, {
      name = "power-out",
      -- description = "Actual electricity power returned (-P) in 1 Watt resolution",
      description = "Instantaneous electricity power returned",
      id = "1-0:2.7.0.255",
      parse = parse_number,
    }, {
      name = "failures-total",
      -- description = "Number of power failures in any phase",
      description = "Power failures in any phase",
      id = "0-0:96.7.21.255",
      unit = "#",
      parse = parse_number,
    }, {
      name = "failures-long-total",
      -- description = "Number of long power failures in any phase",
      description = "Long power failures in any phase",
      id = "0-0:96.7.9.255",
      unit = "#",
      parse = parse_number,
    }, {
      name = "failure-log",
      description = "Power Failure Event Log (long power failures)",
      id = "1-0:99.97.0.255",
      parse = parse_failure_log
    }, {
      name = "voltage-sags-l1",
      -- description = "Number of voltage sags in phase L1",
      description = "Voltage sags in L1",
      id = "1-0:32.32.0.255",
      unit = "#",
      parse = parse_number,
    }, {
      name = "voltage-sags-l2",
      -- description = "Number of voltage sags in phase L2",
      description = "Voltage sags in L2",
      id = "1-0:52.32.0.255",
      unit = "#",
      parse = parse_number,
    }, {
      name = "voltage-sags-l3",
      -- description = "Number of voltage sags in phase L3",
      description = "Voltage sags in L3",
      id = "1-0:72.32.0.255",
      unit = "#",
      parse = parse_number,
    }, {
      name = "voltage-swells-l1",
      -- description = "Number of voltage swells in phase L1",
      description = "Voltage swells in L1",
      id = "1-0:32.36.0.255",
      unit = "#",
      parse = parse_number,
    }, {
      name = "voltage-swells-l2",
      -- description = "Number of voltage swells in phase L2",
      description = "Voltage swells in L2",
      id = "1-0:52.36.0.255",
      unit = "#",
      parse = parse_number,
    }, {
      name = "voltage-swells-l3",
      -- description = "Number of voltage swells in phase L3",
      description = "Voltage swells in L3",
      id = "1-0:72.36.0.255",
      unit = "#",
      parse = parse_number,
    }, {
      name = "text-message",
      description = "Text message",
      id = "0-0:96.13.0.255",
      parse = parse_octet_string,
    }, {
      name = "voltage-l1",
      -- description = "Instantaneous voltage L1 in V resolution",
      description = "Instantaneous voltage L1",
      id = "1-0:32.7.0.255",
      parse = parse_number,
    }, {
      name = "voltage-l2",
      -- description = "Instantaneous voltage L2 in V resolution",
      description = "Instantaneous voltage L2",
      id = "1-0:52.7.0.255",
      parse = parse_number,
    }, {
      name = "voltage-l3",
      -- description = "Instantaneous voltage L3 in V resolution",
      description = "Instantaneous voltage L3",
      id = "1-0:72.7.0.255",
      parse = parse_number,
    }, {
      name = "current-l1",
      -- description = "Instantaneous current L1 in A resolution.",
      description = "Instantaneous current L1",
      id = "1-0:31.7.0.255",
      parse = parse_number,
    }, {
      name = "current-l2",
      -- description = "Instantaneous current L2 in A resolution.",
      description = "Instantaneous current L2",
      id = "1-0:51.7.0.255",
      parse = parse_number,
    }, {
      name = "current-l3",
      -- description = "Instantaneous current L3 in A resolution.",
      description = "Instantaneous current L3",
      id = "1-0:71.7.0.255",
      parse = parse_number,
    }, {
      name = "power-in-l1",
      -- description = "Instantaneous power received L1 (+P) in W resolution",
      description = "Instantaneous power received L1",
      id = "1-0:21.7.0.255",
      parse = parse_number,
    }, {
      name = "power-in-l2",
      -- description = "Instantaneous power received L2 (+P) in W resolution",
      description = "Instantaneous power received L2",
      id = "1-0:41.7.0.255",
      parse = parse_number,
    }, {
      name = "power-in-l3",
      -- description = "Instantaneous power received L3 (+P) in W resolution",
      description = "Instantaneous power received L3",
      id = "1-0:61.7.0.255",
      parse = parse_number,
    }, {
      name = "power-out-l1",
      -- description = "Instantaneous power returned L1 (-P) in W resolution",
      description = "Instantaneous power returned L1",
      id = "1-0:22.7.0.255",
      parse = parse_number,
    }, {
      name = "power-out-l2",
      -- description = "Instantaneous power returned L2 (-P) in W resolution",
      description = "Instantaneous power returned L2",
      id = "1-0:42.7.0.255",
      parse = parse_number,
    }, {
      name = "power-out-l3",
      -- description = "Instantaneous power returned L3 (-P) in W resolution",
      description = "Instantaneous power returned L3",
      id = "1-0:62.7.0.255",
      parse = parse_number,
    }, {
      name = "power",
      -- description = "Instantaneous power (received - returned) in W resolution",
      description = "Instantaneous power (Pin - Pout)",
      id = "ignore",
      calc = function(self, data)
        local p1 = data["power-in"]
        local p2 = data["power-out"]
        data[self.name] = {
          description = self.description,
          unit = p1.unit,
          value = p1.value - p2.value
        }
      end,
    },
    -- Slave device identified by "channel" number 1-4
    {
      name = "device-type",
      description = "Device-Type",
      id = "0-n:24.1.0.255",
      parse = function(self, data, elements)
        local subdevice = get_subdevice(self, data, elements)
        subdevice[self.name] = tonumber(elements[2])
        subdevice.type = ({
          [3] = "gas",
          [997] = "electricity", -- TODO: fix this ID to the proper one
          [998] = "water",       -- TODO: fix this ID to the proper one
          [999] = "thermal",     -- TODO: fix this ID to the proper one
        })[tonumber(elements[2])]
        subdevice.description = subdevice.type .. " delivered to client"
      end,
    }, {
      name = "equipment-identifier",
      description = "Equipment identifier",
      id = "0-n:96.1.0.255",
      parse = function(self, data, elements)
        local subdevice = get_subdevice(self, data, elements)
        subdevice[self.name] = convert_octet_string(elements[2])
      end,
    }, {
      name = "delivered-total",
      -- description = "Last 5-minute value (temperature converted), gas delivered to client in m3, including decimal values and capture time",
      description = "Gas delivered to client in m3",
      id = "0-n:24.2.1.255",
      parse = function(self, data, elements)
        local subdevice = get_subdevice(self, data, elements)
        subdevice.timestamp = parse_timestamp(elements[2])
        local value, unit = parse_number_unit(elements[3])
        subdevice[self.name] = {
          description = self.description,
          value = value,
          unit = unit,
        }
      end,
    }
  }

  -- Generate patterns to match the ID's
  for _, entry in ipairs(metrics) do
    local pattern = entry.id:gsub("%.255$", ""):gsub("%-n:", "-([1234]):")
    pattern = pattern:gsub("%.", "%%."):gsub("%-", "%%-")
    pattern = "^" .. pattern .. "(%(.*%))$"

    entry.pattern = pattern
  end
end


local function crc_check(str, crc)
  -- TODO: implement
  return true
end

local function parse_datagram(str, crc)
  local ok, err = crc_check(str, crc)
  if not ok then
    return nil, err
  end

  local data = {
    type = "electricity"
  }
  for line in stringx.lines(str) do
    line = line:gsub(CR, "") -- drop any CR characters

    -- skips header, trailer and empty lines
    if line ~= "" and line:sub(1,1) ~= "/" and line:sub(1,1) ~= "!" then
      local success = false
      for _, metric in ipairs(metrics) do
        local matches = { line:match(metric.pattern) } -- returns 1 or 2 matches
        if matches[1] then -- found a match
          -- Parse sub-data elements (from the last match)
          local elements = matches[#matches]
          matches[#matches] = nil
          for sub in elements:gmatch("%((.-)%)") do
            matches[#matches+1] = sub
          end
          if metric.parse then
            metric:parse(data, matches)
          else
            log:debug("no parser for '%s'", line)
          end
          success = true
          break
        end
      end
      if not success then
        log:debug("failed to match line: '%s'", line)
      end
    end
  end

  -- calculated fields
  for _, metric in ipairs(metrics) do
    if metric.calc then
      metric:calc(data)
    end
  end

  -- convert to hash-table indexed by device identifier/serial number
  local datagram = {}
  for i = 1,4 do
    local subdevice = data[i]
    if subdevice then
      data[i] = nil
      datagram[subdevice["equipment-identifier"]] = subdevice
    end
  end
  datagram[data["equipment-identifier"]] = data
  return datagram
end


function M.new(opts)
  local self = opts or {}

  function self:push_line(str)
    assert(type(str) == "string", "expected a string")
    if not self.buffer then
      if str:sub(1,1) == "/" then
        self.buffer = str
      end
      return nil, "incomplete"
    end

    -- check for CRC and extract it
    local crc
    if str:sub(1,1) == "!" then
      crc = str:sub(2, -1)
      str = "!"
    end
    self.buffer = self.buffer .. CRLF .. str

    if not crc then
      return nil, "incomplete"
    end

    str = self.buffer
    self.buffer = nil

    return parse_datagram(str, crc)
  end
  return self
end

return M
