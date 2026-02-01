print("=== [Invisible Item Stand] MOD LOADING ===\n")

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local Config = require("../config")
local DEBUG = Config.Debug or false

local function Log(message, level)
    level = level or "info"
    if level == "debug" and not DEBUG then return end

    local prefix = level == "error" and "ERROR: " or level == "warning" and "WARNING: " or ""
    print("[Invisible Item Stand] " .. prefix .. tostring(message) .. "\n")
end

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local COLORS = {
    white = 0, blue = 1, red = 2, green = 3,
    orange = 4, purple = 5, yellow = 6, black = 7,
    cyan = 8, lime = 9, pink = 10, brown = 11,
    none = 12, unpainted = 12, glitch = 13,
    disabled = -1
}

local TEMPERATURE = {
    regular = 1,
    veryCold = 3
}

local ITEM_Z = {
    hidden = 0,
    itemStand = 11.134993,
    wallMount = 5.5
}

local CLASS_PATTERNS = {
    itemStand = "Deployed_ItemStand_ParentBP_C",
    wallMount = "Deployed_ItemStand_WallMount_C",
    foodWarmer = "Deployed_FoodWarmer_C"
}

--------------------------------------------------------------------------------
-- Config Parsing
--------------------------------------------------------------------------------

local function NormalizeColorName(name)
    if type(name) ~= "string" then return nil end
    return name:match("^%s*(.-)%s*$"):lower()
end

local function ParseColorConfig(value, default, configName)
    local color = COLORS[NormalizeColorName(value)]
    if not color then
        Log(string.format("Invalid %s in config. Using %s as default.", configName, default), "warning")
        return COLORS[default]
    end
    return color
end

local TARGET_COLORS = {
    itemStand = ParseColorConfig(Config.InvisibleColorItemStand, "brown", "InvisibleColorItemStand"),
    wallMount = ParseColorConfig(Config.InvisibleColorWallMount, "brown", "InvisibleColorWallMount")
}

local ALWAYS_SHOW_EMPTY = Config.AlwaysShowEmptyItemStands == true
local DISABLE_DECAY = Config.DisableDecayInItemStands == true

-- Pre-computed stand configs (avoids table creation per call)
local STAND_CONFIGS = {
    itemStand = { targetColor = TARGET_COLORS.itemStand, visibleZ = ITEM_Z.itemStand },
    wallMount = { targetColor = TARGET_COLORS.wallMount, visibleZ = ITEM_Z.wallMount }
}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local cachedClasses = {
    itemStand = nil,
    wallMount = nil,
    foodWarmer = nil
}

--------------------------------------------------------------------------------
-- Class Matching (cached IsA -> string fallback -> cache from instance)
--------------------------------------------------------------------------------

-- Helper: Check class match with caching and fallback
-- Returns true if obj matches the class at classKey
local function CheckClass(obj, classKey, getClass)
    local cached = cachedClasses[classKey]

    -- Tier 1: Try cached class (IsValid first, then IsA)
    if cached and cached:IsValid() then
        return obj:IsA(cached)
    end

    -- Tier 2: Fall back to class name matching
    -- (only hit during early loading when classes may be garbage collected)
    local objClass = getClass()
    if objClass:GetFName():ToString() ~= CLASS_PATTERNS[classKey] then
        return false
    end

    -- Tier 3: Class name matched - cache the UClass directly from the object
    cachedClasses[classKey] = objClass
    return true
end

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

-- Returns "itemStand", "wallMount", or nil
local function GetStandType(obj)
    -- Lazy-load class only if needed for fallback
    local objClass = nil
    local function getClass()
        if not objClass then
            objClass = obj:GetClass()
        end
        return objClass
    end

    -- Check order: foodWarmer (exclude), wallMount (specific), itemStand (parent)
    if CheckClass(obj, "foodWarmer", getClass) then return nil end
    if CheckClass(obj, "wallMount", getClass) then return "wallMount" end
    if CheckClass(obj, "itemStand", getClass) then return "itemStand" end

    return nil
end

-- Returns pre-computed config for stand type
local function GetStandConfig(standType)
    return STAND_CONFIGS[standType]
end

-- Checks if local player is host (authority), with caching
-- GetLocalRole: 0=None, 1=SimulatedProxy, 2=AutonomousProxy, 3=Authority
local cachedIsHost = nil
local function IsHost()
    if cachedIsHost == nil then
        local gameState = FindFirstOf("Abiotic_Survival_GameState_C")
        if not gameState:IsValid() then return false end
        cachedIsHost = gameState:GetLocalRole() == 3
        Log(string.format("IsHost: Cached as %s", tostring(cachedIsHost)), "debug")
    end
    return cachedIsHost
end

-- Checks if stand has an item displayed
local function HasItem(stand)
    local inventory = stand.ContainerInventory
    if not inventory or not inventory:IsValid() then return false end

    local outParams = {}
    inventory:IsInventoryEmpty(outParams)
    return not outParams.Empty
end

-- Sets stand mesh visibility and adjusts item Z position
local function SetStandHidden(stand, standType, hidden)
    local config = GetStandConfig(standType)

    local mesh = stand.FurnitureMesh
    if not mesh or not mesh:IsValid() then return false end

    local itemRoot = stand.ItemRoot
    if not itemRoot or not itemRoot:IsValid() then return false end

    mesh:SetHiddenInGame(hidden, false)

    local targetZ = hidden and ITEM_Z.hidden or config.visibleZ
    local loc = itemRoot.RelativeLocation
    if loc then
        itemRoot:K2_SetRelativeLocation({X = loc.X, Y = loc.Y, Z = targetZ}, false, {}, false)
    end

    return true
end

-- Protects items from decay
local function ApplyDecayProtection(stand)
    local inventory = stand.ContainerInventory
    if not inventory or not inventory:IsValid() then
        Log("ApplyDecayProtection: Failed to get inventory", "debug")
        return
    end

    local currentTemp = inventory.InternalTemperature
    if not currentTemp then
        Log("ApplyDecayProtection: Failed to read temperature", "debug")
        return
    end

    if currentTemp ~= TEMPERATURE.veryCold then
        inventory.InternalTemperature = TEMPERATURE.veryCold
        Log(string.format("ApplyDecayProtection: Set temp %d -> %d", currentTemp, TEMPERATURE.veryCold), "debug")
    else
        Log("ApplyDecayProtection: Decay protection already active", "debug")
    end
end

--------------------------------------------------------------------------------
-- Core Visibility Logic
--------------------------------------------------------------------------------

local function UpdateStandVisibility(stand, standType, paintedColor)
    if not stand:IsValid() then return end

    local config = GetStandConfig(standType)
    if config.targetColor == COLORS.disabled then return end

    -- Get current hidden state
    local mesh = stand.FurnitureMesh
    if not mesh or not mesh:IsValid() then return end

    local isCurrentlyHidden = mesh.bHiddenInGame

    -- Determine desired state
    local isTargetColor = paintedColor == config.targetColor
    local hasItem = ALWAYS_SHOW_EMPTY and isTargetColor and HasItem(stand)
    local shouldHide = isTargetColor and (not ALWAYS_SHOW_EMPTY or hasItem)

    -- Only act if state needs to change
    if shouldHide and not isCurrentlyHidden then
        Log(string.format("[%s] Hiding (color=%d)", standType, paintedColor), "debug")
        SetStandHidden(stand, standType, true)
    elseif not shouldHide and isCurrentlyHidden then
        Log(string.format("[%s] Showing (color=%d)", standType, paintedColor), "debug")
        SetStandHidden(stand, standType, false)
    end
end

--------------------------------------------------------------------------------
-- Hook Callbacks
--------------------------------------------------------------------------------

local function OnPlayerCharacterBeginPlay(Context)
    local player = Context:get()
    if not player or not player:IsValid() then return end

    -- Detect main menu to reset host cache (session boundary)
    if player:GetFullName():find("/Game/Maps/MainMenu.MainMenu:PersistentLevel.", 1, true) then
        Log("MainMenu detected, resetting isHost cache", "debug")
        cachedIsHost = nil
    end
end

local function DeployedBeginPlay(Context)
    local stand = Context:get()
    if not stand or not stand:IsValid() then return end

    local standType = GetStandType(stand)
    if not standType then return end

    if DISABLE_DECAY and IsHost() then
        ApplyDecayProtection(stand)
    end

    local color = stand.PaintedColor
    if color == COLORS.unpainted then
        UpdateStandVisibility(stand, standType, color)
    end
end

local function OnRepPaintedColor(Context)
    local stand = Context:get()
    if not stand or not stand:IsValid() then return end

    local standType = GetStandType(stand)
    if not standType then return end

    local color = stand.PaintedColor
    UpdateStandVisibility(stand, standType, color)
end

--------------------------------------------------------------------------------
-- Hook Registration
--------------------------------------------------------------------------------

local HOOK_PATHS = {
    playerChar = "/Game/Blueprints/Characters/Abiotic_PlayerCharacter.Abiotic_PlayerCharacter_C:ReceiveBeginPlay",
    beginPlay = "/Game/Blueprints/DeployedObjects/AbioticDeployed_ParentBP.AbioticDeployed_ParentBP_C:ReceiveBeginPlay",
    onRepColor = "/Game/Blueprints/DeployedObjects/AbioticDeployed_ParentBP.AbioticDeployed_ParentBP_C:OnRep_PaintedColor",
    onRepInventory = "/Game/Blueprints/Characters/Abiotic_InventoryComponent.Abiotic_InventoryComponent_C:OnRep_CurrentInventory",
}

local hooksNeeded = {
    playerChar = DISABLE_DECAY,
    beginPlay = true,
    onRepColor = true,
    onRepInventory = ALWAYS_SHOW_EMPTY,
}

local hooksRegistered = {
    playerChar = false,
    beginPlay = false,
    onRepColor = false,
    onRepInventory = false,
}

local function OnRepCurrentInventory(Context)
    local inventory = Context:get()
    if not inventory or not inventory:IsValid() then return end

    local owner = inventory:GetOwner()
    if not owner or not owner:IsValid() then return end

    local standType = GetStandType(owner)
    if not standType then return end

    local color = owner.PaintedColor
    Log(string.format("OnRep_CurrentInventory: %s color=%d", standType, color), "debug")
    UpdateStandVisibility(owner, standType, color)
end

local HOOK_CALLBACKS = {
    playerChar = OnPlayerCharacterBeginPlay,
    beginPlay = DeployedBeginPlay,
    onRepColor = OnRepPaintedColor,
    onRepInventory = OnRepCurrentInventory,
}

local function AllHooksRegistered()
    for key, needed in pairs(hooksNeeded) do
        if needed and not hooksRegistered[key] then
            return false
        end
    end
    return true
end

local function TryRegisterHooks()
    for key, needed in pairs(hooksNeeded) do
        if needed and not hooksRegistered[key] then
            local ok = pcall(RegisterHook, HOOK_PATHS[key], HOOK_CALLBACKS[key])
            if ok then
                hooksRegistered[key] = true
                Log(string.format("Hook registered: %s", key), "debug")
            end
        end
    end
end

local MAX_HOOK_ATTEMPTS = 20

local function RegisterHooksWithRetry(attempts)
    attempts = attempts or 0

    if AllHooksRegistered() then
        Log("All hooks registered", "debug")
        return
    end

    if attempts >= MAX_HOOK_ATTEMPTS then
        for key, needed in pairs(hooksNeeded) do
            if needed and not hooksRegistered[key] then
                Log(string.format("Failed to register hook after %d attempts: %s", MAX_HOOK_ATTEMPTS, key), "warning")
            end
        end
        return
    end

    TryRegisterHooks()

    if not AllHooksRegistered() then
        ExecuteWithDelay(500, function()
            RegisterHooksWithRetry(attempts + 1)
        end)
    else
        Log("All hooks registered", "debug")
    end
end

ExecuteWithDelay(500, function()
    RegisterHooksWithRetry()
end)

Log("Mod loaded", "debug")
