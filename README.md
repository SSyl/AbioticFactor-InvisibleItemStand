# Invisible Item Stand

UE4SS mod for Abiotic Factor that hides Item Stands when painted a specific color.

## What It Does

Painting an Item Stand or Wall-Mounted Item Stand a configured color (default: brown) makes the stand invisible and lowers the item to ground/wall level. Painting it any other color restores normal visibility.

## Installation

Requires [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS).

1. Extract to `AbioticFactor/Binaries/Win64/Mods/InvisibleItemStand/`
2. Launch the game

## Configuration

Edit `config.lua` to set which colors trigger invisibility.

**Available colors:**
`white`, `blue`, `red`, `green`, `orange`, `purple`, `yellow`, `black`, `cyan`, `lime`, `pink`, `brown`, `unpainted`, `glitch`

**Examples:**
```lua
-- Brown stands are invisible (default)
InvisibleColorItemStand = "brown"

-- Unpainted stands are invisible, visible after painting
InvisibleColorItemStand = "unpainted"

-- Different colors for each type
InvisibleColorItemStand = "brown"
InvisibleColorWallMount = "black"

-- Disable invisibility for wall-mounted stands
InvisibleColorWallMount = "DISABLED"
```

Enable `Debug = true` for detailed logging.

## How It Works

The mod hooks two Blueprint functions on the parent deployed object class:

- **ReceiveBeginPlay** - Processes stands when they spawn (world load, new placement)
  - Only processes unpainted stands (color value 12) to avoid redundancy with OnRep
- **OnRep_PaintedColor** - Processes stands when paint color changes
  - Handles painted stands on world load and all live paint changes

When a stand's color matches the configured trigger color:
- `FurnitureMesh.bHiddenInGame` is set to true
- `ItemRoot.RelativeLocation.Z` is set to 0 (ground level) or 5.5 (wall level)

When painted a different color, these values are restored.

## Technical Notes

- Hooks registered at module load with 2500ms delay for Blueprint class initialization
- Property access optimized by passing values to avoid duplicate GetClass/PaintedColor calls
- Hook callbacks execute on game thread (no ExecuteInGameThread wrapper needed)
- Works in multiplayer - hooks fire on all clients when properties replicate

## Troubleshooting

**Stands not turning invisible:**
- Check config color matches paint color exactly
- Enable `Debug = true` and check UE4SS.log

**Mod not loading:**
- Verify `enabled.txt` exists in mod folder
- Check UE4SS console for load message
- Review UE4SS.log for errors
