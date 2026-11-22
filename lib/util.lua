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

--- Helpers shared by the hooks and the library modules. Platform checks read
--- vfox's RUNTIME, which the offline tests set through vfox.test.load.
local util = {}

--- Removes the blanks at both ends of a string.
local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

util.trim = trim

--- Returns the operating system vfox reports: linux, darwin or windows.
function util.osType()
    return RUNTIME.osType
end

--- Reports whether the plugin runs on Windows.
function util.isWindows()
    return RUNTIME.osType == "windows"
end

--- Returns an environment variable with its blanks removed, or fallback when
--- the variable is unset or blank.
function util.env(name, fallback)
    local value = os.getenv(name)
    if value == nil then
        return fallback
    end
    value = trim(value)
    if value == "" then
        return fallback
    end
    return value
end

--- Returns the GitHub base URL without trailing slashes. GITHUB_URL selects a
--- mirror; without it the URL is https://github.com.
function util.githubURL()
    return (util.env("GITHUB_URL", "https://github.com"):gsub("/+$", ""))
end

--- Reports whether value is an element of list.
function util.contains(list, value)
    for _, item in ipairs(list or {}) do
        if item == value then
            return true
        end
    end
    return false
end

--- Returns the directory separator of the platform.
function util.separator()
    if util.isWindows() then
        return "\\"
    end
    return "/"
end

--- Joins two path segments with the platform's separator, once.
function util.join(left, right)
    local last = left:sub(-1)
    if last == "/" or last == "\\" then
        return left .. right
    end
    return left .. util.separator() .. right
end

--- Quotes one argument for the shell that os.execute and io.popen run:
--- single quotes on Unix (sh -c), double quotes on Windows (cmd.exe).
--- Windows refuses a double quote in the value, which cmd.exe cannot quote.
function util.quote(value)
    if util.isWindows() then
        if value:find('"', 1, true) then
            error("Cannot quote a double quote for cmd.exe: " .. value)
        end
        return '"' .. value .. '"'
    end
    local escaped = value:gsub("'", "'\\''")
    return "'" .. escaped .. "'"
end

--- Reports whether a file can be opened for reading.
function util.exists(path)
    local file = io.open(path, "rb")
    if file == nil then
        return false
    end
    file:close()
    return true
end

return util
