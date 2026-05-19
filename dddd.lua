getgenv().BallMagnet = true
getgenv().BallHitboxSize = Vector3.new(17, 17, 17)
getgenv().BallTransparency = 1
getgenv().BallNoCollide = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local fakeBalls = {}
local originalSizes = {}
local trackedBalls = {} -- track all balls we've ever seen

local function isBallUnderCharacter(ball)
    for _, player in pairs(Players:GetPlayers()) do
        local char = player.Character
        if char and ball:IsDescendantOf(char) then
            print("[BallMagnet] Ball is under character:", player.Name)
            return true
        end
    end
    return false
end

local function createFakeBall(ball)
    if fakeBalls[ball] then return end

    local fake = ball:Clone()
    fake.Name = "FakeBall_Visual"
    fake.Transparency = 0
    fake.CanCollide = false
    fake.Anchored = false
    fake.CastShadow = ball.CastShadow
    fake.Size = originalSizes[ball]
    fake.CFrame = ball.CFrame

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = ball
    weld.Part1 = fake
    weld.Parent = fake

    fake.Parent = workspace
    fakeBalls[ball] = fake

    print("[BallMagnet] Created fake ball for:", ball.Name)

    ball.AncestryChanged:Connect(function()
        if not ball:IsDescendantOf(game) then
            if fakeBalls[ball] then
                fakeBalls[ball]:Destroy()
                fakeBalls[ball] = nil
            end
            originalSizes[ball] = nil
            trackedBalls[ball] = nil
            print("[BallMagnet] Ball removed from game, cleaned up")
        end
    end)
end

local function updateFakeBall(ball)
    local fake = fakeBalls[ball]
    if not fake then return end
    local origSize = originalSizes[ball]
    if origSize and fake.Size ~= origSize then
        fake.Size = origSize
    end
    if fake.Transparency ~= 0 then
        fake.Transparency = 0
    end
end

local function updateBall(ball)
    if not originalSizes[ball] then
        originalSizes[ball] = ball.Size
        print("[BallMagnet] Stored original size for:", ball.Name, "->", tostring(ball.Size))
    end

    if isBallUnderCharacter(ball) then
        local origSize = originalSizes[ball]
        if ball.Size ~= origSize then
            ball.Size = origSize
            print("[BallMagnet] Ball under character, restored size to:", tostring(origSize))
        end
        if ball.Transparency ~= 0 then
            ball.Transparency = 0
        end
        if not ball.CanCollide then
            ball.CanCollide = true
        end
        if fakeBalls[ball] then
            fakeBalls[ball]:Destroy()
            fakeBalls[ball] = nil
            print("[BallMagnet] Destroyed fake ball, ball is under a character")
        end
        return
    end

    createFakeBall(ball)
    updateFakeBall(ball)

    local size = getgenv().BallHitboxSize
    local transparency = getgenv().BallTransparency
    local nocollide = getgenv().BallNoCollide

    if ball.Size ~= size then
        ball.Size = size
        print("[BallMagnet] Updated hitbox of:", ball.Name, "to", tostring(size))
    end

    if ball.Transparency ~= transparency then
        ball.Transparency = transparency
        print("[BallMagnet] Updated transparency of:", ball.Name, "to", transparency)
    end

    local shouldCanCollide = not nocollide
    if ball.CanCollide ~= shouldCanCollide then
        ball.CanCollide = shouldCanCollide
        print("[BallMagnet] Updated CanCollide of:", ball.Name, "to", tostring(shouldCanCollide))
    end
end

local function onDescendantAdded(obj)
    if not getgenv().BallMagnet then return end
    if obj.Name == "Ball" and obj:IsA("MeshPart") then
        print("[BallMagnet] DescendantAdded: Detected Ball MeshPart ->", obj:GetFullName())
        trackedBalls[obj] = true
        updateBall(obj)
    end
end

local function scanAllBalls()
    -- scan workspace descendants to catch balls under characters too
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name == "Ball" and obj:IsA("MeshPart") and obj.Name ~= "FakeBall_Visual" then
            trackedBalls[obj] = true
            updateBall(obj)
        end
    end
    -- also update any tracked balls (in case they moved somewhere)
    for ball in pairs(trackedBalls) do
        updateBall(ball)
    end
end

print("[BallMagnet] Script loaded. BallMagnet =", getgenv().BallMagnet)

workspace.DescendantAdded:Connect(function(obj)
    if obj.Name == "FakeBall_Visual" then return end
    print("[BallMagnet] DescendantAdded fired:", obj.Name, "|", obj.ClassName)
    onDescendantAdded(obj)
end)

print("[BallMagnet] DescendantAdded listener connected")

RunService.Heartbeat:Connect(function()
    if not getgenv().BallMagnet then return end
    scanAllBalls()
end)

print("[BallMagnet] Heartbeat loop started")
