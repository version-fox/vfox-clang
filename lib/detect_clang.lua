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

--- Finds LLVM installations that are already on the machine, for
--- `vfox link --detect clang`. An installation is a directory with bin/clang
--- (bin\clang.exe on Windows). Apple's clang is left out: /usr/bin/clang is a
--- stub that asks to install the Command Line Tools, and it is not LLVM.
local util = require("util")

local detect = {}

--- Lists the immediate children of dir as full paths, or {}. ls on Unix also
--- lists files; callers keep the directories they look for.
function detect.list_children(dir)
    local command
    if util.isWindows() then
        command = "dir /b /ad " .. util.quote(dir) .. " 2>nul"
    else
        command = "ls -1 " .. util.quote(dir) .. " 2>/dev/null"
    end
    local handle = io.popen(command, "r")
    if handle == nil then
        return {}
    end
    local result = {}
    for line in handle:lines() do
        local name = util.trim(line)
        if name ~= "" and name ~= "." and name ~= ".." then
            table.insert(result, util.join(dir, name))
        end
    end
    handle:close()
    return result
end

--- Returns the clang executable of an installation root.
function detect.executable(root)
    local name = util.isWindows() and "clang.exe" or "clang"
    return util.join(util.join(root, "bin"), name)
end

--- Returns the version a `clang --version` line names, such as 18.1.8 from
--- `Ubuntu clang version 18.1.3 (1ubuntu1)`, or nil. Apple's clang is refused.
function detect.version_from_output(text)
    if type(text) ~= "string" or text:find("Apple clang", 1, true) then
        return nil
    end
    return text:match("clang version (%d+%.%d+%.%d+)")
end

--- Returns the shell command that prints the version of exe. Standard error is
--- discarded; on Windows the whole line is quoted for cmd.exe.
function detect.version_command(exe)
    if util.isWindows() then
        return '"' .. util.quote(exe) .. ' --version 2>nul"'
    end
    return util.quote(exe) .. " --version 2>/dev/null"
end

--- Reports whether a path is under a .vfox directory, which vfox manages.
function detect.is_vfox_managed(path)
    local lowered = path:lower()
    return lowered:find("/.vfox/", 1, true) ~= nil or lowered:find("\\.vfox\\", 1, true) ~= nil
end

--- Returns a path as a key for comparisons: Windows paths are case-insensitive.
local function key_of(path)
    if util.isWindows() then
        return (path:lower():gsub("/", "\\"))
    end
    return path
end

--- Returns the children of dir whose names match the Lua pattern, as full paths.
local function children_matching(dir, pattern)
    local found = {}
    for _, path in ipairs(detect.list_children(dir)) do
        local name = path:match("([^/\\]+)$")
        if name ~= nil and name:match(pattern) then
            table.insert(found, path)
        end
    end
    return found
end

--- Returns the LLVM roots under Visual Studio's installs: each edition's
--- VC\Tools\Llvm, with its x64 and ARM64 folders, as Visual Studio lays them out.
local function visual_studio_roots(program_files)
    local roots = {}
    local base = util.join(program_files, "Microsoft Visual Studio")
    for _, year in ipairs(detect.list_children(base)) do
        for _, edition in ipairs(detect.list_children(year)) do
            local llvm = util.join(util.join(util.join(edition, "VC"), "Tools"), "Llvm")
            table.insert(roots, util.join(llvm, "x64"))
            table.insert(roots, util.join(llvm, "ARM64"))
            table.insert(roots, llvm)
        end
    end
    return roots
end

--- Lists the places an LLVM installation can be, each with a note saying how it
--- got there. The order decides which of two installs of one version is kept.
function detect.candidate_roots()
    local roots = {}
    local function add(path, note)
        if path ~= nil and path ~= "" then
            table.insert(roots, { path = path, note = note })
        end
    end
    local function add_all(paths, note)
        for _, path in ipairs(paths) do
            add(path, note)
        end
    end

    local conda = util.env("CONDA_PREFIX", nil)
    if util.isWindows() then
        local program_files = util.env("ProgramFiles", "C:\\Program Files")
        local program_files_x86 = util.env("ProgramFiles(x86)", nil)
        local profile = util.env("USERPROFILE", util.env("HOME", ""))
        add(util.join(program_files, "LLVM"), "installed by the LLVM installer")
        if program_files_x86 ~= nil and key_of(program_files_x86) ~= key_of(program_files) then
            add(util.join(program_files_x86, "LLVM"), "installed by the LLVM installer")
        end
        add_all(visual_studio_roots(program_files), "bundled with Visual Studio")
        if profile ~= "" then
            add(util.join(util.join(util.join(profile, "scoop"), "apps"), "llvm\\current"), "installed by Scoop")
        end
        add("C:\\msys64\\clang64", "installed by MSYS2")
        add("C:\\msys64\\ucrt64", "installed by MSYS2")
    elseif RUNTIME.osType == "darwin" then
        add_all(children_matching("/opt/homebrew/opt", "^llvm"), "installed by Homebrew")
        add_all(children_matching("/usr/local/opt", "^llvm"), "installed by Homebrew")
        add_all(children_matching("/opt", "^llvm"), "installed under /opt")
        add("/usr/local", "installed under /usr/local")
    else
        add_all(children_matching("/usr/lib", "^llvm%-?%d+$"), "system LLVM")
        add_all(children_matching("/usr/lib64", "^llvm%-?%d+$"), "system LLVM")
        add_all(children_matching("/opt", "^llvm"), "installed under /opt")
        add("/usr/local", "installed under /usr/local")
        add_all(children_matching("/home/linuxbrew/.linuxbrew/opt", "^llvm"), "installed by Homebrew")
        local home = util.env("HOME", nil)
        if home ~= nil then
            add_all(children_matching(util.join(home, ".linuxbrew/opt"), "^llvm"), "installed by Homebrew")
        end
    end
    if conda ~= nil then
        add(conda, "pointed to by CONDA_PREFIX")
    end
    return roots
end

--- Compares two dotted versions number by number: negative when a is older.
local function compare_versions(a, b)
    local left = { a:match("(%d+)%.(%d+)%.(%d+)") }
    local right = { b:match("(%d+)%.(%d+)%.(%d+)") }
    for i = 1, 3 do
        local x, y = tonumber(left[i]), tonumber(right[i])
        if x ~= y then
            return x - y
        end
    end
    return 0
end

--- Finds every LLVM installation on the machine that vfox did not install. Each
--- entry names the version the way `vfox search clang` does, with the path to the
--- installation root and a note. A version found twice is listed once, from the
--- first place it was found. The result is sorted newest first.
function detect.find_all()
    local found = {}
    local seen_paths = {}
    local seen_versions = {}
    for _, root in ipairs(detect.candidate_roots()) do
        local key = key_of(root.path)
        local exe = detect.executable(root.path)
        if not seen_paths[key] and not detect.is_vfox_managed(root.path) and util.exists(exe) then
            seen_paths[key] = true
            local output = nil
            local handle = io.popen(detect.version_command(exe), "r")
            if handle ~= nil then
                output = handle:read("*a")
                handle:close()
            end
            local version = detect.version_from_output(output)
            if version ~= nil and not seen_versions[version] then
                seen_versions[version] = true
                table.insert(found, { version = version, path = root.path, note = root.note })
            end
        end
    end
    table.sort(found, function(a, b)
        if a.version ~= b.version then
            return compare_versions(a.version, b.version) > 0
        end
        return a.path < b.path
    end)
    return found
end

return detect
