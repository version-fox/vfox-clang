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

-- Quoting, joining and the environment helpers, on Linux and Windows.
local test = require("vfox.test")
test.load({ os = "linux", arch = "amd64" })
local util = require("util")

-- Closures read state's fields when they run. Under the test VM a closure does
-- not see a local that the main chunk reassigns later, so the state is mutated
-- in place and never replaced.
local state = { env = {} }
os.getenv = function(name)
    return state.env[name]
end

local function expect(got, want, label)
    assert(got == want, ("%s: want %q, got %q"):format(label, tostring(want), tostring(got)))
end

-- POSIX: single quotes, with an apostrophe closed, escaped and reopened.
RUNTIME.osType = "linux"
expect(util.quote("/home/a b/it's"), "'/home/a b/it'\\''s'", "quote posix")
expect(util.join("/opt/a", "bin"), "/opt/a/bin", "join posix")
expect(util.join("/opt/a/", "bin"), "/opt/a/bin", "join posix keeps one separator")

-- Windows: double quotes; a double quote cannot be quoted for cmd.exe.
RUNTIME.osType = "windows"
expect(util.quote("C:\\Program Files\\LLVM"), '"C:\\Program Files\\LLVM"', "quote windows")
expect(util.join("C:\\LLVM", "bin"), "C:\\LLVM\\bin", "join windows")
expect(util.join("C:\\LLVM\\", "bin"), "C:\\LLVM\\bin", "join windows keeps one separator")
local ok, err = pcall(util.quote, 'C:\\bad"name')
assert(not ok and tostring(err):find("double quote", 1, true), "quote windows refuses a double quote")
RUNTIME.osType = "linux"

-- GITHUB_URL: blank or unset means github.com, and trailing slashes go.
expect(util.githubURL(), "https://github.com", "githubURL unset")
state.env.GITHUB_URL = "   "
expect(util.githubURL(), "https://github.com", "githubURL blank")
state.env.GITHUB_URL = " https://mirror.example/gh///\n"
expect(util.githubURL(), "https://mirror.example/gh", "githubURL trimmed")
state.env.GITHUB_URL = nil

-- Conda_Forge falls back to conda-forge when it is blank.
state.env.Conda_Forge = ""
expect(util.env("Conda_Forge", "conda-forge"), "conda-forge", "env blank falls back")
state.env.Conda_Forge = "https://prefix.dev/conda-forge"
expect(util.env("Conda_Forge", "conda-forge"), "https://prefix.dev/conda-forge", "env set")

expect(util.contains({ "22.1.3", "22.1.0" }, "22.1.0"), true, "contains found")
expect(util.contains({ "22.1.3" }, "21.1.8"), false, "contains missing")
expect(util.contains(nil, "x"), false, "contains nil list")
