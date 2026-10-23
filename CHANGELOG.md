# Changelog

## 0.3.1
- New icon: Wowhead's inv_misc_map08 (237387) scaled to 64x64. Used in the addon list, the addon list button, the settings window title, the Options > AddOns page and the DrangedAddons manager.

## 0.3.0
- **Show** tick boxes for the zone name, subzone name and PvP line. A hidden line leaves no gap: the lines under it move up into its place.
- **Font:** pick the font for all the zone text. The list has the game's fonts (Friz Quadrata, Arial Narrow, Skurri, Morpheus) and any font other addons share through LibSharedMedia, each shown in its own font. Sizes and the outline stay as set.
- The version number shows in the top-left corner of the settings window.

## 0.2.0
- **Fill in PvP type** (on by default): the Forever beta reports no PvP type for any zone, so every popup came out in the "No PvP type" colour with no PvP line. ZoneStyle now uses the original game's territories: Elwynn, Dun Morogh, Teldrassil, Westfall, Loch Modan, Darkshore and the Alliance capitals are Alliance territory; Durotar, Mulgore, Tirisfal, Silverpine, The Barrens and the Horde capitals are Horde territory; every other outdoor zone is contested. Friendly or hostile depends on your faction. Caves count as the zone they're in; instances stay "No PvP type".
- Writes the PvP line ("(Alliance Territory)", "(Contested Territory)") for those zones, shown on a new zone and dropped for a subzone-only popup, like the game does.
- Switch it off in the settings window. When the game reports a type itself, that's used instead.
- `/zonestyle debug` prints what the game reports for your zone, your map and what the territory list says.

## 0.1.0
- First version. A settings window (/zonestyle, the addon list button, Options > AddOns) for the zone name popup:
  - **Position:** sliders, or Unlock and drag it. The popup stays up while unlocked.
  - **Text size:** zone name, subzone name and PvP line separately.
  - **Colour by zone PvP type:** a colour for sanctuary, friendly, hostile, contested, free-for-all, combat zone and no PvP type, starting at the game's own. Test shows your zone as each type.
  - **Timing:** fade in, hold and fade out.
  - Preview and Reset all.
- Settings you never touch stay exactly as the game has them.
