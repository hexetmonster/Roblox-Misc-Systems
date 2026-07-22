-- StarterPlayerScripts\MovementController.lua
-- All about the player's movement.
-- Created by Jacksxity (6/17/2026)

--[[ Services ]]--
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

--[[ Constants ]]--
local CLICK_MARKER_ENABLED = true
local FACE_MOUSE_ENABLED = true
local CLICK_TO_MOVE_ENABLED = false
local WALK_SPEED = 16
local SPRINT_SPEED = 20
local DOUBLE_CLICK_WINDOW = 0.35
local AGENT_RADIUS = 2
local AGENT_HEIGHT = 5
local AGENT_CAN_JUMP = false
local WAYPOINT_SPACING = 4
local MIN_DESTINATION_CHANGE = 2.5
local MANUAL_CANCEL_KEYS = {
	[Enum.KeyCode.W] = true,
	[Enum.KeyCode.A] = true,
	[Enum.KeyCode.S] = true,
	[Enum.KeyCode.D] = true,
	[Enum.KeyCode.Up] = true,
	[Enum.KeyCode.Down] = true,
	[Enum.KeyCode.Left] = true,
	[Enum.KeyCode.Right] = true,
}

--[[ Variables ]]--
local player, camera = Players.LocalPlayer, workspace.CurrentCamera
local lastClickTime, currentMoveId = 0, 0
local lastDestination, character, humanoid, root = nil, nil, nil, nil
local currentMarker, alignAttachment, alignOrientation = nil, nil, nil

--[[ Functions ]]--
local function setupMouseLook()
	if not root or not humanoid then return end
	if not FACE_MOUSE_ENABLED then humanoid.AutoRotate = true return end

	humanoid.AutoRotate = false 
	
	if root:FindFirstChild("MouseLookAttachment") then root.MouseLookAttachment:Destroy() end
	if root:FindFirstChild("MouseLookAlign") then root.MouseLookAlign:Destroy() end

	alignAttachment = Instance.new("Attachment")
	alignAttachment.Name = "MouseLookAttachment"
	alignAttachment.Parent = root
	alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Name = "MouseLookAlign"
	alignOrientation.Attachment0 = alignAttachment
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.MaxTorque = 100000
	alignOrientation.MaxAngularVelocity = 15--50
	alignOrientation.Responsiveness = 35--200
	alignOrientation.Parent = root
end

local function getCharacterParts()
	character = player.Character or player.CharacterAdded:Wait()
	humanoid = character:WaitForChild("Humanoid")
	root = character:WaitForChild("HumanoidRootPart")

	humanoid.WalkSpeed = WALK_SPEED
	setupMouseLook()
end

local function cancelCurrentMove() 
	currentMoveId += 1 
	if humanoid then 
		humanoid:Move(Vector3.zero, false) 
		humanoid.WalkSpeed = WALK_SPEED 
	end 
end

local function createClickMarker(position, isSprinting)
	if not CLICK_MARKER_ENABLED then return end

	if currentMarker then currentMarker:Destroy() currentMarker = nil end
	local marker = Instance.new("Part")
	marker.Name = "ClickMoveMarker"
	marker.Shape = Enum.PartType.Cylinder
	marker.Size = Vector3.new(0.15, 2.5, 2.5)
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.Material = Enum.Material.Neon
	marker.Transparency = 0.25
	marker.Color = isSprinting and Color3.fromRGB(255, 100, 75) or Color3.fromRGB(255, 230, 150)
	marker.CFrame = CFrame.new(position + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
	marker.Parent = workspace

	currentMarker = marker

	task.delay(0.8, function()
		if marker and marker.Parent then marker:Destroy() end
		if currentMarker == marker then currentMarker = nil end
	end)
end

local function getMouseWorldPosition()
	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {character, workspace:FindFirstChild("Environment"), workspace:FindFirstChild("Enemies")}
	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)

	if result then return result.Position, result.Instance end
	return nil, nil
end

local function computePath(destination)
	if not root then return nil end

	local path = PathfindingService:CreatePath({AgentRadius = AGENT_RADIUS, AgentHeight = AGENT_HEIGHT, AgentCanJump = AGENT_CAN_JUMP, WaypointSpacing = WAYPOINT_SPACING})
	local success, errorMessage = pcall(function() path:ComputeAsync(root.Position, destination) end)
	if not success then warn("Path compute failed:", errorMessage) return nil end
	if path.Status ~= Enum.PathStatus.Success then return nil end

	return path
end

local function moveToAndWait(position, moveId, timeout)
	if not humanoid then return false end
	if moveId ~= currentMoveId then return false end

	local finished = false
	local reachedResult = false

	local connection
	connection = humanoid.MoveToFinished:Connect(function(reached)
		finished = true
		reachedResult = reached
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end)

	humanoid:MoveTo(position)
	local startTime = os.clock()

	while not finished do
		if moveId ~= currentMoveId then
			if connection then connection:Disconnect() connection = nil end
			return false
		end

		if os.clock() - startTime > timeout then
			if connection then connection:Disconnect() connection = nil end
			return false
		end

		RunService.Heartbeat:Wait()
	end

	return reachedResult
end

local function moveDirectly(destination, moveId)
	if not humanoid then return end
	if moveId ~= currentMoveId then return end

	local reached = moveToAndWait(destination, moveId, 3)
	if moveId ~= currentMoveId then return end
	if not reached then warn("Direct MoveTo failed.") end
end

local function followPath(destination, isSprinting)
	if not character or not humanoid or not root then return end

	currentMoveId += 1
	local moveId = currentMoveId

	createClickMarker(destination, isSprinting)
	local path = computePath(destination)

	if moveId ~= currentMoveId then return end
	if not path then moveDirectly(destination, moveId) return end

	local waypoints = path:GetWaypoints()
	for i, waypoint in ipairs(waypoints) do
		if moveId ~= currentMoveId then return end
		if i == 1 then continue end
		if (waypoint.Position - root.Position).Magnitude < (WAYPOINT_SPACING * 0.75) then continue end

		local reached = moveToAndWait(waypoint.Position, moveId, 2)

		if moveId ~= currentMoveId then return end
		if not reached then warn("Failed to reach waypoint. Stopping path.") return end
	end
end

local function onLeftClick()
	if not CLICK_TO_MOVE_ENABLED then return end
	if UserInputService:GetFocusedTextBox() then return end

	local now = os.clock()
	local isDoubleClick = (now - lastClickTime) <= DOUBLE_CLICK_WINDOW
	lastClickTime = now
	local destination, clickedPart = getMouseWorldPosition()
	if not destination then return end
	if humanoid then humanoid.WalkSpeed = isDoubleClick and SPRINT_SPEED or WALK_SPEED end
	if not isDoubleClick and lastDestination and (destination - lastDestination).Magnitude < MIN_DESTINATION_CHANGE then return end

	lastDestination = destination
	task.spawn(function() followPath(destination, isDoubleClick) end)
end

--[[ Listeners ]]--
getCharacterParts()
player.CharacterAdded:Connect(function() 
	getCharacterParts() 
	currentMoveId += 1
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and CLICK_TO_MOVE_ENABLED then onLeftClick() return end
	if input.UserInputType == Enum.UserInputType.Keyboard and CLICK_TO_MOVE_ENABLED then if MANUAL_CANCEL_KEYS[input.KeyCode] then cancelCurrentMove() end end
end)

--[[ Runtime ]]--
RunService.Heartbeat:Connect(function()
	if not FACE_MOUSE_ENABLED or not root or not alignOrientation then return end

	local mousePos = getMouseWorldPosition()
	if mousePos then
		local lookTarget = Vector3.new(mousePos.X, root.Position.Y, mousePos.Z)
		alignOrientation.CFrame = CFrame.lookAt(root.Position, lookTarget)
	end
end)
