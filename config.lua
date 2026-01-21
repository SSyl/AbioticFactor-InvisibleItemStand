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

    -- Keep empty stands visible until an item is placed
    -- When true: Empty target-colored stands remain visible until you place an item
    -- When false: Target-colored stands are always hidden (even when empty)
    -- Note: Can cause performance drop with a large number of stands in the world
    -- Default: false
    AlwaysShowEmptyItemStands = false,

    -- Disable decay for items on stands (HOST-ONLY)
    -- Protects all items on stands from decay. Great for food displays.
    -- Note: Only the host's setting matters. Clients benefit from it when the
    --       host has it enabled, but changing this setting as a client has no effect.
    -- Default: false
    DisableDecayInItemStands = false,

    -- Advanced: Enable debug logging (useful for troubleshooting)
    -- Leave this as false unless you're experiencing issues
    -- When enabled, prints detailed information to UE4SS.log
    Debug = false
}
