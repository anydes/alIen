-- Wait for the game to be fully loaded before doing anything
if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TextChatService = game:GetService("TextChatService")

local localPlayer = Players.LocalPlayer

local stripOtherPlayers = true

local nameMap = {}
local idMap = {}
local usedNames = {}
local watchedObjects = setmetatable({}, {__mode = "k"})
local watchedRoots = setmetatable({}, {__mode = "k"})

local textClasses = {
	TextLabel = true,
	TextButton = true,
	TextBox = true
}

local suffixes = {
	"1234", "12341", "12342", "12343", "12344", "12345",
	"1234X", "1234Z", "1234A", "1234B", "1234C", "1234D",
	"1234E", "1234F", "1234G", "1234H"
}

local function random1234Name()
	for _, name in ipairs(suffixes) do
		if not usedNames[name] then
			usedNames[name] = true
			return name
		end
	end

	local name
	repeat
		name = "1234" .. math.random(100, 999)
	until not usedNames[name]

	usedNames[name] = true
	return name
end

local function randomFakeId()
	return tostring(math.random(1000000, 9999999))
end

local function addName(realName, fakeName)
	if realName and realName ~= "" and not nameMap[realName] then
		nameMap[realName] = fakeName or random1234Name()
	end
end

local function buildMapsForPlayer(player)
	if player == localPlayer then
		addName(player.Name, "1234")
		usedNames["1234"] = true
	else
		addName(player.Name)
	end

	if player.DisplayName ~= player.Name then
		addName(player.DisplayName)
	end

	local uid = tostring(player.UserId)
	if not idMap[uid] then
		idMap[uid] = randomFakeId()
	end
end

local function replaceAll(text)
	if typeof(text) ~= "string" or text == "" then
		return text
	end

	local newText = text

	for realName, fakeName in pairs(nameMap) do
		newText = newText:gsub(realName:gsub("([^%w])", "%%%1"), fakeName)
	end

	for realId, fakeId in pairs(idMap) do
		newText = newText:gsub(realId, fakeId)
	end

	return newText
end

local function processTextObject(obj)
	if watchedObjects[obj] then
		return
	end

	if not textClasses[obj.ClassName] then
		return
	end

	watchedObjects[obj] = true

	local busy = false

	local function update()
		if busy then return end
		busy = true

		local oldText = obj.Text
		local newText = replaceAll(oldText)

		if newText ~= oldText then
			obj.Text = newText
		end

		busy = false
	end

	update()

	obj:GetPropertyChangedSignal("Text"):Connect(update)
end

local function scanRoot(root)
	if not root or watchedRoots[root] then
		return
	end

	watchedRoots[root] = true

	for _, obj in ipairs(root:GetDescendants()) do
		processTextObject(obj)
	end

	root.DescendantAdded:Connect(function(obj)
		task.defer(function()
			processTextObject(obj)
		end)
	end)
end

local function stripCharacter(char)
	if not char then return end
	
	local function checkAndRemove(obj)
		if obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("Accessory") or obj:IsA("ShirtGraphic") or obj:IsA("CharacterMesh") then
			task.defer(function()
				pcall(function() obj:Destroy() end)
			end)
		end
	end

	for _, obj in ipairs(char:GetDescendants()) do
		checkAndRemove(obj)
	end
	
	char.DescendantAdded:Connect(checkAndRemove)
	
	local function updateColor()
		local bodyColors = char:FindFirstChildOfClass("BodyColors")
		if bodyColors then
			bodyColors.HeadColor = BrickColor.new("Medium stone grey")
			bodyColors.LeftArmColor = BrickColor.new("Medium stone grey")
			bodyColors.RightArmColor = BrickColor.new("Medium stone grey")
			bodyColors.LeftLegColor = BrickColor.new("Medium stone grey")
			bodyColors.RightLegColor = BrickColor.new("Medium stone grey")
			bodyColors.TorsoColor = BrickColor.new("Medium stone grey")
		else
			for _, part in ipairs(char:GetChildren()) do
				if part:IsA("BasePart") then
					part.BrickColor = BrickColor.new("Medium stone grey")
				end
			end
		end
	end
	
	updateColor()
	
	char.ChildAdded:Connect(function(obj)
		if obj:IsA("BodyColors") then
			updateColor()
		elseif obj:IsA("BasePart") then
			obj.BrickColor = BrickColor.new("Medium stone grey")
		end
	end)
end

local function scanPlayer(player)
	buildMapsForPlayer(player)

	if player.Character then
		scanRoot(player.Character)
		if stripOtherPlayers and player ~= localPlayer then
			stripCharacter(player.Character)
		end
	end

	player.CharacterAdded:Connect(function(char)
		task.wait(0.25)
		scanRoot(char)
		if stripOtherPlayers and player ~= localPlayer then
			stripCharacter(char)
		end
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	scanPlayer(player)
end

Players.PlayerAdded:Connect(scanPlayer)

local playerGui = localPlayer:WaitForChild("PlayerGui", 10)
if playerGui then
	scanRoot(playerGui)
end

pcall(function()
	scanRoot(CoreGui)
end)

pcall(function()
	scanRoot(TextChatService)
end)

print("Stream privacy active:", localPlayer.Name, "->", nameMap[localPlayer.Name])
