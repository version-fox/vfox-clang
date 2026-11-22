-- Copyright 2026 vfox-clang contributors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-- Runs pixi.install through the real /bin/sh, in an install directory with a
-- space and an apostrophe in its name (issue #5), with a fake pixi that records
-- its arguments. vfox plugin test disables os.execute, so this runs under glua:
--   go run github.com/yuin/gopher-lua/cmd/glua@v1.1.1 tests/shell_quoting.lua
-- Run it from the repository root.
package.path = "lib/?.lua;" .. package.path
RUNTIME = { osType = "linux", archType = "amd64", pluginDirPath = "" }

local pixi = require("pixi")

local function check(condition, message)
    if not condition then
        error(message, 0)
    end
end

-- Quotes a path for the shell this test uses to set up and clean up.
local function shq(value)
    local escaped = value:gsub("'", "'\\''")
    return "'" .. escaped .. "'"
end

local function run(command)
    local status = os.execute(command)
    check(status == 0, "setup failed: " .. command)
end

local root = (os.getenv("TMPDIR") or "/tmp") .. "/vfox clang's test " .. tostring(os.time())
local install = root .. "/sdks/clang-22.1.3"
run("mkdir -p " .. shq(install))

-- A pixi that writes its arguments and PIXI_HOME next to the clang it installs,
-- then exits with FAKE_PIXI_EXIT (0 by default).
local function write_fake_pixi()
    local path = pixi.binary(install)
    local file = assert(io.open(path, "w"))
    file:write([[
#!/bin/sh
printf '%s\n' "$@" > "$PIXI_HOME/args.txt"
printf '%s\n' "$PIXI_HOME" > "$PIXI_HOME/home.txt"
exit "${FAKE_PIXI_EXIT:-0}"
]])
    file:close()
    run("chmod +x " .. shq(path))
end

-- A successful install: the arguments arrive intact, PIXI_HOME is the install
-- directory, and pixi is removed afterwards.
os.setenv("Conda_Forge", "https://example.invalid/conda-forge&mirror")
write_fake_pixi()
pixi.install(install, "22.1.3")

local args = {}
for line in io.lines(install .. "/args.txt") do
    table.insert(args, line)
end
check(#args == 5, "five arguments, got " .. #args)
check(args[1] == "global", "argument 1: " .. tostring(args[1]))
check(args[2] == "install", "argument 2: " .. tostring(args[2]))
check(args[3] == "-qc", "argument 3: " .. tostring(args[3]))
check(args[4] == "https://example.invalid/conda-forge&mirror", "channel stays one argument: " .. tostring(args[4]))
check(args[5] == "clang=22.1.3", "argument 5: " .. tostring(args[5]))

local home = io.lines(install .. "/home.txt")()
check(home == install, "PIXI_HOME is the install directory: " .. tostring(home))
check(io.open(pixi.binary(install)) == nil, "pixi is removed after a successful install")

-- A failing pixi raises an error that names the command, so vfox can clean up.
os.setenv("FAKE_PIXI_EXIT", "3")
write_fake_pixi()
local ok, err = pcall(pixi.install, install, "22.1.3")
check(not ok, "a failing pixi is an error")
check(tostring(err):find("Failed to execute command:", 1, true), "failure message: " .. tostring(err))

run("rm -rf " .. shq(root))
print("shell quoting: ok")
