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

--- pixi downloads clang from conda-forge into the install directory. This module
--- names pixi's release assets and runs pixi with the paths quoted for the shell.
local util = require("util")

local pixi = {}

--- Maps the architecture vfox reports to the names pixi's assets use.
local ARCHITECTURES = {
    arm64 = "aarch64",
    amd64 = "x86_64",
}

--- Returns the archive name of pixi's latest release for the platform. Each
--- platform name is one vfox reports: darwin is macOS, and vfox never says macos.
function pixi.asset(osType, archType)
    local arch = ARCHITECTURES[archType]
    if arch == nil then
        error("Unsupported architecture: " .. tostring(archType))
    end
    if osType == "darwin" then
        return "pixi-" .. arch .. "-apple-darwin.tar.gz"
    elseif osType == "linux" then
        return "pixi-" .. arch .. "-unknown-linux-musl.tar.gz"
    elseif osType == "windows" and arch == "x86_64" then
        return "pixi-" .. arch .. "-pc-windows-msvc.zip"
    end
    error("Unsupported environment: " .. tostring(osType) .. "-" .. tostring(archType))
end

--- Returns the URL of the pixi archive for the platform, through GITHUB_URL when
--- a mirror is set.
function pixi.downloadURL(osType, archType)
    return util.githubURL() .. "/prefix-dev/pixi/releases/latest/download/" .. pixi.asset(osType, archType)
end

--- Returns the path of the pixi executable that PreInstall unpacked into path.
function pixi.binary(path)
    if util.isWindows() then
        return util.join(path, "pixi.exe")
    end
    return util.join(path, "pixi")
end

--- Returns the command that installs clang into the pixi home, without the
--- redirection of its output. The executable and every argument are quoted for
--- the platform's shell, so an install path with a space works.
function pixi.command(path, version)
    local channel = util.env("Conda_Forge", "conda-forge")
    return util.quote(pixi.binary(path))
        .. " global install -qc "
        .. util.quote(channel)
        .. " "
        .. util.quote("clang=" .. version)
end

--- Wraps a command so that its standard output is discarded. cmd.exe needs the
--- whole line in quotes when its program is quoted, so Windows gets the outer pair.
function pixi.silenced(command)
    if util.isWindows() then
        return '"' .. command .. ' > nul"'
    end
    return command .. " > /dev/null"
end

--- Installs clang into path with pixi, using PIXI_HOME=path so the clang binaries
--- land in path/bin. A failed command raises an error instead of exiting the
--- process, so vfox removes the partial install and its lock files.
function pixi.install(path, version)
    local command = pixi.command(path, version)
    -- vfox's Lua runtime (gopher-lua) provides os.setenv; Lua 5.1 does not.
    ---@diagnostic disable-next-line: undefined-field
    os.setenv("PIXI_HOME", path)
    local status = os.execute(pixi.silenced(command))
    if status ~= 0 then
        error("Failed to execute command: " .. command)
    end
    os.remove(pixi.binary(path))
end

return pixi
