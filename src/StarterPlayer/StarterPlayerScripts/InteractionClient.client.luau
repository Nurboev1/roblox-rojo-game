local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local remotes = ReplicatedStorage:WaitForChild("SurvivalRemotes")
local interactRemote = remotes:WaitForChild("Interact")

local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local TARGET_DISTANCE = 16
local DRAG_SEND_INTERVAL = 0.05

local highlight = Instance.new("Highlight")
highlight.Name = "TargetHighlight"
highlight.FillTransparency = 1
highlight.OutlineTransparency = 0
highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
highlight.DepthMode = Enum.HighlightDepthMode.Occluded
highlight.Enabled = false
highlight.Parent = player:WaitForChild("PlayerGui")

local promptGui = Instance.new("ScreenGui")
promptGui.Name = "InteractionPromptGui"
promptGui.ResetOnSpawn = false
promptGui.IgnoreGuiInset = true
promptGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
promptGui.Parent = player.PlayerGui

local actionPanel = Instance.new("Frame")
actionPanel.Name = "ActionPanel"
actionPanel.AnchorPoint = Vector2.new(1, 1)
actionPanel.Position = UDim2.new(1, -24, 1, -128)
actionPanel.Size = UDim2.fromOffset(130, 62)
actionPanel.BackgroundColor3 = Color3.fromRGB(21, 20, 18)
actionPanel.BackgroundTransparency = 0.12
actionPanel.BorderSizePixel = 0
actionPanel.Visible = false
actionPanel.ZIndex = 30
actionPanel.Parent = promptGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 8)
panelCorner.Parent = actionPanel

local function makeActionLabel(name, y, text)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = UDim2.fromOffset(12, y)
	label.Size = UDim2.new(1, -24, 0, 24)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(245, 238, 218)
	label.TextSize = 15
	label.ZIndex = 31
	label.Parent = actionPanel
	return label
end

local weldLabel = makeActionLabel("WeldLabel", 7, "Z  Weld")
makeActionLabel("StoreLabel", 31, "F  Store")

local currentTarget = nil
local draggingTarget = nil
local lastDragSentAt = 0

local function getCharacter()
	return player.Character
end

local function isInteractable(instance)
	return instance:GetAttribute("Interactable")
		or instance:GetAttribute("Collectible")
		or instance:GetAttribute("Movable")
		or instance:GetAttribute("Weldable")
		or instance:GetAttribute("HarvestableBone")
end

local function getHighlightTarget(instance)
	local cursor = instance

	while cursor and cursor ~= workspace do
		if isInteractable(cursor) then
			return cursor
		end

		cursor = cursor.Parent
	end

	return nil
end

local function findTarget()
	camera = workspace.CurrentCamera
	if not camera then
		return nil
	end

	local character = getCharacter()
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = character and { character } or {}

	local result = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * TARGET_DISTANCE, raycastParams)
	if not result then
		return nil
	end

	return getHighlightTarget(result.Instance)
end

local function setTarget(target)
	if currentTarget == target then
		return
	end

	currentTarget = target
	highlight.Adornee = target
	highlight.Enabled = target ~= nil

	actionPanel.Visible = target and target:GetAttribute("DroppedItem") and not IS_MOBILE

	if target and target:GetAttribute("DroppedItem") then
		weldLabel.Text = target:GetAttribute("Welded") and "Z  Unweld" or "Z  Weld"
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and currentTarget and currentTarget:GetAttribute("Movable") then
		draggingTarget = currentTarget
		return
	end

	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.F and currentTarget and currentTarget:GetAttribute("DroppedItem") then
		interactRemote:FireServer("Store", currentTarget)
	elseif input.KeyCode == Enum.KeyCode.Z and currentTarget and currentTarget:GetAttribute("Weldable") then
		interactRemote:FireServer("ToggleWeld", currentTarget)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if draggingTarget then
			camera = workspace.CurrentCamera
			if camera then
				interactRemote:FireServer("Throw", draggingTarget, camera.CFrame)
			end
		end
		draggingTarget = nil
	end
end)

RunService.RenderStepped:Connect(function()
	if not draggingTarget then
		setTarget(findTarget())
	end

	if draggingTarget and draggingTarget:IsDescendantOf(workspace) then
		local now = os.clock()
		if now - lastDragSentAt >= DRAG_SEND_INTERVAL then
			lastDragSentAt = now
			camera = workspace.CurrentCamera
			if camera then
				interactRemote:FireServer("Drag", draggingTarget, camera.CFrame)
			end
		end
	elseif draggingTarget then
		draggingTarget = nil
	end

	if currentTarget and currentTarget:GetAttribute("DroppedItem") then
		weldLabel.Text = currentTarget:GetAttribute("Welded") and "Z  Unweld" or "Z  Weld"
	end

end)
