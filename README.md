# ZoneStyle

A World of Warcraft addon for WoW Forever (and the Classic beta). It lets you move, resize, recolour and retime the zone name popup, the big text that appears when you enter a new zone, subzone or city.

Everything starts out as the game has it. Change only what you want.

## Features
- **Position:** horizontal and vertical sliders, or **Unlock** and drag the popup where you want it. It stays on screen while unlocked.
- **Text size:** zone name, subzone name and the PvP line ("(Contested Territory)") each have their own size.
- **Show:** a tick box beside each size slider turns that line on or off. Lines below a hidden one move up.
- **Font:** the game's fonts plus any LibSharedMedia fonts your other addons provide.
- **Colour by zone PvP type:** sanctuary, friendly, hostile, contested, free-for-all, combat zone and no PvP type each have a colour. The zone, subzone and PvP lines all take the colour of the zone's type. **Test** shows your current zone as that type.
- **Timing:** fade in, hold and fade out, in seconds.
- **Fill in PvP type (on by default):** the Forever beta reports no PvP type for any zone, so ZoneStyle uses the original game's territories instead: the starting zones and capitals are Alliance or Horde territory, every other outdoor zone is contested. It writes the PvP line too. Once the game reports a type itself, that's used instead.

## Using it
- `/zonestyle` (or `/zstyle`), the addon list button or Options > AddOns > ZoneStyle opens the settings.
- `/zonestyle preview` replays the popup for where you're standing.
- `/zonestyle reset` puts every setting back to the game's.
- `/zonestyle debug` prints what the game reports for your zone (PvP type, map, territory) and where the popup sits.

Settings are account-wide.

Icon: inv_misc_map08 (Wowhead icon 237387), scaled up by `tools/make_icon.py`.
