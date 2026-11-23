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

## Ammo Maker (`ammomaker`, Workshop 2788256295), optional

Nothing of Ammo Maker is copied or changed; Delirium Fix only wraps one of its
global functions on the server and does nothing when Ammo Maker is not loaded.

- Sandbox `DelFix.AmmoMakerDropCasings` (default off): casings are not put on
  the ground at all (shots, reloads, full inventory). Brass catchers and
  casings returned into the inventory keep working.
- Ammo Maker keeps a global ModData record of every casing dropped on the
  ground and forgets it only when that square is loaded with the casing still
  there, so the list only grows. Records older than Ammo Maker's
  `DroppedCasingsLifetime` are removed every ten in-game minutes; younger ones
  stay, so casings lying on the ground now are still cleaned up by Ammo Maker.

## '83 GMC G-Series Vans (`83gmcGseriesVans`, Workshop 3799732653), optional

KI5's van files are not copied or changed.

- Purple paint for the G1500 LWB van (`Base.83gmcG1500lwb`), an 11th skin next
  to KI5's ten. It is picked at random like the others when a van spawns; vans
  already in the world keep their colour.
- `scripts/vehicles/DF_83gmcGseriesVans_skins.txt` holds only the extra `skin`
  block: a second `vehicle` block with the same name is loaded on top of the
  first one and appends skins.

**Load order:** `\DelFix` must come after `\83gmcGseriesVans` in `Mods=`
(`mod.info` also says `loadModAfter`). Loaded before it, the purple skin
becomes skin 0 and every existing van shifts to the next colour.
