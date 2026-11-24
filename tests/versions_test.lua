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

-- Fetching the version list: HTTP failures become messages that name the
-- status, the Available hook's --no-cache, and the cache file it removes.
local test = require("vfox.test")

-- Closures read state's fields when they run; see util_test.lua.
local state = {
    env = {},
    answer = nil,
    requested = {},
    removed = {},
}

local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = {},
    http = function(request)
        table.insert(state.requested, request.url)
        if type(state.answer) == "function" then
            ---@diagnostic disable-next-line: redundant-parameter
            return state.answer(request)
        end
        return state.answer
    end,
})
local versions = require("versions")
local util = require("util")

os.getenv = function(name)
    return state.env[name]
end

os.remove = function(path)
    table.insert(state.removed, path)
    return true
end

local MANIFEST = "https://github.com/version-fox/vfox-clang/releases/manifest"

local function failure_of(fn)
    local ok, err = pcall(fn)
    assert(not ok, "expected an error")
    return tostring(err)
end

local function contains(text, part)
    return text:find(part, 1, true) ~= nil
end

local function last_request()
    return state.requested[#state.requested]
end

-- A 404 is a response, not a transport error: the status must reach the message.
state.answer = { status_code = 404, body = "Not Found" }
local message = failure_of(versions.fetch)
assert(contains(message, "Failed to get versions: status 404"), "404 names the status: " .. message)
assert(not contains(message, "concatenate"), "404 is not a Lua concat error: " .. message)
assert(last_request() == MANIFEST, "the manifest URL: " .. tostring(last_request()))

-- A 200 without a <code> block is reported, not passed to the JSON decoder.
state.answer = { status_code = 200, body = "<html>no list here</html>" }
message = failure_of(versions.fetch)
assert(contains(message, "no version list"), "no <code> block: " .. message)

-- A <code> block that is not JSON.
state.answer = { status_code = 200, body = "<code>{not json</code>" }
message = failure_of(versions.fetch)
assert(contains(message, "not valid JSON"), "bad JSON: " .. message)

-- JSON without a conda-forge entry.
state.answer = { status_code = 200, body = '<code>{"other": ["1.0.0"]}</code>' }
message = failure_of(versions.fetch)
assert(contains(message, "no conda-forge entry"), "missing entry: " .. message)

-- A transport error keeps vfox's own message.
state.answer = function()
    return nil, "dial tcp 127.0.0.1:1: connect: connection refused"
end
message = failure_of(versions.fetch)
assert(contains(message, "Failed to request the version list"), "transport: " .. message)
assert(contains(message, "connection refused"), "transport keeps the cause: " .. message)

-- A valid manifest, as the release body holds it: the first version is the latest.
state.answer = {
    status_code = 200,
    body = '<pre><code>{\n    "conda-forge": [\n        "22.1.3",\n        "22.1.0"\n    ]\n}\n</code></pre>',
}
local list = versions.fetch()
assert(#list == 2 and list[1] == "22.1.3" and list[2] == "22.1.0", "valid list")
local entries = versions.available()
assert(entries[1].version == "22.1.3" and entries[1].note == "latest", "latest is marked")
assert(entries[2].version == "22.1.0" and entries[2].note == nil, "others are not marked")

-- GITHUB_URL selects a mirror for the manifest, trailing slashes included.
state.env.GITHUB_URL = "https://mirror.example/gh/"
versions.fetch()
assert(
    last_request() == "https://mirror.example/gh/version-fox/vfox-clang/releases/manifest",
    "mirror URL: " .. tostring(last_request())
)
state.env.GITHUB_URL = nil

-- The Available hook: --no-cache removes the cache file in the plugin directory
-- and still lists; without it nothing is removed.
local cache = util.join(RUNTIME.pluginDirPath, ".available.cache")
state.answer = { status_code = 200, body = '<code>{"conda-forge": ["22.1.3"]}</code>' }

local result = plugin:Available({ args = {} })
assert(#state.removed == 0, "no flag, no removal")
assert(result[1].version == "22.1.3", "plain listing")

result = plugin:Available({ args = { "--no-cache" } })
assert(#state.removed == 1 and state.removed[1] == cache, "--no-cache removes " .. cache)
assert(result[1].version == "22.1.3", "--no-cache still lists the versions")

-- Each platform lists the versions conda-forge publishes for it: the entry of its conda subdir.
state.answer = {
    status_code = 200,
    body = '<code>{"conda-forge": ["23.1.6", "22.1.3", "22.1.0"], "linux-64": ["23.1.6", "22.1.3"], '
        .. '"win-arm64": ["23.1.6"], "osx-arm64": ["22.1.3", "22.1.0"]}</code>',
}

RUNTIME.osType = "linux"
RUNTIME.archType = "amd64"
local platform = versions.fetch()
assert(#platform == 2 and platform[1] == "23.1.6" and platform[2] == "22.1.3", "linux-64 lists its entry")

RUNTIME.osType = "windows"
RUNTIME.archType = "arm64"
platform = versions.fetch()
assert(#platform == 1 and platform[1] == "23.1.6", "win-arm64 lists only the versions published there")
entries = versions.available()
assert(#entries == 1 and entries[1].version == "23.1.6" and entries[1].note == "latest", "the one version is latest")

RUNTIME.osType = "darwin"
RUNTIME.archType = "arm64"
platform = versions.fetch()
assert(#platform == 2 and platform[2] == "22.1.0", "osx-arm64 lists its entry")

-- win-64 has no entry in this manifest, and an unsupported platform has no subdir: both get the whole list.
RUNTIME.osType = "windows"
RUNTIME.archType = "amd64"
assert(#versions.fetch() == 3, "a subdir without an entry gets the whole list")
RUNTIME.osType = "windows"
RUNTIME.archType = "386"
assert(#versions.fetch() == 3, "an unsupported platform gets the whole list")

-- A manifest from before the entries existed gives the whole list on every platform.
state.answer = { status_code = 200, body = '<code>{"conda-forge": ["22.1.3", "22.1.0"]}</code>' }
RUNTIME.osType = "windows"
RUNTIME.archType = "arm64"
assert(#versions.fetch() == 2, "an old manifest gives the whole list")

-- An empty entry is an error that names its subdir: a platform with no version must not look like one that is not supported.
state.answer = { status_code = 200, body = '<code>{"conda-forge": ["22.1.3"], "win-arm64": []}</code>' }
message = failure_of(versions.fetch)
assert(contains(message, "no version for win-arm64"), "an empty entry names its subdir: " .. message)

RUNTIME.osType = "linux"
RUNTIME.archType = "amd64"
