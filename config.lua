-- Invisible Item Stand Configuration
-- Choose which paint color makes item stands invisible
-- Works with both Item Stands and wall-mounted item stands

return {
    -- Paint color that triggers invisibility for table-top item stands
    -- When painted this color, the stand will become invisible and the item will be lowered
    --
    -- Available colors (case-insensitive):
    --   white, blue, red, green, orange, purple, yellow, black,
    --   cyan, lime, pink, brown, unpainted, glitch
    --   DISABLED - disables invisibility for standard Item Stands (never invisible)
    --
    -- Note: Setting this to "unpainted" will make unpainted stands invisible.
    --       You'll only see the stand after painting it with any color.
    --
    -- Default: "brown" (closest to the item stand's natural wood color)
    InvisibleColorItemStand = "brown",

    -- Paint color that triggers invisibility for wall-mounted item stands
    -- Set to "DISABLED" if you don't want wall mounts to ever be invisible
    -- Default: "brown"
    InvisibleColorWallMount = "brown",

    -- Advanced: Enable debug logging (useful for troubleshooting)
    -- Leave this as false unless you're experiencing issues
    -- When enabled, prints detailed information to UE4SS.log
    Debug = false
}
