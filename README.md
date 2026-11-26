# Delirium Fix (`DelFix`)

Small fixes and compatibility patches (third-party mods and vanilla) for the
Delirium Project Zomboid Build 42 server.

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

## Vanilla farming: longer last stage before rot

The last stage of a crop (seed-bearing, still harvestable) lasts `rotTime`
game hours, or half of `timeToGrow` when the crop has none, and then the plant
rots. On a server with 16 game days per real day that is 13-45 real hours, so
gardens rot while their owners are offline.

- Sandbox `DelFix.FarmingRotTimeMultiplier` (default 10, 1 = vanilla)
  multiplies that time. Growth, yield and the other stages are unchanged.
- Applied when a plant enters the last stage: plants already in it keep the
  deadline they had.
- Server-side wrapper of `farming_vegetableconf.grow`
  (`server/FarmingPatch/DF_FarmingRotTime.lua`), so it also covers modded
  crops added to `farming_vegetableconf.props`.

## True Music Jukebox (`TrueMusicJukebox`, Workshop 3398874593), optional

Own songs on cassettes for the jukebox. Nothing of True Music is copied or
changed; icons and the world model are the jukebox mod's own.

- `Kukhari z sokyroiu` — `DelFix.CassetteKukhariZSokyroyu`. Not spawned in the
  world, given by admins.
- Adding a song: `.ogg` in `media/sound/DelFixMusic/`, a `sound` and an `item`
  with the same name in `scripts/DF_TrueMusic.txt`, a `GlobalMusic` line in
  `lua/shared/TrueMusicPatch/DF_TrueMusicTracks.lua`, the name in
  `ItemName.json` (EN, RU, UA). The name must contain `Cassette`, must not
  start with `TC` and must be unique across all mods: the jukebox finds the
  sound by the item type without the module.

## Player corpses in car trunks

A player corpse could not be picked up or put into a trunk: it vanished until
relog. The engine writes a corpse item into a fixed 20000-byte buffer, and the
corpse carries a copy of the character's mod data. Lifestyle keeps every
learned song in it, hundreds of tables, so the buffer overflowed
(`BufferOverflowException` in the server log).

- Before a corpse is grabbed or dropped into a container, its mod data is
  estimated; above about 4000 bytes the largest tables are removed from the
  corpse copy until it fits. The living character is never touched.
- Each cut is printed to the log: `[DelFix] corpse modData cut before ...`.
- Clothes and inventory use the same buffer: a corpse with packed pockets can
  still overflow, empty them first.
- `lua/shared/CorpsePatch/DF_CorpseModData.lua`, wrappers of
  `ISGrabCorpseAction.new` and `ISDropCorpseIntoContainer.new`/`complete`.
