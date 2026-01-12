print("=== [Invisible Item Stand] MOD LOADING ===\n")

local Config = require("../config")
local DEBUG = Config.Debug or false

local function Log(message, level)
    level = level or "info"

    if level == "debug" and not DEBUG then
        return
    end

    local prefix = ""
    if level == "error" then
        prefix = "ERROR: "
    elseif level == "warning" then
        prefix = "WARNING: "
    end

    print("[Invisible Item Stand] " .. prefix .. tostring(message) .. "\n")
end

-- Z-axis positions for item placement
local HIDDEN_ITEM_Z = 0
local VISIBLE_ITEM_Z_ITEMSTAND = 11.134993
local VISIBLE_ITEM_Z_WALLMOUNT = 5.5

-- Paint color enum values
local COLORS = {
    white = 0, blue = 1, red = 2, green = 3,
    orange = 4, purple = 5, yellow = 6, black = 7,
    cyan = 8, lime = 9, pink = 10, brown = 11,
    none = 12, unpainted = 12, glitch = 13,
    disabled = -1
}

-- Temperature enum values (E_InternalTemperature)
local TEMPERATURE = {
    hot = 0,         -- Increases decay
    regular = 1,     -- Normal decay rate
    cold = 2,        -- Refrigerated (slow decay)
    veryCold = 3     -- Frozen (stops decay)
}

-- Refrigeration mode values
local REFRIG_MODE = {
    disabled = 0,
    all = 1,
    invisible = 2
}

-- Item stand class paths for IsA() checks
local CLASS_ITEMSTAND = "/Game/Blueprints/DeployedObjects/Furniture/Deployed_ItemStand_ParentBP.Deployed_ItemStand_ParentBP_C"
local CLASS_WALLMOUNT = "/Game/Blueprints/DeployedObjects/Furniture/Deployed_ItemStand_WallMount.Deployed_ItemStand_WallMount_C"

local function IsItemStand(obj)
    return obj:IsA(CLASS_ITEMSTAND) or obj:IsA(CLASS_WALLMOUNT)
end

local function NormalizeColorName(name)
    if not name or type(name) ~= "string" then return nil end
    name = name:match("^%s*(.-)%s*$")
    return name:lower()
end

-- Parse and validate config colors
local TARGET_COLOR_ITEMSTAND = COLORS[NormalizeColorName(Config.InvisibleColorItemStand)]
local TARGET_COLOR_WALLMOUNT = COLORS[NormalizeColorName(Config.InvisibleColorWallMount)]

if not TARGET_COLOR_ITEMSTAND then
    Log("Invalid InvisibleColorItemStand in config. Using brown as default.", "error")
    TARGET_COLOR_ITEMSTAND = COLORS.brown
end

if not TARGET_COLOR_WALLMOUNT then
    Log("Invalid InvisibleColorWallMount in config. Using brown as default.", "error")
    TARGET_COLOR_WALLMOUNT = COLORS.brown
end

-- Parse and validate refrigeration mode
local REFRIGERATION_MODE = Config.RefrigerationMode
if type(REFRIGERATION_MODE) == "string" then
    local normalized = REFRIGERATION_MODE:lower():match("^%s*(.-)%s*$")
    if normalized == "disabled" then
        REFRIGERATION_MODE = REFRIG_MODE.disabled
    elseif normalized == "all" then
        REFRIGERATION_MODE = REFRIG_MODE.all
    elseif normalized == "invisible" then
        REFRIGERATION_MODE = REFRIG_MODE.invisible
    else
        Log("Invalid RefrigerationMode in config. Using disabled as default.", "error")
        REFRIGERATION_MODE = REFRIG_MODE.disabled
    end
elseif type(REFRIGERATION_MODE) == "number" then
    if REFRIGERATION_MODE < 0 or REFRIGERATION_MODE > 2 then
        Log("Invalid RefrigerationMode value in config. Must be 0-2. Using disabled as default.", "error")
        REFRIGERATION_MODE = REFRIG_MODE.disabled
    end
else
    Log("Invalid RefrigerationMode type in config. Using disabled as default.", "error")
    REFRIGERATION_MODE = REFRIG_MODE.disabled
end

local function HasItemDisplayed(inventory, className)
    local outParams = {}
    local okEmpty = pcall(function()
        inventory:IsInventoryEmpty(outParams)
    end)

    if not okEmpty then
        Log(string.format("[%s] Could not call IsInventoryEmpty", className), "debug")
        return false
    end

    local isEmpty = outParams.Empty
    Log(string.format("[%s] IsInventoryEmpty returned: %s", className, tostring(isEmpty)), "debug")
    return not isEmpty
end

local function GetDesiredTemperature(isInvisible, hasItem)
    -- Mode 0: Disabled - always regular temperature
    if REFRIGERATION_MODE == REFRIG_MODE.disabled then
        return TEMPERATURE.regular
    end

    -- Mode 1: All stands - always frozen if it's an item stand
    if REFRIGERATION_MODE == REFRIG_MODE.all then
        return TEMPERATURE.veryCold
    end

    -- Mode 2: Invisible only - frozen only when invisible (target color + has item)
    if REFRIGERATION_MODE == REFRIG_MODE.invisible then
        if isInvisible and hasItem then
            return TEMPERATURE.veryCold
        else
            return TEMPERATURE.regular
        end
    end

    -- Fallback to regular
    return TEMPERATURE.regular
end

local function SetRefrigeration(inventory, className, isInvisible, hasItem)
    if REFRIGERATION_MODE == REFRIG_MODE.disabled then return end

    local desiredTemp = GetDesiredTemperature(isInvisible, hasItem)

    local okTemp, currentTemp = pcall(function() return inventory.InternalTemperature end)
    if not okTemp then
        Log(string.format("[%s] Could not read InternalTemperature", className), "debug")
        return
    end

    if currentTemp ~= desiredTemp then
        local okSet = pcall(function()
            inventory.InternalTemperature = desiredTemp
        end)
        if okSet then
            Log(string.format("[%s] Set temperature %d -> %d (invisible=%s, hasItem=%s)",
                className, currentTemp, desiredTemp, tostring(isInvisible), tostring(hasItem)), "debug")
        else
            Log(string.format("[%s] Failed to set InternalTemperature", className), "debug")
        end
    end
end

local function ProcessStand(itemStand, className, paintedColor, inventoryParam)
    if not itemStand:IsValid() then return end

    local isWallMount = itemStand:IsA(CLASS_WALLMOUNT)
    className = className or (isWallMount and "WallMount" or "ItemStand")

    if not paintedColor then
        local ok, color = pcall(function()
            return itemStand.PaintedColor
        end)
        if not ok then return end
        paintedColor = color
    end

    local targetColor = isWallMount and TARGET_COLOR_WALLMOUNT or TARGET_COLOR_ITEMSTAND
    local visibleZ = isWallMount and VISIBLE_ITEM_Z_WALLMOUNT or VISIBLE_ITEM_Z_ITEMSTAND

    if targetColor == COLORS.disabled then return end

    -- Get components once upfront
    local okFurniture, furnitureMesh = pcall(function() return itemStand.FurnitureMesh end)
    local okItemRoot, itemRoot = pcall(function() return itemStand.ItemRoot end)

    if not (okFurniture and furnitureMesh:IsValid()) then return end
    if not (okItemRoot and itemRoot:IsValid()) then return end

    -- Use provided inventory if valid, otherwise fetch it
    local inventory = inventoryParam
    local hasValidInventory = inventory and inventory:IsValid()
    if not hasValidInventory then
        local okInventory
        okInventory, inventory = pcall(function() return itemStand.ContainerInventory end)
        hasValidInventory = okInventory and inventory:IsValid()
    end

    local hasItem = hasValidInventory and HasItemDisplayed(inventory, className) or false

    if paintedColor ~= targetColor then
        local okHidden, isHidden = pcall(function() return furnitureMesh.bHiddenInGame end)
        if okHidden and isHidden then
            Log(string.format("[%s] Showing stand (not target color)", className), "debug")
            pcall(function()
                furnitureMesh:SetHiddenInGame(false, false)
            end)

            local locOk, loc = pcall(function()
                return itemRoot.RelativeLocation
            end)

            if locOk and loc then
                pcall(function()
                    itemRoot:K2_SetRelativeLocation({X = loc.X, Y = loc.Y, Z = visibleZ}, false, {}, false)
                end)
            end
        end

        -- Set temperature for non-target color stands (visible stand, but mode=all still applies)
        if hasValidInventory then
            SetRefrigeration(inventory, className, false, hasItem)
        end
        return
    end

    local shouldHide = hasItem
    local desiredZ = shouldHide and HIDDEN_ITEM_Z or visibleZ

    -- Set refrigeration before visibility check (must run even if visibility unchanged)
    if hasValidInventory then
        local isInvisible = shouldHide  -- For target color stands: invisible = has item
        SetRefrigeration(inventory, className, isInvisible, hasItem)
    end

    local okHidden, isHidden = pcall(function() return furnitureMesh.bHiddenInGame end)
    if not okHidden or isHidden == shouldHide then return end

    Log(string.format("[%s] %s", className, shouldHide and "Hiding stand (has item)" or "Showing stand (no item)"), "debug")

    pcall(function()
        furnitureMesh:SetHiddenInGame(shouldHide, false)
    end)

    local locOk, loc = pcall(function()
        return itemRoot.RelativeLocation
    end)

    if locOk and loc then
        pcall(function()
            itemRoot:K2_SetRelativeLocation({X = loc.X, Y = loc.Y, Z = desiredZ}, false, {}, false)
        end)
    end
end

-- Register hooks after Blueprint classes load
ExecuteWithDelay(2500, function()
    Log("Registering hooks...", "debug")

    -- Hook ReceiveBeginPlay on parent class to catch all deployed objects
    -- Only register if either stand type has "unpainted" as target color
    -- Handles: world load unpainted stands and new unpainted placements
    if TARGET_COLOR_ITEMSTAND == COLORS.unpainted or TARGET_COLOR_WALLMOUNT == COLORS.unpainted then
        local ok1, err1 = pcall(function()
            RegisterHook("/Game/Blueprints/DeployedObjects/AbioticDeployed_ParentBP.AbioticDeployed_ParentBP_C:ReceiveBeginPlay", function(Context)
                local deployedObj = Context:get()
                if not deployedObj:IsValid() then return end
                if not IsItemStand(deployedObj) then return end

                local ok, color = pcall(function() return deployedObj.PaintedColor end)
                if ok and color == 12 then
                    local okLoading, isLoading = pcall(function() return deployedObj.IsCurrentlyLoadingFromSave end)

                    if okLoading and isLoading then
                        Log("[ItemStand] IsCurrentlyLoadingFromSave=true, using 1000ms delay", "debug")
                        ExecuteWithDelay(1000, function()
                            ExecuteInGameThread(function()
                                if not deployedObj:IsValid() then return end
                                ProcessStand(deployedObj, nil, color)
                            end)
                        end)
                    else
                        ProcessStand(deployedObj, nil, color)
                    end
                end
            end)
        end)

        if not ok1 then
            Log("Failed to register ReceiveBeginPlay hook: " .. tostring(err1), "error")
        else
            Log("ReceiveBeginPlay hook registered", "debug")
        end
    else
        Log("ReceiveBeginPlay hook skipped (neither stand type uses 'unpainted')", "debug")
    end

    -- Hook OnRep_PaintedColor on parent class
    -- Handles: live paint/unpaint changes and world load painted stands
    local ok2, err2 = pcall(function()
        RegisterHook("/Game/Blueprints/DeployedObjects/AbioticDeployed_ParentBP.AbioticDeployed_ParentBP_C:OnRep_PaintedColor", function(Context)
            local deployedObj = Context:get()
            if not deployedObj:IsValid() then return end
            if not IsItemStand(deployedObj) then return end

            local okLoading, isLoading = pcall(function() return deployedObj.IsCurrentlyLoadingFromSave end)
            local delay = (okLoading and isLoading) and 1000 or 250

            if okLoading and isLoading then
                Log(string.format("[ItemStand] IsCurrentlyLoadingFromSave=true, using %dms delay", delay), "debug")
            end

            ExecuteWithDelay(delay, function()
                ExecuteInGameThread(function()
                    if not deployedObj:IsValid() then return end

                    local ok, color = pcall(function() return deployedObj.PaintedColor end)
                    if ok then
                        Log(string.format("[ItemStand] OnRep reading PaintedColor=%d", color), "debug")
                        ProcessStand(deployedObj, nil, color)
                    end
                end)
            end)
        end)
    end)

    if not ok2 then
        Log("Failed to register OnRep hook: " .. tostring(err2), "error")
    else
        Log("OnRep hook registered", "debug")
    end

    -- Hook OnContainerInventoryUpdated on parent class
    -- Handles: live item add/remove from stand
    local ok3, err3 = pcall(function()
        RegisterHook("/Game/Blueprints/DeployedObjects/Furniture/Deployed_Container_ParentBP.Deployed_Container_ParentBP_C:OnContainerInventoryUpdated", function(Context, InventoryParam)
            local deployedObj = Context:get()
            if not deployedObj:IsValid() then return end
            if not IsItemStand(deployedObj) then return end

            local ok, color = pcall(function() return deployedObj.PaintedColor end)
            if ok then
                -- Pass the inventory from hook params to avoid redundant lookup
                local inventory = InventoryParam:get()
                ProcessStand(deployedObj, nil, color, inventory)
            end
        end)
    end)

    if not ok3 then
        Log("Failed to register OnContainerInventoryUpdated hook: " .. tostring(err3), "error")
    else
        Log("OnContainerInventoryUpdated hook registered", "debug")
    end
end)

Log("Mod loaded", "debug")
