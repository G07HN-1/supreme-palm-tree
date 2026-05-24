--loadstring(game:HttpGet("https://raw.githubusercontent.com/G07HN-1/supreme-palm-tree/refs/heads/main/script.lua"))()

local PreviousENV = getgenv().FortuneSeedUI

if PreviousENV then
	PreviousENV.Stop = true

	if type(PreviousENV.Connections) == "table" then
		for _, connection in ipairs(PreviousENV.Connections) do
			pcall(function()
				connection:Disconnect()
			end)
		end
	end

	task.wait(0.5)
end

getgenv().FortuneSeedUI = {
	Stop = false,
	Connections = {},
}

local ENV = getgenv().FortuneSeedUI

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RollSeedsRemote = Remotes:WaitForChild("RollSeeds")
local BuySeedRemote = Remotes:WaitForChild("BuySeed")
local SellCratesRemote = Remotes:WaitForChild("SellCrates")
local UpgradePlantRemote = Remotes:FindFirstChild("UpgradePlant")
local RemovePlantRemote = Remotes:FindFirstChild("RemovePlant")
local UseSprayRemote = Remotes:FindFirstChild("UseSpray")
local PlantSeedRemote = Remotes:FindFirstChild("PlantSeed")

local GearRemote = Remotes:FindFirstChild("Gear")
local GearTransaction = GearRemote and GearRemote:FindFirstChild("Transaction")
local EggShopRemote = Remotes:FindFirstChild("EggShop")
local EggShopTransaction = EggShopRemote and EggShopRemote:FindFirstChild("Transaction")
local RollEggRemote = Remotes:FindFirstChild("RollEgg")
local ComposterRemote = Remotes:FindFirstChild("Composter")
local ComposterInsertSeed = ComposterRemote and ComposterRemote:FindFirstChild("InsertSeed")
local ComposterPullLever = ComposterRemote and ComposterRemote:FindFirstChild("PullLever")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local SeedsFolder = Assets:WaitForChild("Seeds")
local GearFolder = Assets:WaitForChild("Gear")
local GearStocksFolder = ReplicatedStorage:FindFirstChild("GearStocks")
	or ReplicatedStorage:WaitForChild("GearStocks", 5)

local OrionURL = "https://raw.githubusercontent.com/GhostDuckyy/UI-Libraries/refs/heads/main/Orion/source.lua"

local OrionLib = loadstring(game:HttpGet(OrionURL))()

--// SETTINGS

local State = {
	AutoRoll = false,
	AutoBuySelectedSeeds = false,
	AutoBuySelectedSeedRarities = false,

	AutoBuyAllGear = false,
	AutoBuyAllEggs = false,
	AutoBuySelectedEggRarities = false,
	AutoSell = false,
	AutoCompost = false,
	AutoUpgradePlants = false,
	AutoSprayPlants = false,
	AutoPlantSeeds = false,
	AntiAFK = true,

	SelectedSeedOption = nil,
	SelectedSeeds = {},
	SelectedSeedRarityOption = nil,
	SelectedSeedRarities = {},
	SelectedEggRarityOption = nil,
	SelectedEggRarities = {},
	SelectedCompostSeedOption = nil,
	SelectedCompostSeeds = {},
	SelectedSprayOption = nil,
	SelectedSprayBaseName = nil,
	SelectedPlantSeedOption = nil,

	SaveConfigEnabled = true,
	RollDelay = 1.25,
	GearDelay = 30,
	EggDelay = 30,
	SellDelay = 15,
	CompostDelay = 5,
	PlantUpgradeDelay = 2.5,
	PlantUpgradeTargetLevel = 40,
	SprayDelay = 5,
	PlantSeedDelay = 5,

	WebhookURL = "",
	WebhookSeedPurchases = true,
	WebhookExpensiveGear = true,
	ExpensiveThreshold = 10000000000,
	ExpensiveThresholdOption = "10B",
}

local SeedOptionMap = {}
local CompostSeedOptionMap = {}
local PlantSeedOptionMap = {}
local SprayOptionMap = {}
local GearNamesCache = nil
local GearPriceCache = {}
local PlotCache = nil
local FarmDirtCache = nil
local FarmDirtCachePlot = nil
local FarmDirtCacheTime = 0
local GearBuyItemDelay = 0.2
local EggBuyItemDelay = 0.2
local PlantUpgradePassDuration = 2.5
local PlantUpgradeBatchSize = 30
local PlantRemovePassDuration = 5
local FarmDirtCacheTTL = 5
local IsUpgradingPlants = false
local IsRemovingPlants = false
local IsSprayingPlants = false
local IsPlantingSeeds = false

local SeedRarityOptions = {
	"Select Rarity",
	"Common",
	"Uncommon",
	"Rare",
	"Epic",
	"Legendary",
	"Secret",
	"Prismatic",
	"Divine",
	"Exotic",
	"Transcended",
}

local SeedRarityColors = {
	Common = 16777215, -- white
	Uncommon = 5763719, -- green
	Rare = 3447003, -- blue
	Epic = 10181046, -- purple
	Legendary = 16753920, -- gold
	Secret = 16711680, -- red
	Prismatic = 16711935, -- pink
	Divine = 16776960, -- yellow
	Exotic = 16744192, -- orange
	Transcended = 65535, -- cyan
	Unknown = 8421504, -- gray
}

local EggRarityOptions = {
	"Select Rarity",
	"Common",
	"Rare",
	"Epic",
}

local ConsoleOutput = false

local function consolePrint(...)
	if ConsoleOutput then
		print(...)
	end
end

local function consoleWarn(...)
	if ConsoleOutput then
		warn(...)
	end
end

local function getSafeDropdownDefault(options, savedValue, fallback)
	for _, option in ipairs(options) do
		if option == savedValue then
			return savedValue
		end
	end

	return fallback
end

--// PRICE UTILS

local function trim(str)
	return tostring(str or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function parsePrice(text)
	text = tostring(text or ""):lower()
	text = text:gsub(",", "")
	text = text:gsub("%$", "")
	text = text:gsub("%s+", "")

	local number, suffix = text:match("([%d%.]+)(%a*)")
	number = tonumber(number)

	if not number then
		return 0
	end

	local mult = 1

	if suffix == "k" then
		mult = 1e3
	elseif suffix == "m" then
		mult = 1e6
	elseif suffix == "b" then
		mult = 1e9
	elseif suffix == "t" then
		mult = 1e12
	elseif suffix == "qa" or suffix == "q" then
		mult = 1e15
	end

	return number * mult
end

local function formatPrice(value)
	value = tonumber(value) or 0

	local units = {
		{ 1e15, "Qa" },
		{ 1e12, "T" },
		{ 1e9, "B" },
		{ 1e6, "M" },
		{ 1e3, "K" },
	}

	for _, unit in ipairs(units) do
		local amount, suffix = unit[1], unit[2]

		if value >= amount then
			local num = value / amount

			if num >= 100 then
				return "$" .. string.format("%.0f", num) .. suffix
			elseif num >= 10 then
				return "$" .. string.format("%.1f", num):gsub("%.0", "") .. suffix
			else
				return "$" .. string.format("%.2f", num):gsub("0$", ""):gsub("%.$", "") .. suffix
			end
		end
	end

	return "$" .. tostring(math.floor(value))
end

--// CONFIG

local ConfigFileName = "FortuneAutoTool_Config_" .. tostring(LocalPlayer.UserId) .. ".json"

local function canUseFileConfig()
	return typeof(readfile) == "function" and typeof(writefile) == "function" and typeof(isfile) == "function"
end

local function getSelectedSeedList()
	local names = {}

	for name, enabled in pairs(State.SelectedSeeds) do
		if enabled then
			table.insert(names, name)
		end
	end

	table.sort(names)

	return names
end

local function applySelectedSeeds(savedSeeds)
	State.SelectedSeeds = {}

	if type(savedSeeds) ~= "table" then
		return
	end

	for key, value in pairs(savedSeeds) do
		if type(key) == "number" and type(value) == "string" then
			State.SelectedSeeds[value] = true
		elseif type(key) == "string" and value then
			State.SelectedSeeds[key] = true
		end
	end
end

local function getSelectedSeedRarityList()
	local rarities = {}

	for rarity, enabled in pairs(State.SelectedSeedRarities) do
		if enabled then
			table.insert(rarities, rarity)
		end
	end

	table.sort(rarities)

	return rarities
end

local function applySelectedSeedRarities(savedRarities)
	State.SelectedSeedRarities = {}

	if type(savedRarities) ~= "table" then
		return
	end

	for key, value in pairs(savedRarities) do
		if type(key) == "number" and type(value) == "string" then
			State.SelectedSeedRarities[value] = true
		elseif type(key) == "string" and value then
			State.SelectedSeedRarities[key] = true
		end
	end
end

local function getSelectedEggRarityList()
	local rarities = {}

	for rarity, enabled in pairs(State.SelectedEggRarities) do
		if enabled then
			table.insert(rarities, rarity)
		end
	end

	table.sort(rarities)

	return rarities
end

local function applySelectedEggRarities(savedRarities)
	State.SelectedEggRarities = {}

	if type(savedRarities) ~= "table" then
		return
	end

	for key, value in pairs(savedRarities) do
		if type(key) == "number" and type(value) == "string" then
			State.SelectedEggRarities[value] = true
		elseif type(key) == "string" and value then
			State.SelectedEggRarities[key] = true
		end
	end
end

local function getSelectedCompostSeedList()
	local names = {}

	for name, enabled in pairs(State.SelectedCompostSeeds) do
		if enabled then
			table.insert(names, name)
		end
	end

	table.sort(names)

	return names
end

local function applySelectedCompostSeeds(savedSeeds)
	State.SelectedCompostSeeds = {}

	if type(savedSeeds) ~= "table" then
		return
	end

	for key, value in pairs(savedSeeds) do
		if type(key) == "number" and type(value) == "string" then
			State.SelectedCompostSeeds[value] = true
		elseif type(key) == "string" and value then
			State.SelectedCompostSeeds[key] = true
		end
	end
end

local function getConfigData()
	return {
		SaveConfigEnabled = State.SaveConfigEnabled,
		AutoRoll = State.AutoRoll,
		AutoBuySelectedSeeds = State.AutoBuySelectedSeeds,
		AutoBuySelectedSeedRarities = State.AutoBuySelectedSeedRarities,
		AutoBuyAllGear = State.AutoBuyAllGear,
		AutoBuyAllEggs = State.AutoBuyAllEggs,
		AutoBuySelectedEggRarities = State.AutoBuySelectedEggRarities,
		AutoSell = State.AutoSell,
		AutoCompost = State.AutoCompost,
		AutoUpgradePlants = State.AutoUpgradePlants,
		AutoSprayPlants = State.AutoSprayPlants,
		AutoPlantSeeds = State.AutoPlantSeeds,
		AntiAFK = State.AntiAFK,
		SelectedSeedOption = State.SelectedSeedOption,
		SelectedSeeds = getSelectedSeedList(),
		SelectedSeedRarityOption = State.SelectedSeedRarityOption,
		SelectedSeedRarities = getSelectedSeedRarityList(),
		SelectedEggRarityOption = State.SelectedEggRarityOption,
		SelectedEggRarities = getSelectedEggRarityList(),
		SelectedCompostSeedOption = State.SelectedCompostSeedOption,
		SelectedCompostSeeds = getSelectedCompostSeedList(),
		SelectedSprayOption = State.SelectedSprayOption,
		SelectedSprayBaseName = State.SelectedSprayBaseName,
		SelectedPlantSeedOption = State.SelectedPlantSeedOption,
		RollDelay = State.RollDelay,
		GearDelay = State.GearDelay,
		EggDelay = State.EggDelay,
		SellDelay = State.SellDelay,
		CompostDelay = State.CompostDelay,
		PlantUpgradeDelay = State.PlantUpgradeDelay,
		PlantUpgradeTargetLevel = State.PlantUpgradeTargetLevel,
		SprayDelay = State.SprayDelay,
		PlantSeedDelay = State.PlantSeedDelay,
		WebhookURL = State.WebhookURL,
		WebhookSeedPurchases = State.WebhookSeedPurchases,
		WebhookExpensiveGear = State.WebhookExpensiveGear,
		ExpensiveThreshold = State.ExpensiveThreshold,
		ExpensiveThresholdOption = State.ExpensiveThresholdOption,
	}
end

local function saveConfig(force)
	if not canUseFileConfig() then
		consoleWarn("[CONFIG] File config functions are not available.")
		return
	end

	local ok, err = pcall(function()
		writefile(ConfigFileName, HttpService:JSONEncode(getConfigData()))
	end)

	if not ok then
		consoleWarn("[CONFIG] Save failed:", err)
	end
end

local function loadConfig()
	if not canUseFileConfig() or not isfile(ConfigFileName) then
		return
	end

	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(ConfigFileName))
	end)

	if not ok or type(data) ~= "table" then
		consoleWarn("[CONFIG] Load failed:", data)
		return
	end

	for _, key in ipairs({
		"SaveConfigEnabled",
		"AutoRoll",
		"AutoBuySelectedSeeds",
		"AutoBuySelectedSeedRarities",
		"AutoBuyAllGear",
		"AutoBuyAllEggs",
		"AutoBuySelectedEggRarities",
		"AutoSell",
		"AutoCompost",
		"AutoUpgradePlants",
		"AutoSprayPlants",
		"AutoPlantSeeds",
		"AntiAFK",
		"WebhookSeedPurchases",
		"WebhookExpensiveGear",
	}) do
		if type(data[key]) == "boolean" then
			State[key] = data[key]
		end
	end

	for _, key in ipairs({
		"RollDelay",
		"GearDelay",
		"EggDelay",
		"SellDelay",
		"CompostDelay",
		"PlantUpgradeDelay",
		"PlantUpgradeTargetLevel",
		"SprayDelay",
		"PlantSeedDelay",
		"ExpensiveThreshold",
	}) do
		if type(data[key]) == "number" then
			State[key] = data[key]
		end
	end

	State.PlantUpgradeTargetLevel = math.clamp(math.floor(State.PlantUpgradeTargetLevel), 1, 100)
	State.PlantUpgradeDelay = math.max(2.5, tonumber(State.PlantUpgradeDelay) or 2.5)

	if type(data.WebhookURL) == "string" then
		State.WebhookURL = data.WebhookURL
	end

	if type(data.SelectedSeedOption) == "string" then
		State.SelectedSeedOption = data.SelectedSeedOption
	end

	if type(data.SelectedSeedRarityOption) == "string" then
		State.SelectedSeedRarityOption = data.SelectedSeedRarityOption
	end

	if type(data.SelectedEggRarityOption) == "string" then
		State.SelectedEggRarityOption = data.SelectedEggRarityOption
	end

	if type(data.SelectedCompostSeedOption) == "string" then
		State.SelectedCompostSeedOption = data.SelectedCompostSeedOption
	end

	if type(data.SelectedSprayOption) == "string" then
		State.SelectedSprayOption = data.SelectedSprayOption
	end

	if type(data.SelectedSprayBaseName) == "string" then
		State.SelectedSprayBaseName = data.SelectedSprayBaseName
	end

	if type(data.SelectedPlantSeedOption) == "string" then
		State.SelectedPlantSeedOption = data.SelectedPlantSeedOption
	end

	if type(data.ExpensiveThresholdOption) == "string" then
		State.ExpensiveThresholdOption = data.ExpensiveThresholdOption
		State.ExpensiveThreshold = parsePrice(data.ExpensiveThresholdOption)
	end

	applySelectedSeeds(data.SelectedSeeds)
	applySelectedSeedRarities(data.SelectedSeedRarities)
	applySelectedEggRarities(data.SelectedEggRarities)
	applySelectedCompostSeeds(data.SelectedCompostSeeds)

	if
		next(State.SelectedCompostSeeds) == nil
		and type(data.SelectedCompostSeedOption) == "string"
		and data.SelectedCompostSeedOption ~= "Select Seed"
		and data.SelectedCompostSeedOption ~= "No Seeds Found"
	then
		State.SelectedCompostSeeds[data.SelectedCompostSeedOption] = true
	end
end

--// BASIC INSTANCE UTILS

local function getText(obj)
	if not obj then
		return "Unknown"
	end

	local okContent, content = pcall(function()
		return obj.ContentText
	end)

	if okContent and content and content ~= "" then
		return content
	end

	local okText, text = pcall(function()
		return obj.Text
	end)

	if okText and text and text ~= "" then
		return text
	end

	return "Unknown"
end

local function getPos(obj)
	if not obj then
		return nil
	end

	if obj:IsA("Attachment") then
		return obj.WorldPosition
	end

	if obj:IsA("BasePart") then
		return obj.Position
	end

	if obj:IsA("Model") then
		return obj:GetPivot().Position
	end

	if obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
		return getPos(obj.Adornee or obj.Parent)
	end

	return getPos(obj.Parent)
end

local function getTopWorkspaceObject(obj)
	local current = obj

	while current and current.Parent and current.Parent ~= workspace do
		current = current.Parent
	end

	return current
end

--// PLOT + SEED SCANNER

local function findMyPlot()
	if PlotCache and PlotCache.Parent then
		return PlotCache
	end

	local plots = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Plots")
	if not plots then
		return nil
	end

	for _, plot in ipairs(plots:GetChildren()) do
		local ownerSign = plot:FindFirstChild("OwnerSign", true)

		if ownerSign then
			for _, obj in ipairs(ownerSign:GetDescendants()) do
				if obj:IsA("TextLabel") or obj:IsA("TextButton") then
					local owner = getText(obj)

					if owner == LocalPlayer.DisplayName or owner == LocalPlayer.Name then
						PlotCache = plot
						return plot
					end
				end
			end
		end
	end

	return nil
end

local function getSlots(plot)
	local seedRoller = plot and plot:FindFirstChild("SeedRoller", true)
	local slots = {}

	if not seedRoller then
		return slots
	end

	for i = 1, 6 do
		local slotObj = seedRoller:FindFirstChild("Seed" .. i)
		local pos = getPos(slotObj)

		if pos then
			table.insert(slots, {
				Slot = i,
				Position = pos,
			})
		end
	end

	return slots
end

local function getSeedInfoFromGui(gui)
	local top = getTopWorkspaceObject(gui)
	local infoFrame = gui:FindFirstChild("Frame") and gui.Frame:FindFirstChild("InfoFrame")

	local name = top and top.Name or "Unknown"
	local rarity = "Unknown"
	local costText = "Unknown"
	local price = 0

	if infoFrame then
		local rarityObj = infoFrame:FindFirstChild("Rarity")
		local costObj = infoFrame:FindFirstChild("Cost")

		rarity = getText(rarityObj)
		costText = getText(costObj)
		price = parsePrice(costText)
	end

	return {
		Name = name,
		Rarity = rarity,
		CostText = costText,
		Price = price,
		Position = getPos(gui),
		Gui = gui,
	}
end

local function getAllSeedGuis()
	local found = {}

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name == "SeedGui" then
			local info = getSeedInfoFromGui(obj)

			if info.Position then
				table.insert(found, info)
			end
		end
	end

	return found
end

local function findClosestSeed(slot, seeds, used)
	local best = nil
	local bestIndex = nil
	local bestDist = math.huge

	for index, seed in ipairs(seeds) do
		if not used[index] then
			local dist = (slot.Position - seed.Position).Magnitude

			if dist < bestDist then
				best = seed
				bestIndex = index
				bestDist = dist
			end
		end
	end

	return best, bestIndex, bestDist
end

local function scanCurrentPlotSeeds()
	local plot = findMyPlot()
	local slots = getSlots(plot)
	local seeds = getAllSeedGuis()
	local used = {}
	local results = {}

	for _, slot in ipairs(slots) do
		local seed, index, dist = findClosestSeed(slot, seeds, used)

		if seed then
			used[index] = true

			table.insert(results, {
				Slot = slot.Slot,
				Name = seed.Name,
				Rarity = seed.Rarity,
				CostText = seed.CostText,
				Price = seed.Price,
				Distance = dist,
				Gui = seed.Gui,
			})
		end
	end

	table.sort(results, function(a, b)
		return a.Slot < b.Slot
	end)

	return results, plot
end

--// GEAR

local function getSeedNames()
	local names = {}

	for _, seed in ipairs(SeedsFolder:GetChildren()) do
		table.insert(names, seed.Name)
	end

	table.sort(names)

	return names
end

local function getGearNames(forceRefresh)
	if GearNamesCache and not forceRefresh then
		return GearNamesCache
	end

	local names = {}

	for _, item in ipairs(GearFolder:GetChildren()) do
		table.insert(names, item.Name)
	end

	table.sort(names)
	GearNamesCache = names

	return names
end

local function getComposterRemotes()
	if ComposterInsertSeed and ComposterPullLever then
		return ComposterInsertSeed, ComposterPullLever
	end

	ComposterRemote = ComposterRemote or Remotes:FindFirstChild("Composter") or Remotes:WaitForChild("Composter", 5)
	ComposterInsertSeed = ComposterRemote
		and (ComposterRemote:FindFirstChild("InsertSeed") or ComposterRemote:WaitForChild("InsertSeed", 5))
	ComposterPullLever = ComposterRemote
		and (ComposterRemote:FindFirstChild("PullLever") or ComposterRemote:WaitForChild("PullLever", 5))

	return ComposterInsertSeed, ComposterPullLever
end

local function getSelectedCompostSeedName()
	local selected = State.SelectedCompostSeedOption

	if not selected or selected == "Select Seed" or selected == "No Seeds Found" then
		return nil
	end

	return CompostSeedOptionMap[selected] or selected
end

local function getCompostSeedKey(seedName)
	return tostring(seedName) .. "_1_Normal"
end

local function getSelectedCompostSeedKeyList()
	local keys = {}

	for _, seedName in ipairs(getSelectedCompostSeedList()) do
		table.insert(keys, getCompostSeedKey(seedName))
	end

	return keys
end

local function getUpgradePlantRemote()
	UpgradePlantRemote = UpgradePlantRemote or Remotes:FindFirstChild("UpgradePlant") or Remotes:WaitForChild("UpgradePlant", 5)

	return UpgradePlantRemote
end

local function getRemovePlantRemote()
	RemovePlantRemote = RemovePlantRemote or Remotes:FindFirstChild("RemovePlant") or Remotes:WaitForChild("RemovePlant", 5)

	return RemovePlantRemote
end

local function getUseSprayRemote()
	UseSprayRemote = UseSprayRemote or Remotes:FindFirstChild("UseSpray") or Remotes:WaitForChild("UseSpray", 5)

	return UseSprayRemote
end

local function getPlantSeedRemote()
	PlantSeedRemote = PlantSeedRemote or Remotes:FindFirstChild("PlantSeed") or Remotes:WaitForChild("PlantSeed", 5)

	return PlantSeedRemote
end

local function getFarmDirts(forceRefresh)
	local plot = findMyPlot()
	local now = os.clock()

	if
		not forceRefresh
		and FarmDirtCache
		and FarmDirtCachePlot == plot
		and now - FarmDirtCacheTime < FarmDirtCacheTTL
	then
		return FarmDirtCache
	end

	local dirts = {}
	local farmPlot = plot and plot:FindFirstChild("FarmPlot")

	if farmPlot then
		for _, plotPart in ipairs(farmPlot:GetChildren()) do
			if plotPart.Name:match("^Plot%d+$") then
				local dirt = plotPart:FindFirstChild("Dirt")

				if dirt then
					table.insert(dirts, dirt)
				end
			end
		end
	end

	table.sort(dirts, function(a, b)
		local aNum = tonumber(a.Parent and a.Parent.Name:match("%d+")) or 0
		local bNum = tonumber(b.Parent and b.Parent.Name:match("%d+")) or 0

		return aNum < bNum
	end)

	FarmDirtCache = dirts
	FarmDirtCachePlot = plot
	FarmDirtCacheTime = now

	return dirts
end

local function isPlantedDirt(dirt)
	if not dirt then
		return false
	end

	local plantName = dirt:GetAttribute("PlantName")
	local plantLevel = dirt:GetAttribute("PlantLevel")

	return type(plantName) == "string" and plantName ~= "" and tonumber(plantLevel) ~= nil
end

local function getPlantLevel(dirt)
	return math.max(0, math.floor(tonumber(dirt and dirt:GetAttribute("PlantLevel")) or 0))
end

local function isOccupiedDirt(dirt)
	if not dirt then
		return false
	end

	local plantName = dirt:GetAttribute("PlantName")

	return (type(plantName) == "string" and plantName ~= "")
		or dirt:GetAttribute("PlantLevel") ~= nil
		or dirt:GetAttribute("PlantTag") ~= nil
end

local function getPlantedDirts(forceRefresh)
	local planted = {}

	for _, dirt in ipairs(getFarmDirts(forceRefresh)) do
		if isPlantedDirt(dirt) then
			table.insert(planted, dirt)
		end
	end

	return planted
end

local function getEmptyDirts(forceRefresh)
	local empty = {}

	for _, dirt in ipairs(getFarmDirts(forceRefresh)) do
		if not isOccupiedDirt(dirt) then
			table.insert(empty, dirt)
		end
	end

	return empty
end

local function getSeedToolBaseName(toolName)
	local name = tostring(toolName or "")

	name = name:gsub("%s*%([xX]%d+%)%s*$", "")
	name = name:gsub("_%d+_[%w%s]+$", "")
	name = name:gsub("%s+[Ss]eed$", "")

	return name
end

local function addSeedToolsFrom(container, tools)
	if not container then
		return
	end

	for _, item in ipairs(container:GetChildren()) do
		if item:IsA("Tool") then
			local baseName = getSeedToolBaseName(item.Name)

			if SeedsFolder:FindFirstChild(baseName) then
				table.insert(tools, item)
			end
		end
	end
end

local function getSeedTools()
	local tools = {}

	addSeedToolsFrom(LocalPlayer:FindFirstChild("Backpack"), tools)
	addSeedToolsFrom(LocalPlayer.Character, tools)

	table.sort(tools, function(a, b)
		return a.Name < b.Name
	end)

	return tools
end

local function getSelectedPlantSeedName()
	local selected = State.SelectedPlantSeedOption

	if not selected or selected == "Select Seed" or selected == "No Seeds Found" then
		return nil
	end

	return PlantSeedOptionMap[selected] or selected
end

local function getSelectedSeedTool()
	local seedName = getSelectedPlantSeedName()

	if not seedName then
		return nil
	end

	for _, tool in ipairs(getSeedTools()) do
		local toolName = tool.Name

		if
			toolName == seedName
			or toolName == getCompostSeedKey(seedName)
			or getSeedToolBaseName(toolName) == seedName
		then
			return tool
		end
	end

	return nil
end

local function equipTool(tool)
	if not tool then
		return false
	end

	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if not character or not humanoid then
		return false
	end

	if tool.Parent == character then
		return true
	end

	pcall(function()
		humanoid:EquipTool(tool)
	end)

	task.wait(0.1)

	return tool.Parent == character
end

local function getSprayBaseName(sprayName)
	return tostring(sprayName or ""):gsub("%s*%([xX]%d+%)%s*$", "")
end

local function addSprayToolsFrom(container, tools)
	if not container then
		return
	end

	for _, item in ipairs(container:GetChildren()) do
		if item:IsA("Tool") and item.Name:lower():find("spray", 1, true) then
			table.insert(tools, item)
		end
	end
end

local function getSprayTools()
	local tools = {}

	addSprayToolsFrom(LocalPlayer:FindFirstChild("Backpack"), tools)
	addSprayToolsFrom(LocalPlayer.Character, tools)

	table.sort(tools, function(a, b)
		return a.Name < b.Name
	end)

	return tools
end

local function getSelectedSprayTool()
	local exact = State.SelectedSprayOption

	if not exact or exact == "Select Spray" or exact == "No Sprays Found" then
		return nil
	end

	if exact and SprayOptionMap[exact] and SprayOptionMap[exact].Parent then
		return SprayOptionMap[exact]
	end

	local targetBase = State.SelectedSprayBaseName or getSprayBaseName(exact)

	if targetBase == "" then
		return nil
	end

	for _, tool in ipairs(getSprayTools()) do
		if getSprayBaseName(tool.Name) == targetBase then
			return tool
		end
	end

	return nil
end

local function equipSprayTool(tool)
	return equipTool(tool)
end

local function getPacedPlantDelay(actionCount, passDuration)
	actionCount = math.max(0, tonumber(actionCount) or 0)
	passDuration = math.max(0, tonumber(passDuration) or 0)

	if actionCount <= 1 then
		return 0
	end

	return passDuration / (actionCount - 1)
end

local function getMyGearStockFolder()
	GearStocksFolder = GearStocksFolder or ReplicatedStorage:FindFirstChild("GearStocks")

	if not GearStocksFolder then
		consoleWarn("[GEAR STOCK] ReplicatedStorage.GearStocks was not found.")
		return nil
	end

	local plot = findMyPlot()

	if plot then
		local stockFolder = GearStocksFolder:FindFirstChild(plot.Name)

		if stockFolder then
			return stockFolder
		end
	end

	return GearStocksFolder:FindFirstChild(LocalPlayer.Name) or GearStocksFolder:FindFirstChild(LocalPlayer.DisplayName)
end

local function getGearStockAmount(stockFolder, gearName)
	local stockValue = stockFolder and stockFolder:FindFirstChild(gearName)

	if not stockValue then
		return 0
	end

	local ok, value = pcall(function()
		return stockValue.Value
	end)

	if not ok then
		return 0
	end

	return math.max(0, math.floor(tonumber(value) or 0)), stockValue
end

local function readGearPriceValue(value)
	if type(value) == "number" then
		return value, formatPrice(value)
	end

	if type(value) == "string" then
		return parsePrice(value), value
	end

	return 0, "Unknown"
end

local function getGearAssetPrice(gearName)
	if GearPriceCache[gearName] then
		return GearPriceCache[gearName].Price, GearPriceCache[gearName].PriceText
	end

	local gear = GearFolder:FindFirstChild(gearName)
	local price = 0
	local priceText = "Unknown"

	if gear then
		for _, attrName in ipairs({ "Price", "Cost", "Value" }) do
			local attrValue = gear:GetAttribute(attrName)

			if attrValue ~= nil then
				price, priceText = readGearPriceValue(attrValue)
				break
			end
		end

		if price <= 0 then
			for _, obj in ipairs(gear:GetDescendants()) do
				local lowerName = string.lower(obj.Name)

				if lowerName == "price" or lowerName == "cost" or lowerName == "value" then
					if obj:IsA("NumberValue") or obj:IsA("IntValue") then
						price, priceText = readGearPriceValue(obj.Value)
						break
					elseif obj:IsA("StringValue") then
						price, priceText = readGearPriceValue(obj.Value)
						break
					end
				end
			end
		end
	end

	GearPriceCache[gearName] = {
		Price = price,
		PriceText = priceText,
	}

	return price, priceText
end

local function normalizeSeedRarity(rawRarity)
	local text = trim(rawRarity or "")

	if text == "" then
		return "Unknown"
	end

	local lower = string.lower(text)

	for index = 2, #SeedRarityOptions do
		local rarity = SeedRarityOptions[index]

		if lower == string.lower(rarity) then
			return rarity
		end
	end

	for index = #SeedRarityOptions, 2, -1 do
		local rarity = SeedRarityOptions[index]

		if lower:find(string.lower(rarity), 1, true) then
			return rarity
		end
	end

	return text
end

local function getSeedRarityColor(rarity)
	return SeedRarityColors[normalizeSeedRarity(rarity)] or SeedRarityColors.Unknown
end

local function normalizeEggRarity(rawRarity)
	local text = trim(rawRarity or "")

	if text == "" then
		return nil
	end

	local compact = string.lower(text):gsub("%s+", "")

	for index = 2, #EggRarityOptions do
		local rarity = EggRarityOptions[index]
		local lowerRarity = string.lower(rarity)

		if compact == lowerRarity or compact == lowerRarity .. "egg" then
			return rarity
		end
	end

	for index = 2, #EggRarityOptions do
		local rarity = EggRarityOptions[index]

		if compact:find(string.lower(rarity), 1, true) then
			return rarity
		end
	end

	return nil
end

local function getEggPodium(slot)
	local merchant = workspace:FindFirstChild("PetMerchant")

	if not merchant then
		return nil
	end

	return merchant:FindFirstChild("Podium" .. tostring(slot) .. "Stock")
		or merchant:FindFirstChild("Podium" .. tostring(slot))
end

local function getEggLabel(podium)
	if not podium then
		return nil
	end

	local surfaceGui = podium:FindFirstChild("SurfaceGui")

	if surfaceGui then
		local label = surfaceGui:FindFirstChild("EggLabel")

		if label then
			return label
		end
	end

	return podium:FindFirstChild("EggLabel", true)
end

local function scanEggShop()
	local eggs = {}

	for slot = 1, 5 do
		local podium = getEggPodium(slot)
		local label = getEggLabel(podium)
		local labelText = getText(label)
		local rarity = normalizeEggRarity(labelText)

		table.insert(eggs, {
			Slot = slot,
			Name = rarity and rarity .. "Egg" or labelText,
			Rarity = rarity,
			LabelText = labelText,
			Podium = podium,
			Label = label,
		})
	end

	return eggs
end

--// DISCORD WEBHOOK

local function getRequestFunction()
	return request or http_request or http and http.request or syn and syn.request
end

local function sendWebhook(title, description, fields, color)
	if State.WebhookURL == "" then
		consoleWarn("[Webhook] No webhook URL set.")
		return
	end

	local req = getRequestFunction()

	local embed = {
		title = title,
		description = description,
		color = color or 65280,
		fields = fields or {},
		footer = {
			text = "Fortune Seed Tool",
		},
		timestamp = DateTime.now():ToIsoDate(),
	}

	local payload = {
		username = "Fortune Seed Tool",
		avatar_url = "https://tr.rbxcdn.com/30DAY-AvatarHeadshot-420-420-Png/noFilter",
		embeds = { embed },
	}

	local body = HttpService:JSONEncode(payload)

	if req then
		local ok, err = pcall(function()
			req({
				Url = State.WebhookURL,
				Method = "POST",
				Headers = {
					["Content-Type"] = "application/json",
				},
				Body = body,
			})
		end)

		if not ok then
			consoleWarn("[Webhook] Request failed:", err)
		end
	else
		local ok, err = pcall(function()
			HttpService:PostAsync(State.WebhookURL, body, Enum.HttpContentType.ApplicationJson)
		end)

		if not ok then
			consoleWarn("[Webhook] HttpService failed:", err)
		end
	end
end

local function sendSeedWebhook(seed)
	if not State.WebhookSeedPurchases then
		return
	end

	local rarity = normalizeSeedRarity(seed.Rarity)

	sendWebhook("🌱 Selected Seed Purchased", "Auto-buy bought a selected seed before rolling again.", {
		{
			name = "Seed",
			value = seed.Name,
			inline = true,
		},
		{
			name = "Slot",
			value = tostring(seed.Slot),
			inline = true,
		},
		{
			name = "Rarity",
			value = rarity,
			inline = true,
		},
		{
			name = "Price",
			value = formatPrice(seed.Price) .. " `" .. seed.CostText .. "`",
			inline = true,
		},
	}, getSeedRarityColor(rarity))
end

local function sendGearWebhook(gearName, price, priceText)
	if not State.WebhookExpensiveGear then
		return
	end

	if price < State.ExpensiveThreshold then
		return
	end

	sendWebhook("🛒 Expensive Gear Purchased", "Auto-buy purchased gear at or above your expensive threshold.", {
		{
			name = "Gear",
			value = gearName,
			inline = true,
		},
		{
			name = "Price",
			value = formatPrice(price) .. " `" .. priceText .. "`",
			inline = true,
		},
		{
			name = "Threshold",
			value = formatPrice(State.ExpensiveThreshold),
			inline = true,
		},
	}, 16753920)
end

local function shouldCheckGearPrices()
	return State.WebhookExpensiveGear and State.WebhookURL ~= ""
end

--// BUY FUNCTIONS

local function buySeedSlot(seed, deferWebhook)
	local ok, err = pcall(function()
		BuySeedRemote:FireServer(seed.Slot)
	end)

	if ok then
		consolePrint("[SEED BUY]", seed.Name, "slot:", seed.Slot, "price:", seed.CostText, "rarity:", seed.Rarity)

		if deferWebhook then
			task.spawn(function()
				sendSeedWebhook(seed)
			end)
		else
			sendSeedWebhook(seed)
		end

		return true
	else
		consoleWarn("[SEED BUY FAILED]", seed.Name, err)
		return false
	end
end

local function buySelectedSeedsFromCurrentRoll()
	local currentSeeds = scanCurrentPlotSeeds()
	local seedsToBuy = {}

	for _, seed in ipairs(currentSeeds) do
		local rarity = normalizeSeedRarity(seed.Rarity)
		local selectedByName = State.AutoBuySelectedSeeds and State.SelectedSeeds[seed.Name]
		local selectedByRarity = State.AutoBuySelectedSeedRarities and State.SelectedSeedRarities[rarity]

		if selectedByName or selectedByRarity then
			table.insert(seedsToBuy, seed)
		end
	end

	for _, seed in ipairs(seedsToBuy) do
		buySeedSlot(seed, true)
	end

	return #seedsToBuy
end

local function getEggShopTransaction()
	if EggShopTransaction then
		return EggShopTransaction
	end

	EggShopRemote = EggShopRemote or Remotes:FindFirstChild("EggShop") or Remotes:WaitForChild("EggShop", 5)
	EggShopTransaction = EggShopRemote
		and (EggShopRemote:FindFirstChild("Transaction") or EggShopRemote:WaitForChild("Transaction", 5))

	return EggShopTransaction
end

local function getRollEggRemote()
	if RollEggRemote then
		return RollEggRemote
	end

	RollEggRemote = Remotes:FindFirstChild("RollEgg") or Remotes:WaitForChild("RollEgg", 5)

	return RollEggRemote
end

local function rollAndClaimEgg(egg, quiet)
	local remote = getRollEggRemote()
	local eggName = egg and egg.Name

	if not remote then
		consoleWarn("[EGG ROLL] RollEgg remote not found.")
		return false
	end

	if not eggName or eggName == "" or eggName == "Unknown" then
		return false
	end

	local rollOk, rollErr = pcall(function()
		remote:FireServer(eggName)
	end)

	if not rollOk then
		consoleWarn("[EGG ROLL FAILED]", eggName, rollErr)
		return false
	end

	task.wait(0.1)

	local claimOk, claimErr = pcall(function()
		remote:FireServer(eggName, "ClaimRolledPet")
	end)

	if claimOk then
		if not quiet then
			consolePrint("[EGG CLAIM]", eggName)
		end

		return true
	else
		consoleWarn("[EGG CLAIM FAILED]", eggName, claimErr)
		return false
	end
end

local function buyEggSlot(egg, quiet)
	local transaction = getEggShopTransaction()

	if not transaction then
		consoleWarn("[EGG] Egg shop transaction remote not found.")
		return false
	end

	if not egg or not egg.Slot then
		return false
	end

	local ok, result = pcall(function()
		return transaction:InvokeServer("BuyEgg", egg.Slot)
	end)

	if ok then
		if not quiet then
			consolePrint(
				"[EGG BUY]",
				egg.Name or "Unknown",
				"slot:",
				tostring(egg.Slot),
				"rarity:",
				egg.Rarity or "Unknown",
				"result:",
				result
			)
		end

		rollAndClaimEgg(egg, quiet)

		return true
	else
		consoleWarn("[EGG BUY FAILED]", egg.Name or "Unknown", "slot:", tostring(egg.Slot), result)
		return false
	end
end

local function buyEggsOnce(buyAll)
	local currentEggs = scanEggShop()
	local bought = 0
	local attempted = 0

	for _, egg in ipairs(currentEggs) do
		if ENV.Stop then
			return bought
		end

		local selectedByRarity = egg.Rarity and State.SelectedEggRarities[egg.Rarity]

		if egg.Rarity and (buyAll or selectedByRarity) then
			attempted += 1

			if buyEggSlot(egg, true) then
				bought += 1
			end

			task.wait(EggBuyItemDelay)
		end
	end

	consolePrint("[EGG BUY] Finished egg pass. attempted:", tostring(attempted), "successful calls:", tostring(bought))

	return bought
end

local function rollSeeds()
	local ok, err = pcall(function()
		RollSeedsRemote:FireServer()
	end)

	if ok then
		consolePrint("[ROLL] Rolled seeds")
	else
		consoleWarn("[ROLL FAILED]", err)
	end
end

local function buyGear(gearName, quiet)
	if not GearTransaction then
		consoleWarn("[GEAR] Gear transaction remote not found.")
		return false
	end

	if not gearName or gearName == "" or gearName == "None" then
		return false
	end

	local price = 0
	local priceText = "Unknown"

	if shouldCheckGearPrices() then
		price, priceText = getGearAssetPrice(gearName)
	end

	local ok, result = pcall(function()
		return GearTransaction:InvokeServer(gearName)
	end)

	if ok then
		if not quiet then
			consolePrint("[GEAR BUY]", gearName, "price:", priceText, "result:", result)
		end

		sendGearWebhook(gearName, price, priceText)
		return true
	else
		consoleWarn("[GEAR BUY FAILED]", gearName, result)
		return false
	end
end

local function buyAllGearOnce()
	local gearNames = getGearNames()
	local stockFolder = getMyGearStockFolder()
	local bought = 0
	local attempted = 0

	if not stockFolder then
		consoleWarn("[GEAR STOCK] Could not find your gear stock folder.")
		return
	end

	for _, gearName in ipairs(gearNames) do
		if ENV.Stop then
			return
		end

		local stockAmount, stockValue = getGearStockAmount(stockFolder, gearName)

		for _ = 1, stockAmount do
			if ENV.Stop then
				return
			end

			local currentStock = stockValue and tonumber(stockValue.Value) or 0

			if currentStock < 1 then
				break
			end

			attempted += 1

			if buyGear(gearName, true) then
				bought += 1
			end

			task.wait(GearBuyItemDelay)
		end
	end

	consolePrint(
		"[GEAR BUY] Finished stock pass. Folder:",
		stockFolder.Name,
		"attempted:",
		tostring(attempted),
		"successful calls:",
		tostring(bought)
	)
end

local function sellCrates()
	local ok, err = pcall(function()
		SellCratesRemote:FireServer()
	end)

	if ok then
		consolePrint("[SELL] Sold crates")
	else
		consoleWarn("[SELL FAILED]", err)
	end
end

local function compostSeedOnce(seedName, quiet)
	local insertSeed, pullLever = getComposterRemotes()

	if not insertSeed or not pullLever then
		consoleWarn("[COMPOST] Composter remotes not found.")
		return false
	end

	if not seedName then
		if not quiet then
			OrionLib:MakeNotification({
				Name = "No Compost Seed",
				Content = "Pick at least one seed in the Compost tab first.",
				Time = 3,
			})
		end

		return false
	end

	local composterId = 3
	local seedKey = getCompostSeedKey(seedName)
	local amount = 1

	local insertOk, insertResult = pcall(function()
		return insertSeed:InvokeServer(composterId, seedKey, amount)
	end)

	if not insertOk then
		consoleWarn("[COMPOST INSERT FAILED]", seedKey, insertResult)
		return false
	end

	task.wait(0.1)

	local pullOk, pullResult = pcall(function()
		return pullLever:InvokeServer(composterId)
	end)

	if pullOk then
		if not quiet then
			OrionLib:MakeNotification({
				Name = "Composted",
				Content = seedKey .. " was sent to the composter.",
				Time = 3,
			})
		end

		consolePrint("[COMPOST]", seedKey, "insert:", insertResult, "pull:", pullResult)
		return true
	else
		consoleWarn("[COMPOST PULL FAILED]", seedKey, pullResult)
		return false
	end
end

local function compostSelectedSeedsOnce(quiet)
	local seedNames = getSelectedCompostSeedList()
	local composted = 0

	if #seedNames == 0 then
		return compostSeedOnce(nil, quiet)
	end

	for _, seedName in ipairs(seedNames) do
		if ENV.Stop then
			break
		end

		if compostSeedOnce(seedName, true) then
			composted += 1
		end

		task.wait(0.1)
	end

	if not quiet and composted > 0 then
		local content = tostring(composted) .. " selected seed variant"

		if composted ~= 1 then
			content ..= "s"
		end

		OrionLib:MakeNotification({
			Name = "Composted",
			Content = content .. " sent to the composter.",
			Time = 3,
		})
	end

	return composted
end

local function upgradePlantsOnce(quiet)
	if IsUpgradingPlants then
		if not quiet then
			OrionLib:MakeNotification({
				Name = "Plant Upgrade Pass",
				Content = "An upgrade pass is already running.",
				Time = 3,
			})
		end

		return 0
	end

	IsUpgradingPlants = true

	local remote = getUpgradePlantRemote()
	local dirts = getFarmDirts(false)
	local targetLevel = math.max(1, math.floor(tonumber(State.PlantUpgradeTargetLevel) or 1))
	local upgradeDirts = {}
	local upgraded = 0
	local skipped = 0

	if not remote then
		IsUpgradingPlants = false
		consoleWarn("[PLOT] UpgradePlant remote not found.")
		return 0
	end

	for _, dirt in ipairs(dirts) do
		if isPlantedDirt(dirt) then
			local level = getPlantLevel(dirt)

			if level < targetLevel then
				if #upgradeDirts < PlantUpgradeBatchSize then
					table.insert(upgradeDirts, dirt)
				end
			else
				skipped += 1
			end
		end
	end

	local delayBetweenCalls = getPacedPlantDelay(#upgradeDirts, PlantUpgradePassDuration)

	for index, dirt in ipairs(upgradeDirts) do
		if ENV.Stop then
			break
		end

		local currentLevel = getPlantLevel(dirt)

		if isPlantedDirt(dirt) and currentLevel < targetLevel then
			local ok, err = pcall(function()
				return remote:InvokeServer(dirt)
			end)

			if ok then
				upgraded += 1
			else
				consoleWarn("[PLOT UPGRADE FAILED]", dirt:GetFullName(), err)
			end
		end

		if index < #upgradeDirts and delayBetweenCalls > 0 then
			task.wait(delayBetweenCalls)
		end
	end

	IsUpgradingPlants = false

	if not quiet then
		OrionLib:MakeNotification({
			Name = "Plant Upgrade Pass",
			Content = "Upgraded " .. tostring(upgraded) .. " plants. Skipped " .. tostring(skipped) .. " at target.",
			Time = 3,
		})
	end

	consolePrint("[PLOT UPGRADE] upgraded:", upgraded, "skipped:", skipped, "target:", targetLevel)
	return upgraded
end

local function removeAllPlants()
	if IsRemovingPlants then
		OrionLib:MakeNotification({
			Name = "Remove Plants",
			Content = "A remove pass is already running.",
			Time = 3,
		})

		return 0
	end

	IsRemovingPlants = true

	local remote = getRemovePlantRemote()
	local dirts = getFarmDirts(true)
	local removeDirts = {}
	local removed = 0

	if not remote then
		IsRemovingPlants = false
		consoleWarn("[PLOT] RemovePlant remote not found.")
		return 0
	end

	for _, dirt in ipairs(dirts) do
		if isPlantedDirt(dirt) then
			table.insert(removeDirts, dirt)
		end
	end

	local delayBetweenCalls = getPacedPlantDelay(#removeDirts, PlantRemovePassDuration)

	for index, dirt in ipairs(removeDirts) do
		if ENV.Stop then
			break
		end

		if isPlantedDirt(dirt) then
			local ok, err = pcall(function()
				remote:FireServer(dirt)
			end)

			if ok then
				removed += 1
			else
				consoleWarn("[PLOT REMOVE FAILED]", dirt:GetFullName(), err)
			end
		end

		if index < #removeDirts and delayBetweenCalls > 0 then
			task.wait(delayBetweenCalls)
		end
	end

	IsRemovingPlants = false

	OrionLib:MakeNotification({
		Name = "Remove Plants",
		Content = "Remove request sent for " .. tostring(removed) .. " plants.",
		Time = 3,
	})

	consolePrint("[PLOT REMOVE] removed:", removed)
	return removed
end

local function sprayPlantsOnce(quiet)
	if IsSprayingPlants then
		if not quiet then
			OrionLib:MakeNotification({
				Name = "Plant Spray",
				Content = "A spray pass is already running.",
				Time = 3,
			})
		end

		return 0
	end

	IsSprayingPlants = true

	local remote = getUseSprayRemote()
	local tool = getSelectedSprayTool()
	local sprayed = 0

	if not remote then
		IsSprayingPlants = false
		consoleWarn("[PLOT] UseSpray remote not found.")
		return 0
	end

	if not tool then
		IsSprayingPlants = false

		if not quiet then
			OrionLib:MakeNotification({
				Name = "Plant Spray",
				Content = "Pick a spray from the Plot tab first.",
				Time = 3,
			})
		end

		return 0
	end

	if not equipSprayTool(tool) then
		IsSprayingPlants = false

		if not quiet then
			OrionLib:MakeNotification({
				Name = "Plant Spray",
				Content = "Could not equip " .. tool.Name .. ".",
				Time = 3,
			})
		end

		return 0
	end

	for _, dirt in ipairs(getPlantedDirts(false)) do
		if ENV.Stop then
			break
		end

		local ok, err = pcall(function()
			remote:FireServer(dirt)
		end)

		if ok then
			sprayed += 1
		else
			consoleWarn("[PLOT SPRAY FAILED]", dirt:GetFullName(), err)
		end

		task.wait(0.05)
	end

	IsSprayingPlants = false

	if not quiet then
		OrionLib:MakeNotification({
			Name = "Plant Spray",
			Content = "Spray request sent for " .. tostring(sprayed) .. " plants.",
			Time = 3,
		})
	end

	consolePrint("[PLOT SPRAY] sprayed:", sprayed, "spray:", tool.Name)
	return sprayed
end

local function plantSeedsOnce(quiet)
	if IsPlantingSeeds then
		if not quiet then
			OrionLib:MakeNotification({
				Name = "Plant Seeds",
				Content = "A planting pass is already running.",
				Time = 3,
			})
		end

		return 0
	end

	IsPlantingSeeds = true

	local remote = getPlantSeedRemote()
	local seedName = getSelectedPlantSeedName()
	local tool = getSelectedSeedTool()
	local planted = 0

	if not remote then
		IsPlantingSeeds = false
		consoleWarn("[PLOT] PlantSeed remote not found.")
		return 0
	end

	if not seedName then
		IsPlantingSeeds = false

		if not quiet then
			OrionLib:MakeNotification({
				Name = "Plant Seeds",
				Content = "Pick a seed from the Plot tab first.",
				Time = 3,
			})
		end

		return 0
	end

	if not tool then
		IsPlantingSeeds = false

		if not quiet then
			OrionLib:MakeNotification({
				Name = "Plant Seeds",
				Content = "No matching " .. seedName .. " seed tool found.",
				Time = 3,
			})
		end

		return 0
	end

	if not equipTool(tool) then
		IsPlantingSeeds = false

		if not quiet then
			OrionLib:MakeNotification({
				Name = "Plant Seeds",
				Content = "Could not equip " .. tool.Name .. ".",
				Time = 3,
			})
		end

		return 0
	end

	for _, dirt in ipairs(getEmptyDirts(true)) do
		if ENV.Stop then
			break
		end

		if not isPlantedDirt(dirt) then
			local ok, err = pcall(function()
				remote:FireServer(dirt)
			end)

			if ok then
				planted += 1
			else
				consoleWarn("[PLOT PLANT FAILED]", dirt:GetFullName(), err)
			end

			task.wait(0.05)
		end
	end

	IsPlantingSeeds = false

	if not quiet then
		OrionLib:MakeNotification({
			Name = "Plant Seeds",
			Content = "Plant request sent for " .. tostring(planted) .. " empty spots.",
			Time = 3,
		})
	end

	consolePrint("[PLOT PLANT] planted:", planted, "seed:", seedName, "tool:", tool.Name)
	return planted
end

local function simulateActivity()
	local camera = Workspace.CurrentCamera

	if not camera then
		return
	end

	VirtualUser:Button2Down(Vector2.zero, camera.CFrame)
	task.wait(1)
	VirtualUser:Button2Up(Vector2.zero, camera.CFrame)
end

local function setupAntiAFK()
	local connection = LocalPlayer.Idled:Connect(function()
		if ENV.Stop or not State.AntiAFK then
			return
		end

		simulateActivity()
		consolePrint("[ANTI AFK] Player successfully un-idled.")
	end)

	table.insert(ENV.Connections, connection)

	if State.AntiAFK then
		consolePrint("[ANTI AFK] Anti AFK active.")
	end
end

loadConfig()
setupAntiAFK()

--// UI

local Window = OrionLib:MakeWindow({
	Name = "Fortune Auto Tool",
	HidePremium = true,
	SaveConfig = false,
	ConfigFolder = "FortuneAutoTool",
	IntroEnabled = true,
	IntroText = "Fortune Tool Loaded",
})

local SeedsTab = Window:MakeTab({
	Name = "Seeds",
	Icon = "leaf",
	PremiumOnly = false,
})

local EggsTab = Window:MakeTab({
	Name = "Eggs",
	Icon = "egg",
	PremiumOnly = false,
})

local CompostTab = Window:MakeTab({
	Name = "Compost",
	Icon = "recycle",
	PremiumOnly = false,
})

local PlotTab = Window:MakeTab({
	Name = "Plot",
	Icon = "sprout",
	PremiumOnly = false,
})

local AutoBuyTab = Window:MakeTab({
	Name = "Auto Buy",
	Icon = "shopping-cart",
	PremiumOnly = false,
})

local SettingsTab = Window:MakeTab({
	Name = "Settings",
	Icon = "settings",
	PremiumOnly = false,
})

--// SEEDS TAB

SeedsTab:AddSection({
	Name = "Seed Roller",
})

local IsRefreshingSeedDropdown = false
local SelectedSeedsLabel
local updateSelectedSeedsLabel
local SelectedSeedRaritiesLabel
local updateSelectedSeedRaritiesLabel

SelectedSeedsLabel = SeedsTab:AddParagraph("Selected Seeds", "None")

function updateSelectedSeedsLabel()
	if not SelectedSeedsLabel then
		return
	end

	local names = getSelectedSeedList()

	if #names == 0 then
		SelectedSeedsLabel:Set("None")
	else
		SelectedSeedsLabel:Set(table.concat(names, ", "))
	end
end

local SeedDropdown = SeedsTab:AddDropdown({
	Name = "Seeds Dropdown",
	Default = "Select Seed",
	Options = {
		"Select Seed",
	},
	Callback = function(value)
		State.SelectedSeedOption = value

		if IsRefreshingSeedDropdown then
			return
		end

		local seedName = SeedOptionMap[value]

		if not seedName then
			return
		end

		State.SelectedSeeds[seedName] = true
		updateSelectedSeedsLabel()
		saveConfig()

		OrionLib:MakeNotification({
			Name = "Seed Selected",
			Content = seedName .. " was added to selected seeds.",
			Time = 3,
		})
	end,
})

SeedsTab:AddSection({
	Name = "Seed Rarity Filter",
})

SelectedSeedRaritiesLabel = SeedsTab:AddParagraph("Selected Rarities", "None")

function updateSelectedSeedRaritiesLabel()
	if not SelectedSeedRaritiesLabel then
		return
	end

	local rarities = getSelectedSeedRarityList()

	if #rarities == 0 then
		SelectedSeedRaritiesLabel:Set("None")
	else
		SelectedSeedRaritiesLabel:Set(table.concat(rarities, ", "))
	end
end

SeedsTab:AddDropdown({
	Name = "Rarity Selector",
	Default = getSafeDropdownDefault(SeedRarityOptions, State.SelectedSeedRarityOption, "Select Rarity"),
	Options = SeedRarityOptions,
	Callback = function(value)
		State.SelectedSeedRarityOption = value

		if value == "Select Rarity" then
			saveConfig()
			return
		end

		State.SelectedSeedRarities[value] = true
		updateSelectedSeedRaritiesLabel()
		saveConfig()

		OrionLib:MakeNotification({
			Name = "Rarity Selected",
			Content = value .. " seeds will be bought when rolled.",
			Time = 3,
		})
	end,
})

SeedsTab:AddButton({
	Name = "Clear Selected Rarities",
	Callback = function()
		table.clear(State.SelectedSeedRarities)
		updateSelectedSeedRaritiesLabel()
		saveConfig()

		OrionLib:MakeNotification({
			Name = "Cleared",
			Content = "Selected seed rarities cleared.",
			Time = 3,
		})
	end,
})

SeedsTab:AddToggle({
	Name = "Auto Buy Selected Rarities",
	Default = State.AutoBuySelectedSeedRarities,
	Callback = function(value)
		State.AutoBuySelectedSeedRarities = value
		saveConfig()
		consolePrint("[TOGGLE] Auto Buy Selected Seed Rarities:", value)
	end,
})

local function refreshSeedDropdown()
	local seedNames = getSeedNames()
	local options = {
		"Select Seed",
	}
	SeedOptionMap = {}

	for _, seedName in ipairs(seedNames) do
		table.insert(options, seedName)
		SeedOptionMap[seedName] = seedName
	end

	if #seedNames == 0 then
		options = {
			"No Seeds Found",
		}
	end

	IsRefreshingSeedDropdown = true
	SeedDropdown:Refresh(options, true)
	pcall(function()
		if State.SelectedSeedOption and SeedOptionMap[State.SelectedSeedOption] then
			SeedDropdown:Set(State.SelectedSeedOption)
		else
			SeedDropdown:Set("Select Seed")
		end
	end)
	IsRefreshingSeedDropdown = false
end

SeedsTab:AddButton({
	Name = "Clear Selected Seeds",
	Callback = function()
		table.clear(State.SelectedSeeds)
		updateSelectedSeedsLabel()
		saveConfig()

		OrionLib:MakeNotification({
			Name = "Cleared",
			Content = "Selected seed list cleared.",
			Time = 3,
		})
	end,
})

SeedsTab:AddToggle({
	Name = "Auto Buy Selected Seeds",
	Default = State.AutoBuySelectedSeeds,
	Callback = function(value)
		State.AutoBuySelectedSeeds = value
		saveConfig()
		consolePrint("[TOGGLE] Auto Buy Selected Seeds:", value)
	end,
})

SeedsTab:AddToggle({
	Name = "Auto Roll",
	Default = State.AutoRoll,
	Callback = function(value)
		State.AutoRoll = value
		saveConfig()
		consolePrint("[TOGGLE] Auto Roll:", value)
	end,
})

--// EGGS TAB

EggsTab:AddSection({
	Name = "Pet Merchant",
})

local SelectedEggRaritiesLabel
local updateSelectedEggRaritiesLabel

SelectedEggRaritiesLabel = EggsTab:AddParagraph("Selected Egg Rarities", "None")

function updateSelectedEggRaritiesLabel()
	if not SelectedEggRaritiesLabel then
		return
	end

	local rarities = getSelectedEggRarityList()

	if #rarities == 0 then
		SelectedEggRaritiesLabel:Set("None")
	else
		SelectedEggRaritiesLabel:Set(table.concat(rarities, ", "))
	end
end

EggsTab:AddDropdown({
	Name = "Egg Rarity Selector",
	Default = getSafeDropdownDefault(EggRarityOptions, State.SelectedEggRarityOption, "Select Rarity"),
	Options = EggRarityOptions,
	Callback = function(value)
		State.SelectedEggRarityOption = value

		if value == "Select Rarity" then
			saveConfig()
			return
		end

		State.SelectedEggRarities[value] = true
		updateSelectedEggRaritiesLabel()
		saveConfig()

		OrionLib:MakeNotification({
			Name = "Egg Rarity Selected",
			Content = value .. " eggs will be bought from the merchant.",
			Time = 3,
		})
	end,
})

EggsTab:AddButton({
	Name = "Clear Selected Egg Rarities",
	Callback = function()
		table.clear(State.SelectedEggRarities)
		updateSelectedEggRaritiesLabel()
		saveConfig()

		OrionLib:MakeNotification({
			Name = "Cleared",
			Content = "Selected egg rarities cleared.",
			Time = 3,
		})
	end,
})

EggsTab:AddButton({
	Name = "Buy Selected Egg Rarities Once",
	Callback = function()
		buyEggsOnce(false)
	end,
})

EggsTab:AddToggle({
	Name = "Auto Buy Selected Egg Rarities",
	Default = State.AutoBuySelectedEggRarities,
	Callback = function(value)
		State.AutoBuySelectedEggRarities = value
		saveConfig()
		consolePrint("[TOGGLE] Auto Buy Selected Egg Rarities:", value)
	end,
})

EggsTab:AddSection({
	Name = "All Eggs",
})

EggsTab:AddButton({
	Name = "Buy All Eggs Once",
	Callback = function()
		buyEggsOnce(true)
	end,
})

EggsTab:AddToggle({
	Name = "Auto Buy All Eggs",
	Default = State.AutoBuyAllEggs,
	Callback = function(value)
		State.AutoBuyAllEggs = value
		saveConfig()
		consolePrint("[TOGGLE] Auto Buy All Eggs:", value)
	end,
})

EggsTab:AddSlider({
	Name = "Egg Buy Loop Delay",
	Min = 1,
	Max = 120,
	Default = State.EggDelay,
	Increment = 1,
	ValueName = "sec",
	Callback = function(value)
		State.EggDelay = value
		saveConfig()
	end,
})

--// COMPOST TAB

CompostTab:AddSection({
	Name = "Auto Compost",
})

local IsRefreshingCompostSeedDropdown = false
local CompostSeedLabel
local updateCompostSeedLabel

CompostSeedLabel = CompostTab:AddParagraph("Selected Seed Variants", "None")

function updateCompostSeedLabel()
	if not CompostSeedLabel then
		return
	end

	local seedKeys = getSelectedCompostSeedKeyList()

	if #seedKeys > 0 then
		CompostSeedLabel:Set(table.concat(seedKeys, ", "))
	else
		CompostSeedLabel:Set("None")
	end
end

local CompostSeedDropdown = CompostTab:AddDropdown({
	Name = "Seed Dropdown",
	Default = "Select Seed",
	Options = {
		"Select Seed",
	},
	Callback = function(value)
		State.SelectedCompostSeedOption = value

		if IsRefreshingCompostSeedDropdown then
			return
		end

		updateCompostSeedLabel()

		local seedName = getSelectedCompostSeedName()

		if seedName then
			State.SelectedCompostSeeds[seedName] = true
			updateCompostSeedLabel()
			saveConfig()

			OrionLib:MakeNotification({
				Name = "Compost Seed Selected",
				Content = getCompostSeedKey(seedName) .. " was added to compost seeds.",
				Time = 3,
			})
		else
			saveConfig()
		end
	end,
})

local function refreshCompostSeedDropdown()
	local seedNames = getSeedNames()
	local options = {
		"Select Seed",
	}
	CompostSeedOptionMap = {}

	for _, seedName in ipairs(seedNames) do
		table.insert(options, seedName)
		CompostSeedOptionMap[seedName] = seedName
	end

	if #seedNames == 0 then
		options = {
			"No Seeds Found",
		}
	end

	IsRefreshingCompostSeedDropdown = true
	CompostSeedDropdown:Refresh(options, true)
	pcall(function()
		if State.SelectedCompostSeedOption and CompostSeedOptionMap[State.SelectedCompostSeedOption] then
			CompostSeedDropdown:Set(State.SelectedCompostSeedOption)
		else
			CompostSeedDropdown:Set("Select Seed")
		end
	end)
	IsRefreshingCompostSeedDropdown = false
	updateCompostSeedLabel()
end

CompostTab:AddButton({
	Name = "Refresh Seed List",
	Callback = function()
		refreshCompostSeedDropdown()
	end,
})

CompostTab:AddButton({
	Name = "Clear Selected Compost Seeds",
	Callback = function()
		table.clear(State.SelectedCompostSeeds)
		updateCompostSeedLabel()
		saveConfig()

		OrionLib:MakeNotification({
			Name = "Cleared",
			Content = "Selected compost seeds cleared.",
			Time = 3,
		})
	end,
})

CompostTab:AddButton({
	Name = "Compost Selected Seeds Once",
	Callback = function()
		compostSelectedSeedsOnce(false)
	end,
})

CompostTab:AddToggle({
	Name = "Auto Compost Selected Seeds",
	Default = State.AutoCompost,
	Callback = function(value)
		State.AutoCompost = value
		saveConfig()
		consolePrint("[TOGGLE] Auto Compost:", value)
	end,
})

CompostTab:AddSlider({
	Name = "Compost Loop Delay",
	Min = 1,
	Max = 120,
	Default = State.CompostDelay,
	Increment = 1,
	ValueName = "sec",
	Callback = function(value)
		State.CompostDelay = value
		saveConfig()
	end,
})

--// PLOT TAB

PlotTab:AddSection({
	Name = "Plant Upgrades",
})

PlotTab:AddSlider({
	Name = "Target Plant Level",
	Min = 1,
	Max = 100,
	Default = State.PlantUpgradeTargetLevel,
	Increment = 1,
	ValueName = "level",
	Callback = function(value)
		State.PlantUpgradeTargetLevel = value
		saveConfig()
	end,
})

PlotTab:AddButton({
	Name = "Upgrade Plants Once",
	Callback = function()
		task.spawn(function()
			upgradePlantsOnce(false)
		end)
	end,
})

PlotTab:AddToggle({
	Name = "Auto Upgrade Plants",
	Default = State.AutoUpgradePlants,
	Callback = function(value)
		State.AutoUpgradePlants = value
		saveConfig()
		consolePrint("[TOGGLE] Auto Upgrade Plants:", value)
	end,
})

PlotTab:AddSlider({
	Name = "Upgrade Pass Delay",
	Min = 2.5,
	Max = 120,
	Default = State.PlantUpgradeDelay,
	Increment = 0.5,
	ValueName = "sec",
	Callback = function(value)
		State.PlantUpgradeDelay = value
		saveConfig()
	end,
})

PlotTab:AddSection({
	Name = "Seed Planting",
})

local IsRefreshingPlantSeedDropdown = false
local PlantSeedDropdown
local SelectedPlantSeedLabel
local updateSelectedPlantSeedLabel

SelectedPlantSeedLabel = PlotTab:AddParagraph("Selected Seed", State.SelectedPlantSeedOption or "None")

function updateSelectedPlantSeedLabel()
	if not SelectedPlantSeedLabel then
		return
	end

	local seedName = getSelectedPlantSeedName()
	local tool = getSelectedSeedTool()

	if seedName and tool then
		SelectedPlantSeedLabel:Set(seedName .. " | " .. tool.Name)
	elseif seedName then
		SelectedPlantSeedLabel:Set(seedName)
	else
		SelectedPlantSeedLabel:Set("None")
	end
end

PlantSeedDropdown = PlotTab:AddDropdown({
	Name = "Seed Dropdown",
	Default = "Select Seed",
	Options = {
		"Select Seed",
	},
	Callback = function(value)
		if IsRefreshingPlantSeedDropdown then
			return
		end

		State.SelectedPlantSeedOption = value
		updateSelectedPlantSeedLabel()
		saveConfig()

		local seedName = getSelectedPlantSeedName()

		if seedName then
			OrionLib:MakeNotification({
				Name = "Plant Seed Selected",
				Content = seedName .. " will be planted in empty dirt spots.",
				Time = 3,
			})
		end
	end,
})

local function refreshPlantSeedDropdown()
	local seedNames = getSeedNames()
	local options = {
		"Select Seed",
	}
	PlantSeedOptionMap = {}

	for _, seedName in ipairs(seedNames) do
		table.insert(options, seedName)
		PlantSeedOptionMap[seedName] = seedName
	end

	if #seedNames == 0 then
		options = {
			"No Seeds Found",
		}
	end

	IsRefreshingPlantSeedDropdown = true
	PlantSeedDropdown:Refresh(options, true)
	pcall(function()
		if State.SelectedPlantSeedOption and PlantSeedOptionMap[State.SelectedPlantSeedOption] then
			PlantSeedDropdown:Set(State.SelectedPlantSeedOption)
		elseif #seedNames == 0 then
			PlantSeedDropdown:Set("No Seeds Found")
		else
			PlantSeedDropdown:Set("Select Seed")
		end
	end)
	IsRefreshingPlantSeedDropdown = false
	updateSelectedPlantSeedLabel()
end

PlotTab:AddButton({
	Name = "Refresh Seed List",
	Callback = function()
		refreshPlantSeedDropdown()
	end,
})

PlotTab:AddButton({
	Name = "Plant Empty Spots Once",
	Callback = function()
		task.spawn(function()
			plantSeedsOnce(false)
		end)
	end,
})

PlotTab:AddToggle({
	Name = "Auto Plant Seeds",
	Default = State.AutoPlantSeeds,
	Callback = function(value)
		State.AutoPlantSeeds = value
		saveConfig()
		consolePrint("[TOGGLE] Auto Plant Seeds:", value)
	end,
})

PlotTab:AddSlider({
	Name = "Plant Pass Delay",
	Min = 1,
	Max = 120,
	Default = State.PlantSeedDelay,
	Increment = 1,
	ValueName = "sec",
	Callback = function(value)
		State.PlantSeedDelay = value
		saveConfig()
	end,
})

PlotTab:AddSection({
	Name = "Plant Sprays",
})

local IsRefreshingSprayDropdown = false
local SprayDropdown
local SelectedSprayLabel
local updateSelectedSprayLabel

SelectedSprayLabel = PlotTab:AddParagraph("Selected Spray", State.SelectedSprayOption or "None")

function updateSelectedSprayLabel()
	if not SelectedSprayLabel then
		return
	end

	local tool = getSelectedSprayTool()

	if tool then
		SelectedSprayLabel:Set(tool.Name)
	elseif State.SelectedSprayOption and State.SelectedSprayOption ~= "Select Spray" then
		SelectedSprayLabel:Set(State.SelectedSprayOption)
	else
		SelectedSprayLabel:Set("None")
	end
end

SprayDropdown = PlotTab:AddDropdown({
	Name = "Spray Dropdown",
	Default = "Select Spray",
	Options = {
		"Select Spray",
	},
	Callback = function(value)
		if IsRefreshingSprayDropdown then
			return
		end

		State.SelectedSprayOption = value

		if value ~= "Select Spray" and value ~= "No Sprays Found" then
			State.SelectedSprayBaseName = getSprayBaseName(value)
		else
			State.SelectedSprayBaseName = nil
		end

		updateSelectedSprayLabel()
		saveConfig()

		if value ~= "Select Spray" and value ~= "No Sprays Found" then
			OrionLib:MakeNotification({
				Name = "Spray Selected",
				Content = value .. " will be used for plant sprays.",
				Time = 3,
			})
		end
	end,
})

local function refreshSprayDropdown()
	local tools = getSprayTools()
	local options = {
		"Select Spray",
	}
	SprayOptionMap = {}

	for _, tool in ipairs(tools) do
		table.insert(options, tool.Name)
		SprayOptionMap[tool.Name] = tool
	end

	if #tools == 0 then
		options = {
			"No Sprays Found",
		}
	end

	IsRefreshingSprayDropdown = true
	SprayDropdown:Refresh(options, true)
	pcall(function()
		local selected = State.SelectedSprayOption
		local didSet = false

		if selected and SprayOptionMap[selected] then
			SprayDropdown:Set(selected)
			didSet = true
		elseif State.SelectedSprayBaseName then
			for _, option in ipairs(options) do
				if getSprayBaseName(option) == State.SelectedSprayBaseName then
					State.SelectedSprayOption = option
					SprayDropdown:Set(option)
					didSet = true
					break
				end
			end
		end

		if not didSet then
			if #tools == 0 then
				SprayDropdown:Set("No Sprays Found")
			else
				SprayDropdown:Set("Select Spray")
			end
		end
	end)
	IsRefreshingSprayDropdown = false
	updateSelectedSprayLabel()
end

PlotTab:AddButton({
	Name = "Refresh Sprays",
	Callback = function()
		refreshSprayDropdown()
	end,
})

PlotTab:AddButton({
	Name = "Spray Plants Once",
	Callback = function()
		task.spawn(function()
			sprayPlantsOnce(false)
		end)
	end,
})

PlotTab:AddToggle({
	Name = "Auto Spray Plants",
	Default = State.AutoSprayPlants,
	Callback = function(value)
		State.AutoSprayPlants = value
		saveConfig()
		consolePrint("[TOGGLE] Auto Spray Plants:", value)
	end,
})

PlotTab:AddSlider({
	Name = "Spray Pass Delay",
	Min = 1,
	Max = 120,
	Default = State.SprayDelay,
	Increment = 1,
	ValueName = "sec",
	Callback = function(value)
		State.SprayDelay = value
		saveConfig()
	end,
})

PlotTab:AddSection({
	Name = "Plant Removal",
})

PlotTab:AddButton({
	Name = "Remove All Plants",
	Callback = function()
		task.spawn(function()
			removeAllPlants()
		end)
	end,
})

--// AUTO BUY TAB

AutoBuyTab:AddSection({
	Name = "Gear Shop",
})

AutoBuyTab:AddButton({
	Name = "Buy Everything Once",
	Callback = function()
		buyAllGearOnce()
	end,
})

AutoBuyTab:AddToggle({
	Name = "Auto Buy Everything",
	Default = State.AutoBuyAllGear,
	Callback = function(value)
		State.AutoBuyAllGear = value
		saveConfig()
		consolePrint("[TOGGLE] Auto Buy Everything:", value)
	end,
})

AutoBuyTab:AddSlider({
	Name = "Gear Buy Loop Delay",
	Min = 1,
	Max = 120,
	Default = State.GearDelay,
	Increment = 1,
	ValueName = "sec",
	Callback = function(value)
		State.GearDelay = value
		saveConfig()
	end,
})

AutoBuyTab:AddSection({
	Name = "Auto Sell",
})

AutoBuyTab:AddToggle({
	Name = "Auto Sell",
	Default = State.AutoSell,
	Callback = function(value)
		State.AutoSell = value
		saveConfig()
		consolePrint("[TOGGLE] Auto Sell:", value)
	end,
})

AutoBuyTab:AddSlider({
	Name = "Sell Loop Delay",
	Min = 1,
	Max = 120,
	Default = State.SellDelay,
	Increment = 1,
	ValueName = "sec",
	Callback = function(value)
		State.SellDelay = value
		saveConfig()
	end,
})

--// SETTINGS TAB

SettingsTab:AddSection({
	Name = "Config",
})

SettingsTab:AddToggle({
	Name = "Save Config",
	Default = State.SaveConfigEnabled,
	Callback = function(value)
		State.SaveConfigEnabled = value
		saveConfig(true)

		if value and not canUseFileConfig() then
			OrionLib:MakeNotification({
				Name = "Config Unavailable",
				Content = "This executor does not expose readfile/writefile config support.",
				Time = 4,
			})
		end
	end,
})

SettingsTab:AddSection({
	Name = "Player",
})

SettingsTab:AddToggle({
	Name = "Anti AFK",
	Default = State.AntiAFK,
	Callback = function(value)
		State.AntiAFK = value
		saveConfig()
		consolePrint("[TOGGLE] Anti AFK:", value)
	end,
})

SettingsTab:AddSection({
	Name = "Discord Webhook",
})

SettingsTab:AddTextbox({
	Name = "Webhook URL",
	Default = State.WebhookURL,
	TextDisappear = false,
	Callback = function(value)
		State.WebhookURL = trim(value)
		saveConfig()
		consolePrint("[WEBHOOK] URL updated.")
	end,
})

SettingsTab:AddToggle({
	Name = "Webhook Seed Purchases",
	Default = State.WebhookSeedPurchases,
	Callback = function(value)
		State.WebhookSeedPurchases = value
		saveConfig()
	end,
})

SettingsTab:AddToggle({
	Name = "Webhook Expensive Gear",
	Default = State.WebhookExpensiveGear,
	Callback = function(value)
		State.WebhookExpensiveGear = value
		saveConfig()
	end,
})

local ThresholdOptions = {
	"500K",
	"1M",
	"10M",
	"50M",
	"75M",
	"750M",
	"1B",
	"10B",
	"15B",
	"20B",
	"100B",
	"1T",
	"25T",
}

SettingsTab:AddDropdown({
	Name = "Expensive Threshold",
	Default = getSafeDropdownDefault(ThresholdOptions, State.ExpensiveThresholdOption, "10B"),
	Options = ThresholdOptions,
	Callback = function(value)
		State.ExpensiveThresholdOption = value
		State.ExpensiveThreshold = parsePrice(value)
		saveConfig()

		OrionLib:MakeNotification({
			Name = "Threshold Updated",
			Content = "Expensive webhook threshold is now " .. value .. ".",
			Time = 3,
		})
	end,
})

SettingsTab:AddButton({
	Name = "Test Webhook",
	Callback = function()
		sendWebhook("✅ Webhook Test", "Your Fortune Auto Tool webhook is working.", {
			{
				name = "Player",
				value = LocalPlayer.Name,
				inline = true,
			},
			{
				name = "Threshold",
				value = formatPrice(State.ExpensiveThreshold),
				inline = true,
			},
		}, 3447003)
	end,
})

SettingsTab:AddSection({
	Name = "Debug",
})

SettingsTab:AddButton({
	Name = "Print Current Plot Seeds",
	Callback = function()
		local seeds = scanCurrentPlotSeeds()

		consolePrint("========== CURRENT PLOT SEEDS ==========")

		for _, seed in ipairs(seeds) do
			consolePrint(
				"Slot "
					.. seed.Slot
					.. " = "
					.. seed.Name
					.. " | "
					.. seed.Rarity
					.. " | "
					.. seed.CostText
					.. " | "
					.. formatPrice(seed.Price)
			)
		end

		consolePrint("========================================")
	end,
})

SettingsTab:AddButton({
	Name = "Print Current Merchant Eggs",
	Callback = function()
		local eggs = scanEggShop()

		consolePrint("========== CURRENT MERCHANT EGGS ==========")

		for _, egg in ipairs(eggs) do
			consolePrint(
				"Slot "
					.. egg.Slot
					.. " = "
					.. tostring(egg.Name)
					.. " | "
					.. tostring(egg.Rarity or "Unknown")
					.. " | "
					.. tostring(egg.LabelText)
			)
		end

		consolePrint("===========================================")
	end,
})

SettingsTab:AddButton({
	Name = "Destroy UI",
	Callback = function()
		ENV.Stop = true
		OrionLib:Destroy()
	end,
})

--// LOOPS

task.spawn(function()
	while not ENV.Stop do
		if State.AutoRoll then
			if State.AutoBuySelectedSeeds or State.AutoBuySelectedSeedRarities then
				local boughtCount = buySelectedSeedsFromCurrentRoll()

				if boughtCount > 0 then
					task.wait(0.05)
				end
			end

			rollSeeds()

			task.wait(math.max(0.5, State.RollDelay))
		else
			task.wait(0.25)
		end
	end
end)

task.spawn(function()
	while not ENV.Stop do
		if State.AutoBuyAllGear then
			buyAllGearOnce()
			task.wait(math.max(1, State.GearDelay))
		else
			task.wait(0.25)
		end
	end
end)

task.spawn(function()
	while not ENV.Stop do
		if State.AutoBuyAllEggs or State.AutoBuySelectedEggRarities then
			buyEggsOnce(State.AutoBuyAllEggs)
			task.wait(math.max(1, State.EggDelay))
		else
			task.wait(0.25)
		end
	end
end)

task.spawn(function()
	while not ENV.Stop do
		if State.AutoCompost then
			compostSelectedSeedsOnce(true)
			task.wait(math.max(1, State.CompostDelay))
		else
			task.wait(0.25)
		end
	end
end)

task.spawn(function()
	while not ENV.Stop do
		if State.AutoUpgradePlants then
			local startedAt = os.clock()

			upgradePlantsOnce(true)

			local elapsed = os.clock() - startedAt
			task.wait(math.max(0, math.max(2.5, State.PlantUpgradeDelay) - elapsed))
		else
			task.wait(0.25)
		end
	end
end)

task.spawn(function()
	while not ENV.Stop do
		if State.AutoPlantSeeds then
			plantSeedsOnce(true)
			task.wait(math.max(1, State.PlantSeedDelay))
		else
			task.wait(0.25)
		end
	end
end)

task.spawn(function()
	while not ENV.Stop do
		if State.AutoSprayPlants then
			sprayPlantsOnce(true)
			task.wait(math.max(1, State.SprayDelay))
		else
			task.wait(0.25)
		end
	end
end)

task.spawn(function()
	while not ENV.Stop do
		if State.AutoSell then
			sellCrates()
			task.wait(math.max(1, State.SellDelay))
		else
			task.wait(0.25)
		end
	end
end)

--// INIT

refreshSeedDropdown()
refreshCompostSeedDropdown()
refreshPlantSeedDropdown()
refreshSprayDropdown()
updateSelectedSeedsLabel()
updateSelectedSeedRaritiesLabel()
updateSelectedEggRaritiesLabel()
updateCompostSeedLabel()
updateSelectedPlantSeedLabel()
updateSelectedSprayLabel()

OrionLib:MakeNotification({
	Name = "Loaded",
	Content = "Fortune Auto Tool loaded.",
	Time = 5,
})

OrionLib:Init()
