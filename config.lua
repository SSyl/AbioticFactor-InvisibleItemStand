-- Invisible Item Stand Configuration
-- Choose which paint color makes item stands invisible
-- Works with both table-top and wall-mounted item stands

return {
    -- Paint color that triggers invisibility for table-top item stands
    -- When painted this color, the stand will become invisible and the item will be lowered
    --
    -- Available colors:
    --   "White", "Blue", "Red", "Green", "Orange", "Purple", "Yellow", "Black",
    --   "Cyan", "Lime", "Pink", "Brown", "None", "Glitch"
    --
    -- Note: Setting this to "None" will make unpainted stands invisible.
    --       You'll only see the stand after painting it with any color.
    --
    -- Default: "Brown" (closest to the item stand's natural wood color)
    InvisibleColorItemStand = "Brown",

    -- Paint color that triggers invisibility for wall-mounted item stands
    -- Default: "Brown"
    InvisibleColorWallMount = "Brown",

    -- Advanced: Enable debug logging (useful for troubleshooting)
    -- Leave this as false unless you're experiencing issues
    -- When enabled, prints detailed information to UE4SS.log
    Debug = false
}
