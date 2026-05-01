local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local nameMap = {}
local idMap = {}
local usedNames = {}
local watchedObjects = {}
local watchedRoots = {}

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
    return math.random(1000000, 9999999)
end

local function buildMapsForPlayer(player)
    if not nameMap[player.Name] then
        nameMap[player.Name] = randomPradaName()
    end
    if player.DisplayName ~= player.Name and not nameMap[player.DisplayName] then
        nameMap[player.DisplayName] = randomPradaName()
    end
    if not idMap[tostring(player.UserId)] then
        idMap[tostring(player.UserId)] = tostring(randomFakeId())
    end
end

local function buildAllMaps()
    for _, player in ipairs(Players:GetPlayers()) do
        buildMapsForPlayer(player)
    end
end

local function replaceAll(text)
    if typeof(text) ~= "string" or text == "" then return text end
    for realName, fakeName in pairs(nameMap) do
        text = text:gsub(realName, fakeName)
    end
    for realId, fakeId in pairs(idMap) do
        text = text:gsub(realId, fakeId)
    end
    return text
end

local function processObject(obj)
    if watchedObjects[obj] then return end

    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        watchedObjects[obj] = true

        local replaced = replaceAll(obj.Text)
        if replaced ~= obj.Text then
            obj.Text = replaced
        end

        obj:GetPropertyChangedSignal("Text"):Connect(function()
            local newText = replaceAll(obj.Text)
            if newText ~= obj.Text then
                obj.Text = newText
            end
        end)

    elseif obj:IsA("TextChatMessage") then
        -- Future-proof for TextChatService messages
        pcall(function()
            local replaced = replaceAll(obj.Text)
            if replaced ~= obj.Text then
                obj.Text = replaced
            end
        end)
    end
end

local function scanDescendants(root)
    pcall(function()
        for _, obj in ipairs(root:GetDescendants()) do
            pcall(processObject, obj)
        end
    end)

    pcall(function()
        root.DescendantAdded:Connect(function(obj)
            task.wait()
            pcall(processObject, obj)
        end)
    end)
end

local function scanRoot(root)
    if not root then return end
    if watchedRoots[root] then return end
    watchedRoots[root] = true

    scanDescendants(root)

    pcall(function()
        root.ChildAdded:Connect(function(child)
            task.wait()
            pcall(scanDescendants, child)
        end)
    end)
end

local function scanEverything()
    -- Core player UI
    pcall(function() scanRoot(localPlayer:WaitForChild("PlayerGui")) end)
    pcall(function() scanRoot(localPlayer:WaitForChild("PlayerBackpack")) end)
    pcall(function() scanRoot(localPlayer:WaitForChild("StarterGear")) end)

    -- Roblox system UI (chat, leaderboard, friends list, etc.)
    pcall(function() scanRoot(game:GetService("CoreGui")) end)

    -- 3D world (BillboardGuis, SurfaceGuis on parts/characters)
    pcall(function() scanRoot(game:GetService("Workspace")) end)

    -- Common storage locations games use
    pcall(function() scanRoot(game:GetService("ReplicatedStorage")) end)
    pcall(function() scanRoot(game:GetService("ReplicatedFirst")) end)

    -- Lighting (skyboxes, effects, some UI stored here)
    pcall(function() scanRoot(game:GetService("Lighting")) end)

    -- StarterGui templates before they're cloned to PlayerGui
    pcall(function() scanRoot(game:GetService("StarterGui")) end)

    -- StarterPack and StarterPlayer
    pcall(function() scanRoot(game:GetService("StarterPack")) end)
    pcall(function() scanRoot(game:GetService("StarterPlayer")) end)

    -- Teams (team names with player names)
    pcall(function() scanRoot(game:GetService("Teams")) end)

    -- TextChatService (new chat system)
    pcall(function() scanRoot(game:GetService("TextChatService")) end)

    -- SoundService (some games embed names in sound labels)
    pcall(function() scanRoot(game:GetService("SoundService")) end)

    -- CollectionService tagged objects
    pcall(function()
        local CollectionService = game:GetService("CollectionService")
        for _, obj in ipairs(CollectionService:GetTagged("GUI")) do
            pcall(scanDescendants, obj)
        end
    end)

    -- Scan every player's character in the world (nametags, overhead GUIs)
    for _, player in ipairs(Players:GetPlayers()) do
        pcall(function()
            if player.Character then
                scanRoot(player.Character)
            end
            player.CharacterAdded:Connect(function(char)
                task.wait()
                scanRoot(char)
            end)
        end)
    end
end

-- Handle players joining/leaving
Players.PlayerAdded:Connect(function(player)
    buildMapsForPlayer(player)
    pcall(function()
        player.CharacterAdded:Connect(function(char)
            task.wait()
            scanRoot(char)
        end)
    end)
    scanEverything()
end)

Players.PlayerRemoving:Connect(function(player)
    nameMap[player.Name] = nil
    nameMap[player.DisplayName] = nil
    idMap[tostring(player.UserId)] = nil
end)

-- Init
buildAllMaps()
scanEverything()
print("Stream privacy active — scanning entire game")
