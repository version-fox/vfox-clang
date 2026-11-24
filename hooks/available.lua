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

local pixi = require("pixi")
local util = require("util")
local versions = require("versions")

--- Lists the versions for the platform. `vfox search clang -- --no-cache` deletes the cache file
--- first (the arguments after -- reach the hook, see vfox#808). On a platform the plugin does not
--- support nothing can be installed, so nothing is listed, and the reason is printed instead.
function PLUGIN:Available(ctx)
    if util.contains(ctx.args, "--no-cache") then
        versions.clearCache()
    end
    local asset, reason = pixi.asset(RUNTIME.osType, RUNTIME.archType)
    if asset == nil then
        print(reason)
        return {}
    end
    return versions.available()
end
