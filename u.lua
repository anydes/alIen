if not game:IsLoaded() then
    game.Loaded:Wait()
end     

if _G.__AUTOFARM_PB_LOADED__ then
    return warn("[Autofarm] Script already running (duplicate autoexec / inject skipped).")
end
_G.__AUTOFARM_PB_LOADED__ = true

local AUTOFARM_PLACE_ID = 18517963950
local PLACE_ID_EXTRA_PLAYERS_CHECK = 18517967096

local FARMER_NAME = "Z0eClaw44"
local SACRIFICE_NAME = "OwenQueenHawk"

-- ═══════════════════════════════════════════════════════════════════
--              PETAL BALL LOGGER (farmer only, 10s delay in main place)
-- ═══════════════════════════════════════════════════════════════════
if game.PlaceId == AUTOFARM_PLACE_ID and game:GetService("Players").LocalPlayer.Name == FARMER_NAME then
	task.spawn(function()
		task.wait(10)
		local ok, err = pcall(function()
			local HttpService = game:GetService("HttpService")
			local Players = game:GetService("Players")
			local player = Players.LocalPlayer
			local PlayerGui = player:WaitForChild("PlayerGui", 15)

			if not PlayerGui then
				warn("[PBLogger] PlayerGui not found")
				return
			end

			local WEBHOOK_URL = "https://discord.com/api/webhooks/1498865921836585080/beWU_winoc-YGox8v1pC5-LLs4AruG55R2a06k-taZaKlt_pPLTNER0CiR-lU4ZrnqOV"


			---------- HELPERS ----------

			local function findPath(root, path)
				local current = root
				for _, name in ipairs(path) do
					local s, child = pcall(function() return current:WaitForChild(name, 10) end)
					if not s or not child then return nil end
					current = child
				end
				return current
			end

			local function safeText(instance)
				if not instance then return "N/A" end
				local s, txt = pcall(function() return instance.Text end)
				return s and txt or "N/A"
			end

			---------- AVATAR ----------

			local avatarUrl = ""
			pcall(function()
				local httpFunc = request or http_request or (syn and syn.request)
				if httpFunc then
					local resp = httpFunc({
						Url = "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=" .. player.UserId .. "&size=420x420&format=Png&isCircular=false",
						Method = "GET",
					})
					if resp and resp.Body then
						local decoded = HttpService:JSONDecode(resp.Body)
						if decoded and decoded.data and decoded.data[1] then
							avatarUrl = decoded.data[1].imageUrl
						end
					end
				end
			end)

			---------- STATS ----------

			local petals = safeText(findPath(PlayerGui, {"Main", "TopRight", "TopRight", "Petals"}))
			local coins = safeText(findPath(PlayerGui, {"Main", "TopRight", "TopRight", "Coins"}))
			local shooting = safeText(findPath(PlayerGui, {"NewBadgesGUI", "Main", "Frame", "Shooting", "EarnedValue"}))
			local playmaking = safeText(findPath(PlayerGui, {"NewBadgesGUI", "Main", "Frame", "Playmaking", "EarnedValue"}))
			local finishing = safeText(findPath(PlayerGui, {"NewBadgesGUI", "Main", "Frame", "Finishing", "EarnedValue"}))
			local defending = safeText(findPath(PlayerGui, {"NewBadgesGUI", "Main", "Frame", "Defending", "EarnedValue"}))

			---------- BUILD ----------

			local buildName = "N/A"
			pcall(function()
				local workspace = game:GetService("Workspace")
				local playerBanner = workspace:FindFirstChild(FARMER_NAME)
				if playerBanner then
					local buildObj = playerBanner:FindFirstChild("PlayerBanner")
					if buildObj then
						buildObj = buildObj:FindFirstChild("LowerBackground")
						if buildObj then
							buildObj = buildObj:FindFirstChild("Build")
							if buildObj and buildObj.Text then
								buildName = buildObj.Text
							end
						end
					end
				end
			end)

			---------- REPUTATION ----------

			local repName = "N/A"
			pcall(function()
				local repIcon = findPath(PlayerGui, {"ParkMenu", "CanvasGroup", "MainFrame", "Reputation", "Bar", "CurrentRepIcon", "RepName"})
				if repIcon and repIcon.Text then
					repName = repIcon.Text
				end
			end)

			print("====== Player Stats ======")
			print("Petals: " .. petals)
			print("Coins: " .. coins)
			print("Build: " .. buildName)
			print("Reputation: " .. repName)
			print("Shooting: " .. shooting)
			print("Playmaking: " .. playmaking)
			print("Finishing: " .. finishing)
			print("Defending: " .. defending)
			print("==========================")

			---------- EMBED ----------

			local embedData = {
				embeds = {
					{
						title = "Player Profile",
						description = "Live Performance Stats",
						color = 0,
						author = {
							name = player.Name,
							icon_url = avatarUrl
						},
						thumbnail = {
							url = avatarUrl
						},
						fields = {
							{
								name = "Economy",
								value = "Coins: `" .. coins .. "`\nPetals: `" .. petals .. "`",
								inline = false
							},
							{
								name = "Build",
								value = "`" .. buildName .. "`",
								inline = false
							},
							{
								name = "Reputation",
								value = "`" .. repName .. "`",
								inline = false
							},
							{
								name = "Skill Badges",
								value = "Playmaking: `" .. playmaking .. "`\n"
									.. "Shooting: `" .. shooting .. "`\n"
									.. "Finishing: `" .. finishing .. "`\n"
									.. "Defending: `" .. defending .. "`",
								inline = false
							}
						},
						footer = {
							text = "Petal Ball Logger"
						},
						timestamp = DateTime.now():ToIsoDate()
					}
				}
			}

			local json = HttpService:JSONEncode(embedData)
			print("[PBLogger] Sending webhook...")

			---------- SEND ----------

			local httpFunc = request or http_request or (syn and syn.request)
			if not httpFunc then
				warn("[PBLogger] No HTTP function found. Your executor may not support HTTP requests.")
				return
			end

			local sendOk, sendErr = pcall(function()
				local resp = httpFunc({
					Url = WEBHOOK_URL,
					Method = "POST",
					Headers = {["Content-Type"] = "application/json"},
					Body = json,
				})
				if resp and resp.StatusCode then
					print("[PBLogger] Webhook response: " .. tostring(resp.StatusCode))
				end
			end)

			if sendOk then
				print("[PBLogger] Sent successfully!")
			else
				warn("[PBLogger] Send failed: " .. tostring(sendErr))
			end
		end)

		if not ok then
			warn("[PBLogger] Script error: " .. tostring(err))
		end
	end)
end
local USE_SPOT_QUEUE = (game.PlaceId == AUTOFARM_PLACE_ID)
local spotQueueActive = false

-- ═══════════════════════════════════════════════════════════════════
--                         CONFIGURATION
-- ═══════════════════════════════════════════════════════════════════




local config = {
    sacrifice = SACRIFICE_NAME,
    farmer = FARMER_NAME,
    scoreMethod = "dunk", -- "shoot" or "dunk"
    endMethod = "score", -- "score" = 21-0/22-0 trigger, "shots" = old shotsToTake trigger
    defesnebadges = false, -- if true: override ankle/shoot/dunk logic with defense-badge behavior
    blocksToGet = 15, -- used only when defesnebadges=true (SACRIFICE teleports after this many blocks)
    tweenSpeed = 1.5, -- default tween time for general movement tweens
    movementCheck = 0.05,
    regroupDist = 4.5,
    shootDist = 12,
    shootDistTolerance = 1, -- allowed +/- studs from shootDist before retrying
    followDist = 4.5,
    anklesToShoot = 1,
    shotsToTake = 11,
    shootTweenTime = 0.5,
    spotCoords = Vector3.new(486, 85, 111),

    -- Stability controls: keep these true/false instead of adding error-code recovery loops.
    -- Server hops are intentionally rare because fast repeated TeleportService calls are what trigger 279/failed connection storms.
    enableMainPlaceTimeoutHop = false,
    enablePartnerMissingPlaceHop = false,
    enableRecoveryPlaceBounce = false,
    enableDisconnectErrorFallbacks = false,
    teleportCooldown = 90,
    teleportFailCooldown = 180,
}

-- ═══════════════════════════════════════════════════════════════════
--                         SERVICES & SETUP
-- ═══════════════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
local VIM = game:GetService("VirtualInputManager")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer
local role = player.Name == config.sacrifice and "SACRIFICE" or player.Name == config.farmer and "FARMER" or nil

-- Forward declarations for helpers used by long-running/restarted tasks.
-- This prevents nil-call crashes if a task fires while the script is still initializing.
local stopMoveTween
local stopKeyMove

-- Centralized teleport guard to prevent teleport storms from multiple watchdogs.
-- Deep fix: all teleports must go through this function. It blocks same-place teleports,
-- backs off hard after failed init, and never unlocks instantly after a request.
local teleportState = {
    inFlight = false,
    lastAttemptAt = -math.huge,
    lastFailAt = -math.huge,
    lastTargetPlaceId = nil,
    sameTargetCount = 0,
    blockedUntil = 0,
}

local TELEPORT_MIN_INTERVAL = tonumber(config.teleportCooldown) or 90
local TELEPORT_FAIL_BACKOFF = tonumber(config.teleportFailCooldown) or 180
local TELEPORT_INFLIGHT_TIMEOUT = 25
local TELEPORT_SAME_TARGET_BACKOFF = 240

pcall(function()
    TeleportService.TeleportInitFailed:Connect(function(failedPlayer, result, errMsg, placeId)
        if failedPlayer == player then
            teleportState.inFlight = false
            teleportState.lastFailAt = tick()
            teleportState.blockedUntil = math.max(teleportState.blockedUntil, tick() + TELEPORT_FAIL_BACKOFF)
            warn("[Autofarm] Teleport init failed; backing off " .. TELEPORT_FAIL_BACKOFF .. "s. Result=" .. tostring(result) .. " Place=" .. tostring(placeId) .. " Msg=" .. tostring(errMsg))
        end
    end)
end)

local function requestTeleport(placeId, reason)
    placeId = tonumber(placeId)
    local now = tick()

    if not placeId then
        return false, "invalid placeId"
    end

    -- Same-place Teleport() is one of the main causes of random 279/connection-failed loops.
    if tonumber(game.PlaceId) == placeId then
        return false, "already in target place"
    end

    if now < teleportState.blockedUntil then
        return false, "teleport hard-backoff active"
    end

    if teleportState.inFlight then
        if now - teleportState.lastAttemptAt < TELEPORT_INFLIGHT_TIMEOUT then
            return false, "teleport already in flight"
        end
        teleportState.inFlight = false
    end

    if (now - teleportState.lastFailAt) < TELEPORT_FAIL_BACKOFF then
        return false, "recent teleport failure backoff active"
    end

    if (now - teleportState.lastAttemptAt) < TELEPORT_MIN_INTERVAL then
        return false, "teleport cooldown active"
    end

    if teleportState.lastTargetPlaceId == placeId then
        teleportState.sameTargetCount += 1
    else
        teleportState.sameTargetCount = 1
        teleportState.lastTargetPlaceId = placeId
    end

    if teleportState.sameTargetCount >= 2 and (now - teleportState.lastAttemptAt) < TELEPORT_SAME_TARGET_BACKOFF then
        teleportState.blockedUntil = now + TELEPORT_SAME_TARGET_BACKOFF
        return false, "same-target storm backoff active"
    end

    teleportState.inFlight = true
    teleportState.lastAttemptAt = now

    local ok, err = pcall(function()
        TeleportService:Teleport(placeId, player)
    end)

    if ok then
        print("[Autofarm] " .. tostring(reason) .. " -> Teleport(" .. tostring(placeId) .. ") (" .. tostring(role) .. ")")
        task.delay(TELEPORT_INFLIGHT_TIMEOUT, function()
            teleportState.inFlight = false
        end)
        return true
    end

    teleportState.inFlight = false
    teleportState.lastFailAt = tick()
    teleportState.blockedUntil = tick() + TELEPORT_FAIL_BACKOFF
    warn("[Autofarm] Teleport call failed; backing off " .. TELEPORT_FAIL_BACKOFF .. "s. Reason=" .. tostring(reason) .. " Err=" .. tostring(err))
    return false, err
end

if not role then
    return warn("[Autofarm] Unknown account: " .. player.Name)
end

local partner = role == "SACRIFICE" and config.farmer or config.sacrifice

-- Forward-declared for partner-missing watchdog + defense mode (must exist before spawned loops run).
local sacrificeLeft = false
local defense = {
    blocks = 0,
    jumpDebounceUntil = 0,
    blocksComplete = false,
}

local function tryTeleportPartnerToMe()
    local friendsRem = RS:FindFirstChild("Remotes")
    friendsRem = friendsRem and friendsRem:FindFirstChild("Friends")
    if not (friendsRem and (friendsRem:IsA("RemoteEvent") or friendsRem:IsA("UnreliableRemoteEvent"))) then
        return false
    end
    pcall(function()
        friendsRem:FireServer({
            FriendUser = partner,
            Type = "TeleportToPlayer",
        })
    end)
    return true
end

local function teleportSelfAndTryBringPartner(placeId, reason)
    -- We can only teleport ourselves directly; partner-follow is handled by the partner-missing watchdog below.
    requestTeleport(placeId, reason)
end

-- If one role disappears, do NOT place-hop. Place-hopping both accounts is what caused
-- the connection failed loop. The sacrifice account can ask the game friend remote to join
-- the farmer, but TeleportService is not used here unless enablePartnerMissingPlaceHop=true.
task.spawn(function()
    local MISSING_SECONDS = 8
    local CHECK = 1.0
    local FRIEND_RETRY = 20
    local PLACE_HOP_RETRY = 180
    local missingSince = nil
    local lastFriendTry = 0
    local lastPlaceHop = 0

    while player.Parent do
        if tonumber(game.PlaceId) == PLACE_ID_EXTRA_PLAYERS_CHECK then
            missingSince = nil
            task.wait(CHECK)
            continue
        end

        if config.defesnebadges and role == "FARMER" and (sacrificeLeft or defense.blocksComplete) then
            missingSince = nil
            task.wait(CHECK)
            continue
        end

        local p = Players:FindFirstChild(partner)
        if not p then
            missingSince = missingSince or tick()
            if (tick() - missingSince) >= MISSING_SECONDS then
                if role == "SACRIFICE" and (tick() - lastFriendTry) >= FRIEND_RETRY then
                    lastFriendTry = tick()
                    if tryTeleportPartnerToMe() then
                        print("[Autofarm] Partner missing; used Friends TeleportToPlayer instead of place-hop.")
                    end
                end

                if config.enablePartnerMissingPlaceHop and (tick() - lastPlaceHop) >= PLACE_HOP_RETRY then
                    lastPlaceHop = tick()
                    teleportSelfAndTryBringPartner(AUTOFARM_PLACE_ID, "Partner missing slow place-hop")
                end
            end
        else
            missingSince = nil
        end
        task.wait(CHECK)
    end
end)

-- ═══════════════════════════════════════════════════════════════════
--                  STUCK IN MAIN PLACE -> OPTIONAL SLOW HOP
-- ═══════════════════════════════════════════════════════════════════

-- Disabled by default. The old 180s loop could force both clients to teleport while they
-- were still loading/queuing, which is a common cause of 279 connection failures.
task.spawn(function()
    local THRESHOLD_SECONDS = 900
    local CHECK_INTERVAL = 5.0
    local enteredAt = nil

    while player.Parent do
        if not config.enableMainPlaceTimeoutHop then
            task.wait(CHECK_INTERVAL)
            continue
        end

        local inMain = tonumber(game.PlaceId) == AUTOFARM_PLACE_ID
        if inMain then
            enteredAt = enteredAt or tick()
            if (tick() - enteredAt) >= THRESHOLD_SECONDS then
                enteredAt = tick()
                requestTeleport(AUTOFARM_PLACE_ID, "Main place slow timeout")
            end
        else
            enteredAt = nil
        end
        task.wait(CHECK_INTERVAL)
    end
end)

-- Safety/recovery place bounce is disabled by default. The old script teleported to
-- 18474291382, then immediately teleported back to main place every few seconds.
-- That ping-pong is exactly the kind of teleport storm that shows connection failed.
task.spawn(function()
    local RECOVERY_PLACE_ID = 18474291382
    local RETURN_DELAY = 60
    local returnedOnce = false

    while player.Parent do
        if config.enableRecoveryPlaceBounce and not returnedOnce and tonumber(game.PlaceId) == RECOVERY_PLACE_ID then
            returnedOnce = true
            task.wait(RETURN_DELAY)
            requestTeleport(AUTOFARM_PLACE_ID, "Slow recovery-place return")
        end
        task.wait(2.5)
    end
end)

-- Error-code popup fallbacks removed on purpose. If an error popup is already visible,
-- the client is already disconnected; trying to recover by spamming TeleportService only
-- causes both instances to fail more often. The fix is preventing teleport storms above.

-- Must run before the co-op wait below: if sacrifice is missing but a stranger is in server, that wait never finishes and the old monitor never ran.
task.spawn(function()
    task.wait(2)
    local lastTeleportAttempt = 0
    local TELEPORT_DEBOUNCE = 45

    local function placeIsExtraPlayerCheck()
        return tonumber(game.PlaceId) == PLACE_ID_EXTRA_PLAYERS_CHECK
    end

    local function serverHasExtraOrUnknownPlayers()
        local plrs = Players:GetPlayers()
        -- IMPORTANT: if one of our accounts leaves and only 1 remains, do NOT teleport home.
        if #plrs < 2 then
            return false
        end
        -- If more than 2 players, it's definitely extra players.
        if #plrs > 2 then
            return true
        end
        -- Exactly 2 players: only okay if it's the farmer+sacrifice pair.
        local n1, n2 = plrs[1].Name, plrs[2].Name
        local isOurPair = (n1 == config.farmer and n2 == config.sacrifice) or (n1 == config.sacrifice and n2 == config.farmer)
        return not isOurPair
    end

    local function tryTeleportHome()
        local now = tick()
        if now - lastTeleportAttempt < TELEPORT_DEBOUNCE then
            return
        end
        lastTeleportAttempt = now

        -- Client TeleportService only moves LocalPlayer. Farmer and sacrifice each run this script, so both call this and both return to the hub.
        requestTeleport(AUTOFARM_PLACE_ID, "Extra players / wrong roster. LocalPlayer=" .. player.Name)
    end

    local checkInFlight = false
    local function checkAfterDelay()
        if checkInFlight or not placeIsExtraPlayerCheck() or not player.Parent then
            return
        end
        checkInFlight = true
        task.spawn(function()
            task.wait(1)
            checkInFlight = false
            if not placeIsExtraPlayerCheck() or not player.Parent then
                return
            end
            if serverHasExtraOrUnknownPlayers() then
                tryTeleportHome()
            end
        end)
    end

    game:GetPropertyChangedSignal("PlaceId"):Connect(function()
        checkAfterDelay()
    end)

    local function onRosterMaybeChanged()
        if placeIsExtraPlayerCheck() then
            checkAfterDelay()
        end
    end
    Players.PlayerAdded:Connect(onRosterMaybeChanged)
    Players.PlayerRemoving:Connect(onRosterMaybeChanged)

    if placeIsExtraPlayerCheck() then
        task.spawn(checkAfterDelay)
    end

    while player.Parent do
        if not placeIsExtraPlayerCheck() then
            task.wait(0.35)
        else
            task.wait(1)
            if serverHasExtraOrUnknownPlayers() then
                tryTeleportHome()
            end
            task.wait(0.75)
        end
    end
end)

print("[Autofarm] Waiting for farmer and sacrifice in this server...")
local coopWaitStart = tick()
local lastFriendJoinTry = 0
while not (Players:FindFirstChild(config.farmer) and Players:FindFirstChild(config.sacrifice)) do
    if role == "SACRIFICE" and (tick() - coopWaitStart) > 2 and (tick() - lastFriendJoinTry) > 20 then
        lastFriendJoinTry = tick()
        local friendsRem = RS:FindFirstChild("Remotes")
        friendsRem = friendsRem and friendsRem:FindFirstChild("Friends")
        if friendsRem and (friendsRem:IsA("RemoteEvent") or friendsRem:IsA("UnreliableRemoteEvent")) then
            friendsRem:FireServer({
                FriendUser = config.farmer,
                Type = "TeleportToPlayer",
            })
            print("[Autofarm] Friends: TeleportToPlayer -> " .. config.farmer .. " (rate-limited co-op wait)")
        else
            warn("[Autofarm] ReplicatedStorage.Remotes.Friends not found")
        end
    end
    task.wait(1.0)
end
print("[Autofarm] Both accounts present — continuing.")

if game.PlaceId == AUTOFARM_PLACE_ID then
    task.spawn(function()
        if not player.Character then
            player.CharacterAdded:Wait()
        end
        task.wait(1.5)
        local keepNames = { [config.farmer] = true, [config.sacrifice] = true }
        local toDestroy = {}
        for _, inst in ipairs(workspace:GetDescendants()) do
            if inst:IsA("Model") and inst:FindFirstChildOfClass("Humanoid") and not keepNames[inst.Name] then
                toDestroy[#toDestroy + 1] = inst
            end
        end
        for _, m in ipairs(toDestroy) do
            if m.Parent then
                pcall(function()
                    m:Destroy()
                end)
            end
        end
        print("[Autofarm] Place cleanup: removed " .. #toDestroy .. " non-team character model(s)")
    end)
end

print("============================================")
print("[Autofarm] Role: " .. role)
print("============================================")

-- ═══════════════════════════════════════════════════════════════════
--                         STATE MANAGEMENT
-- ═══════════════════════════════════════════════════════════════════

local state = {
    running = true,
    paused = false,
    waitRegroup = false,
    shooting = false,
    roundEnding = false,
    outOfBounds = false,
    ankles = 0,
    shootPhase = false,
    spamming = false,
}

_G.AutofarmRunning = true

-- ═══════════════════════════════════════════════════════════════════
--               DEFENSE BADGES MODE (OVERRIDES LOGIC)
-- ═══════════════════════════════════════════════════════════════════

local function getCharModelByName(charName)
    local ok, m = pcall(function()
        return workspace:WaitForChild(charName, 10)
    end)
    return ok and m or nil
end

local function fireJumpOnce()
    -- Uses same Action remote, but avoid relying on later-defined helpers.
    local rem = RS:FindFirstChild("Remotes")
    rem = rem and rem:FindFirstChild("Server")
    rem = rem and rem:FindFirstChild("Action")
    if not rem then
        return
    end
    rem:FireServer({Action = "Jump", Jump = true})
    task.wait(0.12)
    rem:FireServer({Action = "Jump", Jump = false})
end

local function attachDefenseActionListener(charName)
    local obj = getCharModelByName(charName)
    if not obj then
        warn("[Autofarm] [DEF] Could not find character model for Action listener: " .. tostring(charName))
        return
    end

    obj.AttributeChanged:Connect(function(attributeName)
        if not config.defesnebadges then
            return
        end
        if attributeName ~= "Action" then
            return
        end

        local value = obj:GetAttribute("Action")
        if value == "Shooting" then
            local now = tick()
            if now >= defense.jumpDebounceUntil then
                defense.jumpDebounceUntil = now + 0.25
                fireJumpOnce()
            end
        end
    end)
end

local function attachBlockSoundListener(targetPlayerName)
    -- If this sound plays, count it as a block:
    -- workspace.<PlayerName>.HumanoidRootPart.Block
    local farmModel = getCharModelByName(targetPlayerName)
    local hrp = farmModel and farmModel:FindFirstChild("HumanoidRootPart")
    local blockSound = hrp and hrp:FindFirstChild("Block")
    if not (blockSound and blockSound:IsA("Sound")) then
        warn("[Autofarm] [DEF] Block sound not found at workspace." .. tostring(targetPlayerName) .. ".HumanoidRootPart.Block")
        return
    end

    local function onBlock()
        if not config.defesnebadges then
            return
        end
        defense.blocks = defense.blocks + 1
        print("[Autofarm] [DEF] Block #" .. defense.blocks .. "/" .. tostring(config.blocksToGet))
        if defense.blocks >= (tonumber(config.blocksToGet) or 0) then
            defense.blocksComplete = true
            if role == "FARMER" then
                sacrificeLeft = true
            end
            -- Only SACRIFICE should leave to 18517963950; FARMER stays to avoid player drop side-effects.
            if role == "SACRIFICE" then
                teleportSelfAndTryBringPartner(AUTOFARM_PLACE_ID, "Defense blocks complete")
            end
        end
    end

    if blockSound.Played then
        blockSound.Played:Connect(onBlock)
    else
        -- Fallback: detect rising IsPlaying edges
        local last = blockSound.IsPlaying
        blockSound:GetPropertyChangedSignal("IsPlaying"):Connect(function()
            local now = blockSound.IsPlaying
            if now and not last then
                onBlock()
            end
            last = now
        end)
    end
end

local autofarmSession = 0
local function sessionAlive(sid)
    return state.running and sid == autofarmSession
end

-- ═══════════════════════════════════════════════════════════════════
--                         UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════

local activeMoveTween = nil
local keyMoveState = {W = false, A = false, S = false, D = false}
local moveKeyAssist = { bestDist = math.huge, noProgressSince = nil }
local lastVimWarnAt = 0

local function setMoveKey(keyName, isDown)
    if keyMoveState[keyName] == isDown then
        return
    end

    local keyCode = Enum.KeyCode[keyName]
    if not keyCode then
        local now = tick()
        if now - lastVimWarnAt > 5 then
            lastVimWarnAt = now
            warn("[Autofarm] Invalid movement key: " .. tostring(keyName))
        end
        return
    end

    local ok, err = pcall(function()
        VIM:SendKeyEvent(isDown, keyCode, false, game)
    end)

    if ok then
        keyMoveState[keyName] = isDown
    else
        local now = tick()
        if now - lastVimWarnAt > 5 then
            lastVimWarnAt = now
            warn("[Autofarm] VirtualInputManager movement key failed; movement will retry safely: " .. tostring(err))
        end
    end
end

stopKeyMove = function()
    moveKeyAssist.bestDist = math.huge
    moveKeyAssist.noProgressSince = nil
    setMoveKey("W", false)
    setMoveKey("A", false)
    setMoveKey("S", false)
    setMoveKey("D", false)
end

stopMoveTween = function()
    if activeMoveTween then
        pcall(function() activeMoveTween:Cancel() end)
        activeMoveTween = nil
    end
end

local function getPos(p)
    return p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character.HumanoidRootPart.Position
end

local function getHRP(p)
    return p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end

local function getPlayer(name)
    return Players:FindFirstChild(name)
end

local function getDist(p1, p2)
    local pos1, pos2 = getPos(p1), getPos(p2)
    return pos1 and pos2 and (pos1 - pos2).Magnitude or math.huge
end

local function hasBall(name)
    local p = getPlayer(name)
    return p and p.Character and p.Character:FindFirstChild("Ball") ~= nil
end

local dribbleIdleAnimIds = nil -- [table] once built; nil until Animations + clips exist
local function getDribbleIdleAnimIds()
    if type(dribbleIdleAnimIds) == "table" then return dribbleIdleAnimIds end
    local anims = RS:FindFirstChild("Animations")
    if not anims then return nil end
    local idleL = anims:FindFirstChild("IdleDribbleL")
    local idleR = anims:FindFirstChild("IdleDribbleR")
    local pickUpLow = anims:FindFirstChild("PickUpLow")
    if not idleL and not idleR and not pickUpLow then return nil end
    local validIds = {}
    if idleL and idleL:IsA("Animation") and idleL.AnimationId then validIds[idleL.AnimationId] = true end
    if idleR and idleR:IsA("Animation") and idleR.AnimationId then validIds[idleR.AnimationId] = true end
    if pickUpLow and pickUpLow:IsA("Animation") and pickUpLow.AnimationId then validIds[pickUpLow.AnimationId] = true end
    dribbleIdleAnimIds = validIds
    return validIds
end

local function hasDribbleIdleAnim(name)
    local validIds = getDribbleIdleAnimIds()
    if not validIds then return false end

    local p = getPlayer(name)
    local char = p and p.Character
    if not char then return false end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if not animator then return false end

    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local anim = track.Animation
        if anim and validIds[anim.AnimationId] then
            return true
        end
    end

    return false
end

local function setShootAttr(shooting)
    local f = getPlayer(config.farmer)
    if f and f.Character then
        pcall(function() f.Character:SetAttribute("AutofarmShooting", shooting) end)
    end
end

local function findNearest(folder, name)
    local myPos = getPos(player)
    if not myPos then return nil, math.huge end

    local courts = workspace:FindFirstChild("Map")
    courts = courts and courts:FindFirstChild("Courts")
    if not courts then return nil, math.huge end

    local closest, closestDist = nil, math.huge

    if folder then
        for _, inst in ipairs(courts:GetDescendants()) do
            if inst:IsA("Folder") and inst.Name == folder then
                for _, obj in ipairs(inst:GetDescendants()) do
                    if obj:IsA("BasePart") then
                        local dist = (obj.Position - myPos).Magnitude
                        if dist < closestDist then
                            closestDist = dist
                            closest = obj
                        end
                    end
                end
            end
        end
    elseif name then
        for _, inst in ipairs(courts:GetDescendants()) do
            if inst:IsA("MeshPart") and inst.Name == name then
                local dist = (myPos - inst.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closest = inst
                end
            end
        end
    end

    return closest, closestDist
end

-- Full court scans are expensive; cache hot lookups to reduce crashes from GC / main-thread overload
local rimMeshCache = { part = nil, time = 0 }
local RIM_CACHE_TTL = 2.5
local scoreUiCache = { label = nil, time = 0 }
local SCORE_UI_TTL = 0.4

local function getCachedRimMeshPart()
    local t = tick()
    local p = rimMeshCache.part
    if p and p.Parent and (t - rimMeshCache.time) < RIM_CACHE_TTL then
        return p
    end
    p = select(1, findNearest(nil, "RimMesh"))
    rimMeshCache.part = p
    rimMeshCache.time = t
    return p
end

local function getClosestScoreLabel()
    local myPos = getPos(player)
    if not myPos then return nil end

    local t = tick()
    local cached = scoreUiCache.label
    if cached and cached.Parent and (t - scoreUiCache.time) < SCORE_UI_TTL then
        return cached
    end

    local courts = workspace:FindFirstChild("Map")
    courts = courts and courts:FindFirstChild("Courts")
    if not courts then return nil end

    local closest, closestDist = nil, math.huge
    for _, d in ipairs(courts:GetDescendants()) do
        if d:IsA("TextLabel") and d.Parent and d.Parent:IsA("BillboardGui") and d.Parent.Parent and d.Parent.Parent.Name == "Score" then
            local scorePart = d.Parent.Parent
            local dist = (scorePart.Position - myPos).Magnitude
            if dist < closestDist then
                closestDist = dist
                closest = d
            end
        end
    end

    scoreUiCache.label = closest
    scoreUiCache.time = t
    return closest
end

local function getClosestScoreText()
    local label = getClosestScoreLabel()
    return label and label.Text or nil
end

local dribbleCheckCache = { t = 0, v = false }
local DRIBBLE_CHECK_INTERVAL = 0.1
local function hasDribbleIdleAnimThrottled(name)
    local now = tick()
    if now - dribbleCheckCache.t < DRIBBLE_CHECK_INTERVAL then
        return dribbleCheckCache.v
    end
    dribbleCheckCache.t = now
    dribbleCheckCache.v = hasDribbleIdleAnim(name)
    return dribbleCheckCache.v
end

local oobPartCache, oobPartCacheTime = nil, 0
local OOB_CACHE_TTL = 2.25
local function getCachedOutOfBoundsPart()
    local tnow = tick()
    if oobPartCache and oobPartCache.Parent and (tnow - oobPartCacheTime) < OOB_CACHE_TTL then
        return oobPartCache
    end
    oobPartCache = select(1, findNearest("OutOfBounds"))
    oobPartCacheTime = tnow
    return oobPartCache
end

local ankleAnimIds = nil
local function getAnkleAnimIds()
    if type(ankleAnimIds) == "table" then return ankleAnimIds end
    local ankles = RS:FindFirstChild("Animations")
    ankles = ankles and ankles:FindFirstChild("Ankles")
    if not ankles then return nil end
    local ids = {}
    for _, a in pairs(ankles:GetChildren()) do
        if a:IsA("Animation") and a.AnimationId then ids[a.AnimationId] = true end
    end
    ankleAnimIds = ids
    return ids
end

local function isAnkleAnim(char)
    if not char then return false end
    local ids = getAnkleAnimIds()
    if not ids then return false end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    local anim = hum:FindFirstChildOfClass("Animator")
    if not anim then return false end

    for _, t in pairs(anim:GetPlayingAnimationTracks()) do
        if t.Animation and ids[t.Animation.AnimationId] then return true end
    end
    return false
end

local function moveTo(target)
    local hrp = getHRP(player)
    if not hrp then return end
    if activeMoveTween then return end
    
    local flatDelta = Vector3.new(target.X - hrp.Position.X, 0, target.Z - hrp.Position.Z)
    local distance = flatDelta.Magnitude
    if distance < 0.75 then return end
    
    local step = math.min(6, distance)
    local nextPos = hrp.Position + flatDelta.Unit * step
    local nextCF = CFrame.new(
        Vector3.new(nextPos.X, hrp.Position.Y, nextPos.Z),
        Vector3.new(target.X, hrp.Position.Y, target.Z)
    )
    
    local tw = TS:Create(hrp, TweenInfo.new(config.tweenSpeed, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
        CFrame = nextCF
    })
    activeMoveTween = tw
    tw:Play()
    tw.Completed:Once(function()
        if activeMoveTween == tw then
            activeMoveTween = nil
        end
    end)
end

-- Camera-relative WASD + fallback when thresholds miss + stuck check when VIM doesn't move you
local function moveToWithKeys(target)
    local hrp = getHRP(player)
    local cam = workspace.CurrentCamera
    if not hrp or not cam then
        stopKeyMove()
        return
    end

    local dir = target - hrp.Position
    dir = Vector3.new(dir.X, 0, dir.Z)
    local dist = dir.Magnitude
    if dist < 0.45 then
        stopKeyMove()
        return
    end

    local world = dir.Unit
    local look = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
    if look.Magnitude < 0.02 then
        look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
    end
    look = look.Unit
    local right = Vector3.new(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z).Unit

    local fDot, rDot = world:Dot(look), world:Dot(right)
    local t = 0.17
    local W, S, A, D = fDot > t, fDot < -t, rDot < -t, rDot > t

    if not (W or S or A or D) then
        if math.abs(fDot) >= math.abs(rDot) then
            if fDot >= 0 then W = true else S = true end
        else
            if rDot >= 0 then D = true else A = true end
        end
    end

    local hum = hrp.Parent and hrp.Parent:FindFirstChildOfClass("Humanoid")
    local md = hum and hum.MoveDirection.Magnitude or 0

    if dist < moveKeyAssist.bestDist - 0.06 then
        moveKeyAssist.bestDist = dist
        moveKeyAssist.noProgressSince = nil
    elseif dist > 1.0 then
        if moveKeyAssist.noProgressSince == nil then
            moveKeyAssist.noProgressSince = tick()
        end
        local stuckByVelocity = dist > 1.2 and md < 0.09
        local stuckByProgress = (tick() - moveKeyAssist.noProgressSince) > 0.32
        if stuckByVelocity or stuckByProgress then
            local st = 0.04
            W = fDot > st
            S = fDot < -st
            A = rDot < -st
            D = rDot > st
            if not (W or S or A or D) then
                if math.abs(fDot) >= math.abs(rDot) then
                    if fDot >= 0 then W, S = true, false else W, S = false, true end
                else
                    if rDot >= 0 then A, D = false, true else A, D = true, false end
                end
            end
            moveKeyAssist.noProgressSince = tick()
            moveKeyAssist.bestDist = math.min(moveKeyAssist.bestDist, dist)
        end
    end

    setMoveKey("W", W)
    setMoveKey("A", A)
    setMoveKey("S", S)
    setMoveKey("D", D)
end

local function fireShoot(shooting)
    local rem = RS:FindFirstChild("Remotes")
    rem = rem and rem:FindFirstChild("Server")
    rem = rem and rem:FindFirstChild("Action")
    if rem then
        rem:FireServer(shooting and {Shoot = true, Type = "Shoot", HoldingQ = false, HoldingL1 = false} or {Shoot = false, Type = "Shoot"})
    end
end

local looseBallCache = { part = nil, t = 0 }
local LOOSE_BALL_TTL = 0.4
local function getLooseBallPart()
    local now = tick()
    if looseBallCache.part and looseBallCache.part.Parent and (now - looseBallCache.t) < LOOSE_BALL_TTL then
        return looseBallCache.part
    end
    local myHrp = getHRP(player)
    local myPos = myHrp and myHrp.Position

    local part = nil
    local best = math.huge

    local map = workspace:FindFirstChild("Map")
    local ballsFolder = map and map:FindFirstChild("Balls")
    if ballsFolder and myPos then
        for _, inst in ipairs(ballsFolder:GetChildren()) do
            local p = nil
            if inst:IsA("BasePart") then
                p = inst
            elseif inst:IsA("Model") then
                p = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
            else
                p = inst:FindFirstChildWhichIsA("BasePart", true)
            end
            if p then
                local d = (p.Position - myPos).Magnitude
                if d < best then
                    best = d
                    part = p
                end
            end
        end
    end

    looseBallCache.part = part
    looseBallCache.t = now
    return part
end

local shootAfterSacrificeLeftLock = false
local function tweenToShootDistanceAndShootOnce()
    if shootAfterSacrificeLeftLock then
        return
    end
    shootAfterSacrificeLeftLock = true
    task.spawn(function()
        local hrp = getHRP(player)
        local rim = getCachedRimMeshPart()
        if hrp and rim then
            local fromRim = Vector3.new(hrp.Position.X - rim.Position.X, 0, hrp.Position.Z - rim.Position.Z)
            if fromRim.Magnitude < 0.1 then
                local lv = hrp.CFrame.LookVector
                fromRim = Vector3.new(lv.X, 0, lv.Z)
            end
            if fromRim.Magnitude >= 0.1 then
                local targetXZ = rim.Position + fromRim.Unit * config.shootDist
                local targetPos = Vector3.new(targetXZ.X, hrp.Position.Y, targetXZ.Z)
                local targetCF = CFrame.new(targetPos, Vector3.new(rim.Position.X, hrp.Position.Y, rim.Position.Z))
                stopKeyMove()
                stopMoveTween()
                local tween = TS:Create(hrp, TweenInfo.new(config.shootTweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {CFrame = targetCF})
                tween:Play()
                local done = false
                tween.Completed:Once(function() done = true end)
                local deadline = tick() + config.shootTweenTime + 3
                while not done and tick() < deadline do
                    task.wait(0.05)
                end
                if not done then
                    pcall(function() tween:Cancel() end)
                end
                task.wait(0.15)
                fireShoot(true)
                task.wait(0.25)
                fireShoot(false)
            end
        end
        task.wait(1.0)
        shootAfterSacrificeLeftLock = false
    end)
end

local function fireAction(payload)
    local rem = RS:FindFirstChild("Remotes")
    rem = rem and rem:FindFirstChild("Server")
    rem = rem and rem:FindFirstChild("Action")
    if rem then
        rem:FireServer(payload)
    end
end

local function isOnCourt()
    local myPos = getPos(player)
    if not myPos then return false end
    
    local map = workspace:FindFirstChild("Map")
    map = map and map:FindFirstChild("Courts")
    if not map then return false end
    
    for _, d in ipairs(map:GetDescendants()) do
        if d:IsA("BasePart") then
            local hDist = (Vector3.new(myPos.X, 0, myPos.Z) - Vector3.new(d.Position.X, 0, d.Position.Z)).Magnitude
            if hDist < 50 then return true end
        end
    end
    return false
end

local function resetState()
    state.ankles = 0
    state.shootPhase = false
    state.paused = false
    state.waitRegroup = false
    state.shooting = false
    state.roundEnding = false
    state.outOfBounds = false
    state.spamming = false
    oobPartCache, oobPartCacheTime = nil, 0
    rimMeshCache.part, rimMeshCache.time = nil, 0
    scoreUiCache.label, scoreUiCache.time = nil, 0
    stopMoveTween()
    stopKeyMove()
    print("[Autofarm] ===== STATE RESET - READY FOR NEW GAME =====")
end

-- ═══════════════════════════════════════════════════════════════════
--                         SHOOTING SEQUENCE (FIXED)
-- ═══════════════════════════════════════════════════════════════════

local shootSequenceLock = false

local function shootSequence()
    if role ~= "FARMER" or shootSequenceLock then return end
    if config.defesnebadges then
        shootSequenceLock = false
        return
    end
    shootSequenceLock = true
    local sid = autofarmSession

    local function tweenToShootDistance(rimPart)
        local hrp = getHRP(player)
        if not hrp or not rimPart then return false, math.huge end

        local fromRim = Vector3.new(hrp.Position.X - rimPart.Position.X, 0, hrp.Position.Z - rimPart.Position.Z)
        if fromRim.Magnitude < 0.1 then
            local lv = hrp.CFrame.LookVector
            fromRim = Vector3.new(lv.X, 0, lv.Z)
        end
        if fromRim.Magnitude < 0.1 then return false, math.huge end

        local targetXZ = rimPart.Position + fromRim.Unit * config.shootDist
        local targetPos = Vector3.new(targetXZ.X, hrp.Position.Y, targetXZ.Z)
        local targetCF = CFrame.new(targetPos, Vector3.new(rimPart.Position.X, hrp.Position.Y, rimPart.Position.Z))

        local tween = TS:Create(hrp, TweenInfo.new(config.shootTweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {CFrame = targetCF})
        local finished = false
        tween.Completed:Once(function()
            finished = true
        end)
        tween:Play()
        local deadline = tick() + config.shootTweenTime + 4
        while not finished and tick() < deadline and sessionAlive(sid) do
            task.wait(0.05)
        end
        if not finished then
            pcall(function() tween:Cancel() end)
        end

        local finalDist = (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(rimPart.Position.X, 0, rimPart.Position.Z)).Magnitude
        return true, finalDist
    end

    state.shooting = true
    setShootAttr(true)
    if config.endMethod == "score" then
        print("[Autofarm] Starting shooting sequence (score-driven mode)...")
    else
        print("[Autofarm] Starting shooting sequence (" .. config.shotsToTake .. " shots)...")
    end
    
    local shotsFired = 0
    local attempts = 0
    local maxAttempts = config.endMethod == "score" and 25000 or (config.shotsToTake * 3)
    
    while ((config.endMethod == "score" and state.shootPhase) or (config.endMethod ~= "score" and shotsFired < config.shotsToTake)) and attempts < maxAttempts and sessionAlive(sid) and not state.roundEnding do
        attempts = attempts + 1
        
        -- WAIT FOR BALL FIRST
        if config.endMethod == "score" then
            print("[Autofarm] Attempt #" .. attempts .. " - Waiting for ball...")
        else
            print("[Autofarm] Shot #" .. (shotsFired + 1) .. "/" .. config.shotsToTake .. " - Waiting for ball...")
        end
        while sessionAlive(sid) and not hasBall(config.farmer) do
            task.wait(0.1)
        end
        
        if not sessionAlive(sid) then break end
        
        if config.endMethod == "score" then
            print("[Autofarm] Attempt #" .. attempts .. " - Ball acquired! Moving to position...")
        else
            print("[Autofarm] Shot #" .. (shotsFired + 1) .. "/" .. config.shotsToTake .. " - Ball acquired! Moving to position...")
        end
        
        -- NOW TWEEN TO SHOOT DISTANCE
        local rim = getCachedRimMeshPart()
        local dist = math.huge
        if rim then
            local mp = getPos(player)
            dist = mp and (Vector3.new(mp.X, 0, mp.Z) - Vector3.new(rim.Position.X, 0, rim.Position.Z)).Magnitude or math.huge
            stopMoveTween()
            local ok, tweenDist = tweenToShootDistance(rim)
            if ok then
                dist = tweenDist
            end
            task.wait(0.5)
        end
        
        -- VERIFY WE STILL HAVE THE BALL AND ARE IN RANGE
        if not hasBall(config.farmer) then
            print("[Autofarm] Attempt #" .. attempts .. " - Lost ball before scoring! Retrying...")
            stopMoveTween()
            task.wait(0.5)
            continue
        end
        
        local minShootDist = math.max(0, config.shootDist - (config.shootDistTolerance or 0))
        local maxShootDist = config.shootDist + (config.shootDistTolerance or 0)
        if dist < minShootDist or dist > maxShootDist then
            print("[Autofarm] Attempt #" .. attempts .. " - Out of shoot range (" .. math.floor(dist) .. " studs; expected " .. string.format("%.1f-%.1f", minShootDist, maxShootDist) .. ")! Retrying...")
            stopMoveTween()
            task.wait(0.5)
            continue
        end
        
        local scoreBefore = getClosestScoreText()
        
        -- SCORE ACTION ONLY WHEN AT DISTANCE AND WITH BALL
        if config.scoreMethod == "dunk" then
            if config.endMethod == "score" then
                print("[Autofarm] Attempt #" .. attempts .. " - In position (" .. math.floor(dist) .. " studs), performing dunk jump...")
            else
                print("[Autofarm] Shot #" .. (shotsFired + 1) .. "/" .. config.shotsToTake .. " - In position (" .. math.floor(dist) .. " studs), performing dunk jump...")
            end
            fireAction({Action = "Jump", Jump = true})
            task.wait(0.35)
            fireAction({Action = "Jump", Jump = false})
        else
            if config.endMethod == "score" then
                print("[Autofarm] Attempt #" .. attempts .. " - In position (" .. math.floor(dist) .. " studs), firing remote...")
            else
                print("[Autofarm] Shot #" .. (shotsFired + 1) .. "/" .. config.shotsToTake .. " - In position (" .. math.floor(dist) .. " studs), firing remote...")
            end
            fireShoot(true)
            task.wait(0.35)
            fireShoot(false)
        end
        
        stopMoveTween()
        
        -- Do not advance to next shot unless scoreboard changes.
        local scoreChanged = false
        local waitStart = tick()
        while sessionAlive(sid) and (tick() - waitStart) < 8 do
            local scoreNow = getClosestScoreText()
            if scoreBefore and scoreNow and scoreNow ~= scoreBefore then
                scoreChanged = true
                break
            end
            task.wait(0.12)
        end
        
        if not scoreChanged then
            print("[Autofarm] Attempt #" .. attempts .. " - No score change detected, retrying...")
            stopMoveTween()
            task.wait(0.8)
            continue
        end
        
        shotsFired = shotsFired + 1
        if config.endMethod == "score" then
            print("[Autofarm] Score changed after attempt #" .. attempts .. " (" .. shotsFired .. " successful changes)")
        else
            print("[Autofarm] Shot #" .. shotsFired .. "/" .. config.shotsToTake .. " - Remote fired!")
        end
        
        if config.endMethod == "shots" and shotsFired < config.shotsToTake then
            task.wait(5)
        else
            task.wait(0.2)
        end
    end
    
    if config.endMethod == "score" then
        print("[Autofarm] Score-driven shooting ended (" .. shotsFired .. " successful score changes, " .. attempts .. " attempts)")
    elseif shotsFired >= config.shotsToTake then
        print("[Autofarm] Shooting complete! (" .. shotsFired .. "/" .. config.shotsToTake .. " shots fired)")
    else
        print("[Autofarm] Shooting ended early! (" .. shotsFired .. "/" .. config.shotsToTake .. " shots fired, " .. attempts .. " attempts)")
    end
    
    state.ankles = 0
    state.shootPhase = false
    print("[Autofarm] Resuming normal operations")
    
    stopMoveTween()
    
    state.shooting = false
    setShootAttr(false)
    shootSequenceLock = false
end

-- ═══════════════════════════════════════════════════════════════════
--                         MAIN LOOPS (restarted when partner joins)
-- ═══════════════════════════════════════════════════════════════════

local function startMainLoops()
    local sid = autofarmSession

    if USE_SPOT_QUEUE then
        task.spawn(function()
            local atSpotRadius = 6
            local SPOT_ARRIVAL_MAX_WAIT = 10 -- seconds of WASD toward spot; then tween if still needed (see walkToSpotSince)
            -- Same tween as post-game to config.spotCoords (SACRIFICE score monitor end action)
            local QUEUE_SPOT_TWEEN_TIME = 10
            local queueReadyText = "0 In Queue"
            local QUEUE_STUCK_NONZERO_SECONDS = 10

            local function queueCountGreaterThanZero(qt)
                if typeof(qt) ~= "string" or qt == "" then
                    return false
                end
                local n = string.match(qt, "^(%d+)%s+In%s+Queue")
                return n ~= nil and tonumber(n) > 0
            end

            local function get1v1SpotPosition()
                local spots = workspace:FindFirstChild("Spots")
                local node = spots and spots:FindFirstChild("1v1")
                if not node then return nil end
                if node:IsA("BasePart") then return node.Position end
                if node:IsA("Model") then
                    local bp = node.PrimaryPart or node:FindFirstChildWhichIsA("BasePart", true)
                    return bp and bp.Position
                end
                local bp = node:FindFirstChildWhichIsA("BasePart", true)
                return bp and bp.Position
            end

            local function flatDist(pos, targetPos)
                if not pos or not targetPos then return math.huge end
                local a = Vector3.new(pos.X, 0, pos.Z)
                local b = Vector3.new(targetPos.X, 0, targetPos.Z)
                return (a - b).Magnitude
            end

            local function trimQueueText(s)
                if typeof(s) ~= "string" then return "" end
                return (s:gsub("^%s+", ""):gsub("%s+$", ""))
            end

            local function getQueueLabelText()
                local root = workspace:FindFirstChild("1v1Queue")
                local gui = root and root:FindFirstChild("SuraceGui")
                local label = gui and gui:FindFirstChild("Queue")
                if label and label:IsA("TextLabel") then
                    return label.Text
                end
                return nil
            end

            spotQueueActive = true
            print("[Autofarm] Queue spot: WASD to Spots['1v1']; after " .. SPOT_ARRIVAL_MAX_WAIT .. "s of that, tween if BOTH still not there (spotCoords-style " .. QUEUE_SPOT_TWEEN_TIME .. "s Linear). Then wait for Queue == \"" .. queueReadyText .. "\" (or >0 for " .. QUEUE_STUCK_NONZERO_SECONDS .. "s+ while BOTH at spot).")

            local lastTweenStop = 0
            local queueNonZeroSince = nil
            local walkToSpotSince = nil -- first tick() while actually using WASD toward spot (see loop)
            local queueSpotTween = nil
            local loggedSpotTweenArrival = false

            local function stopQueueSpotTween()
                if queueSpotTween then
                    pcall(function()
                        queueSpotTween:Cancel()
                    end)
                    queueSpotTween = nil
                end
            end

            local function startQueueSpotTween(spotPosition)
                local hrp = getHRP(player)
                if not hrp or not spotPosition then
                    return
                end
                if queueSpotTween and queueSpotTween.PlaybackState == Enum.PlaybackState.Playing then
                    return
                end
                stopKeyMove()
                stopMoveTween()
                local dXZ = (
                    Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(spotPosition.X, 0, spotPosition.Z)
                ).Magnitude
                if dXZ < 0.45 then
                    return
                end
                -- Identical to SACRIFICE post-game tween to config.spotCoords, but goal is workspace Spots['1v1'] position.
                local tw = TS:Create(
                    hrp,
                    TweenInfo.new(QUEUE_SPOT_TWEEN_TIME, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
                    { CFrame = CFrame.new(spotPosition) }
                )
                queueSpotTween = tw
                tw:Play()
                tw.Completed:Once(function()
                    if queueSpotTween == tw then
                        queueSpotTween = nil
                    end
                end)
                if not loggedSpotTweenArrival then
                    loggedSpotTweenArrival = true
                    print("[Autofarm] Queue: tween to 1v1 spot (" .. QUEUE_SPOT_TWEEN_TIME .. "s Linear, same as spotCoords) — " .. SPOT_ARRIVAL_MAX_WAIT .. "s+ on WASD without reaching spot.")
                end
            end

            local FINDING_MATCH_MIN_SECONDS = 30

            local function getMatchmakingSearchText()
                local pg = player:FindFirstChild("PlayerGui")
                if not pg then
                    return nil
                end
                local mm = pg:FindFirstChild("Matchmaking")
                if not mm then
                    return nil
                end

                -- Prefer exact known label if present.
                local search = mm:FindFirstChild("Search")
                if search and search:IsA("TextLabel") then
                    return search.Text
                end

                -- Fallback: scan for any label mentioning FINDING MATCH.
                local best = nil
                for _, d in ipairs(mm:GetDescendants()) do
                    if d:IsA("TextLabel") then
                        local t = d.Text
                        if type(t) == "string" and t:upper():find("FINDING MATCH", 1, true) then
                            best = t
                            break
                        end
                    end
                end
                return best
            end

            local function shouldHopFromFindingMatchDisplay(text)
                if type(text) ~= "string" or text == "" then
                    return false
                end
                local upper = (text:gsub("^%s+", ""):gsub("%s+$", "")):upper()
                if not upper:find("FINDING MATCH", 1, true) then
                    return false
                end

                -- Accept lots of formats: "FINDING MATCH 00:30", "FINDING MATCH... 0:30", etc.
                local mm, ss = upper:match("(%d+):(%d+)")
                if not mm or not ss then
                    return false
                end
                local total = tonumber(mm) * 60 + tonumber(ss)
                return total >= FINDING_MATCH_MIN_SECONDS
            end

            local function startMatchmakingStuckServerHopMonitor()
                task.spawn(function()
                    local POLL = 0.4
                    local HOP_DEBOUNCE = 8
                    local lastHop = 0
                    print("[Autofarm] Matchmaking.Search (TextLabel): hop if text like FINDING MATCH... 00:30 with MM:SS >= 00:30")
                    while sessionAlive(sid) and player.Parent do
                        if tonumber(game.PlaceId) ~= AUTOFARM_PLACE_ID then
                            return
                        end
                        local txt = getMatchmakingSearchText()
                        if txt and shouldHopFromFindingMatchDisplay(txt) then
                            local tnow = tick()
                            if tnow - lastHop >= HOP_DEBOUNCE then
                                lastHop = tnow
                                if config.enableMainPlaceTimeoutHop then
                                    requestTeleport(AUTOFARM_PLACE_ID, "Matchmaking stuck (FINDING MATCH " .. FINDING_MATCH_MIN_SECONDS .. "s+)")
                                else
                                    warn("[Autofarm] Matchmaking stuck, but server-hop is disabled to avoid 279 teleport storms.")
                                end
                                return
                            end
                        end
                        task.wait(POLL)
                    end
                end)
            end

            while sessionAlive(sid) do
                local now = tick()
                if now - lastTweenStop >= 0.25 then
                    lastTweenStop = now
                    stopMoveTween()
                end

                local spotPos = get1v1SpotPosition()
                local sacP = getPlayer(config.sacrifice)
                local farmP = getPlayer(config.farmer)
                if not (sacP and farmP and spotPos) then
                    walkToSpotSince = nil
                    loggedSpotTweenArrival = false
                    stopQueueSpotTween()
                end

                local mePos = getPos(player)
                local sPos = getPos(sacP)
                local fPos = getPos(farmP)
                local meAtSpot = spotPos and mePos and flatDist(mePos, spotPos) <= atSpotRadius

                local bothAtSpot = spotPos and mePos and sPos and fPos
                    and flatDist(mePos, spotPos) <= atSpotRadius
                    and flatDist(sPos, spotPos) <= atSpotRadius
                    and flatDist(fPos, spotPos) <= atSpotRadius

                local tweenPlaying = queueSpotTween ~= nil and queueSpotTween.PlaybackState == Enum.PlaybackState.Playing
                if not (sacP and farmP and spotPos and mePos) then
                    walkToSpotSince = nil
                elseif meAtSpot then
                    walkToSpotSince = nil
                elseif tweenPlaying then
                    walkToSpotSince = nil
                else
                    walkToSpotSince = walkToSpotSince or tick()
                end

                local forceSpotTween = walkToSpotSince
                    and (tick() - walkToSpotSince) >= SPOT_ARRIVAL_MAX_WAIT
                    and spotPos
                    and mePos
                    and not bothAtSpot
                    and not meAtSpot

                if meAtSpot then
                    stopQueueSpotTween()
                end

                if forceSpotTween and spotPos then
                    startQueueSpotTween(spotPos)
                elseif spotPos then
                    -- Do not cancel an active arrival tween every frame; only keys/walk path cancels it above (meAtSpot / partner missing).
                    if not queueSpotTween or queueSpotTween.PlaybackState ~= Enum.PlaybackState.Playing then
                        stopQueueSpotTween()
                        moveToWithKeys(spotPos)
                    end
                else
                    stopQueueSpotTween()
                    stopKeyMove()
                end

                local qt = trimQueueText(getQueueLabelText() or "")
                local queueTextOk = qt == queueReadyText

                if bothAtSpot and queueCountGreaterThanZero(qt) then
                    queueNonZeroSince = queueNonZeroSince or tick()
                else
                    queueNonZeroSince = nil
                end
                local queueStuckNonZeroOk = queueNonZeroSince ~= nil and (tick() - queueNonZeroSince) >= QUEUE_STUCK_NONZERO_SECONDS

                if bothAtSpot and (queueTextOk or queueStuckNonZeroOk) then
                    stopQueueSpotTween()
                    stopKeyMove()
                    local Event = RS:FindFirstChild("Queue")
                    if Event and (Event:IsA("RemoteEvent") or Event:IsA("UnreliableRemoteEvent")) then
                        if role == "SACRIFICE" then
                            task.wait(0.1)
                        end
                        Event:FireServer({ JoinQueue = true })
                        startMatchmakingStuckServerHopMonitor()
                        local reason = queueTextOk and "0 In Queue" or (">0 In Queue " .. QUEUE_STUCK_NONZERO_SECONDS .. "s+")
                        print("[Autofarm] Queue: FireServer JoinQueue (" .. role .. ") [" .. reason .. "]")
                    else
                        warn("[Autofarm] ReplicatedStorage.Queue RemoteEvent not found")
                    end
                    break
                end

                task.wait(math.max(0.07, config.movementCheck))
            end

            spotQueueActive = false
            stopQueueSpotTween()
            stopKeyMove()
        end)
    end

-- Ankle detection
task.spawn(function()
    local wasActive = false
    while sessionAlive(sid) do
        if config.defesnebadges then
            task.wait(0.2)
            continue
        end
        local sac = getPlayer(config.sacrifice)
        if sac and sac.Character then
            local detected = isAnkleAnim(sac.Character)
            
            if detected and not wasActive then
                state.ankles = state.ankles + 1
                print("[Autofarm] Ankle break #" .. state.ankles)
                
                -- On fresh ankle break: pause operations, then wait for the
                -- animation to end before starting regroup tweening.
                state.paused = true
                state.waitRegroup = false
                
                if state.ankles >= config.anklesToShoot and not state.shootPhase then
                    state.shootPhase = true
                    print("[Autofarm] ===== SHOOTING PHASE ACTIVE =====")
                    if role == "FARMER" and not state.shooting then
                        task.spawn(shootSequence)
                    end
                end
            end
            
            if not detected and wasActive then
                state.waitRegroup = true
                print("[Autofarm] Ankle ended! Starting regroup...")
            end
            
            wasActive = detected
        end
        task.wait(0.08)
    end
end)

-- Regroup detection
task.spawn(function()
    while sessionAlive(sid) do
        if state.waitRegroup and not state.shooting and not state.shootPhase then
            local dist = getDist(getPlayer(config.sacrifice), getPlayer(config.farmer))
            if dist <= config.regroupDist then
                state.paused = false
                state.waitRegroup = false
                print("[Autofarm] Regrouped! Resuming...")
            end
        end
        task.wait(config.movementCheck)
    end
end)

-- NEW GAME GUI DETECTION (BOTH ROLES)
task.spawn(function()
    local newGameDismissedForVisible = false
    while sessionAlive(sid) do
        local success, newGameGui = pcall(function() 
            return player.PlayerGui:FindFirstChild("NewGame") 
        end)
        
        if success and newGameGui then
            local button = newGameGui:FindFirstChild("Button")
            if button and button.Visible then
                if not newGameDismissedForVisible then
                    newGameDismissedForVisible = true
                    print("[Autofarm] [" .. role .. "] New game detected! Resetting state...")
                    resetState()
                    pcall(function()
                        if type(getconnections) ~= "function" then return end
                        local conns = getconnections(button.MouseButton1Click)
                        if not conns then return end
                        local n = 0
                        for _, c in pairs(conns) do
                            n = n + 1
                            if n > 32 then break end
                            if c and c.Fire then pcall(function() c:Fire() end) end
                        end
                    end)
                end
            else
                newGameDismissedForVisible = false
            end
        else
            newGameDismissedForVisible = false
        end
        
        task.wait(0.5)
    end
end)

-- Score monitor for game end detection (ROLE-SPECIFIC)
if role == "SACRIFICE" or role == "FARMER" then
    local function normalizeScoreText(scoreText)
        if typeof(scoreText) ~= "string" then return "" end
        return scoreText:gsub("%s+", "")
    end

    local function startScoreMonitor(onEndReached)
        task.spawn(function()
            local monitoring = false
            local scoreChanges = 0
            local lastScore = nil
            local currentLabel = nil
            local teleporting = false
            local endActionQueued = false

            local function queueEndAction(reasonText)
                if endActionQueued then return end
                endActionQueued = true
                print(reasonText)
                state.roundEnding = true
                teleporting = true
                monitoring = false
                task.spawn(function()
                    task.wait(10)
                    onEndReached()
                    scoreChanges = 0
                    lastScore = nil
                    currentLabel = nil
                    teleporting = false
                    monitoring = false
                    endActionQueued = false
                    print("[Autofarm] [" .. role .. "] Ready for next game!")
                end)
            end

            while sessionAlive(sid) do
                if state.shootPhase and not monitoring and not teleporting then
                    monitoring = true
                    scoreChanges = 0
                    lastScore = nil
                    currentLabel = nil
                    print("[Autofarm] [" .. role .. "] Monitoring score changes...")
                end

                if monitoring and not teleporting then
                    local label = getClosestScoreLabel()
                    if label and label ~= currentLabel then
                        currentLabel = label
                        lastScore = currentLabel.Text
                        print("[Autofarm] [" .. role .. "] Tracking score: " .. lastScore)
                    end

                    if currentLabel then
                        local currentScore = currentLabel.Text
                        if currentScore ~= lastScore then
                            scoreChanges = scoreChanges + 1
                            print("[Autofarm] [" .. role .. "] Score change #" .. scoreChanges .. ": " .. lastScore .. " -> " .. currentScore)

                            local prevNormalized = normalizeScoreText(lastScore)
                            local currentNormalized = normalizeScoreText(currentScore)
                            local isTargetEndScore = currentNormalized == "21-0" or currentNormalized == "22-0"
                            if config.endMethod == "score" and prevNormalized ~= "" and prevNormalized ~= currentNormalized and isTargetEndScore and not teleporting then
                                queueEndAction("[Autofarm] [" .. role .. "] Score reached " .. currentScore .. "! Waiting 10 seconds before end action...")
                            end

                            lastScore = currentScore
                        end

                        if config.endMethod == "shots" and scoreChanges >= config.shotsToTake and not teleporting then
                            queueEndAction("[Autofarm] [" .. role .. "] All " .. config.shotsToTake .. " shots completed! Waiting 10 seconds...")
                        end
                    end
                end

                task.wait(0.12)
            end
        end)
    end

    if role == "SACRIFICE" then
        startScoreMonitor(function()
            print("[Autofarm] [SACRIFICE] Starting teleport to spot...")
            state.paused = true
            state.waitRegroup = true
            state.spamming = false
            stopMoveTween()
            stopKeyMove()

            local hrp = getHRP(player)
            if hrp then
                local tween = TS:Create(hrp, TweenInfo.new(10, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {CFrame = CFrame.new(config.spotCoords)})
                local tpDone = false
                tween.Completed:Once(function()
                    tpDone = true
                end)
                tween:Play()
                local tpDeadline = tick() + 14
                while not tpDone and tick() < tpDeadline and sessionAlive(sid) do
                    task.wait(0.1)
                end
                if not tpDone then
                    pcall(function() tween:Cancel() end)
                end

                local park = RS:FindFirstChild("Park")
                if park then
                    park:FireServer({Type = "Spot"})
                else
                    warn("[Autofarm] [SACRIFICE] Park remote not found!")
                end
            else
                warn("[Autofarm] [SACRIFICE] HRP not found for teleport!")
            end

            resetState()
            setShootAttr(false)
        end)
    elseif role == "FARMER" then
        startScoreMonitor(function()
            print("[Autofarm] [FARMER] End condition reached. Resetting without teleport.")
            resetState()
            setShootAttr(false)
        end)
    end
end

-- SACRIFICE-only handlers
if role == "SACRIFICE" then
    -- ForgetLoss GUI handler
    task.spawn(function()
        while sessionAlive(sid) do
            local success, loss = pcall(function() return player.PlayerGui:FindFirstChild("ForgetLoss") end)
            if success and loss then
                local lostGui = loss:FindFirstChild("Lost")
                if lostGui and lostGui.Visible then
                    lostGui.Visible = false
                    print("[Autofarm] Closed loss screen")
                end
            end
            task.wait(0.1)
        end
    end)
    
    -- Shooting phase monitor
    task.spawn(function()
        local wasPhase = false
        local shots = 0
        local hadBall = false
        
        while sessionAlive(sid) do
            local fHasBall = hasBall(config.farmer)
            
            if state.shootPhase and not wasPhase then
                wasPhase = true
                shots = 0
                hadBall = fHasBall
                print("[Autofarm] [SACRIFICE] Shooting phase - STOPPING ACTIONS")
            end
            
            if wasPhase then
                if hadBall and not fHasBall then
                    shots = shots + 1
                    if config.endMethod == "score" then
                        print("[Autofarm] [SACRIFICE] Ball release detected during score mode (" .. shots .. ")")
                    else
                        print("[Autofarm] [SACRIFICE] Shot #" .. shots .. "/" .. config.shotsToTake)
                    end
                end
                hadBall = fHasBall
                
                if config.endMethod ~= "score" and shots >= config.shotsToTake then
                    print("[Autofarm] [SACRIFICE] All shots complete!")
                    state.shootPhase = false
                    state.ankles = 0
                end
            end
            
            if not state.shootPhase and wasPhase then
                wasPhase = false
                shots = 0
                print("[Autofarm] [SACRIFICE] RESUMING")
            end
            
            task.wait(0.1)
        end
    end)
    
    -- Movement
    task.spawn(function()
        local wasShooting = false
        
        while sessionAlive(sid) do
            if config.defesnebadges then
                -- DEFENSE MODE: if SACRIFICE has the ball, fire the shoot remote; otherwise stay near farmer.
                if hasBall(config.sacrifice) then
                    fireShoot(true)
                    task.wait(0.2)
                    fireShoot(false)
                end
                stopMoveTween()
                stopKeyMove()
                task.wait(math.max(0.12, config.movementCheck))
                continue
            end

            if USE_SPOT_QUEUE and spotQueueActive then
                task.wait(config.movementCheck)
                continue
            end

            local fPos = getPos(getPlayer(config.farmer))
            
            -- Priority 1: Has ball - go out of bounds
            if hasBall(config.sacrifice) then
                if not state.outOfBounds then
                    state.outOfBounds = true
                    print("[Autofarm] [SACRIFICE] Has ball! Going out of bounds...")
                end
                local oob = getCachedOutOfBoundsPart()
                stopMoveTween()
                if oob then moveToWithKeys(oob.Position) else stopKeyMove() end
                
            -- Priority 2: Shooting/Dunking phase - stand still
            elseif state.shootPhase then
                if not wasShooting then
                    wasShooting = true
                    print("[Autofarm] [SACRIFICE] Shooting phase active - standing still.")
                end
                state.outOfBounds = false
                stopMoveTween()
                stopKeyMove()
                
            else
                if wasShooting then
                    wasShooting = false
                    print("[Autofarm] Shooting ended! Resuming normal...")
                end
                
                if state.outOfBounds and not hasBall(config.sacrifice) then
                    state.outOfBounds = false
                end
                
                -- Priority 3: Regroup
                if state.paused or state.waitRegroup then
                    state.outOfBounds = false
                    if fPos then
                        local dist = getDist(player, getPlayer(config.farmer))
                        stopMoveTween()
                        if dist > config.regroupDist then moveToWithKeys(fPos) else stopKeyMove() end
                    else
                        stopKeyMove()
                    end
                    
                -- Priority 4: Follow farmer
                elseif hasBall(config.farmer) and fPos then
                    stopKeyMove()
                    if state.outOfBounds then
                        state.outOfBounds = false
                        print("[Autofarm] Farmer has ball! Stopping...")
                    end
                    local dist = getDist(player, getPlayer(config.farmer))
                    if dist > config.followDist + 1 then moveTo(fPos) else stopMoveTween() end
                else
                    stopKeyMove()
                    if state.outOfBounds then
                        state.outOfBounds = false
                        print("[Autofarm] Stopping...")
                    end
                    stopMoveTween()
                end
            end
            
            task.wait(config.movementCheck)
        end
    end)
end

-- Main farming loop
task.spawn(function()
    while sessionAlive(sid) do
        if not player or not player.Parent then
            state.running = false
            _G.AutofarmRunning = false
            warn("[Autofarm] Player disconnected")
            break
        end
        
        if not getPlayer(partner) then
            local farmerContinuesDefense = config.defesnebadges and role == "FARMER" and (sacrificeLeft or defense.blocksComplete)
            if not farmerContinuesDefense then
                -- Do NOT kill the whole session when the other account leaves/loads/teleports.
                -- Killing state.running here permanently stops every loop and makes autoexec look "dead".
                state.spamming = false
                state.paused = true
                pcall(function() stopMoveTween() end)
                pcall(function() stopKeyMove() end)
                task.wait(0.5)
                continue
            end
        else
            -- Partner is back. PlayerAdded normally restarts the session, but this keeps the
            -- current loop from staying paused if Roblox misses that signal during teleport load.
            if state.paused and not state.waitRegroup and not state.shooting and not state.shootPhase then
                state.paused = false
            end
        end
        
        if role == "FARMER" then
            if config.defesnebadges then
                -- SACRIFICE gone: get closest ball, then tween to shootDist and fire shoot (ball OR idle dribble = shoot).
                local partnerGone = not getPlayer(partner)
                if partnerGone and (sacrificeLeft or defense.blocksComplete) then
                    local hasB = hasBall(config.farmer)
                    local idleDribble = hasDribbleIdleAnimThrottled(config.farmer)
                    if hasB or idleDribble then
                        state.spamming = false
                        tweenToShootDistanceAndShootOnce()
                    else
                        state.spamming = true
                        local ball = getLooseBallPart()
                        stopMoveTween()
                        if ball then
                            moveToWithKeys(ball.Position)
                        else
                            stopKeyMove()
                        end
                    end
                    task.wait(0.12)
                    continue
                end

                -- DEFENSE MODE: do NOT follow sacrifice; if farmer has ball, walk out of bounds.
                if hasBall(config.farmer) then
                    local oob = getCachedOutOfBoundsPart()
                    stopMoveTween()
                    if oob then
                        moveToWithKeys(oob.Position)
                    else
                        stopKeyMove()
                    end
                else
                    stopMoveTween()
                    stopKeyMove()
                end
                state.spamming = false
                task.wait(0.12)
                continue
            end

            if hasDribbleIdleAnimThrottled(config.farmer) and not state.shooting and not state.shootPhase and not state.paused and not state.waitRegroup and (not USE_SPOT_QUEUE or not spotQueueActive) then
                state.spamming = true
            else
                state.spamming = false
                stopMoveTween()
            end
        else
            local canSpam = not hasBall(config.sacrifice) and not state.shootPhase and not state.paused and not state.waitRegroup and hasBall(config.farmer) and (not USE_SPOT_QUEUE or not spotQueueActive)
            if canSpam then
                state.spamming = true
            else
                state.spamming = false
            end
        end
        
        task.wait(0.12)
    end
end)

-- Remote spam loop for FARMER (dribble action)
if role == "FARMER" then
    task.spawn(function()
        while sessionAlive(sid) do
            if state.spamming then
                pcall(function()
                    local Event = game:GetService("ReplicatedStorage").Remotes.Server.Action
                    Event:FireServer({
                        Keys = "H",
                        Type = "Dribble"
                    })
                end)
            end
            task.wait(0.12)
        end
    end)

    -- Fallback end-score watcher to avoid stuck shootPhase after reset/new game.
    task.spawn(function()
        local function normalizeScoreText(scoreText)
            if typeof(scoreText) ~= "string" then return "" end
            return scoreText:gsub("%s+", "")
        end

        while sessionAlive(sid) do
            if config.endMethod == "score" and (state.shootPhase or state.shooting) and not state.roundEnding then
                local scoreText = getClosestScoreText()
                local normalized = normalizeScoreText(scoreText)
                if normalized == "21-0" or normalized == "22-0" then
                    print("[Autofarm] [FARMER] End score detected by fallback watcher. Resetting round state...")
                    state.roundEnding = true
                    resetState()
                    setShootAttr(false)
                end
            end
            task.wait(0.2)
        end
    end)
end

-- Remote spam loop for SACRIFICE (reach action)
if role == "SACRIFICE" then
    task.spawn(function()
        while sessionAlive(sid) do
            if state.spamming then
                if config.defesnebadges then
                    task.wait(0.12)
                    continue
                end
                pcall(function()
                    local Event = game:GetService("ReplicatedStorage").Remotes.Server.Action
                    Event:FireServer({
                        Action = "Reach",
                        Reach = true
                    })
                end)
            end
            task.wait(0.12)
        end
    end)
end

end

local function restartAutofarmPartnerSync()
    local last = _G.__AUTOFARM_LAST_PARTNER_RESTART
    if last and (tick() - last) < 1.5 then
        return
    end
    _G.__AUTOFARM_LAST_PARTNER_RESTART = tick()

    autofarmSession = autofarmSession + 1
    state.running = false
    _G.AutofarmRunning = false
    task.wait(0.5)
    resetState()
    spotQueueActive = false
    shootSequenceLock = false
    rimMeshCache.part, rimMeshCache.time = nil, 0
    scoreUiCache.label, scoreUiCache.time = nil, 0
    oobPartCache, oobPartCacheTime = nil, 0
    dribbleIdleAnimIds = nil
    ankleAnimIds = nil
    dribbleCheckCache.t = 0
    dribbleCheckCache.v = false
    stopMoveTween()
    stopKeyMove()
    shootAfterSacrificeLeftLock = false
    state.running = true
    _G.AutofarmRunning = true
    task.wait(0.1)
    startMainLoops()
end

Players.PlayerAdded:Connect(function(p)
    if p == player then return end
    if p.Name ~= config.farmer and p.Name ~= config.sacrifice then return end
    print("[Autofarm] Partner joined: " .. p.Name .. " — re-syncing session...")
    task.spawn(restartAutofarmPartnerSync)
end)

Players.PlayerRemoving:Connect(function(p)
    if p == player then
        state.running = false
        _G.AutofarmRunning = false
        pcall(function() stopMoveTween() end)
        pcall(function() stopKeyMove() end)
        return
    end

    if config.defesnebadges and p.Name == config.sacrifice and role == "FARMER" then
        sacrificeLeft = true
        state.spamming = false
        pcall(function() stopMoveTween() end)
        pcall(function() stopKeyMove() end)
        print("[Autofarm] SACRIFICE left; FARMER will pick up ball and shoot.")
        return
    end

    if p.Name == partner or p.Name == config.sacrifice or p.Name == config.farmer then
        -- Partner/server transition only: pause safely, but keep the session alive.
        -- PlayerAdded will call restartAutofarmPartnerSync when the partner comes back.
        state.spamming = false
        state.paused = true
        pcall(function() stopMoveTween() end)
        pcall(function() stopKeyMove() end)
        print("[Autofarm] Partner left/loading; paused without killing loops.")
    end
end)

startMainLoops()

print("[Autofarm] Script running!")

-- Defense-badges wiring (late init, after helpers exist)
task.spawn(function()
    task.wait(1.0)
    if not config.defesnebadges then
        return
    end
    -- Farmer should be tracking sacrifice; also listen for sacrifice Action="Shooting" to jump.
    attachDefenseActionListener(config.sacrifice)
    -- Ensure SACRIFICE can reach teleport threshold even if only FARMER produces the block sound.
    local blockSoundOwner = (role == "SACRIFICE") and config.farmer or player.Name
    attachBlockSoundListener(blockSoundOwner)
end)
