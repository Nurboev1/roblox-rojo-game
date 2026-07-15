local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "DesertLoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.Parent = playerGui

local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(19, 15, 12)
background.BorderSizePixel = 0
background.Parent = gui

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(37, 28, 20)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(104, 74, 43)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(195, 143, 82)),
})
gradient.Rotation = 90
gradient.Parent = background

local sun = Instance.new("Frame")
sun.Name = "Sun"
sun.AnchorPoint = Vector2.new(0.5, 0.5)
sun.Position = UDim2.fromScale(0.5, 0.28)
sun.Size = UDim2.fromOffset(128, 128)
sun.BackgroundColor3 = Color3.fromRGB(255, 201, 118)
sun.BackgroundTransparency = 0.1
sun.BorderSizePixel = 0
sun.Parent = background

local sunCorner = Instance.new("UICorner")
sunCorner.CornerRadius = UDim.new(1, 0)
sunCorner.Parent = sun

local sunGradient = Instance.new("UIGradient")
sunGradient.Color = ColorSequence.new(Color3.fromRGB(255, 223, 158), Color3.fromRGB(213, 119, 58))
sunGradient.Rotation = 90
sunGradient.Parent = sun

local title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.47)
title.Size = UDim2.fromOffset(520, 58)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "DESERT SURVIVAL"
title.TextColor3 = Color3.fromRGB(255, 238, 205)
title.TextSize = 42
title.Parent = background

local status = Instance.new("TextLabel")
status.Name = "Status"
status.AnchorPoint = Vector2.new(0.5, 0.5)
status.Position = UDim2.fromScale(0.5, 0.56)
status.Size = UDim2.fromOffset(360, 30)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.Text = "Preparing the desert..."
status.TextColor3 = Color3.fromRGB(234, 210, 170)
status.TextSize = 18
status.Parent = background

local barBack = Instance.new("Frame")
barBack.Name = "BarBack"
barBack.AnchorPoint = Vector2.new(0.5, 0.5)
barBack.Position = UDim2.fromScale(0.5, 0.64)
barBack.Size = UDim2.fromOffset(360, 8)
barBack.BackgroundColor3 = Color3.fromRGB(50, 38, 28)
barBack.BorderSizePixel = 0
barBack.Parent = background

local barBackCorner = Instance.new("UICorner")
barBackCorner.CornerRadius = UDim.new(1, 0)
barBackCorner.Parent = barBack

local barFill = Instance.new("Frame")
barFill.Name = "BarFill"
barFill.Size = UDim2.fromScale(0.18, 1)
barFill.BackgroundColor3 = Color3.fromRGB(255, 206, 126)
barFill.BorderSizePixel = 0
barFill.Parent = barBack

local barFillCorner = Instance.new("UICorner")
barFillCorner.CornerRadius = UDim.new(1, 0)
barFillCorner.Parent = barFill

local progressTween = nil

local function setProgress(alpha)
	alpha = math.clamp(alpha, 0.08, 1)

	if progressTween then
		progressTween:Cancel()
	end

	progressTween = TweenService:Create(
		barFill,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(alpha, 1) }
	)
	progressTween:Play()
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local worldReady = ReplicatedStorage:WaitForChild("WorldReady", 20)
local worldLoadProgress = ReplicatedStorage:WaitForChild("WorldLoadProgress", 20)

if worldLoadProgress then
	setProgress(worldLoadProgress.Value)
	worldLoadProgress:GetPropertyChangedSignal("Value"):Connect(function()
		local percent = math.floor(worldLoadProgress.Value * 100 + 0.5)
		status.Text = "Loading desert " .. percent .. "%"
		setProgress(worldLoadProgress.Value)
	end)
end

if worldReady and not worldReady.Value then
	worldReady:GetPropertyChangedSignal("Value"):Wait()
end

workspace:WaitForChild("Chunk_0,0", 20)
task.wait(0.35)

if progressTween then
	progressTween:Cancel()
end
barFill.Size = UDim2.fromScale(1, 1)
status.Text = "Ready"
task.wait(0.25)

local fadeInfo = TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
TweenService:Create(background, fadeInfo, { BackgroundTransparency = 1 }):Play()
TweenService:Create(title, fadeInfo, { TextTransparency = 1 }):Play()
TweenService:Create(status, fadeInfo, { TextTransparency = 1 }):Play()
TweenService:Create(sun, fadeInfo, { BackgroundTransparency = 1 }):Play()
TweenService:Create(barBack, fadeInfo, { BackgroundTransparency = 1 }):Play()
TweenService:Create(barFill, fadeInfo, { BackgroundTransparency = 1 }):Play()
task.wait(0.6)
gui:Destroy()
