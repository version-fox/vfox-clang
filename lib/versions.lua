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

--- The versions this plugin offers. They come from the JSON list in the body of
--- the `manifest` release, which the Update version list workflow keeps current.
local http = require("http")
local json = require("json")
local pixi = require("pixi")
local util = require("util")

local versions = {}

--- Path of the manifest release below the GitHub base URL.
local MANIFEST_PATH = "/version-fox/vfox-clang/releases/manifest"

--- The file vfox keeps the Available hook's results in, inside the plugin
--- directory. vfox names it with a leading dot.
local CACHE_FILE = ".available.cache"

--- Returns the versions for the platform. The manifest lists under the conda subdir of each
--- platform the versions that conda-forge publishes there. A manifest without that entry gives
--- the whole conda-forge list, as manifests did before the entries were added.
local function platformList(manifest, all)
    local subdir = pixi.subdir(RUNTIME.osType, RUNTIME.archType)
    if subdir == nil or manifest[subdir] == nil then
        return all
    end
    local list = manifest[subdir]
    if type(list) ~= "table" or #list == 0 then
        error("Failed to get versions: the version list has no version for " .. subdir)
    end
    return list
end

--- Fetches the version list and returns it as a Lua array, newest first, with the versions that
--- conda-forge publishes for the platform. Every failure is raised as an error that names what went
--- wrong, so vfox can show it.
function versions.fetch()
    local resp, err = http.get({
        url = util.githubURL() .. MANIFEST_PATH,
    })
    if err ~= nil then
        error("Failed to request the version list: " .. err)
    end
    -- http.get returns the response for every HTTP status, so a 404 arrives
    -- here with err == nil.
    if resp.status_code ~= 200 then
        error("Failed to get versions: status " .. tostring(resp.status_code))
    end

    local block = resp.body:match("<code>(.-)</code>")
    if block == nil then
        error("Failed to get versions: the manifest has no version list")
    end
    -- vfox's json.decode returns nil and a message for invalid JSON; it does not raise.
    local manifest, decodeErr = json.decode(block)
    if manifest == nil then
        error("Failed to get versions: the version list is not valid JSON: " .. tostring(decodeErr))
    end
    local all = type(manifest) == "table" and manifest["conda-forge"] or nil
    if type(all) ~= "table" then
        error("Failed to get versions: the version list has no conda-forge entry")
    end
    return platformList(manifest, all)
end

--- Returns the entries of the Available hook: every version, the first marked
--- as the latest.
function versions.available()
    local result = {}
    for i, version in ipairs(versions.fetch()) do
        if i == 1 then
            table.insert(result, { version = version, note = "latest" })
        else
            table.insert(result, { version = version })
        end
    end
    return result
end

--- Deletes the Available hook's cache file in the plugin directory, so the next
--- listing asks GitHub again. A missing file is not an error.
function versions.clearCache()
    os.remove(util.join(RUNTIME.pluginDirPath, CACHE_FILE))
end

return versions
