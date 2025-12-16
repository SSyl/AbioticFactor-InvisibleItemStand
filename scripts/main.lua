print("=== [Invisible Item Stand] MOD LOADING ===\n")

local Config = require("../config")
local DEBUG = Config.Debug or false

local function DebugLog(message)
    if DEBUG then
        print("[Invisible Item Stand] " .. tostring(message) .. "\n")
    end
end

local HIDDEN_ITEM_Z = 0  -- Z position when stand is invisible (item at ground level)
local VISIBLE_ITEM_Z_ITEMSTAND = 11.134993  -- Z position for visible item stand
local VISIBLE_ITEM_Z_WALLMOUNT = 5.5  -- Z position for visible wall mounted item stand

-- Color mapping: string name to enum value
local COLORS = {
    White = 0, Blue = 1, Red = 2, Green = 3,
    Orange = 4, Purple = 5, Yellow = 6, Black = 7,
    Cyan = 8, Lime = 9, Pink = 10, Brown = 11,
    None = 12, Glitch = 13
}

-- Add reverse mapping: enum value to string name
for name, value in pairs(COLORS) do
    COLORS[value] = name
end

local TARGET_COLOR_ITEMSTAND = COLORS[Config.InvisibleColorItemStand] or COLORS.Brown
local TARGET_COLOR_WALLMOUNT = COLORS[Config.InvisibleColorWallMount] or COLORS.Brown

if not TARGET_COLOR_ITEMSTAND then
    print("[Invisible Item Stand] ERROR: Invalid InvisibleColorItemStand in config. Using Brown as default.\n")
    TARGET_COLOR_ITEMSTAND = COLORS.Brown
end

if not TARGET_COLOR_WALLMOUNT then
    print("[Invisible Item Stand] ERROR: Invalid InvisibleColorWallMount in config. Using Brown as default.\n")
    TARGET_COLOR_WALLMOUNT = COLORS.Brown
end

local function GetColorName(colorValue)
    return COLORS[colorValue] or "Unknown(" .. tostring(colorValue) .. ")"
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
            DebugLog("Hiding stand (color: " .. GetColorName(paintedColor) .. ")")
        else
            DebugLog("Showing stand (color: " .. GetColorName(paintedColor) .. ")")
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
    DebugLog("Registering paint change hook...")

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
        DebugLog("ERROR registering OnRep_PaintedColor: " .. tostring(err))
    end
end)

print("[Invisible Item Stand] Mod loaded - ItemStand: " .. GetColorName(TARGET_COLOR_ITEMSTAND) .. ", WallMount: " .. GetColorName(TARGET_COLOR_WALLMOUNT) .. "\n")
