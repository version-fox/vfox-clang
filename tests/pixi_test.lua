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

-- pixi's assets per platform, the quoting of its command, and the install
-- itself, with os.execute stubbed. shell_quoting.lua runs the real shell.
local test = require("vfox.test")
test.load({ os = "linux", arch = "amd64" })
local pixi = require("pixi")

-- Closures read state's fields when they run; see util_test.lua.
local state = {
    env = {},
    commands = {},
    setenvs = {},
    removed = {},
    status = 0,
}

os.getenv = function(name)
    return state.env[name]
end
os.execute = function(command)
    table.insert(state.commands, command)
    return state.status
end
os.setenv = function(name, value)
    state.setenvs[name] = value
    return true
end
os.remove = function(path)
    table.insert(state.removed, path)
    return true
end

local function expect(got, want, label)
    assert(got == want, ("%s: want %q, got %q"):format(label, tostring(want), tostring(got)))
end

local function failure_of(fn)
    local ok, err = pcall(fn)
    assert(not ok, "expected an error")
    return tostring(err)
end

-- Every platform vfox reports, with pixi's own asset names.
expect(pixi.asset("linux", "amd64"), "pixi-x86_64-unknown-linux-musl.tar.gz", "linux amd64")
expect(pixi.asset("linux", "arm64"), "pixi-aarch64-unknown-linux-musl.tar.gz", "linux arm64")
expect(pixi.asset("darwin", "amd64"), "pixi-x86_64-apple-darwin.tar.gz", "darwin amd64")
expect(pixi.asset("darwin", "arm64"), "pixi-aarch64-apple-darwin.tar.gz", "darwin arm64")
expect(pixi.asset("windows", "amd64"), "pixi-x86_64-pc-windows-msvc.zip", "windows amd64")

-- macOS is reported as darwin; the old name macos is unsupported (issue #7).
local message = failure_of(function()
    pixi.asset("macos", "arm64")
end)
assert(message:find("Unsupported environment: macos-arm64", 1, true), "macos is unsupported: " .. message)
message = failure_of(function()
    pixi.asset("windows", "arm64")
end)
assert(message:find("Unsupported environment: windows-arm64", 1, true), "windows arm64: " .. message)
message = failure_of(function()
    pixi.asset("linux", "386")
end)
assert(message:find("Unsupported architecture: 386", 1, true), "386: " .. message)

-- The download goes through GITHUB_URL when a mirror is set.
expect(
    pixi.downloadURL("linux", "amd64"),
    "https://github.com/prefix-dev/pixi/releases/latest/download/pixi-x86_64-unknown-linux-musl.tar.gz",
    "download URL"
)
state.env.GITHUB_URL = "https://mirror.example/gh/"
expect(
    pixi.downloadURL("darwin", "arm64"),
    "https://mirror.example/gh/prefix-dev/pixi/releases/latest/download/pixi-aarch64-apple-darwin.tar.gz",
    "mirror download URL"
)
state.env.GITHUB_URL = nil

-- The .sha256 file that pixi publishes sits next to the archive, and a mirror serves it too.
expect(
    pixi.checksumURL(pixi.downloadURL("linux", "amd64")),
    "https://github.com/prefix-dev/pixi/releases/latest/download/pixi-x86_64-unknown-linux-musl.tar.gz.sha256",
    "checksum URL"
)
state.env.GITHUB_URL = "https://mirror.example/gh/"
expect(
    pixi.checksumURL(pixi.downloadURL("windows", "amd64")),
    "https://mirror.example/gh/prefix-dev/pixi/releases/latest/download/pixi-x86_64-pc-windows-msvc.zip.sha256",
    "mirror checksum URL"
)
state.env.GITHUB_URL = nil

-- parseChecksum reads the digest that a .sha256 file holds, as sha256sum writes it. Anything whose
-- first word is not 64 hexadecimal digits is not a checksum.
local DIGEST = "6d2a576bde0a7b26533a068fec0aea6e4ee21c36668efc1dc73fce90110906ae"
expect(pixi.parseChecksum(DIGEST .. "  pixi-x86_64-unknown-linux-musl.tar.gz\n"), DIGEST, "digest and name")
expect(pixi.parseChecksum(DIGEST), DIGEST, "a bare digest")
expect(pixi.parseChecksum(string.upper(DIGEST) .. "  pixi.tar.gz\n"), DIGEST, "upper case is lowercased")
expect(pixi.parseChecksum("  \n" .. DIGEST .. " x\n"), DIGEST, "leading blanks are skipped")
expect(pixi.parseChecksum(string.sub(DIGEST, 1, 63) .. "  x\n"), nil, "63 digits are not a checksum")
expect(pixi.parseChecksum(DIGEST .. "0  x\n"), nil, "65 digits are not a checksum")
expect(pixi.parseChecksum(string.sub(DIGEST, 1, 63) .. "g  x\n"), nil, "a non-hex digit is not a checksum")
expect(pixi.parseChecksum("<html>Not Found</html>"), nil, "a page is not a checksum")
expect(pixi.parseChecksum(""), nil, "an empty file is not a checksum")

-- POSIX: a home with a space and an apostrophe stays one argument (issue #5).
RUNTIME.osType = "linux"
expect(
    pixi.command("/home/a b/it's/clang-22.1.3", "22.1.3"),
    "'/home/a b/it'\\''s/clang-22.1.3/pixi' global install -qc 'conda-forge' 'clang=22.1.3'",
    "posix command"
)
expect(pixi.silenced("cmd"), "cmd > /dev/null", "posix silenced")

-- Windows: the program is quoted, and the whole line is wrapped for cmd.exe.
RUNTIME.osType = "windows"
local windows_home = "C:\\Users\\John Doe\\.vfox\\sdks\\clang\\v-22.1.3\\clang-22.1.3"
expect(
    pixi.command(windows_home, "22.1.3"),
    '"C:\\Users\\John Doe\\.vfox\\sdks\\clang\\v-22.1.3\\clang-22.1.3\\pixi.exe" global install -qc "conda-forge" "clang=22.1.3"',
    "windows command"
)
expect(pixi.silenced('"pixi.exe" global'), '""pixi.exe" global > nul"', "windows silenced")
expect(pixi.binary("C:\\x"), "C:\\x\\pixi.exe", "windows binary")
RUNTIME.osType = "linux"

-- The install runs the command with PIXI_HOME set, then removes pixi itself.
state.env.Conda_Forge = "https://prefix.dev/conda-forge"
pixi.install("/opt/clang-22.1.3", "22.1.3")
assert(#state.commands == 1, "one command, got " .. #state.commands)
expect(
    state.commands[1],
    "'/opt/clang-22.1.3/pixi' global install -qc 'https://prefix.dev/conda-forge' 'clang=22.1.3' > /dev/null",
    "install command"
)
expect(state.setenvs.PIXI_HOME, "/opt/clang-22.1.3", "PIXI_HOME")
expect(state.removed[1], "/opt/clang-22.1.3/pixi", "pixi is removed after the install")
state.env.Conda_Forge = nil

-- A failing pixi raises an error, so vfox can clean up. It does not exit the process.
state.commands, state.removed, state.status = {}, {}, 1
message = failure_of(function()
    pixi.install("/opt/clang-22.1.3", "22.1.3")
end)
assert(message:find("Failed to execute command:", 1, true), "failure message: " .. message)
assert(#state.removed == 0, "a failed pixi is not removed")
