#!/usr/bin/env lua

package.path = "./?/init.lua;"..package.path

local Parser = require("homie-p1.parser")
local parser = Parser.new()


for line in io.lines() do
  local res, err = parser:push_line(line)
  if res then
    print("Datagram: ", require("pl.pretty").write(res))
  else
    if err ~= "incomplete" then
      print("an error:",err)
    end
  end
end
