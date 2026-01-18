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

local CLASS_PATHS = {
    itemStand = "/Game/Blueprints/DeployedObjects/Furniture/Deployed_ItemStand_ParentBP.Deployed_ItemStand_ParentBP_C",
    wallMount = "/Game/Blueprints/DeployedObjects/Furniture/Deployed_ItemStand_WallMount.Deployed_ItemStand_WallMount_C",
    foodWarmer = "/Game/Blueprints/DeployedObjects/Furniture/Deployed_FoodWarmer.Deployed_FoodWarmer_C"
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

local HIDE_ONLY_WITH_ITEM = Config.HideOnlyWithItem == true
local REFRIGERATION_ENABLED = Config.Refrigeration == true

-- Pre-computed stand configs (avoids table creation per call)
local STAND_CONFIGS = {
    itemStand = { targetColor = TARGET_COLORS.itemStand, visibleZ = ITEM_Z.itemStand },
    wallMount = { targetColor = TARGET_COLORS.wallMount, visibleZ = ITEM_Z.wallMount }
}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local cachedClasses = {
    itemStand = CreateInvalidObject(),
    wallMount = CreateInvalidObject(),
    foodWarmer = CreateInvalidObject(),
    loaded = false
}

--------------------------------------------------------------------------------
-- Class Caching (avoids slow StaticFindObject on every IsA call)
--------------------------------------------------------------------------------

local function CacheClasses()
    if cachedClasses.loaded then
        if not cachedClasses.itemStand:IsValid() or not cachedClasses.wallMount:IsValid() or not cachedClasses.foodWarmer:IsValid() then
            Log("Cached classes invalidated, reloading", "debug")
            cachedClasses.loaded = false
            cachedClasses.itemStand = CreateInvalidObject()
            cachedClasses.wallMount = CreateInvalidObject()
            cachedClasses.foodWarmer = CreateInvalidObject()
        else
            return true
        end
    end

    local _, _, itemStandLoaded = LoadAsset(CLASS_PATHS.itemStand)
    local _, _, wallMountLoaded = LoadAsset(CLASS_PATHS.wallMount)
    local _, _, foodWarmerLoaded = LoadAsset(CLASS_PATHS.foodWarmer)

    if not (itemStandLoaded and wallMountLoaded and foodWarmerLoaded) then
        Log("Failed to load ItemStand assets", "debug")
        return false
    end

    cachedClasses.itemStand = StaticFindObject(CLASS_PATHS.itemStand)
    cachedClasses.wallMount = StaticFindObject(CLASS_PATHS.wallMount)
    cachedClasses.foodWarmer = StaticFindObject(CLASS_PATHS.foodWarmer)

    if not cachedClasses.itemStand:IsValid() or not cachedClasses.wallMount:IsValid() or not cachedClasses.foodWarmer:IsValid() then
        Log("Failed to cache class references", "debug")
        return false
    end

    cachedClasses.loaded = true
    Log("Class references cached", "debug")
    return true
end

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

-- Returns "itemStand", "wallMount", or nil
local function GetStandType(obj)
    if not CacheClasses() then return nil end
    if obj:IsA(cachedClasses.foodWarmer) then return nil end
    if obj:IsA(cachedClasses.wallMount) then return "wallMount" end
    if obj:IsA(cachedClasses.itemStand) then return "itemStand" end
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

-- Sets inventory temperature to frozen
local function ApplyRefrigeration(stand)
    local inventory = stand.ContainerInventory
    if not inventory or not inventory:IsValid() then
        Log("ApplyRefrigeration: Failed to get inventory", "debug")
        return
    end

    local currentTemp = inventory.InternalTemperature
    if not currentTemp then
        Log("ApplyRefrigeration: Failed to read temperature", "debug")
        return
    end

    if currentTemp ~= TEMPERATURE.veryCold then
        inventory.InternalTemperature = TEMPERATURE.veryCold
        Log(string.format("ApplyRefrigeration: Set temp %d -> %d", currentTemp, TEMPERATURE.veryCold), "debug")
    else
        Log("ApplyRefrigeration: Already frozen", "debug")
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
    local hasItem = HIDE_ONLY_WITH_ITEM and isTargetColor and HasItem(stand)
    local shouldHide = isTargetColor and (not HIDE_ONLY_WITH_ITEM or hasItem)

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
    if not player:IsValid() then return end

    -- Detect main menu to reset host cache (session boundary)
    if player:GetFullName():find("/Game/Maps/MainMenu.MainMenu:PersistentLevel.", 1, true) then
        Log("MainMenu detected, resetting isHost cache", "debug")
        cachedIsHost = nil
    end
end

local function DeployedBeginPlay(Context)
    local stand = Context:get()
    if not stand:IsValid() then return end

    local standType = GetStandType(stand)
    if not standType then return end

    if REFRIGERATION_ENABLED and IsHost() then
        ApplyRefrigeration(stand)
    end

    local color = stand.PaintedColor
    if color == COLORS.unpainted then
        UpdateStandVisibility(stand, standType, color)
    end
end

local function OnRepPaintedColor(Context)
    local stand = Context:get()
    if not stand:IsValid() then return end

    local standType = GetStandType(stand)
    if not standType then return end

    local color = stand.PaintedColor
    UpdateStandVisibility(stand, standType, color)
end

--------------------------------------------------------------------------------
-- Hook Registration
--------------------------------------------------------------------------------

ExecuteWithDelay(2500, function()
    Log("Registering hooks...", "debug")

    local okPlayerChar, errPlayerChar = pcall(function()
        RegisterHook("/Game/Blueprints/Characters/Abiotic_PlayerCharacter.Abiotic_PlayerCharacter_C:ReceiveBeginPlay",
        OnPlayerCharacterBeginPlay)
    end)
    if not okPlayerChar then
        Log("Failed to register PlayerCharacter hook: " .. tostring(errPlayerChar), "error")
    else
        Log("PlayerCharacter hook registered", "debug")
    end

    local okBeginPlay, errBeginPlay = pcall(function()
        RegisterHook("/Game/Blueprints/DeployedObjects/AbioticDeployed_ParentBP.AbioticDeployed_ParentBP_C:ReceiveBeginPlay", DeployedBeginPlay)
    end)
    if not okBeginPlay then
        Log("Failed to register ReceiveBeginPlay hook: " .. tostring(errBeginPlay), "error")
    else
        Log("ReceiveBeginPlay hook registered", "debug")
    end

    local okOnRep, errOnRep = pcall(function()
        RegisterHook("/Game/Blueprints/DeployedObjects/AbioticDeployed_ParentBP.AbioticDeployed_ParentBP_C:OnRep_PaintedColor", OnRepPaintedColor)
    end)
    if not okOnRep then
        Log("Failed to register OnRep_PaintedColor hook: " .. tostring(errOnRep), "error")
    else
        Log("OnRep_PaintedColor hook registered", "debug")
    end

    if HIDE_ONLY_WITH_ITEM then
        local okOnRepInv, errOnRepInv = pcall(function()
            RegisterHook("/Game/Blueprints/Characters/Abiotic_InventoryComponent.Abiotic_InventoryComponent_C:OnRep_CurrentInventory", function(Context)
                local inventory = Context:get()
                if not inventory:IsValid() then return end

                local owner = inventory:GetOwner()
                if not owner or not owner:IsValid() then return end

                local standType = GetStandType(owner)
                if not standType then return end

                local color = owner.PaintedColor
                Log(string.format("OnRep_CurrentInventory: %s color=%d", standType, color), "debug")
                UpdateStandVisibility(owner, standType, color)
            end)
        end)
        if not okOnRepInv then
            Log("Failed to register OnRep_CurrentInventory hook: " .. tostring(errOnRepInv), "error")
        else
            Log("OnRep_CurrentInventory hook registered", "debug")
        end
    else
        Log("OnRep_CurrentInventory hook skipped (HideOnlyWithItem=false)", "debug")
    end

    Log("All hooks registered", "debug")
end)

Log("Mod loaded", "debug")
