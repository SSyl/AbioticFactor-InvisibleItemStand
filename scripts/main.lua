print("=== [Invisible Item Stand] MOD LOADING ===\n")

local Config = require("../config")
local DEBUG = Config.Debug or false

local function DebugLog(message)
    if DEBUG then
        print("[Invisible Item Stand] " .. tostring(message) .. "\n")
    end
end

local ITEM_Z_HEIGHT = 0
local ORIGINAL_Z_HEIGHT = 11.134993

-- Map color names to enum values
local COLOR_VALUES = {
    White = 0, Blue = 1, Red = 2, Green = 3,
    Orange = 4, Purple = 5, Yellow = 6, Black = 7,
    Cyan = 8, Lime = 9, Pink = 10, Brown = 11,
    None = 12, Glitch = 13
}

local COLOR_NAMES = {
    [0] = "White", [1] = "Blue", [2] = "Red", [3] = "Green",
    [4] = "Orange", [5] = "Purple", [6] = "Yellow", [7] = "Black",
    [8] = "Cyan", [9] = "Lime", [10] = "Pink", [11] = "Brown",
    [12] = "None", [13] = "Glitch"
}

-- Get target color from config
local TARGET_COLOR = COLOR_VALUES[Config.InvisibleColor] or COLOR_VALUES.Brown
if not TARGET_COLOR then
    print("[Invisible Item Stand] ERROR: Invalid InvisibleColor in config. Using Brown as default.\n")
    TARGET_COLOR = COLOR_VALUES.Brown
end

local function GetColorName(colorValue)
    return COLOR_NAMES[colorValue] or "Unknown(" .. tostring(colorValue) .. ")"
end

local function ProcessStand(itemStand)
    if not itemStand or not itemStand:IsValid() then return end

    local ok, paintedColor = pcall(function()
        return itemStand.PaintedColor
    end)

    if not ok then return end

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
        local targetZ

        if paintedColor == TARGET_COLOR then
            shouldHide = true
            targetZ = ITEM_Z_HEIGHT
        else
            shouldHide = false
            targetZ = ORIGINAL_Z_HEIGHT
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
            itemRoot:K2_SetRelativeLocation({X = loc.X, Y = loc.Y, Z = targetZ}, false, {}, false)
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

            -- Filter: only process item stands, not all paintable objects
            local className = paintedObject:GetClass():GetFName():ToString()
            if className ~= "Deployed_ItemStand_ParentBP_C" then return end

            ProcessStand(paintedObject)
        end)
    end)

    if not ok then
        DebugLog("ERROR registering OnRep_PaintedColor: " .. tostring(err))
    end
end)

print("[Invisible Item Stand] Mod loaded - Invisible color: " .. GetColorName(TARGET_COLOR) .. "\n")
