-- StarterPlayerScripts\CameraController.lua
-- Created by Jacksxity (6/17/2026)

-- Create a folder called "Environment" in the Workspace, otherwise this will not work. --

--[[ Services ]]--
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

--[[ Constants ]]--
local CAMERA_OFFSET = Vector3.new(11, 26, 16) -- side, height, back
local CAMERA_SMOOTHNESS = 1
local OCCLUSION_TRANSPARENCY = 0.85 
local FADE_TIME = 0.25

--[[ Variables ]]--
local player = Players.LocalPlayer
local hiddenPartsCache = {}
local fadeTweenInfo = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

--[[ Functions ]]--
local function getCamera()
	local cam = workspace.CurrentCamera
	if cam.CameraType ~= Enum.CameraType.Scriptable then 
		cam.CameraType = Enum.CameraType.Scriptable
	end
	return cam
end

local function getBlockingParts(origin, target, hideableFolder)
	local hits = {}
	local direction = target - origin

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignoreList = {}
	if player.Character then table.insert(ignoreList, player.Character) end

	while true do
		params.FilterDescendantsInstances = ignoreList
		local result = workspace:Raycast(origin, direction, params)

		if result and result.Instance then
			local hitPart = result.Instance
			if hitPart:IsDescendantOf(hideableFolder) then
				table.insert(hits, hitPart)
			end
			table.insert(ignoreList, hitPart)
		else
			break
		end
	end

	return hits
end

--[[ Runtime ]]--
RunService.RenderStepped:Connect(function()
	local character = player.Character
	if not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local camera = getCamera()
	local targetPosition = root.Position + CAMERA_OFFSET
	local targetCFrame = CFrame.lookAt(targetPosition, root.Position)
	camera.CFrame = camera.CFrame:Lerp(targetCFrame, CAMERA_SMOOTHNESS)

	local hideableFolder = workspace:FindFirstChild("Environment")
	if not hideableFolder then return end

	local rayOrigin = camera.CFrame.Position
	local rayTarget = root.Position

	local currentHitParts = getBlockingParts(rayOrigin, rayTarget, hideableFolder)

	local currentHitsDict = {}
	for _, part in ipairs(currentHitParts) do currentHitsDict[part] = true  end

	for part, originalTrans in pairs(hiddenPartsCache) do
		if not currentHitsDict[part] then
			local fadeTween = TweenService:Create(part, fadeTweenInfo, {Transparency = originalTrans})
			fadeTween:Play()
			hiddenPartsCache[part] = nil
		end
	end

	for _, part in ipairs(currentHitParts) do
		if not hiddenPartsCache[part] then
			hiddenPartsCache[part] = part.Transparency
			local fadeTween = TweenService:Create(part, fadeTweenInfo, {Transparency = OCCLUSION_TRANSPARENCY})
			fadeTween:Play()
		end
	end
end)
