-- StarterCharacterScripts\HeartbeatController.lua
-- All about the player's heartbeat, stamina, and adrenaline systems
-- Created by Jacksxity (6/17/2026)

--[[ Services ]]--
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

--[[ Constants ]]--
local HEARTBEAT_SOUND_ID = "rbxassetid://135925258529833"
local ENABLE_HEALTH_STRESS = false
local ENABLE_STAMINA_STRESS = false
local ENABLE_ENEMY_STRESS = true
local HEALTH_THRESHOLD = 0.4 
local STAMINA_THRESHOLD = 0.3 
local ENEMY_STRESS_RADIUS = 133 
local MIN_BPM = 50
local MAX_BPM = 180
local MIN_VOLUME = 0.12
local MAX_VOLUME = 1.2
local BASE_SATURATION = -0.1
local MAX_PANIC_SATURATION = -0.85
local MAX_BLUR_SIZE = 6
local UI_PUMP_SCALE = 1.05

--[[ Variables ]]--
local colorCorrection = Lighting:WaitForChild("ColorCorrection")
local panicBlur = Lighting:WaitForChild("PanicBlur")
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local root = character:WaitForChild("HumanoidRootPart")
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local pGui = player:WaitForChild('PlayerGui')
local resetGUI = pGui:WaitForChild('ResetGUI')
local outerHeart = resetGUI:WaitForChild('OuterHeart')
local uiScale = outerHeart:WaitForChild('UIScale')
local heartbeatSound = Instance.new("Sound") heartbeatSound.Name = "StressHeartbeat" heartbeatSound.SoundId = HEARTBEAT_SOUND_ID heartbeatSound.Volume = MIN_VOLUME heartbeatSound.Parent = root

--[[ Functions ]]--
local function getHealthStress()
	if not ENABLE_HEALTH_STRESS then return 0 end
	local healthPercent = humanoid.Health / humanoid.MaxHealth
	if healthPercent < HEALTH_THRESHOLD then return 1 - (healthPercent / HEALTH_THRESHOLD) end
	return 0
end

local function getStaminaStress()
	if not ENABLE_STAMINA_STRESS then return 0 end
	local currentStamina = character:GetAttribute("Stamina") or 100
	local maxStamina = character:GetAttribute("MaxStamina") or 100
	local staminaPercent = currentStamina / maxStamina
	if staminaPercent < STAMINA_THRESHOLD then return 1 - (staminaPercent / STAMINA_THRESHOLD) end
	return 0
end

local function getEnemyStress()
	if not ENABLE_ENEMY_STRESS then return 0 end
	local enemiesFolder = Workspace:FindFirstChild("Enemies")
	if not enemiesFolder then return 0 end

	local closestDistance = ENEMY_STRESS_RADIUS
	local myPos = root.Position

	for _, enemy in ipairs(enemiesFolder:GetChildren()) do
		local enemyRoot = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
		if enemyRoot then
			local distance = (enemyRoot.Position - myPos).Magnitude
			if distance < closestDistance then
				closestDistance = distance
			end
		end
	end

	if closestDistance < ENEMY_STRESS_RADIUS then
		return 1 - (closestDistance / ENEMY_STRESS_RADIUS)
	end
	return 0
end

--[[ Listeners ]]--
humanoid.Died:Connect(function()
	TweenService:Create(colorCorrection, TweenInfo.new(1), {Saturation = BASE_SATURATION}):Play()
	TweenService:Create(panicBlur, TweenInfo.new(1), {Size = 0}):Play()
	TweenService:Create(uiScale, TweenInfo.new(0.5), {Scale = 1}):Play()
end)

--[[ Runtime ]]--
task.spawn(function()
	while character.Parent and humanoid.Health > 0 do
		local stressLevel = math.max(getHealthStress(), getStaminaStress(), getEnemyStress())
		local currentBpm = MIN_BPM + ((MAX_BPM - MIN_BPM) * stressLevel)
		local waitTime = 60 / currentBpm

		heartbeatSound.Volume = MIN_VOLUME + ((MAX_VOLUME - MIN_VOLUME) * stressLevel)
		heartbeatSound:Play()

		local targetSat = BASE_SATURATION + ((MAX_PANIC_SATURATION - BASE_SATURATION) * stressLevel)
		TweenService:Create(colorCorrection, TweenInfo.new(waitTime), {Saturation = targetSat}):Play()
		local pumpInfo = TweenInfo.new(0.05, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		TweenService:Create(uiScale, pumpInfo, {Scale = UI_PUMP_SCALE}):Play()
		local currentMaxBlur = stressLevel > 0.2 and (MAX_BLUR_SIZE * stressLevel) or 0
		TweenService:Create(panicBlur, pumpInfo, {Size = currentMaxBlur}):Play()

		task.wait(0.1)

		if humanoid.Health > 0 then
			local decayInfo = TweenInfo.new(waitTime - 0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
			TweenService:Create(uiScale, decayInfo, {Scale = 1}):Play()
			TweenService:Create(panicBlur, decayInfo, {Size = 0}):Play()
		end

		task.wait(waitTime - 0.1)
	end
end)
