-- Invisible Item Stand Configuration
-- Choose which paint color makes item stands invisible
-- Works with both Item Stands and wall-mounted item stands

return {
    -- Which paint color makes Item Stands invisible
    -- When you paint the stand this color, it will disappear and lower the item to the ground
    --
    -- Choose from:
    --   white, blue, red, green, orange, purple, yellow, black,
    --   cyan, lime, pink, brown, unpainted, glitch
    --
    -- Special option:
    --   DISABLED - stands will never turn invisible (keeps default behavior)
    --
    -- Note: If you choose "unpainted", then unpainted stands will be invisible.
    --       The stand will only appear after you paint it.
    --
    -- Default: "brown"
    InvisibleColorItemStand = "brown",

    -- Which paint color makes Wall-Mounted Item Stands invisible
    -- Same options as above
    -- Default: "brown"
    InvisibleColorWallMount = "brown",

    -- Advanced: Enable debug logging (useful for troubleshooting)
    -- Leave this as false unless you're experiencing issues
    -- When enabled, prints detailed information to UE4SS.log
    Debug = false
}
