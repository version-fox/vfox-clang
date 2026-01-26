local http = require("http")
local json = require("json")

function fetchVersions()
    local versionList
    local githubURL = os.getenv("GITHUB_URL") or "https://github.com/"
    local resp, err = http.get({
        url = githubURL:gsub("/$", "") .. "/version-fox/vfox-clang/releases/manifest",
    })
    if err ~= nil then
        error("Failed to request: " .. err)
    end
    if resp.status_code ~= 200 then
        error("Failed to get versions: " .. err .. "\nstatus_code => " .. resp.status_code)
    end

    versionList = resp.body:match("<code>(.-)</code>")
    versionList = json.decode(versionList)["conda-forge"]

    return versionList
end



-- available.lua
function fetchAvailable()
    local result = {}
    local ClangVersions = fetchVersions()
    for i, v in ipairs(ClangVersions) do
        if i == 1 then
            table.insert(result, {
                version = v,
                note = "latest",
            })
        else
            table.insert(result, {
                version = v,
            })
        end
    end

    return result
end

function clearCache()
    os.remove(RUNTIME.pluginDirPath .. "/available.cache")
    os.exit()
end

-- pre_install.lua
function getDownloadInfo(version)
    local file
    local ClangVersions = fetchVersions()

    if version == "latest" then
        version = ClangVersions[1]
    end
    if not hasValue(ClangVersions, version) then
        print("Unsupported version: " .. version)
        os.exit(1)
    end
    file = generatePixi(RUNTIME.osType, RUNTIME.archType)

    return file, version
end

function hasValue(table, value)
    for _, v in ipairs(table) do
        if v == value then
            return true
        end
    end

    return false
end

function generatePixi(osType, archType)
    local file
    local githubURL = os.getenv("GITHUB_URL") or "https://github.com/"
    local releaseURL = githubURL:gsub("/$", "") .. "/prefix-dev/pixi/releases/"

    if archType == "arm64" then
        archType = "aarch64"
    elseif archType == "amd64" then
        archType = "x86_64"
    else
        print("Unsupported architecture: " .. archType)
        os.exit(1)
    end
    if osType == "macos" then
        file = "pixi-" .. archType .. "-apple-darwin.tar.gz"
    elseif osType == "linux" then
        file = "pixi-" .. archType .. "-unknown-linux-musl.tar.gz"
    elseif osType == "windows" and archType == "x86_64" then
        file = "pixi-" .. archType .. "-pc-windows-msvc.zip"
    else
        print("Unsupported environment: " .. osType .. "-" .. archType)
        os.exit(1)
    end
    file = releaseURL .. "latest/download/" .. file

    return file
end

-- post_install.lua
function pixiInstall(path, version)
    local condaForge = os.getenv("Conda_Forge") or "conda-forge"
    local noStdout = RUNTIME.osType == "windows" and " > nul" or " > /dev/null"
    local pixi = RUNTIME.osType == "windows" and path .. "\\pixi.exe" or path .. "/pixi"
    local command = pixi .. " global install -qc " .. condaForge .. " clang=" .. version

    os.setenv("PIXI_HOME", path)
    local status = os.execute(command .. noStdout)
    if status ~= 0 then
        print("Failed to execute command: " .. command)
        os.exit(1)
    end
    os.remove(pixi)
end
