--loadstring(game:HttpGet("https://raw.githubusercontent.com/G07HN-1/supreme-palm-tree/refs/heads/main/script.lua"))()

local PreviousENV = getgenv().FortuneSeedUI

if PreviousENV then
	PreviousENV.Stop = true

	if type(PreviousENV.Cleanup) == "function" then
		pcall(PreviousENV.Cleanup)
	else
		if type(PreviousENV.Connections) == "table" then
			for _, connection in ipairs(PreviousENV.Connections) do
				pcall(function()
					connection:Disconnect()
				end)
			end
		end

		if type(PreviousENV.Threads) == "table" then
			for _, thread in ipairs(PreviousENV.Threads) do
				pcall(function()
					task.cancel(thread)
				end)
			end
		end

		if type(PreviousENV.DestroyUI) == "function" then
			pcall(PreviousENV.DestroyUI)
		end
	end

	task.wait(0.5)
end

getgenv().FortuneSeedUI = {
	Stop = false,
	Connections = {},
	Threads = {},
}

local ENV = getgenv().FortuneSeedUI

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RollSeedsRemote = Remotes:WaitForChild("RollSeeds")
local BuySeedRemote = Remotes:WaitForChild("BuySeed")
local SellCratesRemote = Remotes:WaitForChild("SellCrates")
local UpgradePlantRemote = Remotes:FindFirstChild("UpgradePlant")
local RemovePlantRemote = Remotes:FindFirstChild("RemovePlant")
local UseSprayRemote = Remotes:FindFirstChild("UseSpray")
local PlantSeedRemote = Remotes:FindFirstChild("PlantSeed")
local PlantRushRemote = Remotes:FindFirstChild("PlantRush")
local PlantRushShootRemote = PlantRushRemote and PlantRushRemote:FindFirstChild("Shoot")
local PlantRushDropClaimRemote = PlantRushRemote and PlantRushRemote:FindFirstChild("DropClaim")
local PetsRemote = Remotes:FindFirstChild("Pets")
local EquipPetRemote = PetsRemote and PetsRemote:FindFirstChild("EquipPet")
local UnequipPetRemote = PetsRemote and PetsRemote:FindFirstChild("UnequipPet")
local UpgradePetRemote = PetsRemote and PetsRemote:FindFirstChild("UpgradePet")

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

local OrionPrelude = [[
local syn = syn
local baseTable = table
local table = {}

for key, value in pairs(baseTable) do
	table[key] = value
end

local gethui = gethui or function()
	return game:GetService("CoreGui")
end

table.foreach = function(source, callback)
	for key, value in pairs(source) do
		callback(key, value)
	end
end

if syn and type(syn.protect_gui) ~= "function" then
	syn = nil
end
]]

local OrionLib = loadstring(OrionPrelude .. game:HttpGet(OrionURL))()

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
	AutoPlantRushShoot = false,
	AutoPlantRushPickup = false,
	AutoQueenBeeHoneycomb = false,
	AutoUpgradePets = false,
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
	SelectedPlotFloorOption = "All Floors",
	SelectedPetTypeOption = nil,
	SelectedPlotFloors = {
		["All Floors"] = true,
	},

	RollDelay = 1.25,
	GearDelay = 30,
	EggDelay = 30,
	SellDelay = 15,
	CompostDelay = 5,
	PlantUpgradeDelay = 2.5,
	PlantUpgradeTargetLevel = 40,
	SprayDelay = 5,
	PlantSeedDelay = 5,
	PetUpgradeTargetLevel = 50,

	WebhookURL = "",
	WebhookSeedPurchases = true,
	WebhookExpensiveGear = true,
	ExpensiveThreshold = 10000000000,
	ExpensiveThresholdOption = "10B",
}

local SessionStats = {
	SeedsBoughtTotal = 0,
	SeedsBoughtByName = {},
	EggsBoughtTotal = 0,
	EggsBoughtByName = {},
}

local SeedOptionMap = {}
local CompostSeedOptionMap = {}
local PlantSeedOptionMap = {}
local SprayOptionMap = {}
local PetTypeOptionMap = {}
local GearNamesCache = nil
local GearPriceCache = {}
local PlotCache = nil
local FarmDirtCache = nil
local FarmDirtCachePlot = nil
local FarmDirtCacheFloorKey = nil
local FarmDirtCacheTime = 0
local PlantRushTargetRoots = {}
local PlantRushTargetCacheTime = 0
local LastPlantRushRemoteWarn = 0
local LastPlantRushDropClaimTime = 0
local GearBuyItemDelay = 0.2
local EggBuyItemDelay = 0.2
local PlantUpgradePassDuration = 2.5
local PlantUpgradeBatchSize = 30
local PlantRemovePassDuration = 5
local FarmDirtCacheTTL = 5
local PlantRushTargetCacheTTL = 0.4
local PlantRushShotRepeats = 2
local PlantRushDropClaimCooldown = 0.4
local FarmFloorPaths = {
	{
		Name = "Floor 1",
		Path = {},
		Order = 1,
	},
	{
		Name = "Floor 2",
		Path = { "SecondFloor" },
		Order = 2,
	},
	{
		Name = "Floor 3",
		Path = { "ThirdFloor" },
		Order = 3,
	},
}
local PlotFloorOptions = {
	"All Floors",
	"Floor 1",
	"Floor 2",
	"Floor 3",
}
local IsUpgradingPlants = false
local IsRemovingPlants = false
local IsSprayingPlants = false
local IsPlantingSeeds = false
local LastPlotNotReadyLog = 0

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

local function disconnectConnections()
	for _, connection in ipairs(ENV.Connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end

	table.clear(ENV.Connections)
end

local function cancelThreads()
	for _, thread in ipairs(ENV.Threads) do
		pcall(function()
			task.cancel(thread)
		end)
	end

	table.clear(ENV.Threads)
end

local function untrackThread(thread)
	for index = #ENV.Threads, 1, -1 do
		if ENV.Threads[index] == thread then
			table.remove(ENV.Threads, index)
			return
		end
	end
end

local function clearActionLocks()
	IsUpgradingPlants = false
	IsRemovingPlants = false
	IsSprayingPlants = false
	IsPlantingSeeds = false
end

local function clearRuntimeCaches()
	table.clear(SeedOptionMap)
	table.clear(CompostSeedOptionMap)
	table.clear(PlantSeedOptionMap)
	table.clear(SprayOptionMap)
	table.clear(PetTypeOptionMap)
	table.clear(GearPriceCache)
	GearNamesCache = nil
	PlotCache = nil
	FarmDirtCache = nil
	FarmDirtCachePlot = nil
	FarmDirtCacheFloorKey = nil
	FarmDirtCacheTime = 0
	table.clear(PlantRushTargetRoots)
	PlantRushTargetCacheTime = 0
end

local function cleanupCurrentScript()
	if ENV.Cleaned then
		return
	end

	ENV.Cleaned = true
	ENV.Stop = true
	clearActionLocks()
	clearRuntimeCaches()
	disconnectConnections()
	cancelThreads()

	pcall(function()
		OrionLib:Destroy()
	end)
end

ENV.Cleanup = cleanupCurrentScript
ENV.DestroyUI = function()
	pcall(function()
		OrionLib:Destroy()
	end)
end

local function spawnManaged(callback)
	local thread

	thread = task.spawn(function()
		while not ENV.Stop do
			local ok, err = xpcall(callback, debug.traceback)

			if ok then
				break
			end

			if not ENV.Stop then
				consoleWarn("[TASK ERROR]", err)
				clearActionLocks()
				task.wait(1)
			end
		end

		untrackThread(thread)
	end)

	table.insert(ENV.Threads, thread)

	return thread
end

local function spawnOneShot(callback)
	local thread

	thread = task.spawn(function()
		local ok, err = xpcall(callback, debug.traceback)

		if not ok and not ENV.Stop then
			consoleWarn("[TASK ERROR]", err)
			clearActionLocks()
		end

		untrackThread(thread)
	end)

	table.insert(ENV.Threads, thread)

	return thread
end

local function getSafeDropdownDefault(options, savedValue, fallback)
	for _, option in ipairs(options) do
		if option == savedValue then
			return savedValue
		end
	end

	return fallback
end

local StatsSummaryLabel
local StatsSeedsLabel
local StatsEggsLabel
local updateStatsLabels
local PlantViewerLabel
local updatePlantViewerLabel
local updateSelectedPlotFloorsLabel

local function incrementCount(map, key)
	key = tostring(key or "Unknown")
	map[key] = (map[key] or 0) + 1
end

local function formatCountMap(map)
	local entries = {}

	for name, count in pairs(map) do
		table.insert(entries, {
			Name = name,
			Count = count,
		})
	end

	table.sort(entries, function(a, b)
		if a.Count == b.Count then
			return a.Name < b.Name
		end

		return a.Count > b.Count
	end)

	if #entries == 0 then
		return "None"
	end

	local parts = {}

	for index, entry in ipairs(entries) do
		if index > 10 then
			table.insert(parts, "...")
			break
		end

		table.insert(parts, entry.Name .. ": " .. tostring(entry.Count))
	end

	return table.concat(parts, ", ")
end

local function resetSessionStats()
	SessionStats.SeedsBoughtTotal = 0
	SessionStats.EggsBoughtTotal = 0
	table.clear(SessionStats.SeedsBoughtByName)
	table.clear(SessionStats.EggsBoughtByName)

	if updateStatsLabels then
		updateStatsLabels()
	end
end

local function recordSeedPurchase(seed)
	SessionStats.SeedsBoughtTotal += 1
	incrementCount(SessionStats.SeedsBoughtByName, seed and seed.Name)

	if updateStatsLabels then
		updateStatsLabels()
	end
end

local function recordEggPurchase(egg)
	SessionStats.EggsBoughtTotal += 1
	incrementCount(SessionStats.EggsBoughtByName, egg and (egg.Rarity and egg.Rarity .. " Egg" or egg.Name))

	if updateStatsLabels then
		updateStatsLabels()
	end
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

local function isValidPlotFloorOption(option)
	for _, floorOption in ipairs(PlotFloorOptions) do
		if floorOption == option then
			return true
		end
	end

	return false
end

local function getSelectedPlotFloorList()
	local floors = {}

	if State.SelectedPlotFloors["All Floors"] then
		return {
			"All Floors",
		}
	end

	for _, option in ipairs(PlotFloorOptions) do
		if option ~= "All Floors" and State.SelectedPlotFloors[option] then
			table.insert(floors, option)
		end
	end

	if #floors == 0 then
		return {
			"All Floors",
		}
	end

	return floors
end

local function applySelectedPlotFloors(savedFloors)
	State.SelectedPlotFloors = {}

	if type(savedFloors) ~= "table" then
		State.SelectedPlotFloors["All Floors"] = true
		return
	end

	for key, value in pairs(savedFloors) do
		local floorName = nil

		if type(key) == "number" and type(value) == "string" then
			floorName = value
		elseif type(key) == "string" and value then
			floorName = key
		end

		if floorName and isValidPlotFloorOption(floorName) then
			State.SelectedPlotFloors[floorName] = true
		end
	end

	if State.SelectedPlotFloors["All Floors"] or next(State.SelectedPlotFloors) == nil then
		State.SelectedPlotFloors = {
			["All Floors"] = true,
		}
	end
end

local function getConfigData()
	return {
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
		AutoPlantRushShoot = State.AutoPlantRushShoot,
		AutoPlantRushPickup = State.AutoPlantRushPickup,
		AutoQueenBeeHoneycomb = State.AutoQueenBeeHoneycomb,
		AutoUpgradePets = State.AutoUpgradePets,
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
		SelectedPetTypeOption = State.SelectedPetTypeOption,
		SelectedPlotFloorOption = State.SelectedPlotFloorOption,
		SelectedPlotFloors = getSelectedPlotFloorList(),
		RollDelay = State.RollDelay,
		GearDelay = State.GearDelay,
		EggDelay = State.EggDelay,
		SellDelay = State.SellDelay,
		CompostDelay = State.CompostDelay,
		PlantUpgradeDelay = State.PlantUpgradeDelay,
		PlantUpgradeTargetLevel = State.PlantUpgradeTargetLevel,
		SprayDelay = State.SprayDelay,
		PlantSeedDelay = State.PlantSeedDelay,
		PetUpgradeTargetLevel = State.PetUpgradeTargetLevel,
		WebhookURL = State.WebhookURL,
		WebhookSeedPurchases = State.WebhookSeedPurchases,
		WebhookExpensiveGear = State.WebhookExpensiveGear,
		ExpensiveThreshold = State.ExpensiveThreshold,
		ExpensiveThresholdOption = State.ExpensiveThresholdOption,
	}
end

local function saveConfig()
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
		"AutoPlantRushShoot",
		"AutoPlantRushPickup",
		"AutoQueenBeeHoneycomb",
		"AutoUpgradePets",
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
		"PetUpgradeTargetLevel",
		"ExpensiveThreshold",
	}) do
		if type(data[key]) == "number" then
			State[key] = data[key]
		end
	end

	State.PlantUpgradeTargetLevel = math.clamp(math.floor(State.PlantUpgradeTargetLevel), 1, 100)
	State.PlantUpgradeDelay = math.max(1, tonumber(State.PlantUpgradeDelay) or 1)
	State.CompostDelay = math.clamp(tonumber(State.CompostDelay) or 5, 0.1, 5)
	State.PetUpgradeTargetLevel = math.clamp(math.floor(tonumber(State.PetUpgradeTargetLevel) or 50), 1, 50)

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

	if type(data.SelectedPetTypeOption) == "string" then
		State.SelectedPetTypeOption = data.SelectedPetTypeOption
	end

	if type(data.SelectedPlotFloorOption) == "string" and isValidPlotFloorOption(data.SelectedPlotFloorOption) then
		State.SelectedPlotFloorOption = data.SelectedPlotFloorOption
	end

	if type(data.ExpensiveThresholdOption) == "string" then
		State.ExpensiveThresholdOption = data.ExpensiveThresholdOption
		State.ExpensiveThreshold = parsePrice(data.ExpensiveThresholdOption)
	end

	applySelectedSeeds(data.SelectedSeeds)
	applySelectedSeedRarities(data.SelectedSeedRarities)
	applySelectedEggRarities(data.SelectedEggRarities)
	applySelectedCompostSeeds(data.SelectedCompostSeeds)
	applySelectedPlotFloors(data.SelectedPlotFloors)

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
	UpgradePlantRemote = UpgradePlantRemote
		or Remotes:FindFirstChild("UpgradePlant")
		or Remotes:WaitForChild("UpgradePlant", 5)

	return UpgradePlantRemote
end

local function getRemovePlantRemote()
	RemovePlantRemote = RemovePlantRemote
		or Remotes:FindFirstChild("RemovePlant")
		or Remotes:WaitForChild("RemovePlant", 5)

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

local function getPlantRushShootRemote()
	if PlantRushShootRemote and PlantRushShootRemote.Parent then
		return PlantRushShootRemote
	end

	PlantRushRemote = PlantRushRemote or Remotes:FindFirstChild("PlantRush")
	PlantRushShootRemote = PlantRushRemote and PlantRushRemote:FindFirstChild("Shoot")

	return PlantRushShootRemote
end

local function getPlantRushDropClaimRemote()
	if PlantRushDropClaimRemote and PlantRushDropClaimRemote.Parent then
		return PlantRushDropClaimRemote
	end

	PlantRushRemote = PlantRushRemote or Remotes:FindFirstChild("PlantRush")
	PlantRushDropClaimRemote = PlantRushRemote and PlantRushRemote:FindFirstChild("DropClaim")

	return PlantRushDropClaimRemote
end

local function getPetsRemote(remoteName)
	PetsRemote = PetsRemote or Remotes:FindFirstChild("Pets") or Remotes:WaitForChild("Pets", 5)

	return PetsRemote and (PetsRemote:FindFirstChild(remoteName) or PetsRemote:WaitForChild(remoteName, 5))
end

local function getEquipPetRemote()
	EquipPetRemote = EquipPetRemote or getPetsRemote("EquipPet")

	return EquipPetRemote
end

local function getUnequipPetRemote()
	UnequipPetRemote = UnequipPetRemote or getPetsRemote("UnequipPet")

	return UnequipPetRemote
end

local function getUpgradePetRemote()
	UpgradePetRemote = UpgradePetRemote or getPetsRemote("UpgradePet")

	return UpgradePetRemote
end

local function invalidateFarmDirtCache()
	FarmDirtCache = nil
	FarmDirtCachePlot = nil
	FarmDirtCacheFloorKey = nil
	FarmDirtCacheTime = 0
end

local function getSelectedPlotFloorKey()
	return table.concat(getSelectedPlotFloorList(), "|")
end

local function shouldUseFarmFloor(floorInfo)
	if State.SelectedPlotFloors["All Floors"] then
		return true
	end

	if next(State.SelectedPlotFloors) == nil then
		return true
	end

	return State.SelectedPlotFloors[floorInfo.Name] == true
end

local function selectPlotFloorOption(value)
	if not isValidPlotFloorOption(value) then
		return
	end

	State.SelectedPlotFloorOption = value

	if value == "All Floors" then
		State.SelectedPlotFloors = {
			["All Floors"] = true,
		}
	else
		if State.SelectedPlotFloors["All Floors"] then
			State.SelectedPlotFloors = {}
		end

		State.SelectedPlotFloors[value] = not State.SelectedPlotFloors[value]

		if next(State.SelectedPlotFloors) == nil then
			State.SelectedPlotFloorOption = "All Floors"
			State.SelectedPlotFloors = {
				["All Floors"] = true,
			}
		end
	end

	invalidateFarmDirtCache()

	if updateSelectedPlotFloorsLabel then
		updateSelectedPlotFloorsLabel()
	end

	if updatePlantViewerLabel then
		updatePlantViewerLabel(true)
	end

	saveConfig()
end

local function getNestedChild(root, path)
	local current = root

	for _, name in ipairs(path) do
		current = current and current:FindFirstChild(name)

		if not current then
			return nil
		end
	end

	return current
end

local function addFarmDirtsFromFarmPlot(farmPlot, floorInfo, dirts)
	if not farmPlot then
		return
	end

	for _, plotPart in ipairs(farmPlot:GetChildren()) do
		if plotPart.Name:match("^Plot%d+$") then
			local dirt = plotPart:FindFirstChild("Dirt")

			if dirt then
				table.insert(dirts, {
					Dirt = dirt,
					FloorOrder = floorInfo.Order,
					FloorName = floorInfo.Name,
					PlotOrder = tonumber(plotPart.Name:match("%d+")) or 0,
				})
			end
		end
	end
end

local function getFarmDirts(forceRefresh)
	local plot = findMyPlot()
	local now = os.clock()
	local floorKey = getSelectedPlotFloorKey()

	if
		not forceRefresh
		and FarmDirtCache
		and FarmDirtCachePlot == plot
		and FarmDirtCacheFloorKey == floorKey
		and now - FarmDirtCacheTime < FarmDirtCacheTTL
	then
		return FarmDirtCache
	end

	local dirtInfos = {}

	if plot then
		for _, floorInfo in ipairs(FarmFloorPaths) do
			if shouldUseFarmFloor(floorInfo) then
				local floorRoot = getNestedChild(plot, floorInfo.Path)
				local farmPlot = floorRoot and floorRoot:FindFirstChild("FarmPlot")

				addFarmDirtsFromFarmPlot(farmPlot, floorInfo, dirtInfos)
			end
		end
	end

	table.sort(dirtInfos, function(a, b)
		if a.FloorOrder == b.FloorOrder then
			return a.PlotOrder < b.PlotOrder
		end

		return a.FloorOrder < b.FloorOrder
	end)

	local dirts = {}

	for _, info in ipairs(dirtInfos) do
		table.insert(dirts, info.Dirt)
	end

	FarmDirtCache = dirts
	FarmDirtCachePlot = plot
	FarmDirtCacheFloorKey = floorKey
	FarmDirtCacheTime = now

	return dirts
end

local function isPlotReadyForActions(forceRefresh)
	local map = Workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")

	if not plots then
		return false, "Waiting for map plots to load."
	end

	local plot = findMyPlot()

	if not plot then
		return false, "Waiting for your plot to load."
	end

	if #getFarmDirts(forceRefresh == true) == 0 then
		return false, "Waiting for selected farm floors to load."
	end

	return true
end

local function canRunPlotAction(quiet, actionName)
	local ready, reason = isPlotReadyForActions(false)

	if ready then
		return true
	end

	local now = os.clock()

	if now - LastPlotNotReadyLog > 5 then
		LastPlotNotReadyLog = now
		consolePrint("[PLOT]", reason)
	end

	if not quiet then
		OrionLib:MakeNotification({
			Name = actionName or "Plot",
			Content = reason,
			Time = 3,
		})
	end

	return false
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

local function getPlantMutation(dirt)
	return trim(dirt and dirt:GetAttribute("PlantMutation") or "")
end

local function hasActiveMutation(dirt)
	local mutation = getPlantMutation(dirt)
	local lowerMutation = mutation:lower()

	return mutation ~= "" and lowerMutation ~= "normal" and lowerMutation ~= "none"
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

local function getPlantDisplayName(dirt)
	local plantName = trim(dirt and dirt:GetAttribute("PlantName") or "")

	if plantName == "" then
		plantName = "Unknown"
	end

	if hasActiveMutation(dirt) then
		return getPlantMutation(dirt) .. " " .. plantName
	end

	return plantName
end

local function getPlacedPlantSummary(forceRefresh)
	local groups = {}
	local total = 0

	for _, dirt in ipairs(getPlantedDirts(forceRefresh)) do
		local displayName = getPlantDisplayName(dirt)
		local level = getPlantLevel(dirt)
		local key = displayName .. "\0" .. tostring(level)

		if not groups[key] then
			groups[key] = {
				Name = displayName,
				Level = level,
				Count = 0,
			}
		end

		groups[key].Count += 1
		total += 1
	end

	local entries = {}

	for _, entry in pairs(groups) do
		table.insert(entries, entry)
	end

	table.sort(entries, function(a, b)
		if a.Level == b.Level then
			if a.Count == b.Count then
				return a.Name < b.Name
			end

			return a.Count > b.Count
		end

		return a.Level > b.Level
	end)

	return entries, total
end

local function formatPlacedPlantSummary(forceRefresh)
	local ready, reason = isPlotReadyForActions(forceRefresh == true)

	if not ready then
		return reason
	end

	local entries, total = getPlacedPlantSummary(forceRefresh)

	if total == 0 then
		return "No plants placed."
	end

	local lines = {
		"Total Plants: " .. tostring(total),
	}

	for _, entry in ipairs(entries) do
		local countText = entry.Count > 1 and " (x" .. tostring(entry.Count) .. ")" or ""

		table.insert(lines, entry.Name .. countText .. " - Level " .. tostring(entry.Level))
	end

	return table.concat(lines, "\n")
end

local function getSprayableDirts(forceRefresh)
	local sprayable = {}
	local skippedMutated = 0

	for _, dirt in ipairs(getPlantedDirts(forceRefresh)) do
		if hasActiveMutation(dirt) then
			skippedMutated += 1
		else
			table.insert(sprayable, dirt)
		end
	end

	return sprayable, skippedMutated
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

local function getSeedNameFromTool(tool)
	local baseName = getSeedToolBaseName(tool and tool.Name)

	if SeedsFolder:FindFirstChild(baseName) then
		return baseName
	end

	return nil
end

local function addSeedToolsFrom(container, tools)
	if not container then
		return
	end

	for _, item in ipairs(container:GetChildren()) do
		if item:IsA("Tool") then
			if getSeedNameFromTool(item) then
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

		if toolName == State.SelectedPlantSeedOption and getSeedNameFromTool(tool) == seedName then
			return tool
		end

		if toolName == seedName or toolName == getCompostSeedKey(seedName) or getSeedNameFromTool(tool) == seedName then
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

local function getInstanceCFrame(instance)
	if not instance then
		return nil
	end

	local rootPart = instance:FindFirstChild("HumanoidRootPart", true)

	if rootPart and rootPart:IsA("BasePart") then
		return rootPart.CFrame
	end

	if instance:IsA("BasePart") then
		return instance.CFrame
	end

	if instance:IsA("Attachment") then
		return instance.WorldCFrame
	end

	if instance:IsA("Model") then
		local ok, pivot = pcall(function()
			return instance:GetPivot()
		end)

		if ok then
			return pivot
		end
	end

	return nil
end

local function getPlantRushRuntime()
	local interactiveEvents = Workspace:FindFirstChild("InteractiveEvents")
	local plantRush = interactiveEvents and interactiveEvents:FindFirstChild("PlantRush")

	return plantRush and plantRush:FindFirstChild("Runtime")
end

local function findPlantRushMonster(mob)
	for _, child in ipairs(mob:GetChildren()) do
		if child.Name:lower():find("monster", 1, true) then
			return child
		end
	end

	for _, descendant in ipairs(mob:GetDescendants()) do
		if descendant.Name:lower():find("monster", 1, true) then
			return descendant
		end
	end

	return nil
end

local function getPlantRushTargetPart(monster)
	if not monster then
		return nil
	end

	if monster:IsA("BasePart") then
		return monster
	end

	local rootPart = monster:FindFirstChild("HumanoidRootPart", true)

	if rootPart and rootPart:IsA("BasePart") then
		return rootPart
	end

	return monster
end

local function getPlantRushTargetRoots(forceRefresh)
	local now = os.clock()

	if not forceRefresh and now - PlantRushTargetCacheTime < PlantRushTargetCacheTTL then
		return PlantRushTargetRoots
	end

	local runtime = getPlantRushRuntime()
	table.clear(PlantRushTargetRoots)
	PlantRushTargetCacheTime = now

	if not runtime then
		return PlantRushTargetRoots
	end

	for _, mob in ipairs(runtime:GetChildren()) do
		if mob.Name:lower():find("plant", 1, true) then
			local monster = findPlantRushMonster(mob)
			local targetRoot = getPlantRushTargetPart(monster)

			if targetRoot and targetRoot.Parent then
				table.insert(PlantRushTargetRoots, targetRoot)
			end
		end
	end

	return PlantRushTargetRoots
end

local function claimPlantRushDropsOnce()
	local now = os.clock()

	if now - LastPlantRushDropClaimTime < PlantRushDropClaimCooldown then
		return 0
	end

	LastPlantRushDropClaimTime = now

	local remote = getPlantRushDropClaimRemote()

	if not remote then
		return 0
	end

	local claimed = 0

	for left = 1, 9 do
		for right = 1, 9 do
			if ENV.Stop or not State.AutoPlantRushShoot or not State.AutoPlantRushPickup then
				return claimed
			end

			local key = tostring(left) .. "_" .. tostring(right)
			local ok, err = pcall(function()
				remote:FireServer(key)
			end)

			if ok then
				claimed += 1
			else
				consoleWarn("[EVENT PICKUP FAILED]", key, err)
			end
		end

		task.wait()
	end

	return claimed
end

local function shootPlantRushTargetsOnce()
	local remote = getPlantRushShootRemote()

	if not remote then
		local now = os.clock()

		if now - LastPlantRushRemoteWarn > 5 then
			LastPlantRushRemoteWarn = now
			consoleWarn("[EVENT] PlantRush Shoot remote not found.")
		end

		return 0
	end

	local camera = Workspace.CurrentCamera
	local origin = camera and camera.CFrame.Position

	if not origin then
		local character = LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		origin = root and root.Position
	end

	if not origin then
		return 0
	end

	local shotCount = 0

	for _, targetRoot in ipairs(getPlantRushTargetRoots(false)) do
		if ENV.Stop or not State.AutoPlantRushShoot then
			break
		end

		local targetCFrame = getInstanceCFrame(targetRoot)
		local targetPosition = targetCFrame and targetCFrame.Position

		if not targetPosition then
			continue
		end

		local offset = targetPosition - origin

		if offset.Magnitude > 0 then
			local direction = offset.Unit

			for _ = 1, PlantRushShotRepeats do
				local ok, err = pcall(function()
					remote:FireServer(origin, direction, targetPosition)
				end)

				if ok then
					shotCount += 1
				else
					consoleWarn("[EVENT SHOOT FAILED]", err)
				end
			end
		end
	end

	return shotCount
end

local function getQueenBeeHoneycombFolder()
	local interactiveEvents = Workspace:FindFirstChild("InteractiveEvents")
	local queenBee = interactiveEvents and interactiveEvents:FindFirstChild("QueenBee")

	return queenBee and queenBee:FindFirstChild("RuntimeHoneycombs")
end

local function getCharacterRoot()
	local character = LocalPlayer.Character

	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getPromptPart(prompt)
	local current = prompt and prompt.Parent

	while current do
		if current:IsA("BasePart") then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function movePromptNearCharacter(prompt, index)
	local root = getCharacterRoot()
	local promptPart = getPromptPart(prompt)

	if not root or not promptPart then
		return false
	end

	local offsetX = ((index - 1) % 3 - 1) * 2
	local offsetZ = -4 - math.floor((index - 1) / 3) * 1.5

	pcall(function()
		promptPart.Anchored = true
		promptPart.CFrame = root.CFrame * CFrame.new(offsetX, 0, offsetZ)
	end)

	return true
end

local function collectQueenBeeHoneycombsOnce()
	if type(fireproximityprompt) ~= "function" then
		return 0
	end

	local folder = getQueenBeeHoneycombFolder()

	if not folder then
		return 0
	end

	local collected = 0
	local promptIndex = 0

	for _, honeycombModel in ipairs(folder:GetChildren()) do
		if ENV.Stop or not State.AutoQueenBeeHoneycomb then
			break
		end

		local prompt = honeycombModel:FindFirstChild("CollectPrompt", true)

		if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled then
			promptIndex += 1

			local ok, err = pcall(function()
				movePromptNearCharacter(prompt, promptIndex)
				prompt.RequiresLineOfSight = false
				prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance, 30)
				prompt.HoldDuration = 0
				fireproximityprompt(prompt)
			end)

			if ok then
				collected += 1
			else
				consoleWarn("[EVENT HONEYCOMB FAILED]", err)
			end
		end
	end

	return collected
end

local function getPetKeyFromInstance(instance)
	local key = instance and instance:GetAttribute("PetKey")

	if type(key) == "string" and key ~= "" then
		return key
	end

	local name = tostring(instance and instance.Name or "")
	local prefix = "Pet_" .. LocalPlayer.Name .. "_"

	if name:sub(1, #prefix) == prefix then
		return name:sub(#prefix + 1)
	end

	local displayPrefix = "Pet_" .. LocalPlayer.DisplayName .. "_"

	if name:sub(1, #displayPrefix) == displayPrefix then
		return name:sub(#displayPrefix + 1)
	end

	if name:sub(1, 4) == "Pet_" then
		local remaining = name:sub(5)
		local firstUnderscore = remaining:find("_", 1, true)

		if firstUnderscore then
			return remaining:sub(firstUnderscore + 1)
		end
	end

	return nil
end

local function getPetNameFromKey(petKey)
	local name = tostring(petKey or ""):match("^([^_]+)")

	if name and name ~= "" then
		return name
	end

	return nil
end

local function getPetSizeRank(size)
	local lowerSize = tostring(size or ""):lower()

	if lowerSize:find("giant", 1, true) then
		return 3
	end

	if lowerSize:find("big", 1, true) then
		return 2
	end

	if lowerSize:find("regular", 1, true) or lowerSize:find("normal", 1, true) then
		return 1
	end

	return 0
end

local function buildPetInfo(instance)
	local petKey = getPetKeyFromInstance(instance)

	if not petKey then
		return nil
	end

	local petName = instance:GetAttribute("PetName")

	if type(petName) ~= "string" or petName == "" then
		petName = getPetNameFromKey(petKey)
	end

	if not petName then
		return nil
	end

	local petLevel = math.max(0, math.floor(tonumber(instance:GetAttribute("PetLevel")) or 0))
	local petSize = tostring(instance:GetAttribute("PetSize") or "Regular")
	local earningsMultiplier = tonumber(instance:GetAttribute("EarningsMultiplier")) or 0
	local floorIndex = math.max(0, math.floor(tonumber(instance:GetAttribute("FloorIndex")) or 0))

	return {
		Key = petKey,
		Name = petName,
		Level = petLevel,
		Size = petSize,
		SizeRank = getPetSizeRank(petSize),
		EarningsMultiplier = earningsMultiplier,
		FloorIndex = floorIndex,
		Instance = instance,
		Equipped = instance.Name:sub(1, 4) == "Pet_",
	}
end

local function addPetsFromRoot(root, petsByKey)
	if not root then
		return
	end

	for _, instance in ipairs(root:GetDescendants()) do
		if instance:GetAttribute("PetKey") or instance.Name:sub(1, 4) == "Pet_" then
			local petInfo = buildPetInfo(instance)

			if petInfo and not petsByKey[petInfo.Key] then
				petsByKey[petInfo.Key] = petInfo
			end
		end
	end
end

local function getAllPets()
	local petsByKey = {}
	local plot = findMyPlot()

	addPetsFromRoot(LocalPlayer, petsByKey)
	addPetsFromRoot(LocalPlayer.Character, petsByKey)
	addPetsFromRoot(plot, petsByKey)

	local pets = {}

	for _, petInfo in pairs(petsByKey) do
		table.insert(pets, petInfo)
	end

	table.sort(pets, function(a, b)
		if a.Name == b.Name then
			if a.SizeRank == b.SizeRank then
				if a.Level == b.Level then
					return a.Key < b.Key
				end

				return a.Level > b.Level
			end

			return a.SizeRank > b.SizeRank
		end

		return a.Name < b.Name
	end)

	return pets
end

local function getPetTypes()
	local seen = {}
	local types = {}

	for _, petInfo in ipairs(getAllPets()) do
		if not seen[petInfo.Name] then
			seen[petInfo.Name] = true
			table.insert(types, petInfo.Name)
		end
	end

	table.sort(types)

	return types
end

local function getSelectedPetType()
	local selected = State.SelectedPetTypeOption

	if not selected or selected == "Select Pet" or selected == "No Pets Found" then
		return nil
	end

	return PetTypeOptionMap[selected] or selected
end

local function getPetsByType(petType)
	local pets = {}

	for _, petInfo in ipairs(getAllPets()) do
		if petInfo.Name == petType then
			table.insert(pets, petInfo)
		end
	end

	table.sort(pets, function(a, b)
		if a.SizeRank == b.SizeRank then
			if a.Level == b.Level then
				return a.Key < b.Key
			end

			return a.Level > b.Level
		end

		return a.SizeRank > b.SizeRank
	end)

	return pets
end

local function getEquippedPets()
	local equipped = {}
	local plot = findMyPlot()

	if not plot then
		return equipped
	end

	for _, instance in ipairs(plot:GetChildren()) do
		if instance.Name:sub(1, 4) == "Pet_" then
			local petInfo = buildPetInfo(instance)

			if petInfo then
				table.insert(equipped, petInfo)
			end
		end
	end

	return equipped
end

local function formatPetMultiplier(value)
	local number = tonumber(value) or 0

	if number % 1 == 0 then
		return tostring(number)
	end

	return string.format("%.2f", number):gsub("0+$", ""):gsub("%.$", "")
end

local function getEquippedPetsByFloorSummary()
	local petsByFloor = {}
	local total = 0

	for _, petInfo in ipairs(getEquippedPets()) do
		local floorIndex = petInfo.FloorIndex

		if floorIndex < 1 then
			floorIndex = 1
		end

		petsByFloor[floorIndex] = petsByFloor[floorIndex] or {}
		table.insert(petsByFloor[floorIndex], petInfo)
		total += 1
	end

	if total == 0 then
		return "No equipped pets found."
	end

	local floorIndexes = {}

	for floorIndex in pairs(petsByFloor) do
		table.insert(floorIndexes, floorIndex)
	end

	table.sort(floorIndexes)

	local lines = {}

	for _, floorIndex in ipairs(floorIndexes) do
		table.insert(lines, "Floor " .. tostring(floorIndex))

		table.sort(petsByFloor[floorIndex], function(a, b)
			if a.SizeRank == b.SizeRank then
				if a.Level == b.Level then
					return a.Name < b.Name
				end

				return a.Level > b.Level
			end

			return a.SizeRank > b.SizeRank
		end)

		for _, petInfo in ipairs(petsByFloor[floorIndex]) do
			table.insert(
				lines,
				"- "
					.. petInfo.Size
					.. " "
					.. petInfo.Name
					.. " | Level "
					.. tostring(petInfo.Level)
					.. " | Earnings x"
					.. formatPetMultiplier(petInfo.EarningsMultiplier)
			)
		end
	end

	return table.concat(lines, "\n")
end

local function unequipAllPets()
	local remote = getUnequipPetRemote()

	if not remote then
		consoleWarn("[PETS] UnequipPet remote not found.")
		return 0
	end

	local unequipped = 0

	for _, petInfo in ipairs(getEquippedPets()) do
		local ok, err = pcall(function()
			remote:FireServer(petInfo.Key)
		end)

		if ok then
			unequipped += 1
		else
			consoleWarn("[PETS UNEQUIP FAILED]", petInfo.Key, err)
		end

		task.wait(0.05)
	end

	return unequipped
end

local function equipPetByKey(remote, petKey)
	local ok = pcall(function()
		remote:FireServer(petKey)
	end)

	if ok then
		return true
	end

	ok = pcall(function()
		remote:FireServer()
	end)

	return ok
end

local function equipSelectedPetType()
	local remote = getEquipPetRemote()
	local petType = getSelectedPetType()

	if not remote or not petType then
		return 0
	end

	unequipAllPets()
	task.wait(0.2)

	local equipped = 0

	for _, petInfo in ipairs(getPetsByType(petType)) do
		if ENV.Stop then
			break
		end

		if equipPetByKey(remote, petInfo.Key) then
			equipped += 1
		end

		task.wait(0.05)
	end

	return equipped
end

local function upgradePetsOnce(quiet)
	local remote = getUpgradePetRemote()
	local petType = getSelectedPetType()

	if not remote or not petType then
		return 0
	end

	local targetLevel = math.clamp(math.floor(tonumber(State.PetUpgradeTargetLevel) or 50), 1, 50)
	local upgraded = 0

	for _, petInfo in ipairs(getPetsByType(petType)) do
		if ENV.Stop then
			break
		end

		if petInfo.Level < targetLevel then
			local ok, err = pcall(function()
				return remote:InvokeServer(petInfo.Key)
			end)

			if ok then
				upgraded += 1
			else
				consoleWarn("[PETS UPGRADE FAILED]", petInfo.Key, err)
			end

			task.wait(0.1)
		end
	end

	if not quiet and upgraded > 0 then
		OrionLib:MakeNotification({
			Name = "Pets",
			Content = "Upgrade request sent for " .. tostring(upgraded) .. " " .. petType .. " pets.",
			Time = 3,
		})
	end

	return upgraded
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

	sendWebhook("ðŸŒ± Selected Seed Purchased", "Auto-buy bought a selected seed before rolling again.", {
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

	sendWebhook(
		"ðŸ›’ Expensive Gear Purchased",
		"Auto-buy purchased gear at or above your expensive threshold.",
		{
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
		},
		16753920
	)
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
		recordSeedPurchase(seed)

		if deferWebhook then
			spawnOneShot(function()
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
		recordEggPurchase(egg)

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

	if not canRunPlotAction(quiet, "Plant Upgrade Pass") then
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

	if updatePlantViewerLabel then
		updatePlantViewerLabel()
	end

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

	if not canRunPlotAction(false, "Remove Plants") then
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

	if updatePlantViewerLabel then
		updatePlantViewerLabel(true)
	end

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

	if not canRunPlotAction(quiet, "Plant Spray") then
		return 0
	end

	IsSprayingPlants = true

	local remote = getUseSprayRemote()
	local tool = getSelectedSprayTool()
	local sprayableDirts, skippedMutated = getSprayableDirts(false)
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

	if #sprayableDirts == 0 then
		IsSprayingPlants = false

		if not quiet then
			OrionLib:MakeNotification({
				Name = "Plant Spray",
				Content = "No sprayable plants found. Skipped " .. tostring(skippedMutated) .. " mutated plants.",
				Time = 3,
			})
		end

		consolePrint("[PLOT SPRAY] no sprayable plants. skipped mutated:", skippedMutated)
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

	for _, dirt in ipairs(sprayableDirts) do
		if ENV.Stop then
			break
		end

		if hasActiveMutation(dirt) then
			skippedMutated += 1
			continue
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
			Content = "Sprayed " .. tostring(sprayed) .. " plants. Skipped " .. tostring(skippedMutated) .. " mutated.",
			Time = 3,
		})
	end

	consolePrint("[PLOT SPRAY] sprayed:", sprayed, "skipped mutated:", skippedMutated, "spray:", tool.Name)

	if updatePlantViewerLabel then
		updatePlantViewerLabel()
	end

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

	if not canRunPlotAction(quiet, "Plant Seeds") then
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

		if not isOccupiedDirt(dirt) then
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

	if updatePlantViewerLabel then
		updatePlantViewerLabel(true)
	end

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

local function buildPetsTab(PetsTab)
	PetsTab:AddSection({
		Name = "Equipped Pets",
	})

	local EquippedPetsLabel = PetsTab:AddParagraph("Pets By Floor", "Loading...")

	local function updateEquippedPetsLabel()
		EquippedPetsLabel:Set(getEquippedPetsByFloorSummary())
	end

	PetsTab:AddButton({
		Name = "Refresh Equipped Pets",
		Callback = function()
			updateEquippedPetsLabel()
		end,
	})

	PetsTab:AddSection({
		Name = "Pet Equip",
	})

	local IsRefreshingPetTypeDropdown = false
	local PetTypeDropdown
	local SelectedPetTypeLabel = PetsTab:AddParagraph("Selected Pet", State.SelectedPetTypeOption or "None")

	local function updateSelectedPetTypeLabel()
		local petType = getSelectedPetType()

		if not petType then
			SelectedPetTypeLabel:Set("None")
			return
		end

		local pets = getPetsByType(petType)
		local best = pets[1]

		if best then
			SelectedPetTypeLabel:Set(
				petType
					.. " (x"
					.. tostring(#pets)
					.. ") | Best: "
					.. best.Size
					.. " Level "
					.. tostring(best.Level)
			)
		else
			SelectedPetTypeLabel:Set(petType)
		end
	end

	PetTypeDropdown = PetsTab:AddDropdown({
		Name = "Pet Type",
		Default = "Select Pet",
		Options = {
			"Select Pet",
		},
		Callback = function(value)
			if IsRefreshingPetTypeDropdown then
				return
			end

			State.SelectedPetTypeOption = value
			updateSelectedPetTypeLabel()
			saveConfig()
		end,
	})

	local function refreshPetTypeDropdown()
		local petTypes = getPetTypes()
		local options = {
			"Select Pet",
		}
		PetTypeOptionMap = {}

		for _, petType in ipairs(petTypes) do
			table.insert(options, petType)
			PetTypeOptionMap[petType] = petType
		end

		if #petTypes == 0 then
			options = {
				"No Pets Found",
			}
		end

		IsRefreshingPetTypeDropdown = true
		PetTypeDropdown:Refresh(options, true)
		pcall(function()
			if State.SelectedPetTypeOption and PetTypeOptionMap[State.SelectedPetTypeOption] then
				PetTypeDropdown:Set(State.SelectedPetTypeOption)
			elseif #petTypes == 0 then
				PetTypeDropdown:Set("No Pets Found")
			else
				PetTypeDropdown:Set("Select Pet")
			end
		end)
		IsRefreshingPetTypeDropdown = false
		updateSelectedPetTypeLabel()
		updateEquippedPetsLabel()
	end

	PetsTab:AddButton({
		Name = "Refresh Pets",
		Callback = function()
			refreshPetTypeDropdown()
		end,
	})

	PetsTab:AddButton({
		Name = "Unequip All Pets",
		Callback = function()
			spawnOneShot(function()
				local count = unequipAllPets()
				updateEquippedPetsLabel()

				OrionLib:MakeNotification({
					Name = "Pets",
					Content = "Unequipped " .. tostring(count) .. " pets.",
					Time = 3,
				})
			end)
		end,
	})

	PetsTab:AddButton({
		Name = "Equip Selected Type",
		Callback = function()
			spawnOneShot(function()
				local petType = getSelectedPetType()
				local count = equipSelectedPetType()
				updateEquippedPetsLabel()

				OrionLib:MakeNotification({
					Name = "Pets",
					Content = "Equip request sent for "
						.. tostring(count)
						.. " "
						.. tostring(petType or "selected")
						.. " pets.",
					Time = 3,
				})
			end)
		end,
	})

	PetsTab:AddSection({
		Name = "Pet Upgrades",
	})

	PetsTab:AddSlider({
		Name = "Target Pet Level",
		Min = 1,
		Max = 50,
		Default = State.PetUpgradeTargetLevel,
		Increment = 1,
		ValueName = "level",
		Callback = function(value)
			State.PetUpgradeTargetLevel = value
			saveConfig()
		end,
	})

	PetsTab:AddButton({
		Name = "Upgrade Selected Pets Once",
		Callback = function()
			spawnOneShot(function()
				upgradePetsOnce(false)
			end)
		end,
	})

	PetsTab:AddToggle({
		Name = "Auto Upgrade Selected Pets",
		Default = State.AutoUpgradePets,
		Callback = function(value)
			State.AutoUpgradePets = value
			saveConfig()
			consolePrint("[TOGGLE] Auto Upgrade Pets:", value)
		end,
	})

	refreshPetTypeDropdown()
	updateEquippedPetsLabel()
end

loadConfig()
setupAntiAFK()

--// UI

local function buildUI()
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

	local PetsTab = Window:MakeTab({
		Name = "Pets",
		Icon = "paw-print",
		PremiumOnly = false,
	})

	local EventTab = Window:MakeTab({
		Name = "Event",
		Icon = "target",
		PremiumOnly = false,
	})

	local AutoBuyTab = Window:MakeTab({
		Name = "Auto Buy",
		Icon = "shopping-cart",
		PremiumOnly = false,
	})

	local StatsTab = Window:MakeTab({
		Name = "Stats",
		Icon = "bar-chart",
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
		Min = 0.1,
		Max = 5,
		Default = State.CompostDelay,
		Increment = 0.1,
		ValueName = "sec",
		Callback = function(value)
			State.CompostDelay = value
			saveConfig()
		end,
	})

	--// PLOT TAB

	PlotTab:AddSection({
		Name = "Floor Filter",
	})

	local IsInitializingPlotFloorDropdown = true
	local SelectedPlotFloorsLabel =
		PlotTab:AddParagraph("Selected Floors", table.concat(getSelectedPlotFloorList(), ", "))

	function updateSelectedPlotFloorsLabel()
		if not SelectedPlotFloorsLabel then
			return
		end

		SelectedPlotFloorsLabel:Set(table.concat(getSelectedPlotFloorList(), ", "))
	end

	PlotTab:AddDropdown({
		Name = "Floor Selector",
		Default = getSafeDropdownDefault(PlotFloorOptions, State.SelectedPlotFloorOption, "All Floors"),
		Options = PlotFloorOptions,
		Callback = function(value)
			if IsInitializingPlotFloorDropdown then
				return
			end

			selectPlotFloorOption(value)
		end,
	})

	IsInitializingPlotFloorDropdown = false

	PlotTab:AddSection({
		Name = "Plant Viewer",
	})

	PlantViewerLabel = PlotTab:AddParagraph("Placed Plants", "Loading...")

	function updatePlantViewerLabel(forceRefresh)
		if not PlantViewerLabel then
			return
		end

		PlantViewerLabel:Set(formatPlacedPlantSummary(forceRefresh == true))
	end

	PlotTab:AddButton({
		Name = "Refresh Plant Viewer",
		Callback = function()
			updatePlantViewerLabel(true)
		end,
	})

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
			spawnOneShot(function()
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
		Min = 1,
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
		local seedTools = getSeedTools()
		local options = {
			"Select Seed",
		}
		PlantSeedOptionMap = {}

		for _, tool in ipairs(seedTools) do
			local seedName = getSeedNameFromTool(tool)

			if seedName then
				table.insert(options, tool.Name)
				PlantSeedOptionMap[tool.Name] = seedName
			end
		end

		if #seedTools == 0 then
			options = {
				"No Seeds Found",
			}
		end

		IsRefreshingPlantSeedDropdown = true
		PlantSeedDropdown:Refresh(options, true)
		pcall(function()
			if State.SelectedPlantSeedOption and PlantSeedOptionMap[State.SelectedPlantSeedOption] then
				PlantSeedDropdown:Set(State.SelectedPlantSeedOption)
			elseif #seedTools == 0 then
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
			spawnOneShot(function()
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
			spawnOneShot(function()
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
			spawnOneShot(function()
				removeAllPlants()
			end)
		end,
	})

	buildPetsTab(PetsTab)

	--// EVENT TAB

	EventTab:AddSection({
		Name = "Plant Rush",
	})

	EventTab:AddToggle({
		Name = "Auto Shoot",
		Default = State.AutoPlantRushShoot,
		Callback = function(value)
			State.AutoPlantRushShoot = value
			saveConfig()
			consolePrint("[TOGGLE] Auto PlantRush Shoot:", value)
		end,
	})

	EventTab:AddToggle({
		Name = "Auto Pickup",
		Default = State.AutoPlantRushPickup,
		Callback = function(value)
			State.AutoPlantRushPickup = value
			saveConfig()
			consolePrint("[TOGGLE] Auto PlantRush Pickup:", value)
		end,
	})

	EventTab:AddSection({
		Name = "Queen Bee",
	})

	EventTab:AddToggle({
		Name = "Auto Collect Honeycomb",
		Default = State.AutoQueenBeeHoneycomb,
		Callback = function(value)
			State.AutoQueenBeeHoneycomb = value
			saveConfig()
			consolePrint("[TOGGLE] Auto QueenBee Honeycomb:", value)
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

	--// STATS TAB

	StatsTab:AddSection({
		Name = "Session Stats",
	})

	StatsSummaryLabel = StatsTab:AddParagraph("Summary", "Loading...")
	StatsSeedsLabel = StatsTab:AddParagraph("Seeds Bought", "Loading...")
	StatsEggsLabel = StatsTab:AddParagraph("Eggs Bought", "Loading...")

	function updateStatsLabels()
		if not StatsSummaryLabel or not StatsSeedsLabel or not StatsEggsLabel then
			return
		end

		StatsSummaryLabel:Set(
			"Seeds: "
				.. tostring(SessionStats.SeedsBoughtTotal)
				.. " | Eggs: "
				.. tostring(SessionStats.EggsBoughtTotal)
		)
		StatsSeedsLabel:Set(formatCountMap(SessionStats.SeedsBoughtByName))
		StatsEggsLabel:Set(formatCountMap(SessionStats.EggsBoughtByName))
	end

	StatsTab:AddButton({
		Name = "Reset Session Stats",
		Callback = function()
			resetSessionStats()

			OrionLib:MakeNotification({
				Name = "Stats Reset",
				Content = "Session auto-buy stats have been reset.",
				Time = 3,
			})
		end,
	})

	--// SETTINGS TAB

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
			sendWebhook("âœ… Webhook Test", "Your Fortune Auto Tool webhook is working.", {
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

	SettingsTab:AddButton({
		Name = "Destroy UI",
		Callback = function()
			cleanupCurrentScript()
		end,
	})

	--// LOOPS

	spawnManaged(function()
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

	spawnManaged(function()
		while not ENV.Stop do
			if State.AutoBuyAllGear then
				buyAllGearOnce()
				task.wait(math.max(1, State.GearDelay))
			else
				task.wait(0.25)
			end
		end
	end)

	spawnManaged(function()
		while not ENV.Stop do
			if State.AutoBuyAllEggs or State.AutoBuySelectedEggRarities then
				buyEggsOnce(State.AutoBuyAllEggs)
				task.wait(math.max(1, State.EggDelay))
			else
				task.wait(0.25)
			end
		end
	end)

	spawnManaged(function()
		while not ENV.Stop do
			if State.AutoCompost then
				compostSelectedSeedsOnce(true)
				task.wait(math.max(0.1, State.CompostDelay))
			else
				task.wait(0.25)
			end
		end
	end)

	spawnManaged(function()
		while not ENV.Stop do
			if State.AutoUpgradePlants then
				local startedAt = os.clock()

				upgradePlantsOnce(true)

				local elapsed = os.clock() - startedAt
				task.wait(math.max(0, math.max(1, State.PlantUpgradeDelay) - elapsed))
			else
				task.wait(0.25)
			end
		end
	end)

	spawnManaged(function()
		while not ENV.Stop do
			if State.AutoPlantSeeds then
				plantSeedsOnce(true)
				task.wait(math.max(1, State.PlantSeedDelay))
			else
				task.wait(0.25)
			end
		end
	end)

	spawnManaged(function()
		while not ENV.Stop do
			if State.AutoSprayPlants then
				sprayPlantsOnce(true)
				task.wait(math.max(1, State.SprayDelay))
			else
				task.wait(0.25)
			end
		end
	end)

	spawnManaged(function()
		while not ENV.Stop do
			if State.AutoPlantRushShoot then
				local shotCount = shootPlantRushTargetsOnce()

				if shotCount > 0 and State.AutoPlantRushPickup then
					claimPlantRushDropsOnce()
				end

				task.wait(0.02)
			else
				task.wait(0.25)
			end
		end
	end)

	spawnManaged(function()
		while not ENV.Stop do
			if State.AutoUpgradePets then
				upgradePetsOnce(true)
				task.wait(1)
			else
				task.wait(0.25)
			end
		end
	end)

	spawnManaged(function()
		while not ENV.Stop do
			if State.AutoQueenBeeHoneycomb then
				collectQueenBeeHoneycombsOnce()
				task.wait(0.5)
			else
				task.wait(0.25)
			end
		end
	end)

	spawnManaged(function()
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
	updateStatsLabels()
	updatePlantViewerLabel(true)
end

buildUI()

OrionLib:MakeNotification({
	Name = "Loaded",
	Content = "Fortune Auto Tool loaded.",
	Time = 5,
})

OrionLib:Init()
