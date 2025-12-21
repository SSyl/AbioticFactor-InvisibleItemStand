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

local function ProcessStand(itemStand, className, paintedColor)
    if not itemStand or not itemStand:IsValid() then return end

    -- Get className if not provided
    className = className or itemStand:GetClass():GetFName():ToString()

    -- Get paintedColor if not provided
    if not paintedColor then
        local ok, color = pcall(function()
            return itemStand.PaintedColor
        end)
        if not ok then return end
        paintedColor = color
    end

    -- Determine stand type and target configuration
    local isWallMount = (className == "Deployed_ItemStand_WallMount_C")
    local targetColor = isWallMount and TARGET_COLOR_WALLMOUNT or TARGET_COLOR_ITEMSTAND
    local visibleZ = isWallMount and VISIBLE_ITEM_Z_WALLMOUNT or VISIBLE_ITEM_Z_ITEMSTAND

    -- Skip if this stand type is disabled
    if targetColor == COLORS.disabled then return end

    -- Get components
    local ok, furnitureMesh = pcall(function() return itemStand.FurnitureMesh end)
    local ok2, itemRoot = pcall(function() return itemStand.ItemRoot end)

    if not (ok and furnitureMesh:IsValid()) then return end
    if not (ok2 and itemRoot:IsValid()) then return end

    -- Determine desired state
    local shouldHide = (paintedColor == targetColor)
    local desiredZ = shouldHide and HIDDEN_ITEM_Z or visibleZ

    -- Check if already in correct state
    local ok3, isHidden = pcall(function() return furnitureMesh.bHiddenInGame end)
    if not ok3 or isHidden == shouldHide then return end

    -- Apply changes
    Log(shouldHide and "Hiding stand" or "Showing stand", "debug")

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
    -- Only process unpainted stands (OnRep handles painted stands)
    -- Handles: world load unpainted stands and new unpainted placements
    local ok1, err1 = pcall(function()
        RegisterHook("/Game/Blueprints/DeployedObjects/AbioticDeployed_ParentBP.AbioticDeployed_ParentBP_C:ReceiveBeginPlay", function(Context)
            local deployedObj = Context:get()
            if not deployedObj or not deployedObj:IsValid() then return end

            local objClass = deployedObj:GetClass():GetFName():ToString()
            if objClass == "Deployed_ItemStand_ParentBP_C" or objClass == "Deployed_ItemStand_WallMount_C" then
                -- Only process unpainted stands (color 12) - OnRep will handle painted stands
                local ok, color = pcall(function() return deployedObj.PaintedColor end)
                if ok and color == 12 then
                    ProcessStand(deployedObj, objClass, color)
                end
            end
        end)
    end)

    if not ok1 then
        Log("Failed to register ReceiveBeginPlay hook: " .. tostring(err1), "error")
    else
        Log("ReceiveBeginPlay hook registered", "debug")
    end

    -- Hook OnRep_PaintedColor on parent class
    -- Handles: live paint/unpaint changes and world load painted stands
    local ok2, err2 = pcall(function()
        RegisterHook("/Game/Blueprints/DeployedObjects/AbioticDeployed_ParentBP.AbioticDeployed_ParentBP_C:OnRep_PaintedColor", function(Context)
            local deployedObj = Context:get()
            if not deployedObj or not deployedObj:IsValid() then return end

            local objClass = deployedObj:GetClass():GetFName():ToString()
            if objClass == "Deployed_ItemStand_ParentBP_C" or objClass == "Deployed_ItemStand_WallMount_C" then
                -- 250ms delay to allow components to fully replicate during level streaming
                ExecuteWithDelay(250, function()
                    ExecuteInGameThread(function()
                        if not deployedObj or not deployedObj:IsValid() then return end

                        local ok, color = pcall(function() return deployedObj.PaintedColor end)
                        if ok then
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
end)

Log("Mod loaded", "debug")
