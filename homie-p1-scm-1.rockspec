local package_name = "homie-p1"
local package_version = "scm"
local rockspec_revision = "1"
local github_account_name = "Tieske"
local github_repo_name = "homie-p1"


package = package_name
version = package_version.."-"..rockspec_revision

source = {
  url = "git+https://github.com/"..github_account_name.."/"..github_repo_name..".git",
  branch = (package_version == "scm") and "main" or nil,
  tag = (package_version ~= "scm") and package_version or nil,
}

description = {
  summary = "Homie device to read P1 smartmeter data (DSMR)",
  detailed = [[
    Homie device to read P1 smartmeter data (DSMR)
  ]],
  license = "MIT",
  homepage = "https://github.com/"..github_account_name.."/"..github_repo_name,
}

dependencies = {
  "lua >= 5.1, < 5.5",
}

build = {
  type = "builtin",

  modules = {
    ["homie-p1.init"] = "src/homie-p1/init.lua",
  },

  copy_directories = {
    -- can be accessed by `luarocks homie-p1 doc` from the commandline
    "docs",
  },
}
