print("=== [Invisible Item Stand] MOD LOADING ===\n")  -- Pre-config load message

local Config = require("../config")
local DEBUG = Config.Debug or false

local function Log(message, level)
    level = level or "info"

    -- Filter debug messages when DEBUG is disabled
    if level == "debug" and not DEBUG then
        return
    end

    -- Add prefix for errors and warnings
    local prefix = ""
    if level == "error" then
        prefix = "ERROR: "
    elseif level == "warning" then
        prefix = "WARNING: "
    end

    print("[Invisible Item Stand] " .. prefix .. tostring(message) .. "\n")
end

local HIDDEN_ITEM_Z = 0  -- Z position when stand is invisible (item at ground level)
local VISIBLE_ITEM_Z_ITEMSTAND = 11.134993  -- Z position for visible item stand
local VISIBLE_ITEM_Z_WALLMOUNT = 5.5  -- Z position for visible wall mounted item stand

-- Color mapping: string name to enum value
local COLORS = {
    white = 0, blue = 1, red = 2, green = 3,
    orange = 4, purple = 5, yellow = 6, black = 7,
    cyan = 8, lime = 9, pink = 10, brown = 11,
    none = 12, unpainted = 12, glitch = 13,  -- "unpainted" is an alias for "none"
    disabled = -1  -- Special value to disable invisibility for a stand type
}

-- Normalize color name: trim whitespace and lowercase
local function NormalizeColorName(name)
    if not name then return nil end
    name = name:match("^%s*(.-)%s*$")  -- Trim whitespace
    return name:lower()  -- Lowercase
end

local configColorItemStand = NormalizeColorName(Config.InvisibleColorItemStand)
local configColorWallMount = NormalizeColorName(Config.InvisibleColorWallMount)

local TARGET_COLOR_ITEMSTAND = COLORS[configColorItemStand] or COLORS.brown
local TARGET_COLOR_WALLMOUNT = COLORS[configColorWallMount] or COLORS.brown

if not TARGET_COLOR_ITEMSTAND then
    Log("Invalid InvisibleColorItemStand in config. Using Brown as default.", "error")
    TARGET_COLOR_ITEMSTAND = COLORS.brown
end

if not TARGET_COLOR_WALLMOUNT then
    Log("Invalid InvisibleColorWallMount in config. Using Brown as default.", "error")
    TARGET_COLOR_WALLMOUNT = COLORS.brown
end

local function ProcessStand(itemStand)
    if not itemStand or not itemStand:IsValid() then return end

    local ok, paintedColor = pcall(function()
        return itemStand.PaintedColor
    end)

    if not ok then return end

    -- Determine stand type for correct Z positioning and target color
    local className = itemStand:GetClass():GetFName():ToString()
    local isWallMount = (className == "Deployed_ItemStand_WallMount_C")
    local visibleZ = isWallMount and VISIBLE_ITEM_Z_WALLMOUNT or VISIBLE_ITEM_Z_ITEMSTAND
    local targetColor = isWallMount and TARGET_COLOR_WALLMOUNT or TARGET_COLOR_ITEMSTAND

    -- Skip processing if this stand type is disabled
    if targetColor == COLORS.disabled then
        return
    end

    ExecuteInGameThread(function()
        if not itemStand or not itemStand:IsValid() then return end

        local ok, furnitureMesh = pcall(function()
            return itemStand.FurnitureMesh
        end)

        local ok2, itemRoot = pcall(function()
            return itemStand.ItemRoot
        end)

        if not (ok and furnitureMesh and furnitureMesh:IsValid()) then return end
        if not (ok2 and itemRoot and itemRoot:IsValid()) then return end

        local shouldHide
        local desiredZ

        if paintedColor == targetColor then
            shouldHide = true
            desiredZ = HIDDEN_ITEM_Z
        else
            shouldHide = false
            desiredZ = visibleZ
        end

        -- Check if already in desired state to skip redundant work
        -- If visibility is correct, height is guaranteed correct (we set them together)
        local ok3, isHidden = pcall(function()
            return furnitureMesh.bHiddenInGame
        end)

        if not ok3 then return end

        if isHidden == shouldHide then
            return
        end

        if shouldHide then
            Log("Hiding stand (color: " .. paintedColor .. ")", "debug")
        else
            Log("Showing stand (color: " .. paintedColor .. ")", "debug")
        end

        pcall(function()
            furnitureMesh:SetHiddenInGame(shouldHide, false)
        end)

        pcall(function()
            local loc = itemRoot.RelativeLocation
            itemRoot:K2_SetRelativeLocation({X = loc.X, Y = loc.Y, Z = desiredZ}, false, {}, false)
        end)
    end)
end

-- OnRep_PaintedColor fires for both local and remote paint changes.
-- Hooked on parent class (AbioticDeployed_ParentBP_C) where the replicated property lives.
-- Fires during world load (property initialization), new spawns, and live painting.
-- We filter for item stands in the callback since the hook fires for all paintable objects.
ExecuteWithDelay(2500, function()
    Log("Registering paint change hook...", "debug")

    local ok, err = pcall(function()
        RegisterHook("/Game/Blueprints/DeployedObjects/AbioticDeployed_ParentBP.AbioticDeployed_ParentBP_C:OnRep_PaintedColor", function(Context)
            local paintedObject = Context:get()
            if not paintedObject or not paintedObject:IsValid() then return end

            -- Filter: only process item stands (both regular and wall mounted), not all paintable objects
            local className = paintedObject:GetClass():GetFName():ToString()
            if className ~= "Deployed_ItemStand_ParentBP_C" and className ~= "Deployed_ItemStand_WallMount_C" then
                return
            end

            ProcessStand(paintedObject)
        end)
    end)

    if not ok then
        Log("Registering OnRep_PaintedColor: " .. tostring(err), "error")
    end
end)