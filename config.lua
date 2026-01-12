-- Invisible Item Stand Configuration
-- Choose which paint color makes item stands invisible (only when items are displayed)
-- Works with both Item Stands and wall-mounted item stands

return {
    -- Which paint color makes Item Stands invisible
    -- When you paint the stand this color AND place an item on it, the stand will disappear
    -- and lower the item to the ground. The stand reappears when you remove the item.
    --
    -- Choose from:
    --   white, blue, red, green, orange, purple, yellow, black,
    --   cyan, lime, pink, brown, unpainted, glitch
    --
    -- Special option:
    --   DISABLED - stands will never turn invisible (keeps default behavior)
    --
    -- Note: If you choose "unpainted", then unpainted stands with items will be invisible.
    --       The stand will appear when empty or when painted any other color.
    --
    -- Default: "brown"
    InvisibleColorItemStand = "brown",

    -- Which paint color makes Wall-Mounted Item Stands invisible (only when items are displayed)
    -- Same options as above
    -- Default: "brown"
    InvisibleColorWallMount = "brown",

    -- Item Refrigeration (prevents food decay)
    -- Controls whether items on stands preserves food indefinitely (good for food displays)
    --
    -- Options:
    --   0 or "disabled" - No refrigeration (default game behavior)
    --   1 or "all"      - Refrigerate ALL item stands regardless of color or visibility
    --   2 or "invisible" - Only refrigerate invisible item stands (target color + has item)
    --
    -- Default: 0 (disabled)
    RefrigerationMode = 0,

    -- Advanced: Enable debug logging (useful for troubleshooting)
    -- Leave this as false unless you're experiencing issues
    -- When enabled, prints detailed information to UE4SS.log
    Debug = false
}
