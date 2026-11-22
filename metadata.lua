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

--- !!! DO NOT EDIT OR RENAME !!!
PLUGIN = {}

--- !!! MUST BE SET !!!
--- Plugin name
PLUGIN.name = "clang"
--- Plugin version
PLUGIN.version = "0.5.2"
--- Plugin homepage
PLUGIN.homepage = "https://github.com/version-fox/vfox-clang"
--- Plugin license, please choose a correct license according to your needs.
PLUGIN.license = "Apache 2.0"
--- Plugin description
PLUGIN.description = "Clang plugin, https://clang.llvm.org/"

--- !!! OPTIONAL !!!
--[[
NOTE:
    Minimum compatible vfox version.
    If the plugin is not compatible with the current vfox version,
    vfox will not load the plugin and prompt the user to upgrade vfox.
    --]]
PLUGIN.minRuntimeVersion = "0.5.1"
-- Some things that need user to be attention!
PLUGIN.notes = {
    "Versions, environment variables and the list of system installs: https://github.com/version-fox/vfox-clang/blob/main/README.md",
}
