# Delirium Fix (`DelFix`)

Compatibility fixes for third-party mods used on the Delirium Project Zomboid
Build 42 server.

## Common Sense (`BB_CommonSense`, Workshop 2875848298)

Based on *Common Sense Patch [B42.13+]* by FeedeameEsta (Workshop 3667553980,
since removed). Common Sense itself is by BitBraven; all credit to the authors.

- `CS_recipes.txt` override keeps `CleanBandageWithAlcohol` but with
  `[RubbingAlcohol]`: the `Alcohol` fluid was renamed in B42.14+, and the old
  name stops the server from loading the world (`Fluid not found: Alcohol`).
  The patch this is based on removed the recipe instead.
- `CS_fixing.txt` in B42 syntax (the B41 one crashed the vehicle mechanics menu).
- Crowbar prying of doors, windows and vehicle doors done on the server in MP.
- Obvious Collecting gives items on the server in MP.
- Fireplace/BBQ/campfire fuel menus restored to vanilla signatures.
- Wash menu, OnCraft and inventory fluid-container overrides of Common Sense
  disabled (vanilla behaviour).
- Lua error guards: gun stats HUD, recipe code, vehicle dashboard, world
  context menu.
- Auto-rack after reload.

**Load order:** `\DelFix` must come after `\BB_CommonSense` in `Mods=`. Files
keep the patch's paths on purpose: some replace Common Sense files with the same
path, the rest must load after Common Sense files.
