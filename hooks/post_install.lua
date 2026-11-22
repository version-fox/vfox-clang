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

--- Installs clang from conda-forge with the pixi that PreInstall downloaded.
function PLUGIN:PostInstall(ctx)
    local sdkInfo = ctx.sdkInfo["clang"]
    pixi.install(sdkInfo.path, sdkInfo.version)
end
