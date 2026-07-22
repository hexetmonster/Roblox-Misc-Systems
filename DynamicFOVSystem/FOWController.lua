-- StarterPlayerScripts\FOWController.lua
-- All about the FOW (fog of war).
-- Created by Jacksxity (6/17/2026)

-- Inspired by Project Zomboid's FOW system, kinda. --
-- Create a "Enemies" folder in the Workspace, which will be hidden within this script. --
-- Otherwise the script will not work. --
-- This was ripped from one of my games, so it may not work 100%. It isn't modular so you may need to do some work. --

--[[ Services ]]--
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

--[[ Constants ]]--
local USE_DIRECTIONAL_VISION = true
local PERIPHERAL_RADIUS = 6
local VISION_ANGLE = 120
local VISION_RADIUS = 32
local FADE_RADIUS = 8
local MAX_RADIUS = VISION_RADIUS + FADE_RADIUS

--[[ Variables ]]--
local player = Players.LocalPlayer
local character
local root
local enemyCache = setmetatable({}, { __mode = "k" })
local visionRayParams = RaycastParams.new()
visionRayParams.FilterType = Enum.RaycastFilterType.Exclude

--[[ Functions ]]--
local function updateVisionFilter()
	if not character then return end

	local enemiesFolder = workspace:FindFirstChild("Enemies")
	local filterList = {enemiesFolder}
	for _, child in ipairs(character:GetChildren()) do
		if not child:IsA("Tool") then
			table.insert(filterList, child)
		end
	end
	visionRayParams.FilterDescendantsInstances = filterList
end

local function setupCharacter(newCharacter)
	character = newCharacter
	root = character:WaitForChild('HumanoidRootPart')
	if root:FindFirstChild("VisionLightAttachment") then root.VisionLightAttachment:Destroy() end

	character.ChildAdded:Connect(updateVisionFilter)
	character.ChildRemoved:Connect(updateVisionFilter)
	updateVisionFilter()
	
	local attachment = Instance.new("Attachment")
	attachment.Name = "VisionLightAttachment"
	attachment.Position = Vector3.new(0, 5, 0)
	attachment.Parent = root

	if USE_DIRECTIONAL_VISION then
		local spotLight = Instance.new("SpotLight")
		spotLight.Name = "RevealLight"
		spotLight.Brightness = 2.5
		spotLight.Range = MAX_RADIUS + 3
		spotLight.Angle = VISION_ANGLE
		spotLight.Shadows = true
		spotLight.Color = Color3.fromRGB(255, 230, 190)
		attachment.Orientation = Vector3.new(-15, 0, 0)
		spotLight.Parent = attachment
	else
		local revealLight = Instance.new("PointLight")
		revealLight.Name = "RevealLight"
		revealLight.Brightness = 1.8
		revealLight.Range = MAX_RADIUS + 2
		revealLight.Shadows = false
		revealLight.Color = Color3.fromRGB(255, 230, 190)
		revealLight.Parent = attachment

		local shadowLight = Instance.new("PointLight")
		shadowLight.Name = "ShadowLight"
		shadowLight.Brightness = 0.45
		shadowLight.Range = VISION_RADIUS
		shadowLight.Shadows = true
		shadowLight.Color = Color3.fromRGB(255, 215, 170)
		shadowLight.Parent = attachment
	end
end

local function getEnemyData(enemy)
	if enemyCache[enemy] then return enemyCache[enemy] end

	local data = {root = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart,  parts = {},  guis = {},  decals = {},  lastTransparency = -1, hasPlayedAudio = false }

	for _, descendant in ipairs(enemy:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(data.parts, descendant)
		elseif descendant:IsA("BillboardGui") then
			table.insert(data.guis, descendant)
		elseif descendant:IsA("Decal") then
			table.insert(data.decals, descendant)
		end
	end
	enemyCache[enemy] = data

	return data
end

local function applyTransparency(data, targetTransparency)
	local roundedTransparency = math.floor(targetTransparency * 100) / 100
	if data.lastTransparency == roundedTransparency then return end
	data.lastTransparency = roundedTransparency

	for _, part in ipairs(data.parts) do part.LocalTransparencyModifier = roundedTransparency end

	local guiEnabled = roundedTransparency < 0.95
	for _, gui in ipairs(data.guis) do
		if gui.Enabled ~= guiEnabled then
			gui.Enabled = guiEnabled
		end
	end

	for _, decal in ipairs(data.decals) do decal.Transparency = roundedTransparency end
end

--[[ Listeners ]]--
if player.Character then setupCharacter(player.Character) end
player.CharacterAdded:Connect(setupCharacter)

--[[ Runtime ]]--
RunService.RenderStepped:Connect(function()
	if not root then return end 

	local enemiesFolder = workspace:FindFirstChild("Enemies")
	if not enemiesFolder then return end

	local localPos = root.Position
	local forwardVector = root.CFrame.LookVector
	local flatForward = Vector3.new(forwardVector.X, 0, forwardVector.Z).Unit

	for _, enemy in ipairs(enemiesFolder:GetChildren()) do
		if enemy:IsA("Model") then
			local data = getEnemyData(enemy)

			if data.root then
				local enemyPos = data.root.Position
				local distance = (enemyPos - localPos).Magnitude
				local targetTransparency = 1

				if USE_DIRECTIONAL_VISION then
					-- === CONE-BASED FOW WITH RAYCAST OCCLUSION ===
					local inPeripheral = (distance <= PERIPHERAL_RADIUS)
					local inCone = false

					if distance <= MAX_RADIUS then
						local directionToEnemy = (enemyPos - localPos)
						local flatDirection = Vector3.new(directionToEnemy.X, 0, directionToEnemy.Z).Unit
						local dotProduct = flatForward:Dot(flatDirection)
						local angleCos = math.cos(math.rad(VISION_ANGLE / 2))

						if dotProduct >= angleCos then
							inCone = true
						end
					end

					if inPeripheral or inCone then
						local eyePos = localPos + Vector3.new(0, 1.5, 0)
						local targetEyePos = enemyPos + Vector3.new(0, 1.5, 0)
						local rayDirection = targetEyePos - eyePos
						local raycastResult = workspace:Raycast(eyePos, rayDirection, visionRayParams)

						if raycastResult then
							targetTransparency = 1 
						else
							if distance <= VISION_RADIUS then
								targetTransparency = 0
							else
								targetTransparency = (distance - VISION_RADIUS) / FADE_RADIUS
							end
						end
					end
				else
					-- === RADIUS-BASED FOW (Original, no occlusion) ===
					if distance <= VISION_RADIUS then
						targetTransparency = 0
					elseif distance <= MAX_RADIUS then
						targetTransparency = (distance - VISION_RADIUS) / FADE_RADIUS
					end
				end

				if targetTransparency < 1 and not data.hasPlayedAudio then
					data.hasPlayedAudio = true
					local waterphoneThing = enemy:FindFirstChild('waterphone') 
					if waterphoneThing then 
						waterphoneThing:Play() 
					end
				elseif targetTransparency == 1 then
					data.hasPlayedAudio = false 
				end

				applyTransparency(data, targetTransparency)
			end
		end
	end
end)
