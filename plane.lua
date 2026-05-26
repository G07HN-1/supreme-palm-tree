local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local PreviousENV = getgenv().AutoFlyUI

if PreviousENV then
	PreviousENV.Enabled = false

	for _, threadName in ipairs({ "RingThread", "FlightThread", "HudThread", "MouseThread" }) do
		if PreviousENV[threadName] then
			pcall(task.cancel, PreviousENV[threadName])
		end
	end

	if PreviousENV.Connections then
		for _, connection in ipairs(PreviousENV.Connections) do
			pcall(function()
				connection:Disconnect()
			end)
		end
	end

	if PreviousENV.RestorePhysics then
		pcall(PreviousENV.RestorePhysics)
	end

	if PreviousENV.DestroyUI then
		pcall(PreviousENV.DestroyUI)
	end
end

local OldOverlay = PlayerGui:FindFirstChild("AutoFlyOverlay")
if OldOverlay then
	OldOverlay:Destroy()
end

getgenv().AutoFlyUI = {
	Enabled = false,
	Distance = 2500,
	Traveled = 0,
	PartStates = {},
	PhysicsObjects = {},
	Connections = {},
}

local ENV = getgenv().AutoFlyUI
local Events = ReplicatedStorage:WaitForChild("Events")

local RequestLaunch = Events:WaitForChild("RequestLaunch")
local ClientRingCollected = Events:WaitForChild("ClientRingCollected")
local GroundHit = Events:WaitForChild("GroundHit")
local FlightEnded = Events:WaitForChild("FlightEnded")

local MAX_SPEED = 1000
local LAUNCH_DIRECTION = Vector3.new(0.2916684150695801, 1, 0.8976625204086304).Unit
local FORWARD_DIRECTION = Vector3.new(0.2916684150695801, 0, 0.8976625204086304).Unit
local CLIMB_HEIGHT = 150
local CLIMB_SPEED = 750
local GLIDE_SPEED = 300
local RING_DELAY = 0.02

local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/GhostDuckyy/UI-Libraries/refs/heads/main/Orion/source.lua"))()

local OverlayGui = Instance.new("ScreenGui")
OverlayGui.Name = "AutoFlyOverlay"
OverlayGui.ResetOnSpawn = false
OverlayGui.DisplayOrder = 1000
OverlayGui.Parent = PlayerGui

local StudsLabel = Instance.new("TextLabel")
StudsLabel.Name = "StudsTraveled"
StudsLabel.AnchorPoint = Vector2.new(0.5, 0)
StudsLabel.Position = UDim2.new(0.5, 0, 0, 24)
StudsLabel.Size = UDim2.new(0, 300, 0, 32)
StudsLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
StudsLabel.BackgroundTransparency = 0.35
StudsLabel.BorderSizePixel = 0
StudsLabel.Font = Enum.Font.GothamBold
StudsLabel.Text = "Studs Traveled: 0 / 2500"
StudsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
StudsLabel.TextSize = 16
StudsLabel.Visible = false
StudsLabel.Parent = OverlayGui

local function updateStudsLabel()
	StudsLabel.Text = ("Studs Traveled: %d / %d"):format(math.floor(ENV.Traveled), math.floor(ENV.Distance))
end

ENV.DestroyUI = function()
	local overlay = PlayerGui:FindFirstChild("AutoFlyOverlay")
	if overlay then
		overlay:Destroy()
	end

	OrionLib:Destroy()
end

local function releaseMouse()
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

local function destroyFlyingHUDInstance(gui)
	if not gui or not gui.Parent then
		return
	end

	for _, descendant in ipairs(gui:GetDescendants()) do
		if descendant:IsA("GuiButton") then
			descendant.Modal = false
		end
	end

	if gui:IsA("ScreenGui") then
		gui.Enabled = false
	end

	gui:Destroy()
	releaseMouse()
end

local function destroyFlyingHUD(parent)
	for _, descendant in ipairs(parent:GetDescendants()) do
		if descendant.Name == "FlyingHUD" then
			destroyFlyingHUDInstance(descendant)
		elseif descendant:IsA("GuiButton") and descendant.Name == "UnlockMouse" then
			descendant.Modal = false
			descendant.Active = false
			descendant.Visible = false
		end
	end
end

local function disconnectConnections()
	for _, connection in ipairs(ENV.Connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end

	table.clear(ENV.Connections)
end

local function stopMouseFix()
	if ENV.HudThread then
		pcall(task.cancel, ENV.HudThread)
		ENV.HudThread = nil
	end

	if ENV.MouseThread then
		pcall(task.cancel, ENV.MouseThread)
		ENV.MouseThread = nil
	end

	disconnectConnections()
end

local function startMouseFix()
	stopMouseFix()

	for _, parent in ipairs({ StarterGui, PlayerGui }) do
		destroyFlyingHUD(parent)

		table.insert(ENV.Connections, parent.DescendantAdded:Connect(function(descendant)
			if descendant.Name == "FlyingHUD" then
				destroyFlyingHUDInstance(descendant)
			elseif descendant:IsA("GuiButton") and descendant.Name == "UnlockMouse" then
				descendant.Modal = false
				descendant.Active = false
				descendant.Visible = false
			end
		end))
	end

	ENV.HudThread = task.spawn(function()
		while ENV.Enabled do
			destroyFlyingHUD(StarterGui)
			destroyFlyingHUD(PlayerGui)
			releaseMouse()
			task.wait(0.25)
		end
	end)

	ENV.MouseThread = task.spawn(function()
		while ENV.Enabled do
			RunService.RenderStepped:Wait()
			releaseMouse()
		end
	end)
end

ENV.RestorePhysics = function()
	for _, object in ipairs(ENV.PhysicsObjects) do
		if object and object.Parent then
			object:Destroy()
		end
	end

	table.clear(ENV.PhysicsObjects)

	for part, state in pairs(ENV.PartStates) do
		if part and part.Parent then
			part.CanCollide = state.CanCollide
			part.CanTouch = state.CanTouch
			part.Anchored = state.Anchored
		end
	end

	table.clear(ENV.PartStates)
end

local Window = OrionLib:MakeWindow({
	Name = "Auto Fly",
	SaveConfig = false,
	IntroEnabled = false,
})

local MainTab = Window:MakeTab({
	Name = "Main",
})

local SettingsTab = Window:MakeTab({
	Name = "Settings",
})

local function landPlane()
	GroundHit:FireServer()
	FlightEnded:FireServer("landed")
end

local function stopAutoFly()
	ENV.Enabled = false
	ENV.Traveled = 0
	updateStudsLabel()
	StudsLabel.Visible = false

	for _, threadName in ipairs({ "RingThread", "FlightThread" }) do
		if ENV[threadName] then
			pcall(task.cancel, ENV[threadName])
			ENV[threadName] = nil
		end
	end

	stopMouseFix()
	ENV.RestorePhysics()
end

local function spamRings()
	while ENV.Enabled do
		ClientRingCollected:FireServer("Legendary")
		task.wait(RING_DELAY)
	end
end

local function getPlaneRoot(plane)
	return plane and (plane:FindFirstChild("HumanoidRootPart") or plane.PrimaryPart)
end

local function planeMatchesPlayer(plane)
	local planeName = plane.Name:lower()
	local playerName = LocalPlayer.Name:lower()
	local displayName = LocalPlayer.DisplayName:lower()

	if planeName:find(playerName, 1, true) or planeName:find(displayName, 1, true) then
		return true
	end

	for _, attributeName in ipairs({ "Owner", "OwnerName", "Player", "PlayerName", "Username" }) do
		local value = plane:GetAttribute(attributeName)
		if type(value) == "string" and value:lower() == playerName then
			return true
		end
	end

	local userId = plane:GetAttribute("OwnerUserId") or plane:GetAttribute("UserId")
	if userId == LocalPlayer.UserId then
		return true
	end

	local ownerValue = plane:FindFirstChild("Owner", true) or plane:FindFirstChild("Player", true)
	if ownerValue then
		if ownerValue:IsA("ObjectValue") and ownerValue.Value == LocalPlayer then
			return true
		end

		if ownerValue:IsA("StringValue") and ownerValue.Value:lower() == playerName then
			return true
		end

		if ownerValue:IsA("IntValue") and ownerValue.Value == LocalPlayer.UserId then
			return true
		end
	end

	return false
end

local function findPlayerPlane()
	local activePlanes = Workspace:FindFirstChild("ActivePlanes")
	if not activePlanes then
		return nil
	end

	for _, plane in ipairs(activePlanes:GetChildren()) do
		if getPlaneRoot(plane) and planeMatchesPlayer(plane) then
			return plane
		end
	end

	local characterRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local closestPlane
	local closestDistance = math.huge

	if characterRoot then
		for _, plane in ipairs(activePlanes:GetChildren()) do
			local root = getPlaneRoot(plane)

			if root then
				local distance = (root.Position - characterRoot.Position).Magnitude

				if distance < closestDistance then
					closestDistance = distance
					closestPlane = plane
				end
			end
		end

		if closestPlane then
			return closestPlane
		end
	end

	for _, plane in ipairs(activePlanes:GetChildren()) do
		if getPlaneRoot(plane) then
			return plane
		end
	end

	return activePlanes:FindFirstChild("Plane_" .. LocalPlayer.Name)
		or activePlanes:FindFirstChild(LocalPlayer.Name)
end

local function waitForPlane(timeout)
	local startedAt = os.clock()

	while ENV.Enabled and os.clock() - startedAt < timeout do
		local plane = findPlayerPlane()
		local root = getPlaneRoot(plane)

		if plane and root then
			return plane, root
		end

		task.wait(0.05)
	end

	return nil, nil
end

local function preparePlanePhysics(plane)
	local parts = plane:IsA("BasePart") and { plane } or plane:GetDescendants()

	for _, part in ipairs(parts) do
		if part:IsA("BasePart") then
			if not ENV.PartStates[part] then
				ENV.PartStates[part] = {
					CanCollide = part.CanCollide,
					CanTouch = part.CanTouch,
					Anchored = part.Anchored,
				}
			end

			part.CanCollide = false
			part.CanTouch = false
			part.Anchored = false
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function facePlane(plane, root, direction)
	local upVector = math.abs(direction:Dot(Vector3.yAxis)) > 0.98 and Vector3.zAxis or Vector3.yAxis

	return CFrame.lookAt(root.Position, root.Position + direction, upVector)
end

local function moveWithVelocity(plane, root, getVelocity, distance, speed)
	local lastPosition = root.Position
	local realTraveled = 0

	if distance <= 0 then
		return
	end

	speed = math.min(speed, MAX_SPEED)

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bodyVelocity.P = 6000
	bodyVelocity.Parent = root
	table.insert(ENV.PhysicsObjects, bodyVelocity)

	local bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	bodyGyro.P = 6000
	bodyGyro.D = 300
	bodyGyro.Parent = root
	table.insert(ENV.PhysicsObjects, bodyGyro)

	while ENV.Enabled and root.Parent and realTraveled < distance do
		local dt = RunService.Heartbeat:Wait()
		local velocity = getVelocity(root.Position, realTraveled, speed)
		local direction = velocity.Magnitude > 0 and velocity.Unit or FORWARD_DIRECTION
		local currentPosition = root.Position
		local moved = (currentPosition - lastPosition).Magnitude

		lastPosition = currentPosition
		realTraveled += moved
		ENV.Traveled = math.min(ENV.Traveled + moved, ENV.Distance)
		updateStudsLabel()

		bodyVelocity.Velocity = velocity
		bodyGyro.CFrame = facePlane(plane, root, direction)
		root.AssemblyLinearVelocity = velocity
		root.AssemblyAngularVelocity = Vector3.zero
	end

	bodyVelocity:Destroy()
	bodyGyro:Destroy()
	table.clear(ENV.PhysicsObjects)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local function moveLine(plane, root, targetOffset, speed)
	local direction = targetOffset.Unit
	moveWithVelocity(plane, root, function(_, _, currentSpeed)
		return direction * currentSpeed
	end, targetOffset.Magnitude, speed)
end

local function moveStraight(plane, root, distance)
	if distance <= 0 then
		return
	end

	local speed = math.min(GLIDE_SPEED, MAX_SPEED)
	local targetY = root.Position.Y

	moveWithVelocity(plane, root, function(position, _, currentSpeed)
		local verticalSpeed = math.clamp((targetY - position.Y) * 18, -MAX_SPEED, MAX_SPEED)
		return (FORWARD_DIRECTION * currentSpeed) + Vector3.new(0, verticalSpeed, 0)
	end, distance, speed)
end

local function boostPlaneOffSpawn()
	local startedAt = os.clock()

	while ENV.Enabled and os.clock() - startedAt < 0.5 do
		local plane = findPlayerPlane()
		local root = getPlaneRoot(plane)

		if root and not root.Anchored then
			root.AssemblyLinearVelocity = LAUNCH_DIRECTION * MAX_SPEED
			root.AssemblyAngularVelocity = Vector3.zero
		end

		task.wait()
	end
end

local function flyPath()
	local plane, root = waitForPlane(1)

	if not plane or not root then
		return
	end

	preparePlanePhysics(plane)
	ENV.Traveled = 0
	updateStudsLabel()

	local climbDistance = math.min(CLIMB_HEIGHT, ENV.Distance)
	moveLine(plane, root, Vector3.new(0, climbDistance, 0), CLIMB_SPEED)

	if ENV.Enabled and root.Parent then
		moveStraight(plane, root, ENV.Distance - ENV.Traveled)
	end
end

local function runFlight()
	while ENV.Enabled do
		releaseMouse()
		RequestLaunch:FireServer(LAUNCH_DIRECTION, MAX_SPEED)
		releaseMouse()
		task.defer(releaseMouse)
		task.spawn(boostPlaneOffSpawn)

		flyPath()

		if not ENV.Enabled then
			return
		end

		ENV.RestorePhysics()
		landPlane()
	end
end

MainTab:AddToggle({
	Name = "Auto Fly",
	Default = false,
	Callback = function(enabled)
		stopAutoFly()

		if enabled then
			ENV.Enabled = true
			ENV.Traveled = 0
			StudsLabel.Visible = true
			updateStudsLabel()
			startMouseFix()
			ENV.RingThread = task.spawn(spamRings)
			ENV.FlightThread = task.spawn(runFlight)
		else
			landPlane()
		end
	end,
})

MainTab:AddTextbox({
	Name = "Studs",
	Default = tostring(ENV.Distance),
	TextDisappear = false,
	Callback = function(value)
		local distance = tonumber(value)

		if distance then
			ENV.Distance = math.clamp(math.abs(distance), CLIMB_HEIGHT, 100000)
			updateStudsLabel()
		end
	end,
})

SettingsTab:AddButton({
	Name = "Destroy UI",
	Callback = function()
		stopAutoFly()
		landPlane()
		ENV.DestroyUI()
	end,
})

OrionLib:Init()
