local Lighting = game:GetService("Lighting")

local MINUTES_PER_DAY = 10
local SECONDS_PER_DAY = MINUTES_PER_DAY * 60
local START_TIME = 9
local SOLAR_LATITUDE = 23.5

local DAY_START = 6.5
local DAY_END = 17.5
local NIGHT_START = 19
local NIGHT_END = 5

local startTime = tick() - (START_TIME / 24 * SECONDS_PER_DAY)

for _, child in Lighting:GetChildren() do
	if child:IsA("Atmosphere") then
		child:Destroy()
	end
end

local function smoothstep(alpha)
	alpha = math.clamp(alpha, 0, 1)
	return alpha * alpha * (3 - 2 * alpha)
end

local function inverseLerp(minValue, maxValue, value)
	return math.clamp((value - minValue) / (maxValue - minValue), 0, 1)
end

local function getNightAlpha(clockTime)
	if clockTime >= NIGHT_START or clockTime <= NIGHT_END then
		return 1
	end

	if clockTime > DAY_END and clockTime < NIGHT_START then
		return smoothstep(inverseLerp(DAY_END, NIGHT_START, clockTime))
	end

	if clockTime > NIGHT_END and clockTime < DAY_START then
		return 1 - smoothstep(inverseLerp(NIGHT_END, DAY_START, clockTime))
	end

	return 0
end

local function lerpNumber(a, b, alpha)
	return a + (b - a) * alpha
end

local function applyLighting(clockTime)
	local nightAlpha = getNightAlpha(clockTime)

	Lighting.GlobalShadows = true
	Lighting.Brightness = lerpNumber(2.2, 0.8, nightAlpha)
	Lighting.ExposureCompensation = lerpNumber(0, -0.2, nightAlpha)
	Lighting.Ambient = Color3.fromRGB(35, 31, 27):Lerp(Color3.fromRGB(42, 40, 36), nightAlpha)
	Lighting.OutdoorAmbient = Color3.fromRGB(138, 125, 105):Lerp(Color3.fromRGB(74, 69, 60), nightAlpha)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 224, 170):Lerp(Color3.fromRGB(112, 106, 92), nightAlpha)
	Lighting.ColorShift_Bottom = Color3.fromRGB(190, 120, 70):Lerp(Color3.fromRGB(28, 26, 23), nightAlpha)

	-- Day fog hides chunk pop-in; night fog makes the desert feel dark and close.
	Lighting.FogStart = lerpNumber(260, 80, nightAlpha)
	Lighting.FogEnd = lerpNumber(900, 420, nightAlpha)
	Lighting.FogColor = Color3.fromRGB(184, 163, 135):Lerp(Color3.fromRGB(34, 32, 29), nightAlpha)

end

_G.SetTimeManually = function(newTime)
	local clockTime = math.clamp(newTime, 0, 24)
	startTime = tick() - (clockTime / 24 * SECONDS_PER_DAY)
	Lighting.ClockTime = clockTime
	applyLighting(clockTime)
end

Lighting.ClockTime = START_TIME
Lighting.GeographicLatitude = SOLAR_LATITUDE
applyLighting(START_TIME)

task.spawn(function()
	while true do
		local elapsed = (tick() - startTime) % SECONDS_PER_DAY
		local clockTime = (elapsed / SECONDS_PER_DAY) * 24

		Lighting.ClockTime = clockTime
		applyLighting(clockTime)

		task.wait(0.25)
	end
end)
