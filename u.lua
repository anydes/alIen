local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local nameMap = {}
local idMap = {}
local usedNames = {}
local watchedObjects = {}

local function randomPradaName()
    local suffixes = {
        "Prada", "Prada1", "Prada2", "Prada3", "Prada4", "Prada5",
        "PradaX", "PradaZ", "PradaA", "PradaB", "PradaC", "PradaD",
        "PradaE", "PradaF", "PradaG", "PradaH"
    }
    for _, name in ipairs(suffixes) do
        if not usedNames[name] then
            usedNames[name] = true
            return name
        end
    end
    return "Prada" .. math.random(100, 999)
end

local function randomFakeId()
    return tostring(math.random(1000000, 9999999))
end

local function buildMapsForPlayer(player)
    if not nameMap[player.Name] then
        nameMap[player.Name] = randomPradaName()
    end
    if player.DisplayName ~= player.Name and not nameMap[player.DisplayName] then
        nameMap[player.DisplayName] = randomPradaName()
    end
    local uid = tostring(player.UserId)
    if not idMap[uid] then
        idMap[uid] = randomFakeId()
    end
end

-- Explicitly map local player first before anything else
local function buildLocalPlayerMap()
    -- Name
    if not nameMap[localPlayer.Name] then
        nameMap[localPlayer.Name] = "Prada"
        usedNames["Prada"] = true
    end
    -- Display name
    if localPlayer.DisplayName ~= localPlayer.Name then
        if not nameMap[localPlayer.DisplayName] then
            nameMap[localPlayer.DisplayName] = randomPradaName()
        end
    end
    -- User ID
    local uid = tostring(localPlayer.UserId)
    if not idMap[uid] then
        idMap[uid] = randomFakeId()
    end
end

local function buildAllMaps()
    buildLocalPlayerMap()
    for _, player in ipairs(Players:GetPlayers()) do
        buildMapsForPlayer(player)
    end
end

local function replaceAll(text)
    if typeof(text) ~= "string" or text == "" then return text end

    for realName, fakeName in pairs(nameMap) do
        local escaped = realName:gsub("([^%w])", "%%%1")
        text = text:gsub(escaped, fakeName)
    end

    for realId, fakeId in pairs(idMap) do
        text = text:gsub(realId, fakeId)
    end

    return text
end

local function processObject(obj)
    pcall(function()
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            -- Always re-process even if watched, in case map grew
            local replaced = replaceAll(obj.Text)
            if replaced ~= obj.Text then
                obj.Text = replaced
            end

            if not watchedObjects[obj] then
                watchedObjects[obj] = true
                obj:GetPropertyChangedSignal("Text"):Connect(function()
                    local newText = replaceAll(obj.Text)
                    if newText ~= obj.Text then
                        obj.Text = newText
                    end
                end)
            end
        end
    end)
end

-- GetDescendants on absolutely everything
local function scanRoot(root)
    if not root then return end
    pcall(function()
        -- Process root itself
        processObject(root)

        -- GetDescendants covers every single child, grandchild, etc.
        for _, obj in ipairs(root:GetDescendants()) do
            processObject(obj)
        end

        -- Watch for anything added in future
        root.DescendantAdded:Connect(function(obj)
            task.wait()
            buildAllMaps() -- ensure maps are fresh
            processObject(obj)
        end)
    end)
end

local function scanEverything()
    -- Entire DataModel top-level catch-all
    pcall(scanRoot, game)

    -- Every service explicitly with GetDescendants
    local services = {
        "CoreGui", "Workspace", "ReplicatedStorage", "ReplicatedFirst",
        "Lighting", "StarterGui", "StarterPack", "StarterPlayer",
        "Teams", "TextChatService", "SoundService", "Chat",
        "LocalizationService", "Players"
    }
    for _, serviceName in ipairs(services) do
        pcall(function()
            scanRoot(game:GetService(serviceName))
        end)
    end

    -- PlayerGui and Backpack explicitly
    pcall(function() scanRoot(localPlayer:WaitForChild("PlayerGui", 5)) end)
    pcall(function() scanRoot(localPlayer:WaitForChild("PlayerBackpack", 5)) end)

    -- Every player's character
    for _, player in ipairs(Players:GetPlayers()) do
        pcall(function()
            if player.Character then
                scanRoot(player.Character)
            end
            player.CharacterAdded:Connect(function(char)
                task.wait(0.5)
                scanRoot(char)
            end)
        end)
    end
end

-- Rescan all already-found objects with latest maps
local function rescanAllWatched()
    for obj in pairs(watchedObjects) do
        pcall(function()
            if obj and obj.Parent then
                local newText = replaceAll(obj.Text)
                if newText ~= obj.Text then
                    obj.Text = newText
                end
            else
                watchedObjects[obj] = nil
            end
        end)
    end
end

-- Continuous loop every 1 second
task.spawn(function()
    while true do
        task.wait(1)
        buildAllMaps()
        scanEverything()
        rescanAllWatched()
    end
end)

Players.PlayerAdded:Connect(function(player)
    task.wait(0.5)
    buildMapsForPlayer(player)
    scanEverything()
    player.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        scanRoot(char)
    end)
end)

Players.PlayerRemoving:Connect(function()
    watchedObjects = {}
end)

-- Init: build local player map FIRST before anything is scanned
buildLocalPlayerMap()
buildAllMaps()
scanEverything()

print("Stream privacy active — local player: " .. localPlayer.Name .. " -> " .. nameMap[localPlayer.Name])
