-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

-- Player & Camera
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--------------------------------------------------------------------------------
-- 🖼️ BACKGROUND IMAGE CONFIGURATION
--------------------------------------------------------------------------------
local BACKGROUND_IMAGE_ID = "rbxassetid://1234567890" 

--------------------------------------------------------------------------------
-- ⚙️ CONFIGURATION SYSTEM
--------------------------------------------------------------------------------
local DefaultConfig = {
	MaxDistance = 300,
	MaxAngleDegrees = 10,
	BaseSmoothness = 0.08,
	PredictionTime = 0.025,
	MissSpreadOffset = 3.5,

	-- Combat Toggles
	LockOnEnabled = false,
	HardAimEnabled = false,
	TeamCheckEnabled = true,
	HitChanceEnabled = true,
	HitChancePercent = 80,
	TargetPartName = "Head",

	DiscordInvite = "https://discord.gg/JXqx2McNv",
	YouTubeChannel = "https://www.youtube.com/@GhostcoreA",

	Keybinds = {
		ToggleAim = Enum.KeyCode.Q,
		ToggleHardAim = Enum.KeyCode.H,
		ToggleTargetPart = Enum.KeyCode.F,
		ToggleMenu = Enum.KeyCode.K,
	},

	-- Ken V4 Sleek Neon / Electric Cyan Palette
	Colors = {
		Background = Color3.fromRGB(12, 14, 18),
		CardBG = Color3.fromRGB(18, 22, 28),
		CardHoverBG = Color3.fromRGB(24, 30, 38),
		RowBG = Color3.fromRGB(14, 18, 24),
		
		PrimaryTheme = Color3.fromRGB(6, 182, 212),
		PrimaryGlow = Color3.fromRGB(56, 189, 248),
		AccentNeon = Color3.fromRGB(6, 182, 212),
		
		DiscordColor = Color3.fromRGB(88, 101, 242),
		YouTubeColor = Color3.fromRGB(239, 68, 68),
		TextPrimary = Color3.fromRGB(248, 250, 252),
		TextMuted = Color3.fromRGB(148, 163, 184),
		BorderColor = Color3.fromRGB(30, 41, 59),
		BorderActiveColor = Color3.fromRGB(56, 189, 248)
	}
}

local Config = table.clone(DefaultConfig)
local CONFIG_FILE_NAME = "KEN_Shuradao_KenV4_Config.json"

local function SaveConfig()
	if writefile then
		local saveData = {
			MaxDistance = Config.MaxDistance,
			MaxAngleDegrees = Config.MaxAngleDegrees,
			BaseSmoothness = Config.BaseSmoothness,
			PredictionTime = Config.PredictionTime,
			LockOnEnabled = Config.LockOnEnabled,
			HardAimEnabled = Config.HardAimEnabled,
			TeamCheckEnabled = Config.TeamCheckEnabled,
			HitChanceEnabled = Config.HitChanceEnabled,
			HitChancePercent = Config.HitChancePercent,
			TargetPartName = Config.TargetPartName,
		}
		pcall(function()
			writefile(CONFIG_FILE_NAME, HttpService:JSONEncode(saveData))
		end)
	end
end

local function LoadConfig()
	if readfile and isfile and isfile(CONFIG_FILE_NAME) then
		pcall(function()
			local decoded = HttpService:JSONDecode(readfile(CONFIG_FILE_NAME))
			if type(decoded) == "table" then
				for key, value in pairs(decoded) do
					if Config[key] ~= nil then
						Config[key] = value
					end
				end
			end
		end)
	end
end

LoadConfig()

--------------------------------------------------------------------------------
-- RUNTIME TARGETING LOGIC
--------------------------------------------------------------------------------
local currentTargetPart = nil
local currentMissOffset = Vector3.zero
local lastOffsetTime = 0

local function hasLineOfSight(targetPart)
	local character = LocalPlayer.Character
	if not character or not character:FindFirstChild("Head") then return false end

	local origin = Camera.CFrame.Position
	local destination = targetPart.Position
	local direction = destination - origin

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.IgnoreWater = true

	local result = Workspace:Raycast(origin, direction, raycastParams)
	if result then
		return result.Instance:IsDescendantOf(targetPart.Parent)
	end
	return false
end

local function isTeammate(targetPlayer)
	if not Config.TeamCheckEnabled then return false end
	if targetPlayer.Neutral then return false end

	if targetPlayer.Team ~= nil and LocalPlayer.Team ~= nil then
		return targetPlayer.Team == LocalPlayer.Team
	end

	if targetPlayer.TeamColor ~= nil and LocalPlayer.TeamColor ~= nil then
		return targetPlayer.TeamColor == LocalPlayer.TeamColor
	end

	return false
end

local function getBestTarget()
	local bestTarget = nil
	local smallestAngle = math.rad(Config.MaxAngleDegrees)
	local cameraCFrame = Camera.CFrame
	local cameraLook = cameraCFrame.LookVector

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and not isTeammate(player) then
			local char = player.Character
			if char then
				local part = char:FindFirstChild(Config.TargetPartName)
				local humanoid = char:FindFirstChildOfClass("Humanoid")

				if part and humanoid and humanoid.Health > 0 then
					local toTarget = (part.Position - cameraCFrame.Position)
					local distance = toTarget.Magnitude

					if distance <= Config.MaxDistance then
						local directionToTarget = toTarget.Unit
						local angle = math.acos(math.clamp(cameraLook:Dot(directionToTarget), -1, 1))

						if angle < smallestAngle then
							if hasLineOfSight(part) then
								smallestAngle = angle
								bestTarget = part
							end
						end
					end
				end
			end
		end
	end
	return bestTarget
end

local function getTargetPosition()
	if not currentTargetPart then return nil end

	local targetVelocity = Vector3.zero
	local targetParent = currentTargetPart.Parent
	if targetParent then
		local rootPart = targetParent:FindFirstChild("HumanoidRootPart")
		if rootPart then
			targetVelocity = rootPart.AssemblyLinearVelocity
		end
	end

	local rawPosition = currentTargetPart.Position + (targetVelocity * Config.PredictionTime)
	local finalPosition = rawPosition

	if Config.HitChanceEnabled then
		local now = tick()
		if now - lastOffsetTime > 0.15 then
			lastOffsetTime = now
			local roll = math.random(1, 100)
			if roll > Config.HitChancePercent then
				local randomAngle = math.rad(math.random(0, 360))
				local randomElevation = math.rad(math.random(-45, 45))
				currentMissOffset = Vector3.new(
					math.cos(randomAngle) * Config.MissSpreadOffset,
					math.sin(randomElevation) * Config.MissSpreadOffset,
					math.sin(randomAngle) * Config.MissSpreadOffset
				)
			else
				currentMissOffset = Vector3.zero
			end
		end
		finalPosition = rawPosition + currentMissOffset
	end

	return finalPosition
end

--------------------------------------------------------------------------------
-- CAMERA STEP
--------------------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
	if not Config.LockOnEnabled then 
		currentTargetPart = nil
		return 
	end

	currentTargetPart = getBestTarget()

	if Config.LockOnEnabled and currentTargetPart then
		local finalPosition = getTargetPosition()
		if not finalPosition then return end

		local targetCFrame = CFrame.new(Camera.CFrame.Position, finalPosition)

		if Config.HardAimEnabled then
			Camera.CFrame = targetCFrame
		else
			local currentLook = Camera.CFrame.LookVector
			local targetDir = (finalPosition - Camera.CFrame.Position).Unit
			local angleDistance = math.acos(math.clamp(currentLook:Dot(targetDir), -1, 1))
			local dynamicSmoothness = math.clamp(Config.BaseSmoothness * (1 + angleDistance * 2), 0.02, 0.25)

			Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, dynamicSmoothness)
		end
	end
end)

--------------------------------------------------------------------------------
-- ⚡ KEN V4 MINIMALIST NEON UI SYSTEM
--------------------------------------------------------------------------------
local ToggleStateUpdaters = {}

local function createUI()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local colors = Config.Colors

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "KEN_Shuradao_KenV4"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- Main Ken V4 Frame Container (Sleek Rounded Geometry with Subtle Glow Accent)
	local mainCanvas = Instance.new("CanvasGroup")
	mainCanvas.Name = "MainCanvas"
	mainCanvas.Size = UDim2.new(0, 440, 0, 580)
	mainCanvas.Position = UDim2.new(0.5, -220, 0.5, -290)
	mainCanvas.BackgroundColor3 = colors.Background
	mainCanvas.GroupTransparency = 0
	mainCanvas.Active = true
	mainCanvas.Draggable = true
	mainCanvas.Parent = screenGui

	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, 10)
	containerCorner.Parent = mainCanvas

	local containerStroke = Instance.new("UIStroke")
	containerStroke.Name = "MainStroke"
	containerStroke.Color = Config.LockOnEnabled and colors.PrimaryGlow or colors.BorderColor
	containerStroke.Thickness = 1.5
	containerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	containerStroke.Parent = mainCanvas

	-- Neon Top Accent Line
	local topAccent = Instance.new("Frame")
	topAccent.Name = "TopAccent"
	topAccent.Size = UDim2.new(1, 0, 0, 2)
	topAccent.BackgroundColor3 = colors.PrimaryTheme
	topAccent.BorderSizePixel = 0
	topAccent.ZIndex = 3
	topAccent.Parent = mainCanvas

	-- Background Image Layer with Dark Aesthetic Blend
	local bgImage = Instance.new("ImageLabel")
	bgImage.Name = "BackgroundImage"
	bgImage.Size = UDim2.new(1, 0, 1, 0)
	bgImage.Position = UDim2.new(0, 0, 0, 0)
	bgImage.BackgroundTransparency = 1
	bgImage.Image = BACKGROUND_IMAGE_ID
	bgImage.ScaleType = Enum.ScaleType.Crop
	bgImage.ImageTransparency = 0.85
	bgImage.ZIndex = 0
	bgImage.Parent = mainCanvas

	local darkOverlay = Instance.new("Frame")
	darkOverlay.Name = "DarkOverlay"
	darkOverlay.Size = UDim2.new(1, 0, 1, 0)
	darkOverlay.BackgroundColor3 = Color3.fromRGB(8, 10, 14)
	darkOverlay.BackgroundTransparency = 0.3
	darkOverlay.ZIndex = 0
	darkOverlay.Parent = mainCanvas

	-- Header Frame
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 64)
	header.BackgroundTransparency = 1
	header.ZIndex = 2
	header.Parent = mainCanvas

	local headerTitle = Instance.new("TextLabel")
	headerTitle.Size = UDim2.new(1, -190, 0, 24)
	headerTitle.Position = UDim2.new(0, 18, 0, 14)
	headerTitle.BackgroundTransparency = 1
	headerTitle.Text = "KEN V4 //修羅道"
	headerTitle.Font = Enum.Font.GothamBold
	headerTitle.TextSize = 15
	headerTitle.TextColor3 = colors.TextPrimary
	headerTitle.TextXAlignment = Enum.TextXAlignment.Left
	headerTitle.ZIndex = 2
	headerTitle.Parent = header

	local headerSub = Instance.new("TextLabel")
	headerSub.Size = UDim2.new(1, -190, 0, 14)
	headerSub.Position = UDim2.new(0, 18, 0, 38)
	headerSub.BackgroundTransparency = 1
	headerSub.Text = "TOGGLE: [" .. Config.Keybinds.ToggleMenu.Name .. "] | SYSTEM: ACTIVE"
	headerSub.Font = Enum.Font.Code
	headerSub.TextSize = 8
	headerSub.TextColor3 = colors.TextMuted
	headerSub.TextXAlignment = Enum.TextXAlignment.Left
	headerSub.ZIndex = 2
	headerSub.Parent = header

	local function attachButtonHandlers(btn, defaultColor, hoverColor)
		btn.MouseEnter:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = hoverColor}):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = defaultColor}):Play()
		end)
	end

	-- Social Quick Buttons (Ken V4 style)
	local discordBtn = Instance.new("TextButton")
	discordBtn.Name = "DiscordBtn"
	discordBtn.Size = UDim2.new(0, 78, 0, 30)
	discordBtn.Position = UDim2.new(1, -170, 0, 17)
	discordBtn.BackgroundColor3 = colors.CardBG
	discordBtn.Text = "DISCORD"
	discordBtn.Font = Enum.Font.GothamBold
	discordBtn.TextSize = 9
	discordBtn.TextColor3 = colors.TextPrimary
	discordBtn.ZIndex = 2
	discordBtn.Parent = header

	local discordCorner = Instance.new("UICorner")
	discordCorner.CornerRadius = UDim.new(0, 6)
	discordCorner.Parent = discordBtn

	local discordStroke = Instance.new("UIStroke")
	discordStroke.Color = colors.BorderColor
	discordStroke.Thickness = 1
	discordStroke.Parent = discordBtn

	attachButtonHandlers(discordBtn, colors.CardBG, colors.CardHoverBG)

	discordBtn.Activated:Connect(function()
		if setclipboard then
			setclipboard(Config.DiscordInvite)
			discordBtn.Text = "COPIED"
			task.wait(1.2)
			discordBtn.Text = "DISCORD"
		end
	end)

	local ytBtn = Instance.new("TextButton")
	ytBtn.Name = "YouTubeBtn"
	ytBtn.Size = UDim2.new(0, 78, 0, 30)
	ytBtn.Position = UDim2.new(1, -86, 0, 17)
	ytBtn.BackgroundColor3 = colors.CardBG
	ytBtn.Text = "YOUTUBE"
	ytBtn.Font = Enum.Font.GothamBold
	ytBtn.TextSize = 9
	ytBtn.TextColor3 = colors.TextPrimary
	ytBtn.ZIndex = 2
	ytBtn.Parent = header

	local ytCorner = Instance.new("UICorner")
	ytCorner.CornerRadius = UDim.new(0, 6)
	ytCorner.Parent = ytBtn

	local ytStroke = Instance.new("UIStroke")
	ytStroke.Color = colors.BorderColor
	ytStroke.Thickness = 1
	ytStroke.Parent = ytBtn

	attachButtonHandlers(ytBtn, colors.CardBG, colors.CardHoverBG)

	ytBtn.Activated:Connect(function()
		if setclipboard then
			setclipboard(Config.YouTubeChannel)
			ytBtn.Text = "COPIED"
			task.wait(1.2)
			ytBtn.Text = "YOUTUBE"
		end
	end)

	-- Navigation Bar (Tabs)
	local navBar = Instance.new("Frame")
	navBar.Name = "NavBar"
	navBar.Size = UDim2.new(1, -36, 0, 42)
	navBar.Position = UDim2.new(0, 18, 0, 68)
	navBar.BackgroundColor3 = colors.CardBG
	navBar.BackgroundTransparency = 0.2
	navBar.ZIndex = 2
	navBar.Parent = mainCanvas

	local navCorner = Instance.new("UICorner")
	navCorner.CornerRadius = UDim.new(0, 6)
	navCorner.Parent = navBar

	local navStroke = Instance.new("UIStroke")
	navStroke.Color = colors.BorderColor
	navStroke.Thickness = 1
	navStroke.Parent = navBar

	-- Combat Tab
	local tabMainBtn = Instance.new("TextButton")
	tabMainBtn.Size = UDim2.new(0.5, -4, 1, -6)
	tabMainBtn.Position = UDim2.new(0, 3, 0, 3)
	tabMainBtn.BackgroundColor3 = colors.PrimaryTheme
	tabMainBtn.Text = "COMBAT"
	tabMainBtn.Font = Enum.Font.GothamBold
	tabMainBtn.TextSize = 10
	tabMainBtn.TextColor3 = colors.TextPrimary
	tabMainBtn.ZIndex = 3
	tabMainBtn.Parent = navBar

	local tabMainCorner = Instance.new("UICorner")
	tabMainCorner.CornerRadius = UDim.new(0, 5)
	tabMainCorner.Parent = tabMainBtn

	-- Settings Tab
	local tabConfigBtn = Instance.new("TextButton")
	tabConfigBtn.Size = UDim2.new(0.5, -4, 1, -6)
	tabConfigBtn.Position = UDim2.new(0.5, 1, 0, 3)
	tabConfigBtn.BackgroundColor3 = colors.CardBG
	tabConfigBtn.Text = "SETTINGS"
	tabConfigBtn.Font = Enum.Font.GothamBold
	tabConfigBtn.TextSize = 10
	tabConfigBtn.TextColor3 = colors.TextMuted
	tabConfigBtn.ZIndex = 3
	tabConfigBtn.Parent = navBar

	local tabConfigCorner = Instance.new("UICorner")
	tabConfigCorner.CornerRadius = UDim.new(0, 5)
	tabConfigCorner.Parent = tabConfigBtn

	-- Pages Container
	local pagesHolder = Instance.new("Frame")
	pagesHolder.Size = UDim2.new(1, -36, 1, -126)
	pagesHolder.Position = UDim2.new(0, 18, 0, 118)
	pagesHolder.BackgroundTransparency = 1
	pagesHolder.ZIndex = 2
	pagesHolder.Parent = mainCanvas

	local mainPage = Instance.new("CanvasGroup")
	mainPage.Size = UDim2.new(1, 0, 1, 0)
	mainPage.BackgroundTransparency = 1
	mainPage.GroupTransparency = 0
	mainPage.ZIndex = 2
	mainPage.Parent = pagesHolder

	local mainScroll = Instance.new("ScrollingFrame")
	mainScroll.Size = UDim2.new(1, 0, 1, 0)
	mainScroll.BackgroundTransparency = 1
	mainScroll.ScrollBarThickness = 2
	mainScroll.ScrollBarImageColor3 = colors.PrimaryGlow
	mainScroll.ZIndex = 2
	mainScroll.Parent = mainPage

	local mainLayout = Instance.new("UIListLayout")
	mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
	mainLayout.Padding = UDim.new(0, 10)
	mainLayout.Parent = mainScroll

	mainLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		mainScroll.CanvasSize = UDim2.new(0, 0, 0, mainLayout.AbsoluteContentSize.Y + 12)
	end)

	local configPage = Instance.new("CanvasGroup")
	configPage.Size = UDim2.new(1, 0, 1, 0)
	configPage.BackgroundTransparency = 1
	configPage.GroupTransparency = 1
	configPage.Visible = false
	configPage.ZIndex = 2
	configPage.Parent = pagesHolder

	local configScroll = Instance.new("ScrollingFrame")
	configScroll.Size = UDim2.new(1, 0, 1, 0)
	configScroll.BackgroundTransparency = 1
	configScroll.ScrollBarThickness = 2
	configScroll.ScrollBarImageColor3 = colors.PrimaryGlow
	configScroll.ZIndex = 2
	configScroll.Parent = configPage

	local configLayout = Instance.new("UIListLayout")
	configLayout.SortOrder = Enum.SortOrder.LayoutOrder
	configLayout.Padding = UDim.new(0, 10)
	configLayout.Parent = configScroll

	configLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		configScroll.CanvasSize = UDim2.new(0, 0, 0, configLayout.AbsoluteContentSize.Y + 12)
	end)

	local currentTab = "Main"

	tabMainBtn.Activated:Connect(function()
		if currentTab == "Main" then return end
		currentTab = "Main"
		TweenService:Create(tabMainBtn, TweenInfo.new(0.15), {BackgroundColor3 = colors.PrimaryTheme, TextColor3 = colors.TextPrimary}):Play()
		TweenService:Create(tabConfigBtn, TweenInfo.new(0.15), {BackgroundColor3 = colors.CardBG, TextColor3 = colors.TextMuted}):Play()
		mainPage.Visible = true
		TweenService:Create(mainPage, TweenInfo.new(0.2), {GroupTransparency = 0}):Play()
		TweenService:Create(configPage, TweenInfo.new(0.1), {GroupTransparency = 1}):Play()
		task.delay(0.1, function() if currentTab ~= "Config" then configPage.Visible = false end end)
	end)

	tabConfigBtn.Activated:Connect(function()
		if currentTab == "Config" then return end
		currentTab = "Config"
		TweenService:Create(tabConfigBtn, TweenInfo.new(0.15), {BackgroundColor3 = colors.PrimaryTheme, TextColor3 = colors.TextPrimary}):Play()
		TweenService:Create(tabMainBtn, TweenInfo.new(0.15), {BackgroundColor3 = colors.CardBG, TextColor3 = colors.TextMuted}):Play()
		configPage.Visible = true
		TweenService:Create(configPage, TweenInfo.new(0.2), {GroupTransparency = 0}):Play()
		TweenService:Create(mainPage, TweenInfo.new(0.1), {GroupTransparency = 1}):Play()
		task.delay(0.1, function() if currentTab ~= "Main" then mainPage.Visible = false end end)
	end)

	local function createToggleRow(parentPage, name, titleText, hotkeyText, initialValue, onToggle)
		local isChecked = initialValue

		local row = Instance.new("Frame")
		row.Name = name .. "Row"
		row.Size = UDim2.new(1, 0, 0, 52)
		row.BackgroundColor3 = colors.CardBG
		row.BackgroundTransparency = 0.1
		row.ZIndex = 3
		row.Parent = parentPage

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 6)
		rowCorner.Parent = row

		local rowStroke = Instance.new("UIStroke")
		rowStroke.Color = isChecked and colors.PrimaryGlow or colors.BorderColor
		rowStroke.Thickness = isChecked and 1.5 or 1
		rowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		rowStroke.Parent = row

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(0.6, 0, 0.45, 0)
		title.Position = UDim2.new(0, 14, 0, 9)
		title.BackgroundTransparency = 1
		title.Text = titleText
		title.Font = Enum.Font.GothamBold
		title.TextSize = 11
		title.TextColor3 = colors.TextPrimary
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.ZIndex = 3
		title.Parent = row

		local subtext = Instance.new("TextLabel")
		subtext.Name = "Subtext"
		subtext.Size = UDim2.new(0.6, 0, 0.35, 0)
		subtext.Position = UDim2.new(0, 14, 0.45, 3)
		subtext.BackgroundTransparency = 1
		subtext.Text = hotkeyText
		subtext.Font = Enum.Font.Code
		subtext.TextSize = 8
		subtext.TextColor3 = colors.TextMuted
		subtext.TextXAlignment = Enum.TextXAlignment.Left
		subtext.ZIndex = 3
		subtext.Parent = row

		local switchTrack = Instance.new("Frame")
		switchTrack.Size = UDim2.new(0, 42, 0, 22)
		switchTrack.Position = UDim2.new(1, -54, 0.5, -11)
		switchTrack.BackgroundColor3 = isChecked and colors.PrimaryTheme or colors.RowBG
		switchTrack.ZIndex = 3
		switchTrack.Parent = row

		local trackCorner = Instance.new("UICorner")
		trackCorner.CornerRadius = UDim.new(0, 11)
		trackCorner.Parent = switchTrack

		local switchKnob = Instance.new("Frame")
		switchKnob.Size = UDim2.new(0, 16, 0, 16)
		switchKnob.Position = isChecked and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
		switchKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		switchKnob.ZIndex = 4
		switchKnob.Parent = switchTrack

		local knobCorner = Instance.new("UICorner")
		knobCorner.CornerRadius = UDim.new(0, 8)
		knobCorner.Parent = switchKnob

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 1, 0)
		btn.BackgroundTransparency = 1
		btn.Text = ""
		btn.ZIndex = 5
		btn.Parent = row

		row.MouseEnter:Connect(function()
			TweenService:Create(row, TweenInfo.new(0.15), {BackgroundColor3 = colors.CardHoverBG}):Play()
		end)
		row.MouseLeave:Connect(function()
			TweenService:Create(row, TweenInfo.new(0.15), {BackgroundColor3 = colors.CardBG}):Play()
		end)

		local function setToggleState(state)
			isChecked = state
			TweenService:Create(switchTrack, TweenInfo.new(0.15), {BackgroundColor3 = isChecked and colors.PrimaryTheme or colors.RowBG}):Play()
			TweenService:Create(switchKnob, TweenInfo.new(0.15), {Position = isChecked and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)}):Play()
			TweenService:Create(rowStroke, TweenInfo.new(0.15), {Color = isChecked and colors.PrimaryGlow or colors.BorderColor, Thickness = isChecked and 1.5 or 1}):Play()
		end

		btn.Activated:Connect(function()
			isChecked = not isChecked
			setToggleState(isChecked)
			onToggle(isChecked, subtext)
			SaveConfig()
		end)

		ToggleStateUpdaters[name] = setToggleState
		return setToggleState, subtext
	end

	local function createSliderRow(parentPage, name, titleText, minVal, maxVal, currentVal, suffix, onChange)
		local sliderRow = Instance.new("Frame")
		sliderRow.Name = name .. "Slider"
		sliderRow.Size = UDim2.new(1, 0, 0, 56)
		sliderRow.BackgroundColor3 = colors.CardBG
		sliderRow.BackgroundTransparency = 0.1
		sliderRow.ZIndex = 3
		sliderRow.Parent = parentPage

		local sliderCorner = Instance.new("UICorner")
		sliderCorner.CornerRadius = UDim.new(0, 6)
		sliderCorner.Parent = sliderRow

		local sliderStroke = Instance.new("UIStroke")
		sliderStroke.Color = colors.BorderColor
		sliderStroke.Thickness = 1
		sliderStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		sliderStroke.Parent = sliderRow

		local sliderLabel = Instance.new("TextLabel")
		sliderLabel.Size = UDim2.new(0.55, 0, 0, 16)
		sliderLabel.Position = UDim2.new(0, 14, 0, 9)
		sliderLabel.BackgroundTransparency = 1
		sliderLabel.Text = titleText
		sliderLabel.Font = Enum.Font.GothamBold
		sliderLabel.TextSize = 11
		sliderLabel.TextColor3 = colors.TextPrimary
		sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
		sliderLabel.ZIndex = 3
		sliderLabel.Parent = sliderRow

		local sliderValueText = Instance.new("TextLabel")
		sliderValueText.Size = UDim2.new(0.35, 0, 0, 16)
		sliderValueText.Position = UDim2.new(1, -114, 0, 9)
		sliderValueText.BackgroundTransparency = 1
		sliderValueText.Text = tostring(currentVal) .. suffix
		sliderValueText.Font = Enum.Font.Code
		sliderValueText.TextSize = 10
		sliderValueText.TextColor3 = colors.PrimaryGlow
		sliderValueText.TextXAlignment = Enum.TextXAlignment.Right
		sliderValueText.ZIndex = 3
		sliderValueText.Parent = sliderRow

		local sliderTrack = Instance.new("Frame")
		sliderTrack.Size = UDim2.new(1, -28, 0, 6)
		sliderTrack.Position = UDim2.new(0, 14, 0, 38)
		sliderTrack.BackgroundColor3 = colors.RowBG
		sliderTrack.ZIndex = 3
		sliderTrack.Parent = sliderRow

		local trackCorner = Instance.new("UICorner")
		trackCorner.CornerRadius = UDim.new(0, 3)
		trackCorner.Parent = sliderTrack

		local initScale = math.clamp((currentVal - minVal) / (maxVal - minVal), 0, 1)

		local sliderFill = Instance.new("Frame")
		sliderFill.Size = UDim2.new(initScale, 0, 1, 0)
		sliderFill.BackgroundColor3 = colors.PrimaryTheme
		sliderFill.ZIndex = 3
		sliderFill.Parent = sliderTrack

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0, 3)
		fillCorner.Parent = sliderFill

		local sliderKnob = Instance.new("Frame")
		sliderKnob.Size = UDim2.new(0, 12, 0, 12)
		sliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
		sliderKnob.Position = UDim2.new(initScale, 0, 0.5, 0)
		sliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		sliderKnob.ZIndex = 4
		sliderKnob.Parent = sliderTrack

		local knobCorner = Instance.new("UICorner")
		knobCorner.CornerRadius = UDim.new(0, 6)
		knobCorner.Parent = sliderKnob

		local sliderInteractBtn = Instance.new("TextButton")
		sliderInteractBtn.Size = UDim2.new(1, 0, 1, 0)
		sliderInteractBtn.BackgroundTransparency = 1
		sliderInteractBtn.Text = ""
		sliderInteractBtn.ZIndex = 5
		sliderInteractBtn.Parent = sliderRow

		local isDragging = false

		local function updateSlider(xPos)
			local trackAbsPos = sliderTrack.AbsolutePosition.X
			local trackAbsSize = sliderTrack.AbsoluteSize.X
			local scale = math.clamp((xPos - trackAbsPos) / trackAbsSize, 0, 1)
			local val = minVal + (scale * (maxVal - minVal))

			if maxVal <= 1 then
				val = math.floor(val * 100) / 100
			elseif maxVal <= 20 then
				val = math.floor(val * 10) / 10
			else
				val = math.floor(val)
			end

			sliderFill.Size = UDim2.new(scale, 0, 1, 0)
			sliderKnob.Position = UDim2.new(scale, 0, 0.5, 0)

			sliderValueText.Text = tostring(val) .. suffix
			onChange(val)
		end

		sliderRow.MouseEnter:Connect(function()
			TweenService:Create(sliderRow, TweenInfo.new(0.15), {BackgroundColor3 = colors.CardHoverBG}):Play()
		end)
		sliderRow.MouseLeave:Connect(function()
			TweenService:Create(sliderRow, TweenInfo.new(0.15), {BackgroundColor3 = colors.CardBG}):Play()
		end)

		sliderInteractBtn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				isDragging = true
				mainCanvas.Draggable = false
				updateSlider(input.Position.X)
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				updateSlider(input.Position.X)
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				if isDragging then
					isDragging = false
					mainCanvas.Draggable = true
					SaveConfig()
				end
			end
		end)
	end

	-- COMBAT TAB CONTENT
	createToggleRow(
		mainScroll, "LockOn", "Aim Assist", "KEY: [" .. Config.Keybinds.ToggleAim.Name .. "]",
		Config.LockOnEnabled,
		function(newState)
			Config.LockOnEnabled = newState
			if not Config.LockOnEnabled then currentTargetPart = nil end
			containerStroke.Color = Config.LockOnEnabled and colors.PrimaryGlow or colors.BorderColor
			topAccent.BackgroundColor3 = Config.LockOnEnabled and colors.PrimaryGlow or colors.PrimaryTheme
		end
	)

	createToggleRow(
		mainScroll, "HardAim", "Hard Lock Snap", "KEY: [" .. Config.Keybinds.ToggleHardAim.Name .. "]",
		Config.HardAimEnabled,
		function(newState) Config.HardAimEnabled = newState end
	)

	local _, targetPartSubtext = createToggleRow(
		mainScroll, "TargetPart", "Target Bone", "KEY: [" .. Config.Keybinds.ToggleTargetPart.Name .. "]",
		Config.TargetPartName == "HumanoidRootPart",
		function(isChecked, subtextLabel)
			Config.TargetPartName = isChecked and "HumanoidRootPart" or "Head"
			subtextLabel.Text = isChecked and "PART: TORSO" or "PART: HEAD"
		end
	)
	targetPartSubtext.Text = Config.TargetPartName == "HumanoidRootPart" and "PART: TORSO" or "PART: HEAD"

	createToggleRow(
		mainScroll, "HitChance", "Hit Chance RNG", "Simulates spread offset",
		Config.HitChanceEnabled,
		function(newState) Config.HitChanceEnabled = newState end
	)

	createSliderRow(
		mainScroll, "Accuracy", "Accuracy Rate",
		0, 100, Config.HitChancePercent, "%",
		function(val) Config.HitChancePercent = val end
	)

	createToggleRow(
		mainScroll, "TeamCheck", "Team Check", "Filter out teammates",
		Config.TeamCheckEnabled,
		function(newState) Config.TeamCheckEnabled = newState end
	)

	-- SETTINGS TAB CONTENT
	createSliderRow(
		configScroll, "MaxDistance", "Aim Range",
		50, 1000, Config.MaxDistance, " studs",
		function(val) Config.MaxDistance = val end
	)

	createSliderRow(
		configScroll, "MaxAngleDegrees", "FOV Range",
		1, 90, Config.MaxAngleDegrees, "°",
		function(val) Config.MaxAngleDegrees = val end
	)

	createSliderRow(
		configScroll, "BaseSmoothness", "Smoothness",
		0.01, 0.25, Config.BaseSmoothness, "",
		function(val) Config.BaseSmoothness = val end
	)

	createSliderRow(
		configScroll, "PredictionTime", "Prediction",
		0, 0.1, Config.PredictionTime, "s",
		function(val) Config.PredictionTime = val end
	)

	-- Keybind toggling behavior
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Config.Keybinds.ToggleMenu then
			mainCanvas.Visible = not mainCanvas.Visible
		elseif input.KeyCode == Config.Keybinds.ToggleAim then
			Config.LockOnEnabled = not Config.LockOnEnabled
			if ToggleStateUpdaters["LockOn"] then
				ToggleStateUpdaters["LockOn"](Config.LockOnEnabled)
			end
			containerStroke.Color = Config.LockOnEnabled and colors.PrimaryGlow or colors.BorderColor
			topAccent.BackgroundColor3 = Config.LockOnEnabled and colors.PrimaryGlow or colors.PrimaryTheme
			SaveConfig()
		elseif input.KeyCode == Config.Keybinds.ToggleHardAim then
			Config.HardAimEnabled = not Config.HardAimEnabled
			if ToggleStateUpdaters["HardAim"] then
				ToggleStateUpdaters["HardAim"](Config.HardAimEnabled)
			end
			SaveConfig()
		elseif input.KeyCode == Config.Keybinds.ToggleTargetPart then
			if Config.TargetPartName == "Head" then
				Config.TargetPartName = "HumanoidRootPart"
				if ToggleStateUpdaters["TargetPart"] then
					ToggleStateUpdaters["TargetPart"](true)
				end
			else
				Config.TargetPartName = "Head"
				if ToggleStateUpdaters["TargetPart"] then
					ToggleStateUpdaters["TargetPart"](false)
				end
			end
			SaveConfig()
		end
	end)
end

createUI()
