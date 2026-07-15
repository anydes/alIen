local Library = loadstring(game:HttpGetAsync("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()
local SaveManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau"))()
local InterfaceManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau"))()

do
-- Shared service cache for the whole script (reduces duplicates + overhead).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local ViewportSize = Camera.ViewportSize

local IsMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled


local winSize = IsMobile and UDim2.fromOffset(430, 320) or UDim2.fromOffset(550, 400)

local Window = Library:CreateWindow{
    Title = "Playground Basketball",
    SubTitle = "    Vanta | Beta 1.0",
    TabWidth = 160,
    Size = winSize,
    Resize = not IsMobile,
    MinSize = Vector2.new(470, 380),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl,
}

local Tabs = {
    Shooting = Window:CreateTab{ Title = "Shooting", Icon = "phosphor-target-bold" },
    Player = Window:CreateTab{ Title = "Player", Icon = "phosphor-person-simple-walk-bold" },
    Dribble = Window:CreateTab{ Title = "Dribble", Icon = "phosphor-basketball-bold" },
    Defense = Window:CreateTab{ Title = "Defense", Icon = "phosphor-shield-bold" },
    Avatar = Window:CreateTab{ Title = "Avatar", Icon = "phosphor-user-bold" },
    Settings = Window:CreateTab{ Title = "Settings", Icon = "settings" },
}

local Options = Library.Options

SaveManager:SetLibrary(Library)
InterfaceManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("pbvanta")
SaveManager:SetFolder("pbvanta/config")

    do -- Shooting
            do
                -- ============================================
                -- AUTOTIME SECTION (Side 1)
                -- ============================================
            Tabs.Shooting:AddSection("Timer")

                do
                    local player = Players.LocalPlayer
                    local charName = player.Name
                    
                    -- Initialize global state (persists across toggle)
                    getgenv().AutoTimeState = getgenv().AutoTimeState or {
                        DelayValue = 0.34,
                        -- AI Learning data
                        timingHistory = {},
                        maxHistory = 20,
                        perfectStreak = 0,
                        totalShots = 0,
                        perfectShots = 0,
                        lastAdjustment = 0,
                        -- Timing adjustment weights
                        adjustments = {
                            ["Perfect"] = 0,
                            ["Good"] = 0,
                            ["Slightly Early"] = 0.015,
                            ["Slightly Late"] = -0.015,
                            ["Early"] = 0.035,
                            ["Late"] = -0.035,
                        },
                        -- Tracking data
                        pingHistory = {},
                        maxPingHistory = 15,
                        frameTimeHistory = {},
                        maxFrameHistory = 30,
                    }
                    
                    local state = getgenv().AutoTimeState

                    Tabs.Shooting:CreateToggle("AutoTimeToggle", {
                        Title = "AutoTime",
                        Default = false,
                        Callback = function(Value)
                            if Value then
                                -- ============================================
                                -- UTILITY FUNCTIONS (scoped to toggle)
                                -- ============================================
                                
                                local function getCurrentPing()
                                    local success, ping = pcall(function()
                                        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
                                    end)
                                    return success and ping or 0.05
                                end
                                
                                local function getSmoothedPing()
                                    local ping = getCurrentPing()
                                    table.insert(state.pingHistory, ping)
                                    if #state.pingHistory > state.maxPingHistory then
                                        table.remove(state.pingHistory, 1)
                                    end
                                    
                                    -- Use median for stability
                                    local sorted = {}
                                    for _, p in ipairs(state.pingHistory) do
                                        table.insert(sorted, p)
                                    end
                                    table.sort(sorted)
                                    
                                    local mid = math.floor(#sorted / 2)
                                    if #sorted % 2 == 0 and mid > 0 then
                                        return (sorted[mid] + sorted[mid + 1]) / 2
                                    else
                                        return sorted[mid + 1] or ping
                                    end
                                end
                                
                                local function getAverageFrameTime()
                                    if #state.frameTimeHistory == 0 then return 1/60 end
                                    local sum = 0
                                    for _, ft in ipairs(state.frameTimeHistory) do
                                        sum = sum + ft
                                    end
                                    return sum / #state.frameTimeHistory
                                end
                                
                                local function trackFrameTime(dt)
                                    table.insert(state.frameTimeHistory, dt)
                                    if #state.frameTimeHistory > state.maxFrameHistory then
                                        table.remove(state.frameTimeHistory, 1)
                                    end
                                end
                                
                                local function clampTiming(value)
                                    return math.clamp(value, 0.12, 0.65)
                                end
                                
                                -- ============================================
                                -- AI LEARNING SYSTEM
                                -- ============================================
                                
                                local function processTimingFeedback(timing)
                                    if not timing or timing == "" then return end
                                    
                                    state.totalShots = state.totalShots + 1
                                    local baseAdjustment = state.adjustments[timing] or 0
                                    
                                    if timing == "Perfect" or timing == "Good" then
                                        state.perfectShots = state.perfectShots + 1
                                        state.perfectStreak = state.perfectStreak + 1
                                        
                                        -- Stable after 3 perfects
                                        if state.perfectStreak >= 3 then
                                            return
                                        end
                                    else
                                        state.perfectStreak = 0
                                    end
                                    
                                    if baseAdjustment ~= 0 then
                                        local learningRate = 1.0
                                        
                                        -- Conservative if recently perfect
                                        if state.perfectStreak > 0 then
                                            learningRate = 0.5
                                        end
                                        
                                        -- Detect oscillation
                                        if #state.timingHistory >= 2 then
                                            local last = state.timingHistory[#state.timingHistory]
                                            local prev = state.timingHistory[#state.timingHistory - 1]
                                            
                                            local lastIsEarly = string.find(last, "Early") ~= nil
                                            local prevIsEarly = string.find(prev, "Early") ~= nil
                                            local currIsEarly = string.find(timing, "Early") ~= nil
                                            
                                            if (currIsEarly ~= lastIsEarly) and (lastIsEarly ~= prevIsEarly) then
                                                learningRate = learningRate * 0.4
                                            end
                                        end
                                        
                                        local adjustment = baseAdjustment * learningRate
                                        
                                        -- Smooth with previous
                                        if state.lastAdjustment ~= 0 then
                                            if (adjustment > 0) == (state.lastAdjustment > 0) then
                                                adjustment = adjustment * 1.1
                                            else
                                                adjustment = adjustment * 0.7
                                            end
                                        end
                                        
                                        state.DelayValue = clampTiming(state.DelayValue + adjustment)
                                        state.lastAdjustment = adjustment
                                        
                                        -- Update slider in real-time using the correct method
                                        task.spawn(function()
                                            pcall(function()
                                                if Options.OffsetSlider then
                                                    Options.OffsetSlider:SetValue(state.DelayValue)
                                                end
                                            end)
                                        end)
                                    end
                                    
                                    table.insert(state.timingHistory, timing)
                                    if #state.timingHistory > state.maxHistory then
                                        table.remove(state.timingHistory, 1)
                                    end
                                end
                                
                                -- ============================================
                                -- MAIN SYSTEM SETUP
                                -- ============================================
                                
                                local obj = workspace:WaitForChild(charName, 5)
                                if not obj then return end
                                
                                local remote = ReplicatedStorage
                                    :WaitForChild("Remotes")
                                    :WaitForChild("Server")
                                    :WaitForChild("Action")
                                
                                local shootArgs = {{Shoot = false, Type = "Shoot"}}
                                local jumpArgs = {{Action = "Jump", Jump = false}}
                                
                                -- Session state
                                local isProcessing = false
                                local actionStartTime = nil
                                local firedThisAction = false
                                local wasShooting = false
                                local connections = {}
                                
                                -- Reset stats on enable
                                state.totalShots = 0
                                state.perfectShots = 0
                                state.perfectStreak = 0
                                state.timingHistory = {}
                                state.lastAdjustment = 0
                                
                                -- Frame time tracking (sample every 3 frames to cut table churn / CPU)
                                local ftAccum, ftCount = 0, 0
                                connections[#connections + 1] = RunService.Heartbeat:Connect(function(dt)
                                    ftAccum += dt
                                    ftCount += 1
                                    if ftCount >= 3 then
                                        trackFrameTime(ftAccum / ftCount)
                                        ftAccum, ftCount = 0, 0
                                    end
                                end)
                                
                                -- Main action listener (shooting + AI feedback combined)
                                connections[#connections + 1] = obj:GetAttributeChangedSignal("Action"):Connect(function()
                                    local action = obj:GetAttribute("Action")
                                    
                                    -- AI Feedback tracking
                                    if action == "Shooting" or action == "Dunking" then
                                        wasShooting = true
                                    elseif wasShooting then
                                        wasShooting = false
                                        task.defer(function()
                                            local timing = obj:GetAttribute("Timing")
                                            if timing then
                                                processTimingFeedback(timing)
                                            end
                                        end)
                                    end
                                    
                                    -- AutoTime execution
                                    if (action == "Shooting" or action == "Dunking") and not isProcessing then
                                        isProcessing = true
                                        firedThisAction = false
                                        actionStartTime = os.clock()
                                        
                                        local baseTiming = state.DelayValue
                                        local ping = getSmoothedPing()
                                        local avgFrameTime = getAverageFrameTime()
                                        
                                        -- Ping compensation
                                        local pingComp = math.min(ping * 0.3, 0.04)
                                        
                                        -- FPS compensation
                                        local targetFrameTime = 1/60
                                        local fpsComp = 0
                                        if avgFrameTime > targetFrameTime * 1.5 then
                                            fpsComp = (avgFrameTime - targetFrameTime) * 0.5
                                        end
                                        
                                        local finalTiming = clampTiming(baseTiming - pingComp - fpsComp)
                                        local startTime = actionStartTime
                                        
                                        -- Primary timing execution
                                        task.spawn(function()
                                            -- Coarse wait
                                            local coarseWait = finalTiming * 0.85
                                            if coarseWait > 0.01 then
                                                task.wait(coarseWait)
                                            end
                                            
                                            if not isProcessing or actionStartTime ~= startTime or firedThisAction then return end
                                            
                                            -- Fine-grained timing
                                            local elapsed = os.clock() - startTime
                                            while elapsed < finalTiming and isProcessing and not firedThisAction do
                                                RunService.Heartbeat:Wait()
                                                elapsed = os.clock() - startTime
                                            end
                                            
                                            if isProcessing and not firedThisAction then
                                                local currentAction = obj:GetAttribute("Action")
                                                if currentAction == "Shooting" or currentAction == "Dunking" then
                                                    firedThisAction = true
                                                    pcall(function() remote:FireServer(unpack(shootArgs)) end)
                                                    task.wait(0.008)
                                                    pcall(function() remote:FireServer(unpack(jumpArgs)) end)
                                                end
                                            end
                                        end)
                                        
                                        -- Backup timing (slightly later)
                                        task.delay(finalTiming * 1.08, function()
                                            if isProcessing and not firedThisAction and actionStartTime == startTime then
                                                local currentAction = obj:GetAttribute("Action")
                                                if currentAction == "Shooting" or currentAction == "Dunking" then
                                                    firedThisAction = true
                                                    pcall(function() remote:FireServer(unpack(shootArgs)) end)
                                                    task.wait(0.008)
                                                    pcall(function() remote:FireServer(unpack(jumpArgs)) end)
                                                end
                                            end
                                        end)
                                        
                                        -- Reset
                                        task.delay(finalTiming + 0.2, function()
                                            if actionStartTime == startTime then
                                                isProcessing = false
                                                firedThisAction = false
                                            end
                                        end)
                                        
                                    elseif action ~= "Shooting" and action ~= "Dunking" then
                                        isProcessing = false
                                    end
                                end)
                                
                                -- Handle respawns
                                connections[#connections + 1] = player.CharacterAdded:Connect(function(newChar)
                                    task.wait(0.5)
                                    obj = workspace:WaitForChild(charName, 5)
                                    if obj then
                                        wasShooting = false
                                        isProcessing = false
                                        firedThisAction = false
                                    end
                                end)
                                
                                -- Store connections
                                getgenv().AutoTimeConnections = connections
                                
                            else
                                -- Cleanup connections
                                if getgenv().AutoTimeConnections then
                                    for _, conn in ipairs(getgenv().AutoTimeConnections) do
                                        if conn then conn:Disconnect() end
                                    end
                                    getgenv().AutoTimeConnections = nil
                                end
                            end
                        end
                    })

                    Tabs.Shooting:CreateSlider("OffsetSlider", {
                        Title = "Offset",
                        Default = state.DelayValue,
                        Max = 0.5,
                        Min = 0.05,
                        Rounding = 3,
                        Callback = function(Value)
                            state.DelayValue = Value
                        end
                    })
                end

                -- ============================================
                -- AUTO CRAB SECTION
                -- ============================================
            Tabs.Shooting:AddSection("Auto Crab")

                do
                    local AC_LERP_SPEED      = 0.032
                    local AC_USE_DELTA_ALPHA = false
                    local AC_PREDICTION_TIME = 0.4
                    local AC_OFFSET          = 10
                    local AC_MAX_DIST        = 10
                    local AC_MAX_PRED_OFFSET = 6
                    local AC_PLAYER_CACHE    = 0.15
                    local AC_RIM_CACHE       = 5

                    local acAllowed = false
                    local acActive  = false

                    -- Tracked keybind (updated when user rebinds in UI)
                    local acToggleKey    = Enum.KeyCode.Q
                    local acToggleButton = Enum.KeyCode.ButtonL1

                    local acLastTargetPos   = nil
                    local acLastPosTime     = 0
                    local acCachedPlayer    = nil
                    local acPlayerCacheTime = 0
                    local acCachedRim       = nil
                    local acRimCacheTime    = 0
                    local acBusyStartTime   = 0

                    local acLp    = Players.LocalPlayer
                    local acChar  = acLp.Character or acLp.CharacterAdded:Wait()
                    local acHRP   = acChar:WaitForChild("HumanoidRootPart")
                    local acHuman = acChar:WaitForChild("Humanoid")

                    acLp.CharacterAdded:Connect(function(c)
                        acChar = c
                        acHRP   = acChar:WaitForChild("HumanoidRootPart")
                        acHuman = acChar:WaitForChild("Humanoid")
                        acLastTargetPos   = nil; acLastPosTime     = 0
                        acCachedPlayer    = nil; acPlayerCacheTime = 0
                        acCachedRim       = nil; acRimCacheTime    = 0
                        acBusyStartTime   = 0
                    end)

                    local function acHasBall()
                        if not acChar then return false end
                        return acChar:FindFirstChild("Ball") ~= nil
                    end

                    local function acIsBusy()
                        if not acChar then return false end
                        local act = acChar:GetAttribute("Action")
                        if act ~= nil and tostring(act) ~= "" then
                            if acBusyStartTime == 0 then
                                acBusyStartTime = tick()
                            elseif tick() - acBusyStartTime >= 0.25 then
                                return true
                            end
                        else
                            acBusyStartTime = 0
                        end
                        return false
                    end

                    local function acGetClosest()
                        if not acHRP or not acHRP.Parent then return nil end
                        if acCachedPlayer
                            and acCachedPlayer.Character
                            and acCachedPlayer.Character:FindFirstChild("HumanoidRootPart")
                            and (tick() - acPlayerCacheTime) < AC_PLAYER_CACHE then
                            return acCachedPlayer
                        end
                        local closest, shortest = nil, math.huge
                        local myPos = acHRP.Position
                        for _, p in ipairs(Players:GetPlayers()) do
                            if p ~= acLp then
                                local pCh = p.Character
                                if pCh then
                                    local pHRP = pCh:FindFirstChild("HumanoidRootPart")
                                    local pH   = pCh:FindFirstChildOfClass("Humanoid")
                                    if pHRP and pH and pH.Health > 0 then
                                        local d = (myPos - pHRP.Position).Magnitude
                                        if d < shortest then shortest = d; closest = p end
                                    end
                                end
                            end
                        end
                        acCachedPlayer    = closest
                        acPlayerCacheTime = tick()
                        return closest
                    end

                    local function acFindRim()
                        if not acHRP or not acHRP.Parent then return nil end
                        if acCachedRim and acCachedRim.Parent and (tick() - acRimCacheTime) < AC_RIM_CACHE then
                            return acCachedRim
                        end
                        local map = workspace:FindFirstChild("Map")
                        if not map then return nil end
                        local courts = map:FindFirstChild("Courts")
                        if not courts then return nil end
                        local closestRim, shortest = nil, math.huge
                        local myPos = acHRP.Position
                        for _, d in ipairs(courts:GetDescendants()) do
                            if d:IsA("MeshPart") and d.Name == "Backboard" and d.Parent and d.Parent:IsA("Model") then
                                local dist = (myPos - d.Position).Magnitude
                                if dist < shortest then shortest = dist; closestRim = d end
                            end
                        end
                        if closestRim then acCachedRim = closestRim; acRimCacheTime = tick() end
                        return closestRim
                    end

                    -- Single permanent connection, gated by both allowed state and active state
                    RunService.RenderStepped:Connect(function(dt)
                        if not (acAllowed and acActive) then return end
                        if not acChar or not acChar.Parent then return end
                        if not acHRP  or not acHRP.Parent  then return end
                        if not acHuman or acHuman.Health <= 0 then return end
                        if acIsBusy()      then return end
                        if not acHasBall() then return end

                        local closest = acGetClosest()
                        if not closest or not closest.Character then return end
                        local tHRP = closest.Character:FindFirstChild("HumanoidRootPart")
                        if not tHRP then return end

                        local distToTarget = (acHRP.Position - tHRP.Position).Magnitude
                        if distToTarget > AC_MAX_DIST then
                            acLastTargetPos = nil; acLastPosTime = 0; return
                        end

                        local rim = acFindRim()
                        if not rim then return end

                        local predictedPos = tHRP.Position
                        if acLastTargetPos and acLastPosTime > 0 then
                            local timeDelta = tick() - acLastPosTime
                            if timeDelta > 0 and timeDelta < 0.2 then
                                local vel    = (tHRP.Position - acLastTargetPos) / timeDelta
                                local offset = vel * AC_PREDICTION_TIME
                                if offset.Magnitude > AC_MAX_PRED_OFFSET then
                                    offset = offset.Unit * AC_MAX_PRED_OFFSET
                                end
                                predictedPos = tHRP.Position + offset
                            end
                        end
                        acLastTargetPos = tHRP.Position
                        acLastPosTime   = tick()

                        local dirVec = rim.Position - predictedPos
                        if dirVec.Magnitude <= 0 then return end
                        local dir       = dirVec.Unit
                        local targetPos = predictedPos + (dir * AC_OFFSET)
                        local goal      = CFrame.new(targetPos, tHRP.Position)

                        if AC_USE_DELTA_ALPHA then
                            local alpha = 1 - math.exp(-AC_LERP_SPEED * 60 * dt)
                            acHRP.CFrame = acHRP.CFrame:Lerp(goal, alpha)
                        else
                            acHRP.CFrame = acHRP.CFrame:Lerp(goal, AC_LERP_SPEED)
                        end
                    end)

                    -- Keybind toggle (Q / ButtonL1) — same as original script
                    local acUIS = game:GetService("UserInputService")
                    acUIS.InputBegan:Connect(function(input, gameProcessed)
                        if gameProcessed then return end
                        
                        -- Only allow keybind to work if the feature is enabled in the UI
                        if not acAllowed then return end
                        
                        if input.KeyCode == acToggleKey or input.KeyCode == acToggleButton then
                            acActive = not acActive
                            
                            -- Optional notification to match original script behavior
                            if acActive then
                            else
                            end
                        end
                    end)

                    -- UI elements
                    Tabs.Shooting:CreateToggle("Shooting_AutoCrab", {
                        Title = "Enable Auto Crab",
                        Default = false,
                        Callback = function(Value)
                            acAllowed = Value
                            -- If turned off from UI, disable the active state as well
                            if not Value then
                                acActive = false
                            end
                        end,
                    })

                    Tabs.Shooting:CreateToggle("AutoCrab_DeltaAlpha", {
                        Title = "Legit mode (helps fps aswell)",
                        Default = AC_USE_DELTA_ALPHA,
                        Callback = function(Value)
                            AC_USE_DELTA_ALPHA = Value
                        end,
                    })

                    Tabs.Shooting:CreateSlider("AutoCrab_LerpSpeed", {
                        Title = "Lerp Speed",
                        Min     = 0.02,
                        Max     = 0.03,
                        Default = AC_LERP_SPEED,
                        Rounding = 3,
                        Callback = function(Value)
                            AC_LERP_SPEED = Value
                        end,
                    })

                    Tabs.Shooting:CreateSlider("AutoCrab_PredictionTime", {
                        Title = "Prediction Time",
                        Min     = 0.3,
                        Max     = 1.0,
                        Default = AC_PREDICTION_TIME,
                        Rounding = 1,
                        Callback = function(Value)
                            AC_PREDICTION_TIME = Value
                        end,
                    })

                    -- Keybind element (UI display + rebinding; updates acToggleKey on change)
                    Tabs.Shooting:CreateKeybind("AutoCrab_Keybind", {
                        Title = "Toggle Keybind",
                        Mode = "Always",
                        Default = "Q",
                        Callback = function()
                            -- actual toggle is handled by InputBegan above
                        end,
                        ChangedCallback = function(New)
                            -- keep the InputBegan listener in sync when user rebinds
                            if typeof(New) == "EnumItem" and New.EnumType == Enum.KeyCode then
                                acToggleKey = New
                            end
                        end,
                    })

                    Tabs.Shooting:CreateParagraph("AutoCrab_Note", {
                        Title = "Controller",
                        Content = "Press L1 on controller to toggle Auto Crab on/off.",
                    })
                end


                do -- Experimental / anti contest
            Tabs.Shooting:AddSection("Experimental")

    -- -- Anti Contest Setup ----------------------------------------------------

    local Players    = game:GetService("Players")
    local RunService = game:GetService("RunService")

    local RECOIL_MODE        = "Tween"
    local RECOIL_DISTANCE    = 3
    local TWEEN_TIME         = 0.2
    local GUARDER_CHECK_RATE = 10

    local lp       = Players.LocalPlayer
    local charName = lp.Name

    local character        = lp.Character or lp.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    local obj              = workspace:WaitForChild(charName)

    local actionActive = false
    local wasShooting  = false

    local recoilActive      = false
    local recoilElapsed     = 0
    local recoilStartCF     = nil
    local recoilGuarderRoot = nil

    local frameCount    = 0
    local cachedGuarder = nil

    local antiContestEnabled = false
    local attrConn  = nil
    local hbConn    = nil
    local cleanupConn = nil

    -- -- Guarder Search --------------------------------------------------------

    local function scanGuarder()
        local closest     = nil
        local closestDist = math.huge
        local hrpPos      = humanoidRootPart.Position

        local players = Players:GetPlayers()
        for i = 1, #players do
            local p = players[i]
            if p == lp then continue end

            local pChar = p.Character
            if not pChar then continue end
            if pChar:GetAttribute("Guarding") ~= charName then continue end

            local pRoot = pChar:FindFirstChild("HumanoidRootPart")
            if not pRoot then continue end

            local dist = (hrpPos - pRoot.Position).Magnitude
            if dist < closestDist then
                closestDist = dist
                closest = pRoot
            end
        end

        cachedGuarder = closest
    end

    -- -- Dynamic Goal CFrame ---------------------------------------------------

    local function getGoalCFrame(guarderCF, startCF)
        local look = guarderCF.LookVector
        local flat = Vector3.new(look.X, 0, look.Z)

        if flat.Magnitude < 1e-4 then
            local right = guarderCF.RightVector
            flat = Vector3.new(right.X, 0, right.Z)
            if flat.Magnitude < 1e-4 then return startCF end
        end

        local dir    = flat.Unit
        local origin = startCF.Position
        local goal   = origin + dir * RECOIL_DISTANCE

        local goalPos = origin:Lerp(goal, 1)
        return CFrame.new(goalPos, goalPos + startCF.LookVector)
    end

    -- -- Start / Stop Logic ----------------------------------------------------

    local function startAntiContest()
        -- Refresh character references in case of respawn
        character        = lp.Character or lp.CharacterAdded:Wait()
        humanoidRootPart = character:WaitForChild("HumanoidRootPart")
        obj              = workspace:WaitForChild(charName)

    attrConn = obj.AttributeChanged:Connect(function(attr)
    if attr == "Action" then
        local action = obj:GetAttribute("Action")
        actionActive = (action == "Dunking" or action == "Shooting")
    end
    end)

        hbConn = RunService.Heartbeat:Connect(function(dt)
            if not antiContestEnabled then return end

            frameCount = frameCount + 1

            -- Idle: skip expensive guarder scan most frames; ramp up when shooting/recoil active
            local busy = actionActive or recoilActive
            local scanPeriod = busy and GUARDER_CHECK_RATE or (GUARDER_CHECK_RATE * 3)
            if frameCount % scanPeriod == 0 then
                scanGuarder()
            end

            if actionActive and not wasShooting then
                local guarder = cachedGuarder

                if guarder and guarder.Parent then
                    if RECOIL_MODE == "Teleport" then
                        local look = guarder.CFrame.LookVector
                        local flat = Vector3.new(look.X, 0, look.Z)
                        if flat.Magnitude > 1e-4 then
                            local dir = flat.Unit
                            local p   = humanoidRootPart.Position
                            local sl  = humanoidRootPart.CFrame.LookVector
                            local np  = p + dir * RECOIL_DISTANCE
                            humanoidRootPart.CFrame = CFrame.new(np, np + sl)
                        end

                    elseif RECOIL_MODE == "Tween" then
                        recoilStartCF     = humanoidRootPart.CFrame
                        recoilGuarderRoot = guarder
                        recoilElapsed     = 0
                        recoilActive      = true
                    end
                end
            end

            if recoilActive then
                local gr = recoilGuarderRoot
                if not gr or not gr.Parent then
                    recoilActive = false
                else
                    recoilElapsed = recoilElapsed + dt
                    local t = recoilElapsed / TWEEN_TIME
                    if t >= 1 then
                        t = 1
                        recoilActive = false
                    end

                    local et     = 1 - (1 - t) * (1 - t)
                    local goalCF = getGoalCFrame(gr.CFrame, recoilStartCF)
                    humanoidRootPart.CFrame = recoilStartCF:Lerp(goalCF, et)
                end
            end

            wasShooting = actionActive
        end)

        cleanupConn = character.AncestryChanged:Connect(function()
            if not character:IsDescendantOf(game) then
                if attrConn  then attrConn:Disconnect()  end
                if hbConn    then hbConn:Disconnect()    end
                recoilActive      = false
                recoilGuarderRoot = nil
                cachedGuarder     = nil
            end
        end)
    end

    local function stopAntiContest()
        if attrConn   then attrConn:Disconnect();   attrConn   = nil end
        if hbConn     then hbConn:Disconnect();     hbConn     = nil end
        if cleanupConn then cleanupConn:Disconnect(); cleanupConn = nil end

        recoilActive      = false
        recoilGuarderRoot = nil
        cachedGuarder     = nil
        actionActive      = false
        wasShooting       = false
    end

    -- -- UI: Toggle ------------------------------------------------------------

    Tabs.Shooting:CreateToggle("Shooting_Experimental_AntiContestLegit", {
        Title = "Anti Contest (Legit)",
        Default = false,
        Callback = function(state)
            antiContestEnabled = state
            if state then
                startAntiContest()
            else
                stopAntiContest()
            end
        end,
    })

    Tabs.Shooting:CreateSlider("ExpirmentalSection", {
        Title = "Anti contest amount",
        Max = 0.3,
        Min = 0.1,
        Rounding = 2,
        Default = TWEEN_TIME,
        Callback = function(value)
            TWEEN_TIME = value
        end,
    })

end

                -- ============================================
                -- GREEN CELEBRATION SECTION (Side 2)
                -- ============================================
            Tabs.Shooting:AddSection("Green celebration")

                do
                    local player = Players.LocalPlayer
                    
                    -- Animation variables
                    local greenCelebrationEnabled = false
                    local selectedAnimationId = nil
                    local replacementTrack = nil
                    local replacementActive = false
                    
                    -- Get all animations in Celebrations folder
                    local animationsFolder = ReplicatedStorage.Animations.Celebrations
                    local animationList = {}
                    local animationMap = {}
                    
                    for _, obj in ipairs(animationsFolder:GetDescendants()) do
                        if obj:IsA("Animation") then
                            table.insert(animationList, obj.Name)
                            animationMap[obj.Name] = obj.AnimationId
                        end
                    end
                    
                    Tabs.Shooting:CreateToggle("GreenCelebrationToggle", {
                        Title = "Green Celebration Changer",
                        Default = false,
                        Callback = function(Value)
                            greenCelebrationEnabled = Value
                            
                            if Value and selectedAnimationId then
                                -- Initialize the animation replacement system
                                local character = workspace:WaitForChild(player.Name)
                                local humanoid = character:WaitForChild("Humanoid")
                                local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
                                
                                -- Target animation ID to replace
                                local TARGET_ANIMATION_ID = "rbxassetid://127251278624242"
                                
                                -- Load replacement animation
                                local replacementAnimation = Instance.new("Animation")
                                replacementAnimation.AnimationId = selectedAnimationId
                                replacementTrack = animator:LoadAnimation(replacementAnimation)
                                
                                local function stopOtherAnimationsExcept(exceptTrack)
                                    for _, track in pairs(animator:GetPlayingAnimationTracks()) do
                                        if track ~= exceptTrack then
                                            track:Stop(0.1)
                                        end
                                    end
                                end
                                
                                animator.AnimationPlayed:Connect(function(animationTrack)
                                    if not greenCelebrationEnabled then return end
                                    
                                    local animId = animationTrack.Animation and animationTrack.Animation.AnimationId
                                    
                                    if replacementActive then
                                        -- Replacement is playing, block all other animations except replacementTrack itself
                                        if animationTrack ~= replacementTrack then
                                            animationTrack:Stop(0.1)
                                        end
                                        return
                                    end
                                    
                                    if animId == TARGET_ANIMATION_ID then
                                        replacementActive = true
                                        
                                        -- Stop all other animations except the target animation
                                        stopOtherAnimationsExcept(animationTrack)
                                        
                                        -- Stop the original animation with fade-out
                                        animationTrack:Stop(0.1)
                                        
                                        -- Match speed and weight
                                        replacementTrack:AdjustSpeed(animationTrack.Speed)
                                        replacementTrack:AdjustWeight(animationTrack.WeightCurrent)
                                        
                                        -- Play replacement animation with fade-in
                                        replacementTrack:Play(0.1)
                                        
                                        -- Play again shortly after to ensure playback
                                        task.delay(0.1, function()
                                            if not replacementTrack.IsPlaying then
                                                replacementTrack:Play(0.1)
                                            end
                                        end)
                                        
                                        -- When replacement animation ends, reset flag
                                        replacementTrack.Stopped:Connect(function()
                                            replacementActive = false
                                        end)
                                        
                                        -- When original animation stops, stop replacement to keep sync
                                        animationTrack.Stopped:Connect(function()
                                            replacementTrack:Stop(0.1)
                                        end)
                                    end
                                end)
                            else
                                -- Clean up if disabled
                                replacementActive = false
                                if replacementTrack then
                                    replacementTrack:Stop()
                                    replacementTrack = nil
                                end
                            end
                        end
                    })
                    
                    Tabs.Shooting:CreateDropdown("AnimationDropdown", {
                        Title = "Animation",
                        Values = animationList,
                        Multi = false,
                        Default = (#animationList > 0) and 1 or 1,
                        Callback = function(Value)
                            -- Value is the selected animation name
                            selectedAnimationId = animationMap[Value]
                            
                            -- If toggle is already enabled, reload the replacement animation
                            if greenCelebrationEnabled and replacementTrack then
                                local character = workspace:FindFirstChild(player.Name)
                                if character then
                                    local humanoid = character:FindFirstChild("Humanoid")
                                    if humanoid then
                                        local animator = humanoid:FindFirstChildOfClass("Animator")
                                        if animator then
                                            -- Stop the old replacement track
                                            replacementTrack:Stop()
                                            
                                            -- Load new replacement animation
                                            local replacementAnimation = Instance.new("Animation")
                                            replacementAnimation.AnimationId = selectedAnimationId
                                            replacementTrack = animator:LoadAnimation(replacementAnimation)
                                        end
                                    end
                                end
                            end
                        end
                    })

                    Tabs.Shooting:CreateParagraph("Shooting_CelebrationNote", {
                        Title = "Note",
                        Content = "Use Default Celebration for this to work. Yes — everyone can see.",
                    })
                end
            end
    end



do -- PlayerTab
    local player = Players.LocalPlayer
    local charName = player.Name
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    local obj = workspace:WaitForChild(charName)

    local speedActive = false
    local MOVE_SPEED = 2
    local speedConnection = nil
    local speedCharConn = nil
    local speedBallChildAddedConn, speedBallChildRemovedConn = nil, nil
    local characterHasBall = false

    local BLOCKED_ACTIONS = {
        Shooting = true,
        Dunking = true,
        Dribbling = true
    }

    local function isBlockedAction(action)
        return BLOCKED_ACTIONS[action] == true
    end

    local function disableNormalWalkspeed()
        speedActive = false
        if speedConnection then
            speedConnection:Disconnect()
            speedConnection = nil
        end
        if speedBallChildAddedConn then
            speedBallChildAddedConn:Disconnect()
            speedBallChildAddedConn = nil
        end
        if speedBallChildRemovedConn then
            speedBallChildRemovedConn:Disconnect()
            speedBallChildRemovedConn = nil
        end
        if speedCharConn then
            speedCharConn:Disconnect()
            speedCharConn = nil
        end
        characterHasBall = false
    end

    local function syncSpeedBallCache(ch)
        characterHasBall = ch and ch:FindFirstChild("Ball") ~= nil
    end

    local function bindSpeedBallListeners(ch)
        if speedBallChildAddedConn then speedBallChildAddedConn:Disconnect() end
        if speedBallChildRemovedConn then speedBallChildRemovedConn:Disconnect() end
        if not ch then return end
        speedBallChildAddedConn = ch.ChildAdded:Connect(function(c)
            if c.Name == "Ball" then characterHasBall = true end
        end)
        speedBallChildRemovedConn = ch.ChildRemoved:Connect(function(c)
            if c.Name == "Ball" then characterHasBall = false end
        end)
        syncSpeedBallCache(ch)
    end

    -- Listen for attribute changes
    obj.AttributeChanged:Connect(function(attributeName)
        if attributeName == "Action" then
            local value = obj:GetAttribute("Action")
            speedActive = not isBlockedAction(value)
        end
    end)
    
Tabs.Player:AddSection("Movement")

local antiPushConnection, antiStunConnection

Tabs.Player:CreateToggle("Player_Movement_AntiStun", {
    Title = "AntiStun",
    Default = false,
    Callback = function(enabled)
        if antiPushConnection then
            antiPushConnection:Disconnect()
            antiPushConnection = nil
        end
        if antiStunConnection then
            antiStunConnection:Disconnect()
            antiStunConnection = nil
        end

        if enabled then
            local char = game:GetService("Players").LocalPlayer.Character
            if not char then return end

            char:SetAttribute("PushStun", false)
            antiPushConnection = char:GetAttributeChangedSignal("PushStun"):Connect(function()
                if char:GetAttribute("PushStun") ~= false then
                    char:SetAttribute("PushStun", false)
                end
            end)

            char:SetAttribute("Stunned", false)
            antiStunConnection = char:GetAttributeChangedSignal("Stunned"):Connect(function()
                if char:GetAttribute("Stunned") ~= false then
                    char:SetAttribute("Stunned", false)
                end
            end)
        end
    end
})

local function cframeSpeedMethod(moveVector, deltaTime)
    if not (humanoidRootPart and humanoidRootPart.Parent and humanoid and humanoid.Parent) then return end
    if moveVector.Magnitude > 0 then
        humanoidRootPart.CFrame = humanoidRootPart.CFrame + (moveVector * MOVE_SPEED * deltaTime)
    end
end

Tabs.Player:CreateToggle("Player_Movement_Walkspeed", {
    Title = "Speedhacks",
    Default = false,
    Callback = function(enabled)
        if enabled then
            speedActive = true
            bindSpeedBallListeners(character)
            if speedCharConn then speedCharConn:Disconnect() end
            speedCharConn = player.CharacterAdded:Connect(function(newChar)
                character = newChar
                humanoid = character:WaitForChild("Humanoid")
                humanoidRootPart = character:WaitForChild("HumanoidRootPart")
                bindSpeedBallListeners(character)
            end)

            -- Apply CFrame movement each Heartbeat, sourced from the humanoid's MoveDirection
            if speedConnection then speedConnection:Disconnect() end
            speedConnection = RunService.Heartbeat:Connect(function(deltaTime)
                if not speedActive then return end
                if characterHasBall then return end
                if not (humanoidRootPart and humanoidRootPart.Parent and humanoid and humanoid.Parent) then return end

                local moveVector = humanoid.MoveDirection
                if moveVector.Magnitude > 0 then
                    moveVector = moveVector.Unit
                end

                cframeSpeedMethod(moveVector, deltaTime)
            end)
        else
            speedActive = false
            if speedConnection then speedConnection:Disconnect() speedConnection = nil end
            if speedCharConn then speedCharConn:Disconnect() speedCharConn = nil end
            disableNormalWalkspeed()
        end
    end
})

Tabs.Player:CreateSlider("Player_Movement_WalkspeedAmount", {
    Title = "Speed amount",
    Default = 2,
    Max = 10,
    Min = 1,
    Rounding = 0,
    Callback = function(Value)
        MOVE_SPEED = Value
    end
})

if type(getgc) == "function" then
    local function getGcRoots()
        local ok, roots = pcall(function()
            return getgc(true)
        end)
        if ok and roots ~= nil then
            return roots
        end

        ok, roots = pcall(function()
            return getgc(false)
        end)
        if ok and roots ~= nil then
            return roots
        end

        return getgc()
    end

    local GC_SCAN_MAX_DEPTH = 1000
    local GC_SCAN_MAX_VISITS = 600000
    local GC_YIELD_EVERY = 350

    local function normalizeGcKey(value)
        if type(value) ~= "string" then
            return nil
        end
        -- Normalize common naming variants: spaces, hyphens, underscores, and casing.
        return string.lower((value:gsub("[%s%-%_]+", "")))
    end

    local function gcReplaceKey(targetKey, newValue)
        task.spawn(function()
            local targetNormalized = normalizeGcKey(targetKey)
            local totalPatches = 0

            local function scan(tbl, depth, seenRef, visitsRef)
                if depth > GC_SCAN_MAX_DEPTH or visitsRef.count >= GC_SCAN_MAX_VISITS then
                    return
                end
                if type(tbl) ~= "table" or seenRef[tbl] then
                    return
                end
                seenRef[tbl] = true

                for k, v in next, tbl do
                    visitsRef.count += 1
                    if visitsRef.count >= GC_SCAN_MAX_VISITS then
                        return
                    end
                    if visitsRef.count % GC_YIELD_EVERY == 0 then
                        task.wait()
                    end
                    local keyStr = tostring(k)
                    local keyMatches = (keyStr == targetKey)
                    if not keyMatches and targetNormalized ~= nil then
                        keyMatches = (normalizeGcKey(keyStr) == targetNormalized)
                    end

                    if keyMatches and type(v) == "number" then
                        tbl[k] = newValue
                        totalPatches += 1
                    elseif type(v) == "table" then
                        scan(v, depth + 1, seenRef, visitsRef)
                    end
                end
            end

            -- Run a few bounded passes so values that initialize shortly after UI click still get patched.
            for pass = 1, 3 do
                local seen = {}
                local visitsRef = {count = 0}
                local roots = getGcRoots()
                local n = #roots
                for i = 1, n do
                    if i % GC_YIELD_EVERY == 0 then
                        task.wait()
                    end
                    local gcObj = roots[i]
                    if type(gcObj) == "table" then
                        pcall(scan, gcObj, 0, seen, visitsRef)
                    end
                end

                if visitsRef.count >= GC_SCAN_MAX_VISITS then
                    break
                end
                if totalPatches > 0 then
                    break
                end
                if pass < 3 then
                    task.wait(0.15)
                end
            end
        end)
    end

    local physSpeedValue = 99
    local physSpeedBallValue = 99
Tabs.Player:AddSection("Physicals")
    Tabs.Player:CreateButton{
        Title = "Change Speed",
        Callback = function()
            gcReplaceKey("Speed", physSpeedValue)
        end,
    }
    Tabs.Player:CreateSlider("Player_Physicals_SpeedValue", {
        Title = "Speed Value",
        Default = 99,
        Max = 99,
        Min = 50,
        Rounding = 1,
        Callback = function(Value)
            physSpeedValue = Value
        end,
    })
    Tabs.Player:CreateButton{
        Title = "Change Speed + Ball",
        Callback = function()
            gcReplaceKey("Speed With-Ball", physSpeedBallValue)
        end,
    }
    Tabs.Player:CreateSlider("Player_Physicals_SpeedBallValue", {
        Title = "Speed With-Ball Value",
        Default = 99,
        Max = 99,
        Min = 70,
        Rounding = 1,
        Callback = function(Value)
            physSpeedBallValue = Value
        end,
    })
    Tabs.Player:CreateButton{
        Title = "Max Stamina",
        Callback = function()
            gcReplaceKey("Stamina", 99)
        end,
    }
    Tabs.Player:CreateButton{
        Title = "Max Strength",
        Callback = function()
            gcReplaceKey("Strength", 99)
        end,
    }
    Tabs.Player:CreateButton{
        Title = "Max Acceleration",
        Callback = function()
            gcReplaceKey("Acceleration", 99)
        end,
    }
end
end



do -- Dribbling

do
    -- Prada Slide Section
Tabs.Dribble:AddSection("Prada slide")

    Tabs.Dribble:CreateToggle("PradaSlideBackwardsToggle", {
        Title = "Prada Slide (Backwards)",
        Default = false,
        Callback = function(Value)
            if Value then
                local RS = ReplicatedStorage
                
                local Event = RS.Remotes.Server.Action
                local LP = Players.LocalPlayer
                
                local RightAnim = RS.Animations.Dribbling.DEFAULT.DEFAULTPostStepbackRight
                local LeftAnim = RS.Animations.Dribbling.DEFAULT.DEFAULTPostStepbackLeft
                
                -- Cache references once
                local char = LP.Character or LP.CharacterAdded:Wait()
                local animator = char:WaitForChild("Humanoid"):WaitForChild("Animator")
                local postAnimFolder = char:WaitForChild("Animate"):WaitForChild("MovementAnimations"):WaitForChild("PostAnimations")
                
                -- Cache animation IDs once
                local PostAnimIds = {}
                for _, anim in ipairs(postAnimFolder:GetDescendants()) do
                    if anim:IsA("Animation") then
                        PostAnimIds[anim.AnimationId] = true
                    end
                end
                
                local isExecuting = false
                local connections = {}
                
                getgenv().PradaSlideBackwardsEnabled = true
                
                -- Single connection for all animations
                connections[#connections + 1] = animator.AnimationPlayed:Connect(function(track)
                    if not getgenv().PradaSlideBackwardsEnabled or isExecuting then return end
                    
                    local animId = track.Animation.AnimationId
                    
                    -- Check if it's a post animation
                    if PostAnimIds[animId] then
                        isExecuting = true
                        
                        
                        -- Create temporary connection for stepback detection
                        local stepbackConn
                        stepbackConn = animator.AnimationPlayed:Connect(function(stepTrack)
                            local id = stepTrack.Animation.AnimationId
                            local dir
                            
                            if id == RightAnim.AnimationId then
                                dir = "Right"
                            elseif id == LeftAnim.AnimationId then
                                dir = "Left"
                            end
                            
                            if dir then
                                stepbackConn:Disconnect()
                                
                                -- Execute slide sequence
                                Event:FireServer({
                                    Sprinting = true,
                                    Type = "Sprint"
                                })
                                
                                Event:FireServer({
                                    Keys = (dir == "Right") and "CX" or "ZX",
                                    Type = "Dribble"
                                })
                                
                                Event:FireServer({
                                    Sprinting = false,
                                    Type = "Sprint"
                                })
                                
                                isExecuting = false
                            end
                        end)
                        
                        -- Timeout cleanup
                        task.delay(1, function()
                            if stepbackConn and stepbackConn.Connected then
                                stepbackConn:Disconnect()
                                isExecuting = false
                            end
                        end)
                    end
                end)
                
                -- Store connections for cleanup
                getgenv().PradaSlideBackwardsConnections = connections
                
            else
                getgenv().PradaSlideBackwardsEnabled = false
                
                -- Clean up connections
                if getgenv().PradaSlideBackwardsConnections then
                    for _, conn in ipairs(getgenv().PradaSlideBackwardsConnections) do
                        if conn and conn.Connected then
                            conn:Disconnect()
                        end
                    end
                    getgenv().PradaSlideBackwardsConnections = nil
                end
            end
        end
    })

    -- Prada Slide (Left/Right) Toggle
    Tabs.Dribble:CreateToggle("PradaSlideLeftRightToggle", {
        Title = "Prada Slide (Left/Right)",
        Default = false,
        Callback = function(Value)
            if Value then
                local RS = ReplicatedStorage
                
                local Event = RS.Remotes.Server.Action
                local LP = Players.LocalPlayer
                
                local RightAnim = RS.Animations.Dribbling.DEFAULT.DEFAULTFakePostSpinRight
                local LeftAnim = RS.Animations.Dribbling.DEFAULT.DEFAULTFakePostSpinLeft
                
                -- Cache references once
                local char = LP.Character or LP.CharacterAdded:Wait()
                local animator = char:WaitForChild("Humanoid"):WaitForChild("Animator")
                local postAnimFolder = char:WaitForChild("Animate"):WaitForChild("MovementAnimations"):WaitForChild("PostAnimations")
                
                -- Cache animation IDs once
                local PostAnimIds = {}
                for _, anim in ipairs(postAnimFolder:GetDescendants()) do
                    if anim:IsA("Animation") then
                        PostAnimIds[anim.AnimationId] = true
                    end
                end
                
                local isExecuting = false
                local connections = {}
                
                getgenv().PradaSlideLeftRightEnabled = true
                
                -- Single connection for all animations
                connections[#connections + 1] = animator.AnimationPlayed:Connect(function(track)
                    if not getgenv().PradaSlideLeftRightEnabled or isExecuting then return end
                    
                    local animId = track.Animation.AnimationId
                    
                    -- Check if it's a post animation
                    if PostAnimIds[animId] then
                        isExecuting = true
                        
                        -- Create temporary connection for stepback detection
                        local stepbackConn
                        stepbackConn = animator.AnimationPlayed:Connect(function(stepTrack)
                            local id = stepTrack.Animation.AnimationId
                            local dir
                            
                            if id == RightAnim.AnimationId then
                                dir = "Right"
                            elseif id == LeftAnim.AnimationId then
                                dir = "Left"
                            end
                            
                            if dir then
                                stepbackConn:Disconnect()
                                
                                -- Execute slide sequence
                                Event:FireServer({
                                    Sprinting = true,
                                    Type = "Sprint"
                                })
                                
                                Event:FireServer({
                                    Keys = (dir == "Right") and "CX" or "ZX",
                                    Type = "Dribble"
                                })
                                
                                Event:FireServer({
                                    Sprinting = false,
                                    Type = "Sprint"
                                })
                                
                                isExecuting = false
                            end
                        end)
                        
                        -- Timeout cleanup
                        task.delay(1, function()
                            if stepbackConn and stepbackConn.Connected then
                                stepbackConn:Disconnect()
                                isExecuting = false
                            end
                        end)
                    end
                end)
                
                -- Store connections for cleanup
                getgenv().PradaSlideLeftRightConnections = connections
                
            else
                getgenv().PradaSlideLeftRightEnabled = false
                
                -- Clean up connections
                if getgenv().PradaSlideLeftRightConnections then
                    for _, conn in ipairs(getgenv().PradaSlideLeftRightConnections) do
                        if conn and conn.Connected then
                            conn:Disconnect()
                        end
                    end
                    getgenv().PradaSlideLeftRightConnections = nil
                end
            end
        end
    })
    
    Tabs.Dribble:CreateParagraph("Dribble_PradaInfo", {
        Title = "Prada slide info",
        Content = [=[Requirements:
• Silver Quick Chain | Bronze Quick Chain
• 50+ Post Moves | Silver Post Playmaker

Steps:
1 - Go into a post move
2a - Backwards prada slide: exit while moving backward
2b - Left/Right prada slide: exit while standing still]=],
    })
end


    -- Spin Section
Tabs.Dribble:AddSection("Spin")

    do
        Tabs.Dribble:CreateToggle("HellSpinToggle", {
            Title = "Hell Spin",
            Default = false,
            Callback = function(Value)
                if Value then
                    local UserInputService = game:GetService("UserInputService")
                    local ReplicatedStorage = game:GetService("ReplicatedStorage")

                    local Event = ReplicatedStorage.Remotes.Server.Action

                    local debounce = false

                    getgenv().HellSpinEnabled = true

                    getgenv().HellSpinConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                        if input.KeyCode ~= Enum.KeyCode.ButtonR3 and input.KeyCode ~= Enum.KeyCode.B then
                            return
                        end
                        if gameProcessed then return end
                        if not getgenv().HellSpinEnabled then return end

                        if debounce then return end
                        debounce = true

                        -- Step 1: Guard ON
                        Event:FireServer({
                            Action = "Guard",
                            Guard = true
                        })

                        -- Step 2: Short wait
                        task.wait(0.02)

                        -- Step 3: Guard OFF
                        Event:FireServer({
                            Action = "Guard",
                            Guard = false
                        })

                        -- Step 4: Dribble
                        Event:FireServer({
                            Keys = "H",
                            Type = "Dribble"
                        })

                        debounce = false
                    end)
                else
                    getgenv().HellSpinEnabled = false

                    if getgenv().HellSpinConnection then
                        getgenv().HellSpinConnection:Disconnect()
                        getgenv().HellSpinConnection = nil
                    end
                end
            end
        })

        Tabs.Dribble:CreateParagraph("Dribble_HellSpinInfo", {
            Title = "Hell Spin",
            Content = [=[How to use Hell Spin:
Keybind: Press [B] on keyboard or [R3] (Right Stick Click) on controller]=],
        })
    end

    -- Dribble Glide Section
Tabs.Dribble:AddSection("Glide")

    do
        Tabs.Dribble:CreateToggle("DribbleGlideToggle", {
            Title = "Dribble Glide",
            Default = false,
            Callback = function(Value)
                if Value then
                    local player = Players.LocalPlayer
                    local charName = player.Name
                    local character = player.Character or player.CharacterAdded:Wait()
                    local humanoid = character:WaitForChild("Humanoid")
                    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
                    
                    local obj = workspace:WaitForChild(charName)
                    local isDribbling = false
                    
                    local function refreshAction()
                        isDribbling = (obj and obj:GetAttribute("Action") == "Dribbling") or false
                    end
                    refreshAction()

                    local attrConnection = obj:GetAttributeChangedSignal("Action"):Connect(refreshAction)
                    
                    local renderConnection = RunService.Heartbeat:Connect(function(deltaTime)
                        if not isDribbling then return end
                        if not (humanoid and humanoidRootPart and humanoidRootPart.Parent) then return end
                        
                        local moveDirection = humanoid.MoveDirection
                        
                        if moveDirection.Magnitude > 0 then
                            moveDirection = moveDirection.Unit
                            humanoidRootPart.CFrame = humanoidRootPart.CFrame + 
                                (moveDirection * (getgenv().DribbleMoveSpeedValue or 4) * deltaTime)
                        end
                    end)

                    local respawnConnection = player.CharacterAdded:Connect(function(newChar)
                        character = newChar
                        humanoid = character:WaitForChild("Humanoid")
                        humanoidRootPart = character:WaitForChild("HumanoidRootPart")
                        obj = workspace:WaitForChild(charName)
                        refreshAction()
                    end)
                    
                    getgenv().DribbleGlideAttrConnection = attrConnection
                    getgenv().DribbleGlideRenderConnection = renderConnection
                    getgenv().DribbleGlideRespawnConnection = respawnConnection
                else
                    if getgenv().DribbleGlideAttrConnection then
                        getgenv().DribbleGlideAttrConnection:Disconnect()
                        getgenv().DribbleGlideAttrConnection = nil
                    end
                    if getgenv().DribbleGlideRenderConnection then
                        getgenv().DribbleGlideRenderConnection:Disconnect()
                        getgenv().DribbleGlideRenderConnection = nil
                    end
                    if getgenv().DribbleGlideRespawnConnection then
                        getgenv().DribbleGlideRespawnConnection:Disconnect()
                        getgenv().DribbleGlideRespawnConnection = nil
                    end
                end
            end
        })

        Tabs.Dribble:CreateSlider("DribbleGlideAmount", {
            Title = "Glide amount",
            Min = 1,
            Default = 4,
            Max = 10,
            Rounding = 1,
            Callback = function(Value)
                getgenv().DribbleMoveSpeedValue = Value
            end
        })
    end

-- Quick Handles Section
Tabs.Dribble:AddSection("Auto Hellspin")

do
    Tabs.Dribble:CreateToggle("TweenHellSpinToggle", {
    Title = "Tween Hell Spin",
    Default = false,
    Callback = function(Value)
        if Value then
            local Players = game:GetService("Players")
            local ReplicatedStorage = game:GetService("ReplicatedStorage")

            local player = Players.LocalPlayer
            local Event = ReplicatedStorage.Remotes.Server.Action

            local dribblingFolder = ReplicatedStorage:WaitForChild("Animations"):WaitForChild("Dribbling")

            -- ?? Keep your fixed animations
            local ANIMATIONS = {
                ["rbxassetid://118866485239122"] = 0.6,
                ["rbxassetid://108261426238875"] = 0.6
            }

            -- ?? Add BetweenTheLegs animations dynamically
            for _, obj in ipairs(dribblingFolder:GetDescendants()) do
                if obj:IsA("Animation") then
                    local nameLower = string.lower(obj.Name)

                    if string.find(nameLower, "betweenthelegs") then
                        local numericId = obj.AnimationId:match("%d+")
                        if numericId then
                            local id = "rbxassetid://" .. numericId

                            -- Avoid overwriting your fixed ones
                            if not ANIMATIONS[id] then
                                ANIMATIONS[id] = 0.4 -- default delay for detected ones
                            end
                        end
                    end
                end
            end

            -- Prevent duplicate triggers
            local activeTracks = {}

            local function fireSequence(delay)
                task.wait(delay)

                Event:FireServer({ Action = "Guard", Guard = true })
                task.wait(0.02)
                Event:FireServer({ Action = "Guard", Guard = false })
                Event:FireServer({ Keys = "H", Type = "Dribble" })
            end

            local function onAnimationPlayed(track)
                local anim = track.Animation
                if not anim then return end

                local id = anim.AnimationId
                local delay = ANIMATIONS[id]

                if not delay then return end

                if activeTracks[track] then return end
                activeTracks[track] = true

                task.spawn(fireSequence, delay)

                track.Stopped:Once(function()
                    activeTracks[track] = nil
                end)
            end

            local function setupCharacter(char)
                local humanoid = char:WaitForChild("Humanoid")
                local animator = humanoid:WaitForChild("Animator")

                local conn = animator.AnimationPlayed:Connect(onAnimationPlayed)
                getgenv().TweenHellSpinAnimConn = conn
            end

            local charConn = player.CharacterAdded:Connect(setupCharacter)
            getgenv().TweenHellSpinCharConn = charConn

            if player.Character then
                setupCharacter(player.Character)
            end
        else
            if getgenv().TweenHellSpinAnimConn then
                getgenv().TweenHellSpinAnimConn:Disconnect()
                getgenv().TweenHellSpinAnimConn = nil
            end
            if getgenv().TweenHellSpinCharConn then
                getgenv().TweenHellSpinCharConn:Disconnect()
                getgenv().TweenHellSpinCharConn = nil
            end
        end
    end
    })

    Tabs.Dribble:CreateToggle("HesiHellSpinToggle", {
        Title = "Hesi Hell Spin",
        Default = false,
        Callback = function(Value)
            if Value then
                local Dribbling = ReplicatedStorage:WaitForChild("Animations"):WaitForChild("Dribbling")

                local hesiAnimations = {}

                for _, obj in ipairs(Dribbling:GetDescendants()) do
                    if obj:IsA("Animation") and string.find(string.lower(obj.Name), "hesi", 1, true) then
                        hesiAnimations[obj.AnimationId] = obj
                    end
                end

                local player = Players.LocalPlayer
                local Event = ReplicatedStorage.Remotes.Server.Action

                local activeTracks = {}

                local function fireSequence()
                    task.wait(0.73)

                    Event:FireServer({ Action = "Guard", Guard = true })
                    task.wait(0.02)
                    Event:FireServer({ Action = "Guard", Guard = false })
                    Event:FireServer({ Keys = "H", Type = "Dribble" })
                end

                local function setupCharacter(character)
                    local humanoid = character:WaitForChild("Humanoid")
                    local animator = humanoid:WaitForChild("Animator")

                    -- Clean up old tracking
                    activeTracks = {}

                    local conn = animator.AnimationPlayed:Connect(function(animationTrack)
                        local animId = animationTrack.Animation.AnimationId

                        if hesiAnimations[animId] and not activeTracks[animId] then
                            activeTracks[animId] = true

                            fireSequence()

                            -- Wait for the animation to stop before allowing re-trigger
                            animationTrack.Stopped:Once(function()
                                activeTracks[animId] = nil
                            end)
                        end
                    end)
                    getgenv().HesiHellSpinAnimConn = conn
                end

                local charConn = player.CharacterAdded:Connect(setupCharacter)
                getgenv().HesiHellSpinCharConn = charConn

                if player.Character then
                    setupCharacter(player.Character)
                end
            else
                if getgenv().HesiHellSpinAnimConn then
                    getgenv().HesiHellSpinAnimConn:Disconnect()
                    getgenv().HesiHellSpinAnimConn = nil
                end
                if getgenv().HesiHellSpinCharConn then
                    getgenv().HesiHellSpinCharConn:Disconnect()
                    getgenv().HesiHellSpinCharConn = nil
                end
            end
        end
    })
end



end

                

do
    local MANUAL_MOBILE_MODE = false
    local UserInputService = game:GetService("UserInputService")
    local isMobileGlobal = MANUAL_MOBILE_MODE or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)

Tabs.Defense:AddSection("Guarding")

    local manualOverrideEnabled = false

    Tabs.Defense:CreateToggle("ManualOverrideToggle", {
        Title = "Manual Override",
        Default = false,
        Callback = function(Value)
            manualOverrideEnabled = Value
        end
    })

    Tabs.Defense:CreateToggle("AutoGuardToggle", {
        Title = "Auto Guard",
        Default = false,
        Callback = function(Value)
            if Value then
                local client = Players.LocalPlayer
                local virtualinputmanager = game:GetService("VirtualInputManager")
                local players = Players

                local isMobile = isMobileGlobal

                local function get_char(player)
                    return player.Character
                end

                local function get_root(char)
                    return char and char:FindFirstChild("HumanoidRootPart")
                end

                local function get_hum(char)
                    return char and char:FindFirstChildWhichIsA("Humanoid")
                end

                -- ================================================
                -- MANUAL OVERRIDE
                -- ================================================

                local autoguardSendingKey = {}
                local realPlayerKeys = {}
                local CONTROLLER_DEADZONE = 0.2
                local mobileTouchActive = false
                local inputConnections = {}

                local movementKeys = {
                    Enum.KeyCode.W, Enum.KeyCode.A,
                    Enum.KeyCode.S, Enum.KeyCode.D
                }

                -- Do not use InputChanged for thumbsticks: it fires hundreds of times/sec per analog axis and causes hitches.
                -- Poll GetGamepadState only when manual override is checked (from Heartbeat), not on every InputChanged.
                local function leftStickManualOverrideActive()
                    if not UserInputService.GamepadEnabled then
                        return false
                    end
                    for _, padType in ipairs({ Enum.UserInputType.Gamepad1, Enum.UserInputType.Gamepad2 }) do
                        local ok, inputs = pcall(UserInputService.GetGamepadState, UserInputService, padType)
                        if ok and type(inputs) == "table" then
                            for _, inputObj in ipairs(inputs) do
                                if inputObj.KeyCode == Enum.KeyCode.Thumbstick1 then
                                    local pos = inputObj.Position
                                    local mag = math.sqrt(pos.X * pos.X + pos.Y * pos.Y)
                                    if mag > CONTROLLER_DEADZONE then
                                        return true
                                    end
                                    break
                                end
                            end
                        end
                    end
                    return false
                end

                local keyDownConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                    for _, k in ipairs(movementKeys) do
                        if input.KeyCode == k then
                            if not autoguardSendingKey[k] then
                                realPlayerKeys[k] = true
                            end
                            break
                        end
                    end
                end)
                table.insert(inputConnections, keyDownConn)

                local keyUpConn = UserInputService.InputEnded:Connect(function(input, gameProcessed)
                    for _, k in ipairs(movementKeys) do
                        if input.KeyCode == k then
                            realPlayerKeys[k] = false
                            break
                        end
                    end
                end)
                table.insert(inputConnections, keyUpConn)

                local touchStartConn = UserInputService.TouchStarted:Connect(function(touch, gameProcessed)
                    local viewX = workspace.CurrentCamera.ViewportSize.X
                    if touch.Position.X < viewX * 0.5 then
                        mobileTouchActive = true
                    end
                end)
                table.insert(inputConnections, touchStartConn)

                local touchEndConn = UserInputService.TouchEnded:Connect(function(touch, gameProcessed)
                    local viewX = workspace.CurrentCamera.ViewportSize.X
                    local anyLeftTouch = false
                    for _, t in ipairs(UserInputService:GetTouchesOnScreen()) do
                        if t.Position.X < viewX * 0.5 then
                            anyLeftTouch = true
                            break
                        end
                    end
                    if not anyLeftTouch then
                        mobileTouchActive = false
                    end
                end)
                table.insert(inputConnections, touchEndConn)

                getgenv().AutoGuardInputConnections = inputConnections

                local function isPlayerMovingManually()
                    if not manualOverrideEnabled then
                        return false
                    end
                    if leftStickManualOverrideActive() then
                        return true
                    end
                    if isMobile then
                        return mobileTouchActive
                    else
                        for _, k in ipairs(movementKeys) do
                            if realPlayerKeys[k] then
                                return true
                            end
                        end
                        return false
                    end
                end

                -- ================================================

                local function CalculateGuardPosition(ballHolderRoot, rimPosition, myRoot)
                    local GUARD_DISTANCE = getgenv().GuardDistanceValue or 5
                    local PREDICTION_FACTOR = getgenv().PredictionFactorValue or 0.2

                    local ballPos = ballHolderRoot.Position
                    local velocity = ballHolderRoot.AssemblyLinearVelocity
                    local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
                    local speed = horizontalVelocity.Magnitude

                    local ballToRim = rimPosition - ballPos
                    local horizontalBallToRim = Vector3.new(ballToRim.X, 0, ballToRim.Z)

                    if horizontalBallToRim.Magnitude == 0 then
                        return ballPos
                    end

                    local laneDirection = horizontalBallToRim.Unit
                    local baseGuardPos = ballPos + (laneDirection * GUARD_DISTANCE)

                    local predictionScale = math.clamp(speed / 20, 0, 1) * PREDICTION_FACTOR
                    local predictedOffset = horizontalVelocity * predictionScale
                    local finalPos = baseGuardPos + predictedOffset

                    local predictedBallPos = ballPos + predictedOffset
                    local correctedDirection = (rimPosition - predictedBallPos)
                    local horizontalCorrectedDir = Vector3.new(correctedDirection.X, 0, correctedDirection.Z)

                    if horizontalCorrectedDir.Magnitude > 0 then
                        finalPos = predictedBallPos + (horizontalCorrectedDir.Unit * GUARD_DISTANCE)
                    end

                    finalPos = Vector3.new(finalPos.X, ballPos.Y, finalPos.Z)
                    return finalPos
                end

                local function is_guarding(char)
                    if not char then return false end
                    return char:GetAttribute("Guarding") ~= nil
                end

                local function is_shooting_or_dunking(char)
                    if not char then return false end
                    local action = char:GetAttribute("Action")
                    return action == "Shooting" or action == "Dunking"
                end

                local function get_closest_rim(rims, position)
                    local dist, closest = math.huge, nil
                    for _, rim in ipairs(rims) do
                        local d = (rim:GetPivot().Position - position).Magnitude
                        if d < dist then
                            dist = d
                            closest = rim
                        end
                    end
                    return closest
                end

                local rims = {}
                for _, obj in workspace:GetDescendants() do
                    if obj:IsA("MeshPart") and obj.Name == "RimMesh" then
                        table.insert(rims, obj)
                    end
                end

                -- ================================================
                -- PC MOVEMENT: Hold-based key system
                -- Keys are held down continuously and only switched
                -- when direction changes enough to warrant it.
                -- This looks like a real player holding WASD.
                -- ================================================

                -- Which keys autoguard currently has held down
                local heldKeys = {
                    [Enum.KeyCode.W] = false,
                    [Enum.KeyCode.A] = false,
                    [Enum.KeyCode.S] = false,
                    [Enum.KeyCode.D] = false,
                }

                -- How long each key has been held (for legit look)
                local keyHeldTime = {
                    [Enum.KeyCode.W] = 0,
                    [Enum.KeyCode.A] = 0,
                    [Enum.KeyCode.S] = 0,
                    [Enum.KeyCode.D] = 0,
                }

                -- Min time to hold a key before switching (seconds)
                -- Prevents rapid flickering between keys
                local MIN_HOLD_TIME = 0.08

                -- How much the direction needs to change before we
                -- switch keys � prevents jitter from small movements
                local DIRECTION_CHANGE_THRESHOLD = 0.15

                local lastForwardDir = 0  -- -1, 0, or 1
                local lastRightDir = 0    -- -1, 0, or 1
                local timeSinceForwardChange = 0
                local timeSinceRightChange = 0

                local function pressKey(key)
                    if heldKeys[key] then return end
                    autoguardSendingKey[key] = true
                    pcall(function()
                        virtualinputmanager:SendKeyEvent(true, key, false, game)
                    end)
                    heldKeys[key] = true
                    keyHeldTime[key] = 0
                end

                local function releaseKey(key)
                    if not heldKeys[key] then return end
                    pcall(function()
                        virtualinputmanager:SendKeyEvent(false, key, false, game)
                    end)
                    heldKeys[key] = false
                    keyHeldTime[key] = 0
                    autoguardSendingKey[key] = false
                end

                local function releaseAllKeys()
                    for key, _ in pairs(heldKeys) do
                        releaseKey(key)
                    end
                    lastForwardDir = 0
                    lastRightDir = 0
                    timeSinceForwardChange = 0
                    timeSinceRightChange = 0
                end

                local lastGuardState = false
                local wasControllingMovement = false
                local currentTargetPos = nil

                -- Speed boost uses hum.MoveDirection which is driven
                -- by the held keys, so it works the same as before
                local speedBoostConnection = nil
                local isSpeedBoostActive = false

                local function startSpeedBoost()
                    if isSpeedBoostActive then return end
                    isSpeedBoostActive = true

                    speedBoostConnection = RunService.Heartbeat:Connect(function(deltaTime)
                        local char = get_char(client)
                        local hum = get_hum(char)
                        local root = get_root(char)

                        if not (char and hum and root) then return end

                        -- Update held key timers
                        for key, held in pairs(heldKeys) do
                            if held then
                                keyHeldTime[key] = keyHeldTime[key] + deltaTime
                            end
                        end

                        local moveDirection = hum.MoveDirection
                        if moveDirection.Magnitude > 0 and currentTargetPos then
                            local distToTarget = (currentTargetPos - root.Position).Magnitude
                            local MOVE_SPEED = getgenv().MoveSpeedValue or 3

                            local dynamicSpeed = MOVE_SPEED
                            if distToTarget > 6 then
                                dynamicSpeed = MOVE_SPEED * 2
                            elseif distToTarget > 3 then
                                dynamicSpeed = MOVE_SPEED * 1.5
                            end

                            root.CFrame = root.CFrame + (moveDirection.Unit * dynamicSpeed * deltaTime)
                        end
                    end)
                    getgenv().AutoGuardSpeedBoost = speedBoostConnection
                end

                local function stopSpeedBoost()
                    if not isSpeedBoostActive then return end
                    isSpeedBoostActive = false
                    currentTargetPos = nil

                    if speedBoostConnection then
                        speedBoostConnection:Disconnect()
                        speedBoostConnection = nil
                    end
                    getgenv().AutoGuardSpeedBoost = nil
                end

                local function move_to_position_wasd(char, targetPosition, deltaTime)
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if not root then
                        releaseAllKeys()
                        return
                    end

                    currentTargetPos = targetPosition
                    local TOLERANCE = 0.5

                    local direction = (targetPosition - root.Position)
                    local horizontalDirection = Vector3.new(direction.X, 0, direction.Z)
                    local distToTarget = horizontalDirection.Magnitude

                    -- Close enough � release everything and stop
                    if distToTarget <= TOLERANCE then
                        releaseAllKeys()
                        return
                    end

                    local moveVector = horizontalDirection.Unit
                    local cam = workspace.CurrentCamera
                    if not cam then
                        releaseAllKeys()
                        return
                    end

                    local camCF = cam.CFrame
                    local camRight = camCF.RightVector
                    local camLook = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z).Unit

                    local forward = moveVector:Dot(camLook)  -- -1 to 1
                    local right = moveVector:Dot(camRight)    -- -1 to 1

                    -- Convert to discrete direction: -1, 0, or 1
                    -- Use a dead zone so small wiggles don't cause key changes
                    local function toDir(value)
                        if value > DIRECTION_CHANGE_THRESHOLD then return 1
                        elseif value < -DIRECTION_CHANGE_THRESHOLD then return -1
                        else return 0
                        end
                    end

                    local newForwardDir = toDir(forward)
                    local newRightDir = toDir(right)

                    timeSinceForwardChange = timeSinceForwardChange + (deltaTime or 0)
                    timeSinceRightChange = timeSinceRightChange + (deltaTime or 0)

                    -- Forward/backward keys � only switch after min hold time
                    -- to prevent rapid flickering
                    if newForwardDir ~= lastForwardDir and timeSinceForwardChange >= MIN_HOLD_TIME then
                        -- Release old forward/back key
                        if lastForwardDir == 1 then releaseKey(Enum.KeyCode.W)
                        elseif lastForwardDir == -1 then releaseKey(Enum.KeyCode.S)
                        end
                        -- Press new forward/back key
                        if newForwardDir == 1 then pressKey(Enum.KeyCode.W)
                        elseif newForwardDir == -1 then pressKey(Enum.KeyCode.S)
                        end
                        lastForwardDir = newForwardDir
                        timeSinceForwardChange = 0
                    end

                    -- Left/right keys � only switch after min hold time
                    if newRightDir ~= lastRightDir and timeSinceRightChange >= MIN_HOLD_TIME then
                        -- Release old left/right key
                        if lastRightDir == 1 then releaseKey(Enum.KeyCode.D)
                        elseif lastRightDir == -1 then releaseKey(Enum.KeyCode.A)
                        end
                        -- Press new left/right key
                        if newRightDir == 1 then pressKey(Enum.KeyCode.D)
                        elseif newRightDir == -1 then pressKey(Enum.KeyCode.A)
                        end
                        lastRightDir = newRightDir
                        timeSinceRightChange = 0
                    end
                end

                -- ================================================
                -- MOBILE CONTROLS (unchanged)
                -- ================================================

                local currentTween = nil
                local isTweening = false
                local isInCloseRange = false
                local mobileSpeedBoostConnection = nil
                local isMobileSpeedBoostActive = false
                local mobileCurrentTargetPos = nil

                local function tweenToPosition(root, targetPos)
                    if currentTween then
                        currentTween:Cancel()
                    end

                    local distance = (targetPos - root.Position).Magnitude
                    local speed = getgenv().MoveSpeedValue or 10
                    local duration = distance / (speed * 10)

                    local targetCFrame = CFrame.new(targetPos.X, root.Position.Y, targetPos.Z)
                    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

                    currentTween = TweenService:Create(root, tweenInfo, {CFrame = targetCFrame})
                    isTweening = true
                    currentTween:Play()

                    currentTween.Completed:Connect(function()
                        isTweening = false
                    end)
                end

                local function startMobileSpeedBoost()
                    if isMobileSpeedBoostActive then return end
                    isMobileSpeedBoostActive = true

                    mobileSpeedBoostConnection = RunService.Heartbeat:Connect(function(deltaTime)
                        local char = get_char(client)
                        local hum = get_hum(char)
                        local root = get_root(char)

                        if not (char and hum and root) then return end
                        if not mobileCurrentTargetPos then return end

                        local direction = (mobileCurrentTargetPos - root.Position)
                        local horizontalDirection = Vector3.new(direction.X, 0, direction.Z)

                        if horizontalDirection.Magnitude <= 0.3 then
                            return
                        end

                        local moveVector = horizontalDirection.Unit
                        local distToTarget = horizontalDirection.Magnitude
                        local MOVE_SPEED = getgenv().MoveSpeedValue or 10

                        local dynamicSpeed = MOVE_SPEED
                        if distToTarget > 6 then
                            dynamicSpeed = MOVE_SPEED * 2
                        elseif distToTarget > 3 then
                            dynamicSpeed = MOVE_SPEED * 1.5
                        end

                        local newPosition = root.Position + (moveVector * dynamicSpeed * deltaTime)

                        if getgenv().AutoGuardBallHolderRoot then
                            local ballHolderPos = getgenv().AutoGuardBallHolderRoot.Position
                            local lookDirection = (ballHolderPos - newPosition).Unit
                            local lookVector = Vector3.new(lookDirection.X, 0, lookDirection.Z)

                            if lookVector.Magnitude > 0 then
                                root.CFrame = CFrame.new(newPosition, newPosition + lookVector)
                            else
                                root.CFrame = CFrame.new(newPosition)
                            end
                        else
                            root.CFrame = CFrame.new(newPosition)
                        end
                    end)
                    getgenv().AutoGuardMobileSpeedBoost = mobileSpeedBoostConnection
                end

                local function stopMobileSpeedBoost()
                    if not isMobileSpeedBoostActive then return end
                    isMobileSpeedBoostActive = false
                    mobileCurrentTargetPos = nil
                    getgenv().AutoGuardBallHolderRoot = nil

                    if mobileSpeedBoostConnection then
                        mobileSpeedBoostConnection:Disconnect()
                        mobileSpeedBoostConnection = nil
                    end
                    getgenv().AutoGuardMobileSpeedBoost = nil
                end

                -- AUTO GUARD LOOP
                -- Throttle expensive ball-holder scanning; most frames can reuse cached results.
                local BALL_DETECTION_RANGE = 25
                local scanEvery = 0.12
                local scanAccum = scanEvery
                local cachedPlayerWithBall, cachedBallHolderPlayer = nil, nil

                local function scanBallHolder(root)
                    local dist, closestChar, closestPlayer = math.huge, nil, nil
                    for _, plr in players:GetPlayers() do
                        if plr == client then continue end
                        local p_char = plr.Character
                        local p_root = p_char and p_char:FindFirstChild("HumanoidRootPart")
                        local has_ball = p_char and p_char:FindFirstChild("Ball")
                        if p_root and has_ball then
                            local d = (p_root.Position - root.Position).Magnitude
                            if d <= BALL_DETECTION_RANGE and d < dist then
                                dist = d
                                closestChar = p_char
                                closestPlayer = plr
                            end
                        end
                    end
                    cachedPlayerWithBall, cachedBallHolderPlayer = closestChar, closestPlayer
                end

                local loopConnection = RunService.Heartbeat:Connect(function(deltaTime)
                    local char = get_char(client)
                    local root = get_root(char)
                    local hum = get_hum(char)

                    if not (char and root and hum) then
                        if not isMobile then
                            releaseAllKeys()
                            stopSpeedBoost()
                        end
                        wasControllingMovement = false
                        return
                    end

                    if isPlayerMovingManually() then
                        if not isMobile then
                            releaseAllKeys()
                            stopSpeedBoost()
                        else
                            if currentTween then
                                currentTween:Cancel()
                                isTweening = false
                            end
                            stopMobileSpeedBoost()
                            isInCloseRange = false
                        end
                        return
                    end

                    local currentGuardState = is_guarding(char)

                    if not isMobile then
                        if lastGuardState and not currentGuardState then
                            releaseAllKeys()
                            stopSpeedBoost()
                            wasControllingMovement = false
                        end
                    end

                    lastGuardState = currentGuardState

                    -- No guard / no active chase: skip ball scan and rest of loop (major FPS win while idle)
                    if not currentGuardState and not wasControllingMovement then
                        return
                    end

                    scanAccum += (deltaTime or 0)
                    if scanAccum >= scanEvery then
                        scanAccum = 0
                        scanBallHolder(root)
                    end

                    local player_with_ball, ball_holder_player = cachedPlayerWithBall, cachedBallHolderPlayer

                    local guardingPlayer = char:GetAttribute("Guarding")
                    local isGuardingBallHolder = ball_holder_player and guardingPlayer and guardingPlayer == ball_holder_player.Name

                    if player_with_ball and currentGuardState and isGuardingBallHolder then
                        wasControllingMovement = true

                        local ballHolderRoot = player_with_ball:FindFirstChild("HumanoidRootPart")
                        if ballHolderRoot then
                            local closest_rim = get_closest_rim(rims, ballHolderRoot.Position)
                            if closest_rim then
                                local rimPosition = closest_rim:GetPivot().Position
                                local target_position = CalculateGuardPosition(ballHolderRoot, rimPosition, root)
                                local distanceToTarget = (target_position - root.Position).Magnitude

                                local ballHolderChar = ball_holder_player and ball_holder_player.Character
                                local isBallHolderShooting = is_shooting_or_dunking(ballHolderChar)

                                if isMobile then
                                    if isBallHolderShooting then
                                        if currentTween then
                                            currentTween:Cancel()
                                            isTweening = false
                                        end
                                        isInCloseRange = true
                                        getgenv().AutoGuardBallHolderRoot = ballHolderRoot
                                        startMobileSpeedBoost()
                                        mobileCurrentTargetPos = target_position
                                    else
                                        if distanceToTarget > 10 and not isInCloseRange then
                                            if not isTweening or distanceToTarget > 15 then
                                                tweenToPosition(root, target_position)
                                            end
                                        else
                                            if not isInCloseRange then
                                                if currentTween then
                                                    currentTween:Cancel()
                                                    isTweening = false
                                                end
                                                isInCloseRange = true
                                            end
                                            getgenv().AutoGuardBallHolderRoot = ballHolderRoot
                                            startMobileSpeedBoost()
                                            mobileCurrentTargetPos = target_position
                                        end
                                    end
                                else
                                    -- PC: hold keys smoothly, pass deltaTime for timing
                                    startSpeedBoost()
                                    move_to_position_wasd(char, target_position, deltaTime)
                                end
                            end
                        end
                    else
                        if wasControllingMovement then
                            if not isMobile then
                                releaseAllKeys()
                                stopSpeedBoost()
                            else
                                if currentTween then
                                    currentTween:Cancel()
                                    isTweening = false
                                end
                                stopMobileSpeedBoost()
                                isInCloseRange = false
                            end
                            wasControllingMovement = false
                        end
                    end
                end)

                getgenv().AutoGuardLoopConnection = loopConnection
                getgenv().AutoGuardSpeedBoost = speedBoostConnection
                getgenv().AutoGuardMobileSpeedBoost = mobileSpeedBoostConnection
                getgenv().AutoGuardReleaseKeys = releaseAllKeys
                getgenv().AutoGuardCurrentTween = currentTween
                getgenv().AutoGuardInputConnections = inputConnections

            else
                if getgenv().AutoGuardLoopConnection then
                    getgenv().AutoGuardLoopConnection:Disconnect()
                    getgenv().AutoGuardLoopConnection = nil
                end
                if getgenv().AutoGuardSpeedBoost then
                    getgenv().AutoGuardSpeedBoost:Disconnect()
                    getgenv().AutoGuardSpeedBoost = nil
                end
                if getgenv().AutoGuardMobileSpeedBoost then
                    getgenv().AutoGuardMobileSpeedBoost:Disconnect()
                    getgenv().AutoGuardMobileSpeedBoost = nil
                end
                if getgenv().AutoGuardReleaseKeys then
                    getgenv().AutoGuardReleaseKeys()
                    getgenv().AutoGuardReleaseKeys = nil
                end
                if getgenv().AutoGuardCurrentTween then
                    getgenv().AutoGuardCurrentTween:Cancel()
                    getgenv().AutoGuardCurrentTween = nil
                end
                if getgenv().AutoGuardInputConnections then
                    for _, conn in ipairs(getgenv().AutoGuardInputConnections) do
                        conn:Disconnect()
                    end
                    getgenv().AutoGuardInputConnections = nil
                end
            end
        end
    })

    Tabs.Defense:CreateSlider("GuardDistanceSlider", {
        Title = "Guard Distance",
        Min = 1,
        Max = 15,
        Default = 5,
        Rounding = 1,
        Callback = function(value)
            getgenv().GuardDistanceValue = value
        end
    })

    Tabs.Defense:CreateSlider("MoveSpeedSlider", {
        Title = "Move Speed",
        Min = isMobileGlobal and 10 or 1,
        Max = 20,
        Default = isMobileGlobal and 10 or 3,
        Rounding = 1,
        Callback = function(value)
            getgenv().MoveSpeedValue = value
        end
    })

    Tabs.Defense:CreateSlider("PredictionFactorSlider", {
        Title = "Prediction",
        Min = 0,
        Max = 1,
        Default = 0.2,
        Rounding = 1,
        Callback = function(value)
            getgenv().PredictionFactorValue = value
        end
    })

    -- Experimental Section
Tabs.Defense:AddSection("Experimental")

    Tabs.Defense:CreateToggle("AutoContestToggle", {
        Title = "Auto Runup",
        Default = false,
        Callback = function(Value)
            if Value then
                -- Set global flag so Auto Guard knows to pause when contesting
                getgenv().AutoContestActive = true
                
                -- Auto Contest code
                local lp = Players.LocalPlayer
                local char = lp.Character or lp.CharacterAdded:Wait()
                local hrp = char:WaitForChild("HumanoidRootPart")

                local LERP_SPEED = 0.0165
                local FRONT_OFFSET = 0.1
                local RANGE = 15 -- only activate within this many studs
                
                -- Lock Y position once at initialization
                local LOCKED_Y = hrp.Position.Y

                local function getClosestPlayer()
                    local closest
                    local dist = math.huge

                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= lp and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                            local root = p.Character.HumanoidRootPart
                            local d = (hrp.Position - root.Position).Magnitude
                            if d < dist then
                                dist = d
                                closest = p
                            end
                        end
                    end

                    return closest, dist
                end

                local function isActionShootingOrDunking(player)
                    local char = player.Character
                    if not char then return false end

                    local action = char:GetAttribute("Action")
                    if action == "Shooting" or action == "Dunking" then
                        return true
                    end
                    return false
                end

                -- Cache + throttle the expensive player scan to reduce Heartbeat cost.
                local scanEvery = 0.12
                local scanAccum = scanEvery
                local cachedTarget, cachedDist = nil, math.huge

                local function refreshTarget()
                    cachedTarget, cachedDist = getClosestPlayer()
                end

                local function getValidTarget()
                    local tp = cachedTarget
                    if not tp then return nil, math.huge end
                    local tChar = tp.Character
                    local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart")
                    if not tHrp then return nil, math.huge end
                    return tp, cachedDist
                end

                local function disconnectAutoContest()
                    if _G.AutoContestConnection then _G.AutoContestConnection:Disconnect(); _G.AutoContestConnection = nil end
                    if _G.AutoContestCharConn then _G.AutoContestCharConn:Disconnect(); _G.AutoContestCharConn = nil end
                end

                disconnectAutoContest()

                _G.AutoContestCharConn = lp.CharacterAdded:Connect(function(newChar)
                    char = newChar
                    hrp = char:WaitForChild("HumanoidRootPart")
                    LOCKED_Y = hrp.Position.Y
                    cachedTarget, cachedDist = nil, math.huge
                    scanAccum = scanEvery
                end)

                _G.AutoContestConnection = RunService.Heartbeat:Connect(function(dt)
                    -- Check if we're guarding someone
                    local guardingPlayer = char:GetAttribute("Guarding")
                    if not guardingPlayer then return end
                    if not hrp or not hrp.Parent then return end

                    scanAccum += (dt or 0)
                    if scanAccum >= scanEvery then
                        scanAccum = 0
                        refreshTarget()
                    end

                    local targetPlayer, dist = getValidTarget()
                    if not targetPlayer then return end
                    if dist > RANGE then return end
                    if not isActionShootingOrDunking(targetPlayer) then return end
                    
                    -- Only contest if we're guarding the player who is shooting/dunking
                    if guardingPlayer ~= targetPlayer.Name then return end

                    local targetRoot = targetPlayer.Character.HumanoidRootPart
                    local facePos = targetRoot.Position + (targetRoot.CFrame.LookVector * FRONT_OFFSET)

                    -- Use the locked Y position
                    facePos = Vector3.new(facePos.X, LOCKED_Y, facePos.Z)

                    local goal = CFrame.new(
                        facePos,
                        Vector3.new(targetRoot.Position.X, LOCKED_Y, targetRoot.Position.Z)
                    )

                    hrp.CFrame = hrp.CFrame:Lerp(goal, LERP_SPEED)
                end)
            else
                -- Clear global flag
                getgenv().AutoContestActive = false
                
                -- Disconnect the Heartbeat connection when toggle is turned off
                if _G.AutoContestConnection then _G.AutoContestConnection:Disconnect(); _G.AutoContestConnection = nil end
                if _G.AutoContestCharConn then _G.AutoContestCharConn:Disconnect(); _G.AutoContestCharConn = nil end
            end
        end
    })

Tabs.Defense:AddSection("Blocking")
    -- Auto Block (block dunk attempts by auto jump+sprint burst)
    getgenv().AutoBlockMaxRange = getgenv().AutoBlockMaxRange or 20

    Tabs.Defense:CreateToggle("AutoBlockToggle", {
        Title = "Auto Block",
        Default = false,
        Callback = function(enabled)
            local function disconnectAutoBlock()
                if _G.AutoBlockScanConn then _G.AutoBlockScanConn:Disconnect(); _G.AutoBlockScanConn = nil end
                if _G.AutoBlockMyCharConn then _G.AutoBlockMyCharConn:Disconnect(); _G.AutoBlockMyCharConn = nil end
                if _G.AutoBlockTargetCharConn then _G.AutoBlockTargetCharConn:Disconnect(); _G.AutoBlockTargetCharConn = nil end
                if _G.AutoBlockTargetAttrConn then _G.AutoBlockTargetAttrConn:Disconnect(); _G.AutoBlockTargetAttrConn = nil end
                _G.AutoBlockTarget = nil
                pcall(function()
                    game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.W, false, game)
                end)
            end

            if not enabled then
                disconnectAutoBlock()
                return
            end

            disconnectAutoBlock()

            local VIM = game:GetService("VirtualInputManager")
            local LP = Players.LocalPlayer
            local remote = ReplicatedStorage.Remotes.Server.Action

            local SCAN_INTERVAL = 0.2
            local lastScan = 0
            local currentTarget = nil

            local JUMP_PAYLOAD = {Action = "Jump", Jump = true}
            local SPRINT_ON = {Sprinting = true, Type = "Sprint"}
            local SPRINT_OFF = {Sprinting = false, Type = "Sprint"}

            local function pressW() VIM:SendKeyEvent(true, Enum.KeyCode.W, false, game) end
            local function releaseW() VIM:SendKeyEvent(false, Enum.KeyCode.W, false, game) end

            local function onDunk()
                pressW()
                remote:FireServer(SPRINT_ON)
                remote:FireServer(JUMP_PAYLOAD)
                remote:FireServer(SPRINT_OFF)
                releaseW()
            end

            local function watchChar(char)
                if _G.AutoBlockTargetAttrConn then _G.AutoBlockTargetAttrConn:Disconnect(); _G.AutoBlockTargetAttrConn = nil end
                if not char then return end
                _G.AutoBlockTargetAttrConn = char:GetAttributeChangedSignal("Action"):Connect(function()
                    if currentTarget and char:GetAttribute("Action") == "Dunking" then
                        onDunk()
                    end
                end)
            end

            local function watchTarget(player)
                if _G.AutoBlockTargetCharConn then _G.AutoBlockTargetCharConn:Disconnect(); _G.AutoBlockTargetCharConn = nil end
                if _G.AutoBlockTargetAttrConn then _G.AutoBlockTargetAttrConn:Disconnect(); _G.AutoBlockTargetAttrConn = nil end

                currentTarget = player
                _G.AutoBlockTarget = player
                if not player then return end

                if player.Character then
                    watchChar(player.Character)
                end
                _G.AutoBlockTargetCharConn = player.CharacterAdded:Connect(function(char)
                    if currentTarget == player then
                        watchChar(char)
                    end
                end)
            end

            _G.AutoBlockMyCharConn = LP.CharacterAdded:Connect(function()
                releaseW()
                currentTarget = nil
                _G.AutoBlockTarget = nil
            end)

            _G.AutoBlockScanConn = RunService.Heartbeat:Connect(function()
                local now = os.clock()
                if now - lastScan < SCAN_INTERVAL then return end
                lastScan = now

                local myChar = LP.Character
                local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if not myRoot then return end

                local closest, minDist = nil, math.huge
                local maxRange = getgenv().AutoBlockMaxRange or 20

                for _, p in Players:GetPlayers() do
                    if p ~= LP then
                        local tChar = p.Character
                        local root = tChar and tChar:FindFirstChild("HumanoidRootPart")
                        if root and tChar:FindFirstChild("Ball") then
                            local d = (myRoot.Position - root.Position).Magnitude
                            if d < minDist and d <= maxRange then
                                minDist, closest = d, p
                            end
                        end
                    end
                end

                if closest ~= currentTarget then
                    watchTarget(closest)
                end
            end)
        end
    })

    Tabs.Defense:CreateSlider("AutoBlockRangeSlider", {
        Title = "Auto Block Range",
        Min = 5,
        Max = 10,
        Default = getgenv().AutoBlockMaxRange,
        Rounding = 1,
        Callback = function(value)
            getgenv().AutoBlockMaxRange = value
        end
    })

    Tabs.Defense:CreateParagraph("Defense_AutoBlockNote", { Title = "Note", Content = "Auto block: only for dunks." })
end



    do -- AvatarTab
    local Players = game:GetService("Players")
    local HttpService = game:GetService("HttpService")
    local LocalPlayer = Players.LocalPlayer

    local PreserveBodyParts = false

    local function apply_avatar(UserId)
        local character = LocalPlayer.Character
        if not character then return end
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid then return end

        pcall(function()
            workspace[LocalPlayer.Name].Camera.Disabled = true
        end)

        local success = pcall(function()
            local description = Players:GetHumanoidDescriptionFromUserIdAsync(UserId)
            local current_desc = humanoid:GetAppliedDescription()
            
            -- Preserve original animations
            description.ClimbAnimation = current_desc.ClimbAnimation
            description.FallAnimation = current_desc.FallAnimation
            description.IdleAnimation = current_desc.IdleAnimation
            description.JumpAnimation = current_desc.JumpAnimation
            description.RunAnimation = current_desc.RunAnimation
            description.SwimAnimation = current_desc.SwimAnimation
            description.WalkAnimation = current_desc.WalkAnimation
            
            -- Preserve original scales
            description.DepthScale = current_desc.DepthScale
            description.HeadScale = current_desc.HeadScale
            description.HeightScale = current_desc.HeightScale
            description.ProportionScale = current_desc.ProportionScale
            description.WidthScale = current_desc.WidthScale
            description.BodyTypeScale = current_desc.BodyTypeScale
            
            if PreserveBodyParts then
                description.Head = current_desc.Head
                description.Torso = current_desc.Torso
                description.LeftArm = current_desc.LeftArm
                description.RightArm = current_desc.RightArm
                description.LeftLeg = current_desc.LeftLeg
                description.RightLeg = current_desc.RightLeg
            end
            
            -- Remove ALL existing shirts, pants, and accessories
            for _, item in ipairs(character:GetChildren()) do
                if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("Accessory") or item:IsA("ShirtGraphic") or item:IsA("CharacterMesh") then
                    item:Destroy()
                end
            end

            humanoid:ApplyDescriptionClientServer(description)
            task.wait(0.1)
            workspace.CurrentCamera.CameraSubject = humanoid
        end)

        pcall(function()
            workspace[LocalPlayer.Name].Camera.Disabled = false
        end)
    end

    local function reset_avatar()
        apply_avatar(LocalPlayer.UserId)
    end

    Tabs.Avatar:AddSection("Avatar Changer")

    Tabs.Avatar:CreateToggle("Player_PreserveBodyParts", {
        Title = "Preserve Body Parts",
        Default = false,
        Callback = function(Value)
            PreserveBodyParts = Value
        end
    })

    local targetUserId = 0
    Tabs.Avatar:CreateInput("Player_UserIdInput", {
        Title = "User ID",
        Default = "",
        PlaceholderText = "Enter User ID...",
        Callback = function(Text)
            targetUserId = tonumber(Text) or 0
        end
    })

    Tabs.Avatar:CreateButton({
        Title = "Apply Avatar",
        Callback = function()
            if targetUserId and targetUserId > 0 then
                apply_avatar(targetUserId)
            end
        end
    })

    Tabs.Avatar:CreateButton({
        Title = "Random Avatar",
        Callback = function()
            local random_id = math.random(10000000, 500000000)
            apply_avatar(random_id)
        end
    })

    Tabs.Avatar:CreateButton({
        Title = "Reset to Original",
        Callback = function()
            reset_avatar()
        end
    })

    Tabs.Avatar:CreateButton({
        Title = "Remove Shoes",
        Callback = function()
            local charName = LocalPlayer.Name
            pcall(function() workspace[charName]["PB BasketBall Shoes2"]:Destroy() end)
            pcall(function() workspace[charName]["PB BasketBall Shoes"]:Destroy() end)
        end
    })

    Tabs.Avatar:AddSection("Favorites")
    
    local FavoritesFile = "Favorites.json"
    local Favorites = {}

    if type(isfile) == "function" and type(readfile) == "function" and isfile(FavoritesFile) then 
        local success, data = pcall(function() return HttpService:JSONDecode(readfile(FavoritesFile)) end)
        if success and type(data) == "table" then Favorites = data end
    end

    local function save_favorites()
        if type(writefile) == "function" then
            writefile(FavoritesFile, HttpService:JSONEncode(Favorites))
        end
    end

    local function get_usernames_from_favorites()
        local names = {}
        for i, id in ipairs(Favorites) do
            local success, name = pcall(function() return Players:GetNameFromUserIdAsync(id) end)
            if success and name then
                table.insert(names, name .. " (" .. id .. ")")
            else
                table.insert(names, "User (" .. id .. ")")
            end
        end
        if #names == 0 then table.insert(names, "No Favorites") end
        return names
    end

    local favDropdown
    
    local function refresh_dropdown()
        if favDropdown then
            local vals = get_usernames_from_favorites()
            if not pcall(function() favDropdown:Refresh(vals, true) end) then
                if not pcall(function() favDropdown:SetValues(vals) end) then
                    pcall(function() favDropdown.Values = vals; favDropdown:Update() end)
                end
            end
        end
    end
    
    Tabs.Avatar:CreateButton({
        Title = "Add Target ID to Favorites",
        Callback = function()
            if targetUserId and targetUserId > 0 then
                for i = 1, #Favorites do
                    if Favorites[i] == targetUserId then return end
                end
                table.insert(Favorites, targetUserId)
                save_favorites()
                refresh_dropdown()
            end
        end
    })

    local selectedFavoriteId = 0
    favDropdown = Tabs.Avatar:CreateDropdown("Player_FavDropdown", {
        Title = "Saved Favorites",
        Values = get_usernames_from_favorites(),
        Multi = false,
        Default = 1,
        Callback = function(Option)
            local idStr = string.match(Option, "%((%d+)%)")
            if idStr then
                selectedFavoriteId = tonumber(idStr)
            end
        end
    })

    Tabs.Avatar:CreateButton({
        Title = "Apply Selected Favorite",
        Callback = function()
            if selectedFavoriteId and selectedFavoriteId > 0 then
                apply_avatar(selectedFavoriteId)
            end
        end
    })

    Tabs.Avatar:CreateButton({
        Title = "Remove Selected Favorite",
        Callback = function()
            if selectedFavoriteId and selectedFavoriteId > 0 then
                for i = 1, #Favorites do
                    if Favorites[i] == selectedFavoriteId then
                        table.remove(Favorites, i)
                        save_favorites()
                        selectedFavoriteId = 0
                        refresh_dropdown()
                        break
                    end
                end
            end
        end
    })
end





InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

Library:Notify{
    Title = "vanta.gg",
    Content = "Playground Basketball loaded.",
    Duration = 5,
}

SaveManager:LoadAutoloadConfig()
end
