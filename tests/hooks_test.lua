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

-- The hooks as vfox calls them: PreInstall resolves the version, the pixi archive
-- and its SHA-256, EnvKeys puts the binaries on PATH, Detect finds system installs.
local test = require("vfox.test")

-- Closures read state's fields when they run; see util_test.lua. The version list
-- and the .sha256 file are answered apart, because PreInstall asks for both.
local state = { answer = nil, checksum = nil, requested = {} }

--- A stub answers with a response table, or with a function that makes one, as versions_test does.
local function answerWith(answer, request)
    if type(answer) == "function" then
        ---@diagnostic disable-next-line: redundant-parameter
        return answer(request)
    end
    return answer
end

local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = {},
    http = function(request)
        table.insert(state.requested, request.url)
        if request.url:sub(-7) == ".sha256" then
            return answerWith(state.checksum, request)
        end
        return answerWith(state.answer, request)
    end,
})

local manifest = {
    status_code = 200,
    body = '<code>{"conda-forge": ["22.1.3", "22.1.0"]}</code>',
}

-- The archives of pixi v0.84.2 and the digests its .sha256 files hold.
local RELEASE = "https://github.com/prefix-dev/pixi/releases/latest/download/"
local LINUX_ARCHIVE = "pixi-x86_64-unknown-linux-musl.tar.gz"
local LINUX_DIGEST = "6d2a576bde0a7b26533a068fec0aea6e4ee21c36668efc1dc73fce90110906ae"
local DARWIN_ARCHIVE = "pixi-aarch64-apple-darwin.tar.gz"
local DARWIN_DIGEST = "039d4b48c7e17bc62a36faa2af1b13d0d187f5dd6e8fea17e0587302438df6e6"
local WINDOWS_ARM64_ARCHIVE = "pixi-aarch64-pc-windows-msvc.zip"
local WINDOWS_ARM64_DIGEST = "2c8d16e4f1a3600e587c0157ddb25f9a046b41da275e2125f0384e94841a45e6"

local function expect(got, want, label)
    assert(got == want, ("%s: want %q, got %q"):format(label, tostring(want), tostring(got)))
end

local function failure_of(fn)
    local ok, err = pcall(fn)
    assert(not ok, "expected an error")
    return tostring(err)
end

local function last_request()
    return state.requested[#state.requested]
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
-- pixi publishes no .sha256 here, so PreInstall returns no checksum and vfox warns.
state.answer = manifest
state.checksum = { status_code = 404, body = "Not Found" }
local install = plugin:PreInstall({ version = "latest" })
expect(install.version, "22.1.3", "latest resolves to the first version")
expect(install.url, RELEASE .. LINUX_ARCHIVE, "linux archive")
expect(install.sha256, nil, "no published SHA-256 gives no checksum")
expect(last_request(), RELEASE .. LINUX_ARCHIVE .. ".sha256", "the .sha256 is requested next to the archive")

-- A published SHA-256 is returned, so vfox checks the archive before it unpacks it.
state.checksum = { status_code = 200, body = LINUX_DIGEST .. "  " .. LINUX_ARCHIVE .. "\n" }
install = plugin:PreInstall({ version = "22.1.0" })
expect(install.version, "22.1.0", "a listed version resolves to itself")
expect(install.sha256, LINUX_DIGEST, "the published SHA-256 is returned")

RUNTIME.osType = "darwin"
RUNTIME.archType = "arm64"
state.checksum = { status_code = 200, body = DARWIN_DIGEST .. "  " .. DARWIN_ARCHIVE .. "\n" }
install = plugin:PreInstall({ version = "22.1.3" })
expect(install.url, RELEASE .. DARWIN_ARCHIVE, "darwin arm64 archive")
expect(install.sha256, DARWIN_DIGEST, "darwin arm64 SHA-256")
expect(last_request(), RELEASE .. DARWIN_ARCHIVE .. ".sha256", "darwin arm64 .sha256 URL")
RUNTIME.osType = "linux"
RUNTIME.archType = "amd64"

-- Windows arm64 has an archive of its own, and its SHA-256 is requested next to it.
RUNTIME.osType = "windows"
RUNTIME.archType = "arm64"
state.checksum = { status_code = 200, body = WINDOWS_ARM64_DIGEST .. "  " .. WINDOWS_ARM64_ARCHIVE .. "\n" }
install = plugin:PreInstall({ version = "22.1.3" })
expect(install.url, RELEASE .. WINDOWS_ARM64_ARCHIVE, "windows arm64 archive")
expect(install.sha256, WINDOWS_ARM64_DIGEST, "windows arm64 SHA-256")
expect(last_request(), RELEASE .. WINDOWS_ARM64_ARCHIVE .. ".sha256", "windows arm64 .sha256 URL")
RUNTIME.osType = "linux"
RUNTIME.archType = "amd64"

-- A platform without an archive returns no result and prints the reason, which names the platform
-- and the supported ones. It raises no error, so vfox prints no stack traceback, and it requests
-- nothing: the version list is not read either.
local realPrint = print
local printed = {}
print = function(...)
    table.insert(printed, table.concat({ ... }, "\t"))
end
RUNTIME.osType = "freebsd"
local requestsBeforeUnsupported = #state.requested
local noResult = plugin:PreInstall({ version = "latest" })
print = realPrint
RUNTIME.osType = "linux"
expect(noResult, nil, "an unsupported platform returns no result")
expect(#printed, 1, "an unsupported platform prints the reason once")
assert(
    printed[1]:find("Unsupported platform: freebsd-amd64. The plugin installs clang on Linux x86_64", 1, true),
    "the reason names the platform and the supported ones: " .. printed[1]
)
expect(#state.requested, requestsBeforeUnsupported, "an unsupported platform requests nothing")

-- A SHA-256 that cannot be read stops the install: a published value is never skipped.
state.checksum = { status_code = 500, body = "Internal Server Error" }
local message = failure_of(function()
    plugin:PreInstall({ version = "22.1.3" })
end)
assert(
    message:find("Failed to get the SHA-256 of the archive: status 500", 1, true),
    "a 500 names the status: " .. message
)

state.checksum = { status_code = 200, body = "<html>Not a checksum</html>" }
message = failure_of(function()
    plugin:PreInstall({ version = "22.1.3" })
end)
assert(message:find("has no SHA-256 value", 1, true), "a page is not a SHA-256: " .. message)

state.checksum = function()
    return nil, "dial tcp 127.0.0.1:1: connect: connection refused"
end
message = failure_of(function()
    plugin:PreInstall({ version = "22.1.3" })
end)
assert(message:find("Failed to request the SHA-256 of the archive", 1, true), "transport: " .. message)
assert(message:find("connection refused", 1, true), "transport keeps the cause: " .. message)

-- An unlisted version is an error that names the search command, not an exit. It is
-- refused before the SHA-256 is asked for, so only the version list is requested.
local requestsBefore = #state.requested
message = failure_of(function()
    plugin:PreInstall({ version = "1.0.0" })
end)
assert(message:find("Unsupported version: 1.0.0", 1, true), "unlisted version message: " .. message)
assert(message:find("vfox search clang", 1, true), "the message names the search command")
expect(#state.requested, requestsBefore + 1, "an unlisted version requests no SHA-256")
expect(last_request(), "https://github.com/version-fox/vfox-clang/releases/manifest", "the version list URL")

-- Detect with nothing installed returns an empty list. The test VM disables
-- io.popen, and the real file system is not this test's business: nothing exists.
io.open = function()
    return nil
end
io.popen = function()
    return nil
end
expect(#plugin:Detect({}), 0, "Detect finds nothing on an empty system")
