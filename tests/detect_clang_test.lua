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

-- `vfox link --detect clang` on a fake file system: the install layouts of
-- Linux, macOS and Windows, the version each binary reports, and what is left out.
local test = require("vfox.test")
local plugin = test.load({ os = "linux", arch = "amd64" })
local detect = require("detect_clang")

-- Closures read state's fields when they run; see util_test.lua.
local state = {
    env = {},
    -- Paths that exist.
    files = {},
    -- The output of `<path> --version`, per binary path.
    versions = {},
    -- The entry names of each listed directory, as ls and dir print them.
    children = {},
}

os.getenv = function(name)
    return state.env[name]
end

io.open = function(path, mode)
    if state.files[path] == nil then
        return nil
    end
    return {
        close = function()
            return true
        end,
    }
end

-- The path a listing or a version command names: the first quoted word.
local function named_path(command)
    return command:match("'([^']+)'") or command:match('"([^"]+)"')
end

io.popen = function(command, mode)
    local target = named_path(command)
    local output = ""
    if command:find("--version", 1, true) then
        output = state.versions[target] or ""
    else
        output = table.concat(state.children[target] or {}, "\n")
    end
    -- Only read and close, as vfox's io.popen returns them on Windows: a call to
    -- lines would fail there, so the stub fails here too.
    return {
        read = function()
            return output
        end,
        close = function()
            return true
        end,
    }
end

local function reset(os_type)
    state.files = {}
    state.versions = {}
    state.children = {}
    state.env = {}
    RUNTIME.osType = os_type
end

local function expect(got, want, label)
    assert(got == want, ("%s: want %q, got %q"):format(label, tostring(want), tostring(got)))
end

local function paths_of(list)
    local out = {}
    for _, item in ipairs(list) do
        table.insert(out, item.path)
    end
    return table.concat(out, " ")
end

-- Adds an installation: its clang binary exists and prints the given output.
local function install(root, output)
    local exe = detect.executable(root)
    state.files[exe] = true
    state.versions[exe] = output
end

-- The version a `clang --version` line names, and the lines that are refused.
expect(detect.version_from_output("Ubuntu clang version 18.1.3 (1ubuntu1)\nTarget: x86_64"), "18.1.3", "ubuntu")
expect(detect.version_from_output("clang version 22.1.3 (https://github.com/llvm)"), "22.1.3", "llvm")
expect(detect.version_from_output("Homebrew clang version 18.1.8"), "18.1.8", "homebrew")
expect(detect.version_from_output("Apple clang version 15.0.0 (clang-1500.3.9.4)"), nil, "apple refused")
expect(detect.version_from_output(""), nil, "empty output")
expect(detect.version_from_output(nil), nil, "nil output")

-- Linux: system LLVM under /usr/lib and /usr/lib64, /opt, Linuxbrew, CONDA_PREFIX.
-- A vfox install under .vfox is never reported, though it is clang too.
reset("linux")
state.env.HOME = "/home/u"
state.children["/usr/lib"] = { "llvm-18", "llvm", "python3" }
state.children["/usr/lib64"] = { "llvm19" }
state.children["/opt"] = { "llvm-22", "other" }
state.children["/home/u/.linuxbrew/opt"] = { "llvm@17" }
install("/usr/lib/llvm-18", "Ubuntu clang version 18.1.3 (1ubuntu1)\n")
install("/usr/lib64/llvm19", "clang version 19.1.7 (Fedora)\n")
install("/opt/llvm-22", "clang version 22.1.3\n")
install("/home/u/.linuxbrew/opt/llvm@17", "Homebrew clang version 17.0.6\n")
state.env.CONDA_PREFIX = "/home/u/.vfox/sdks/clang/v-22.1.3/clang-22.1.3"
install(state.env.CONDA_PREFIX, "clang version 22.1.3\n")

local found = detect.find_all()
expect(#found, 4, "linux count: " .. paths_of(found))
expect(found[1].version, "22.1.3", "linux newest first")
expect(found[1].path, "/opt/llvm-22", "linux 22.1.3 from /opt")
expect(found[1].note, "installed under /opt", "linux note")
expect(found[2].version, "19.1.7", "linux second")
expect(found[3].version, "18.1.3", "linux third")
expect(found[3].note, "system LLVM", "linux system note")
expect(found[4].version, "17.0.6", "linux linuxbrew")
expect(found[4].note, "installed by Homebrew", "linux brew note")
assert(not paths_of(found):find(".vfox", 1, true), "a vfox install is never reported")

-- The same version in two places is listed once, from the first place found:
-- /usr/lib comes before CONDA_PREFIX.
reset("linux")
state.children["/usr/lib"] = { "llvm-18" }
install("/usr/lib/llvm-18", "clang version 18.1.8\n")
state.env.CONDA_PREFIX = "/opt/conda"
install("/opt/conda", "clang version 18.1.8\n")
found = detect.find_all()
expect(#found, 1, "one entry per version")
expect(found[1].path, "/usr/lib/llvm-18", "first place wins")

-- macOS: Homebrew's llvm and llvm@18; Apple's clang is never reported, even where
-- it sits in a searched place.
reset("darwin")
state.env.HOME = "/Users/u"
state.children["/opt/homebrew/opt"] = { "llvm", "llvm@18", "python" }
install("/opt/homebrew/opt/llvm", "Homebrew clang version 22.1.3\n")
install("/opt/homebrew/opt/llvm@18", "Homebrew clang version 18.1.8\n")
install("/usr/local", "Apple clang version 15.0.0 (clang-1500.3.9.4)\n")
found = detect.find_all()
expect(#found, 2, "darwin count: " .. paths_of(found))
expect(found[1].path, "/opt/homebrew/opt/llvm", "darwin newest")
expect(found[1].note, "installed by Homebrew", "darwin note")
expect(found[2].version, "18.1.8", "darwin llvm@18")

-- Windows: the LLVM installer, a Visual Studio bundle two levels down, and a
-- Program Files that is the same folder with other case is not listed twice.
reset("windows")
state.env.ProgramFiles = "C:\\Program Files"
state.env["ProgramFiles(x86)"] = "c:\\program files"
state.env.USERPROFILE = "C:\\Users\\John Doe"
local vs_base = "C:\\Program Files\\Microsoft Visual Studio"
local vs_edition = vs_base .. "\\2022\\Community"
state.children[vs_base] = { "2022" }
state.children[vs_base .. "\\2022"] = { "Community" }
install(vs_edition .. "\\VC\\Tools\\Llvm\\x64", "clang version 19.1.5\n")
install("C:\\Program Files\\LLVM", "clang version 18.1.8\n")
found = detect.find_all()
expect(#found, 2, "windows count: " .. paths_of(found))
expect(found[1].version, "19.1.5", "windows newest first")
expect(found[1].note, "bundled with Visual Studio", "windows VS note")
expect(found[1].path, vs_edition .. "\\VC\\Tools\\Llvm\\x64", "windows VS path")
expect(found[2].path, "C:\\Program Files\\LLVM", "windows installer")
expect(found[2].note, "installed by the LLVM installer", "windows installer note")

-- A Windows install under .vfox is out, whatever the case of the folder.
reset("windows")
state.env.ProgramFiles = "C:\\Users\\John Doe\\.VFOX\\sdks"
install("C:\\Users\\John Doe\\.VFOX\\sdks\\LLVM", "clang version 18.1.8\n")
expect(#detect.find_all(), 0, "windows vfox install is out")

-- Nothing installed: an empty list.
reset("linux")
expect(#detect.find_all(), 0, "nothing found")

-- The Detect hook returns what find_all finds.
reset("linux")
state.children["/usr/lib"] = { "llvm-18" }
install("/usr/lib/llvm-18", "clang version 18.1.8\n")
local hooked = plugin:Detect({})
expect(#hooked, 1, "Detect hook count")
expect(hooked[1].version, "18.1.8", "Detect hook version")
expect(hooked[1].path, "/usr/lib/llvm-18", "Detect hook path")
