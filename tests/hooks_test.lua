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

-- The hooks as vfox calls them: PreInstall resolves the version and the pixi
-- archive, EnvKeys puts the binaries on PATH, Detect finds system installs.
local test = require("vfox.test")

-- Closures read state's fields when they run; see util_test.lua.
local state = { answer = nil }

local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = {},
    http = function()
        return state.answer
    end,
})

local manifest = {
    status_code = 200,
    body = '<code>{"conda-forge": ["22.1.3", "22.1.0"]}</code>',
}

local function expect(got, want, label)
    assert(got == want, ("%s: want %q, got %q"):format(label, tostring(want), tostring(got)))
end

-- EnvKeys: PATH points at the bin directory, with the platform's separator.
local keys = plugin:EnvKeys({ path = "/opt/clang-22.1.3" })
expect(keys[1].key, "PATH", "EnvKeys key")
expect(keys[1].value, "/opt/clang-22.1.3/bin", "EnvKeys linux value")
RUNTIME.osType = "windows"
keys = plugin:EnvKeys({ path = "C:\\clang-22.1.3" })
expect(keys[1].value, "C:\\clang-22.1.3\\bin", "EnvKeys windows value")
RUNTIME.osType = "linux"

-- PreInstall: latest is the first version, and the archive matches the platform.
state.answer = manifest
local install = plugin:PreInstall({ version = "latest" })
expect(install.version, "22.1.3", "latest resolves to the first version")
expect(
    install.url,
    "https://github.com/prefix-dev/pixi/releases/latest/download/pixi-x86_64-unknown-linux-musl.tar.gz",
    "linux archive"
)

install = plugin:PreInstall({ version = "22.1.0" })
expect(install.version, "22.1.0", "a listed version resolves to itself")

RUNTIME.osType = "darwin"
RUNTIME.archType = "arm64"
install = plugin:PreInstall({ version = "22.1.3" })
expect(
    install.url,
    "https://github.com/prefix-dev/pixi/releases/latest/download/pixi-aarch64-apple-darwin.tar.gz",
    "darwin arm64 archive"
)
RUNTIME.osType = "linux"
RUNTIME.archType = "amd64"

-- An unlisted version is an error that names the search command, not an exit.
local ok, err = pcall(function()
    plugin:PreInstall({ version = "1.0.0" })
end)
assert(not ok, "an unlisted version fails")
assert(tostring(err):find("Unsupported version: 1.0.0", 1, true), "unlisted version message: " .. tostring(err))
assert(tostring(err):find("vfox search clang", 1, true), "the message names the search command")

-- Detect with nothing installed returns an empty list. The test VM disables
-- io.popen, and the real file system is not this test's business: nothing exists.
io.open = function()
    return nil
end
io.popen = function()
    return nil
end
expect(#plugin:Detect({}), 0, "Detect finds nothing on an empty system")
