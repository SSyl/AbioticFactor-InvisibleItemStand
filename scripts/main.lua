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

local function HasItemDisplayed(itemStand, className)
    local okInventory, inventory = pcall(function()
        return itemStand.ContainerInventory
    end)

    if not okInventory then
        Log(string.format("[%s] Could not access ContainerInventory - pcall failed: %s", className, tostring(inventory)), "debug")
        return false
    end

    if not inventory:IsValid() then
        Log(string.format("[%s] ContainerInventory is not valid", className), "debug")
        return false
    end

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

local function ProcessStand(itemStand, className, paintedColor)
    if not itemStand:IsValid() then return end

    className = className or itemStand:GetClass():GetFName():ToString()

    if not paintedColor then
        local ok, color = pcall(function()
            return itemStand.PaintedColor
        end)
        if not ok then return end
        paintedColor = color
    end

    local isWallMount = (className == "Deployed_ItemStand_WallMount_C")
    local targetColor = isWallMount and TARGET_COLOR_WALLMOUNT or TARGET_COLOR_ITEMSTAND
    local visibleZ = isWallMount and VISIBLE_ITEM_Z_WALLMOUNT or VISIBLE_ITEM_Z_ITEMSTAND

    if targetColor == COLORS.disabled then return end

    local ok, furnitureMesh = pcall(function() return itemStand.FurnitureMesh end)
    local ok2, itemRoot = pcall(function() return itemStand.ItemRoot end)

    if not (ok and furnitureMesh:IsValid()) then return end
    if not (ok2 and itemRoot:IsValid()) then return end

    if paintedColor ~= targetColor then
        local ok3, isHidden = pcall(function() return furnitureMesh.bHiddenInGame end)
        if ok3 and isHidden then
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
        return
    end

    local hasItem = HasItemDisplayed(itemStand, className)
    local shouldHide = hasItem
    local desiredZ = shouldHide and HIDDEN_ITEM_Z or visibleZ

    local ok3, isHidden = pcall(function() return furnitureMesh.bHiddenInGame end)
    if not ok3 or isHidden == shouldHide then return end

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

                local objClass = deployedObj:GetClass():GetFName():ToString()
                if objClass == "Deployed_ItemStand_ParentBP_C" or objClass == "Deployed_ItemStand_WallMount_C" then
                    local ok, color = pcall(function() return deployedObj.PaintedColor end)
                    if ok and color == 12 then
                        local okLoading, isLoading = pcall(function() return deployedObj.IsCurrentlyLoadingFromSave end)

                        if okLoading and isLoading then
                            Log(string.format("[%s] IsCurrentlyLoadingFromSave=true, using 1000ms delay", objClass), "debug")
                            ExecuteWithDelay(1000, function()
                                ExecuteInGameThread(function()
                                    if not deployedObj:IsValid() then return end
                                    ProcessStand(deployedObj, objClass, color)
                                end)
                            end)
                        else
                            ProcessStand(deployedObj, objClass, color)
                        end
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

            local objClass = deployedObj:GetClass():GetFName():ToString()
            if objClass == "Deployed_ItemStand_ParentBP_C" or objClass == "Deployed_ItemStand_WallMount_C" then
                local okLoading, isLoading = pcall(function() return deployedObj.IsCurrentlyLoadingFromSave end)
                local delay = (okLoading and isLoading) and 1000 or 250

                if okLoading and isLoading then
                    Log(string.format("[%s] IsCurrentlyLoadingFromSave=true, using %dms delay", objClass, delay), "debug")
                end

                ExecuteWithDelay(delay, function()
                    ExecuteInGameThread(function()
                        if not deployedObj:IsValid() then return end

                        local ok, color = pcall(function() return deployedObj.PaintedColor end)
                        if ok then
                            Log(string.format("[%s] OnRep reading PaintedColor=%d", objClass, color), "debug")
                            ProcessStand(deployedObj, objClass, color)
                        end
                    end)
                end)
            end
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
        RegisterHook("/Game/Blueprints/DeployedObjects/Furniture/Deployed_Container_ParentBP.Deployed_Container_ParentBP_C:OnContainerInventoryUpdated", function(Context, Inventory)
            local deployedObj = Context:get()
            if not deployedObj:IsValid() then return end

            local objClass = deployedObj:GetClass():GetFName():ToString()
            if objClass == "Deployed_ItemStand_ParentBP_C" or objClass == "Deployed_ItemStand_WallMount_C" then
                local ok, color = pcall(function() return deployedObj.PaintedColor end)
                if ok then
                    ProcessStand(deployedObj, objClass, color)
                end
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
