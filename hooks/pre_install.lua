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

local http = require("http")
local versions = require("versions")
local util = require("util")
local pixi = require("pixi")

--- Asks GitHub for the SHA-256 that pixi publishes next to the archive at url. nil means pixi
--- publishes none (a 404), so vfox skips the check and warns. Any other failure is an error: a
--- published value is never skipped without a word.
local function fetchChecksum(url)
    local checksumURL = pixi.checksumURL(url)
    local resp, err = http.get({
        url = checksumURL,
    })
    if err ~= nil then
        error("Failed to request the SHA-256 of the archive: " .. err)
    end
    -- http.get returns the response for every HTTP status, so a 404 arrives here with err == nil.
    if resp.status_code == 404 then
        return nil
    end
    if resp.status_code ~= 200 then
        error("Failed to get the SHA-256 of the archive: status " .. tostring(resp.status_code))
    end
    local sha256 = pixi.parseChecksum(resp.body)
    if sha256 == nil then
        error("Failed to get the SHA-256 of the archive: " .. checksumURL .. " has no SHA-256 value")
    end
    return sha256
end

--- Resolves the requested version against the list and tells vfox where pixi is, and the SHA-256
--- that pixi publishes for the archive, which vfox checks before it unpacks the archive.
--- On a platform the plugin does not support, it prints the reason and returns no result.
function PLUGIN:PreInstall(ctx)
    local url, reason = pixi.downloadURL(RUNTIME.osType, RUNTIME.archType)
    if url == nil then
        -- An error raised here reaches the user with a Lua stack traceback. A hook that returns
        -- no result stops the install too, and vfox then prints its own message after the reason.
        print(reason)
        return nil
    end

    local list = versions.fetch()
    local version = ctx.version
    if version == "latest" then
        version = list[1]
    end
    if version == nil or not util.contains(list, version) then
        -- Like an unsupported platform: the reason is printed, and no result stops the install
        -- without a stack traceback. A failure to read the list is still an error.
        print(
            "Unsupported version: "
                .. tostring(ctx.version)
                .. ". Run `vfox search clang` to list the versions for this platform."
        )
        return nil
    end

    return {
        url = url,
        version = version,
        -- nil: vfox prints that no checksum is provided and installs without the check.
        sha256 = fetchChecksum(url),
    }
end
