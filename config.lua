-- Invisible Item Stand Configuration
-- Choose which paint color makes item stands invisible
-- Works with both Item Stands and wall-mounted item stands

return {
    -- Which paint color makes Item Stands invisible
    -- When you paint the stand this color, the stand will disappear
    -- and lower items to the ground.
    --
    -- Choose from:
    --   white, blue, red, green, orange, purple, yellow, black,
    --   cyan, lime, pink, brown, unpainted, glitch
    --
    -- Special option:
    --   DISABLED - stands will never turn invisible (keeps default behavior)
    --
    -- Default: "brown"
    InvisibleColorItemStand = "brown",

    -- Which paint color makes Wall-Mounted Item Stands invisible
    -- Same options as above
    -- Default: "brown"
    InvisibleColorWallMount = "brown",

    -- Only hide stands when they have an item displayed
    -- When true: Empty target-colored stands remain visible until you place an item
    -- When false: Target-colored stands are always hidden (even when empty)
    -- Default: true
    HideOnlyWithItem = true,

    -- Item Refrigeration (HOST-ONLY - prevents food decay)
    -- Freezes all items on stands to prevent decay. Great for food displays.
    -- Note: Only works when you're hosting. Clients won't see the frozen icon,
    --       but the decay prevention is still active.
    -- Default: false
    Refrigeration = false,

    -- Advanced: Enable debug logging (useful for troubleshooting)
    -- Leave this as false unless you're experiencing issues
    -- When enabled, prints detailed information to UE4SS.log
    Debug = false
}
