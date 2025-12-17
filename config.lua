-- Invisible Item Stand Configuration
-- Choose which paint color makes item stands invisible
-- Works with both Item Stands and wall-mounted item stands

return {
    -- Paint color that triggers invisibility for Item Stands
    -- When painted this color, the stand will become invisible and the item will be lowered
    --
    -- Available colors (case-insensitive):
    --   white, blue, red, green, orange, purple, yellow, black,
    --   cyan, lime, pink, brown, unpainted, glitch
    --   DISABLED - Item Stands will always be visible, regardless of paint color
    --
    -- Note: Setting this to "unpainted" will make unpainted stands invisible.
    --       You'll only see the stand after painting it with any color.
    --
    -- Default: "brown" (closest to the item stand's natural wood color)
    InvisibleColorItemStand = "brown",

    -- Paint color that triggers invisibility for Wall-Mounted Item Stands
    -- Set to "DISABLED" to keep wall-mounted stands always visible, regardless of paint color
    -- Default: "brown"
    InvisibleColorWallMount = "brown",

    -- Advanced: Enable debug logging (useful for troubleshooting)
    -- Leave this as false unless you're experiencing issues
    -- When enabled, prints detailed information to UE4SS.log
    Debug = false
}
