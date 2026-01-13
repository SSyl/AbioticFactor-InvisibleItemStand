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
    wallMount = "/Game/Blueprints/DeployedObjects/Furniture/Deployed_ItemStand_WallMount.Deployed_ItemStand_WallMount_C"
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

local HIDE_ONLY_WITH_ITEM = Config.HideOnlyWithItem ~= false
local REFRIGERATION_ENABLED = Config.Refrigeration == true

-- Pre-computed stand configs (avoids table creation per call)
local STAND_CONFIGS = {
    itemStand = { targetColor = TARGET_COLORS.itemStand, visibleZ = ITEM_Z.itemStand },
    wallMount = { targetColor = TARGET_COLORS.wallMount, visibleZ = ITEM_Z.wallMount }
}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local isHost = false

local cachedClasses = {
    itemStand = nil,
    wallMount = nil,
    loaded = false
}

--------------------------------------------------------------------------------
-- Class Caching (avoids slow StaticFindObject on every IsA call)
--------------------------------------------------------------------------------

local function CacheClasses()
    if cachedClasses.loaded then
        if (cachedClasses.itemStand and not cachedClasses.itemStand:IsValid()) or
           (cachedClasses.wallMount and not cachedClasses.wallMount:IsValid()) then
            Log("Cached classes invalidated, reloading", "debug")
            cachedClasses.loaded = false
            cachedClasses.itemStand = nil
            cachedClasses.wallMount = nil
        else
            return true
        end
    end

    local _, _, itemStandLoaded = LoadAsset(CLASS_PATHS.itemStand)
    local _, _, wallMountLoaded = LoadAsset(CLASS_PATHS.wallMount)

    if not (itemStandLoaded and wallMountLoaded) then
        Log("Failed to load ItemStand assets", "debug")
        return false
    end

    cachedClasses.itemStand = StaticFindObject(CLASS_PATHS.itemStand)
    cachedClasses.wallMount = StaticFindObject(CLASS_PATHS.wallMount)

    if not cachedClasses.itemStand:IsValid() or not cachedClasses.wallMount:IsValid() then
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
    if obj:IsA(cachedClasses.wallMount) then return "wallMount" end
    if obj:IsA(cachedClasses.itemStand) then return "itemStand" end
    return nil
end

-- Returns pre-computed config for stand type
local function GetStandConfig(standType)
    return STAND_CONFIGS[standType]
end

-- Checks if stand has an item displayed
local function HasItem(stand)
    local okInventory, inventory = pcall(function() return stand.ContainerInventory end)
    if not okInventory or not inventory:IsValid() then return false end

    local outParams = {}
    local okEmpty = pcall(function()
        inventory:IsInventoryEmpty(outParams)
    end)

    if not okEmpty then return false end
    return not outParams.Empty
end

-- Sets stand mesh visibility and adjusts item Z position
local function SetStandHidden(stand, standType, hidden)
    local config = GetStandConfig(standType)

    local okMesh, mesh = pcall(function() return stand.FurnitureMesh end)
    if not okMesh or not mesh:IsValid() then return false end

    local okRoot, itemRoot = pcall(function() return stand.ItemRoot end)
    if not okRoot or not itemRoot:IsValid() then return false end

    pcall(function() mesh:SetHiddenInGame(hidden, false) end)

    local targetZ = hidden and ITEM_Z.hidden or config.visibleZ
    local okLoc, loc = pcall(function() return itemRoot.RelativeLocation end)
    if okLoc and loc then
        pcall(function()
            itemRoot:K2_SetRelativeLocation({X = loc.X, Y = loc.Y, Z = targetZ}, false, {}, false)
        end)
    end

    return true
end

-- Sets inventory temperature to frozen
local function ApplyRefrigeration(stand)
    local okInventory, inventory = pcall(function() return stand.ContainerInventory end)
    if not okInventory or not inventory:IsValid() then
        Log("ApplyRefrigeration: Failed to get inventory", "debug")
        return
    end

    local okTemp, currentTemp = pcall(function() return inventory.InternalTemperature end)
    if not okTemp then
        Log("ApplyRefrigeration: Failed to read temperature", "debug")
        return
    end

    if currentTemp ~= TEMPERATURE.veryCold then
        local okSet = pcall(function() inventory.InternalTemperature = TEMPERATURE.veryCold end)
        if okSet then
            Log(string.format("ApplyRefrigeration: Set temp %d -> %d", currentTemp, TEMPERATURE.veryCold), "debug")
        else
            Log("ApplyRefrigeration: Failed to set temperature", "debug")
        end
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
    local okMesh, mesh = pcall(function() return stand.FurnitureMesh end)
    if not okMesh or not mesh:IsValid() then return end

    local okHidden, isCurrentlyHidden = pcall(function() return mesh.bHiddenInGame end)
    if not okHidden then return end

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

local function OnSurvivalGameStateBeginPlay(Context)
    local gameState = Context:get()
    if not gameState:IsValid() then return end

    local okRole, localRole = pcall(function() return gameState:GetLocalRole() end)
    -- GetLocalRole: 0=None, 1=SimulatedProxy, 2=AutonomousProxy, 3=Authority
    isHost = okRole and (localRole == 3) or false
    Log(string.format("SurvivalGameState:ReceiveBeginPlay - GetLocalRole()=%s, isHost=%s", tostring(localRole), tostring(isHost)), "debug")
end

local function DeployedBeginPlay(Context)
    local stand = Context:get()
    if not stand:IsValid() then return end

    local standType = GetStandType(stand)
    if not standType then return end

    local okLoading, isLoading = pcall(function() return stand.IsCurrentlyLoadingFromSave end)
    local delay = (okLoading and isLoading) and 1000 or 0

    ExecuteWithDelay(delay, function()
        ExecuteInGameThread(function()
            if not stand:IsValid() then return end

            if REFRIGERATION_ENABLED then
                if isHost then
                    Log(string.format("DeployedBeginPlay: Attempting refrigeration for %s", standType), "debug")
                    ApplyRefrigeration(stand)
                else
                    Log("DeployedBeginPlay: Skipping refrigeration (not host)", "debug")
                end
            end

            local okColor, color = pcall(function() return stand.PaintedColor end)
            if okColor and color == COLORS.unpainted then
                UpdateStandVisibility(stand, standType, color)
            end
        end)
    end)
end

local function OnRepPaintedColor(Context)
    local stand = Context:get()
    if not stand:IsValid() then return end

    local standType = GetStandType(stand)
    if not standType then return end

    local okLoading, isLoading = pcall(function() return stand.IsCurrentlyLoadingFromSave end)
    local delay = (okLoading and isLoading) and 1000 or 250

    ExecuteWithDelay(delay, function()
        ExecuteInGameThread(function()
            if not stand:IsValid() then return end

            local okColor, color = pcall(function() return stand.PaintedColor end)
            if okColor then
                UpdateStandVisibility(stand, standType, color)
            end
        end)
    end)
end

--------------------------------------------------------------------------------
-- Hook Registration
--------------------------------------------------------------------------------

ExecuteWithDelay(2500, function()
    Log("Registering hooks...", "debug")

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

    -- Only register inventory hook if HideOnlyWithItem is enabled (otherwise not needed)
    if HIDE_ONLY_WITH_ITEM then
        local okOnRepInv, errOnRepInv = pcall(function()
            RegisterHook("/Game/Blueprints/Characters/Abiotic_InventoryComponent.Abiotic_InventoryComponent_C:OnRep_CurrentInventory", function(Context)
                local inventory = Context:get()
                if not inventory:IsValid() then return end

                local okOwner, owner = pcall(function() return inventory:GetOwner() end)
                if not okOwner or not owner:IsValid() then return end

                local standType = GetStandType(owner)
                if not standType then return end

                local okColor, color = pcall(function() return owner.PaintedColor end)
                if okColor then
                    Log(string.format("OnRep_CurrentInventory: %s color=%d", standType, color), "debug")
                    UpdateStandVisibility(owner, standType, color)
                end
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

    local okGameState, errGameState = pcall(function()
        RegisterHook("/Game/Blueprints/Meta/Abiotic_Survival_GameState.Abiotic_Survival_GameState_C:ReceiveBeginPlay", OnSurvivalGameStateBeginPlay)
    end)
    if not okGameState then
        Log("Failed to register SurvivalGameState hook: " .. tostring(errGameState), "error")
    else
        Log("SurvivalGameState hook registered", "debug")
    end

    Log("All hooks registered", "debug")
end)

Log("Mod loaded", "debug")
