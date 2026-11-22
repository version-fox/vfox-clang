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

local versions = require("versions")
local util = require("util")
local pixi = require("pixi")

--- Resolves the requested version against the list and tells vfox where pixi is.
function PLUGIN:PreInstall(ctx)
    local list = versions.fetch()
    local version = ctx.version
    if version == "latest" then
        version = list[1]
    end
    if version == nil or not util.contains(list, version) then
        error("Unsupported version: " .. tostring(ctx.version) .. ". Run `vfox search clang` to list the versions.")
    end

    return {
        url = pixi.downloadURL(RUNTIME.osType, RUNTIME.archType),
        version = version,
    }
end
