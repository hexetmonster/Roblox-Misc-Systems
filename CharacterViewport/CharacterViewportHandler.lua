-- PlayerGui\CharacterViewportHandler.lua
-- Handles the mini character at the top left corner.
-- Created by Jacksxity (6/17/2026)

--[[ Services ]]--
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

--[[ Variables ]]--
local player = Players.LocalPlayer
local pUI = player:WaitForChild('PlayerGui')
local character = player.Character
local dummyProfile
local jointMap = {}

--[[ Functions ]]--
local function setupLiveProfile()
	local ui = pUI:WaitForChild('ResetGUI')
	local vpFrame = ui:WaitForChild("PlayerViewportFrame")
	if dummyProfile then dummyProfile:Destroy() end

	table.clear(jointMap)
	local whitelistedScripts = {'Animate'} 
	local worldModel = Instance.new('WorldModel') 
	worldModel.Parent = vpFrame 
	worldModel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent 
	character.Archivable = true
	dummyProfile = character:Clone()
	dummyProfile.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	for _, desc in ipairs(dummyProfile:GetDescendants()) do
		if desc:IsA("Audio") or desc:IsA("Sound") or desc:IsA("Tool") then
			desc:Destroy()
		elseif (desc:IsA("LocalScript") or desc:IsA("ModuleScript") or desc:IsA("Script")) and table.find(whitelistedScripts, desc.Name) == nil then
			desc:Destroy()
		elseif desc:IsA("Motor6D") then
			local realJoint = character:FindFirstChild(desc.Name, true)
			if realJoint then
				jointMap[desc] = realJoint
			end
		end
	end

	dummyProfile:PivotTo(CFrame.new(0, 1000, 0))
	local vpCamera = Instance.new("Camera")
	vpCamera.CameraType = Enum.CameraType.Scriptable
	local portraitCenter = dummyProfile:GetPivot().Position + Vector3.new(0, 1.5, 0)
	vpCamera.CFrame = CFrame.new(portraitCenter + Vector3.new(0, 0, -2.5), portraitCenter)
	vpFrame.CurrentCamera = vpCamera
	dummyProfile.Parent = worldModel
end

local function onCharacterReady(newCharacter)
	character = newCharacter
	local animateScript = character:WaitForChild("Animate", 5)
	if animateScript then animateScript:WaitForChild("PlayEmote", 5) end
	task.wait(0.1)
	setupLiveProfile()
end

--[[ Listeners ]]--
player.CharacterAppearanceLoaded:Connect(onCharacterReady)
if player.Character and player:HasAppearanceLoaded() then task.spawn(function() onCharacterReady(player.Character) end) end

--[[ Runtime ]]--
RunService.RenderStepped:Connect(function()
	if not dummyProfile or not character or not character.Parent then return end
	for dummyJoint, realJoint in pairs(jointMap) do 
		dummyJoint.Transform = realJoint.Transform 
	end
end)
