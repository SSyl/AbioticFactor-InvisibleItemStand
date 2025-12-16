-- Invisible Item Stand Configuration
-- Choose which paint color makes the item stand invisible

return {
    -- Paint color that triggers invisibility
    -- When an item stand is painted this color, the stand will become invisible and the item will be lowered
    --
    -- Available colors:
    --   "White", "Blue", "Red", "Green", "Orange", "Purple", "Yellow", "Black",
    --   "Cyan", "Lime", "Pink", "Brown", "None", "Glitch"
    --
    -- Note: Setting this to "None" will make unpainted item stands invisible.
    --       You'll only see the stand after painting it with any color.
    --
    -- Default: "Brown" (closest to the item stand's natural wood color)
    InvisibleColor = "Brown",

    -- Advanced: Enable debug logging (useful for troubleshooting)
    -- Leave this as false unless you're experiencing issues
    -- When enabled, prints detailed information to UE4SS.log
    Debug = false
}
