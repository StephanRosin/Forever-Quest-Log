# Forever Quest Log

A quest tracker for WoW: Forever in the style of the other Forever addons
(Forever Unit Frames, Forever Square Minimap, Forever Progress Bars): a gold
frame you can drag and resize, quests grouped by zone or sorted by level, the
quest level in its difficulty colour, a thin progress bar under each counted
objective, tracked recipes, and everything Blizzard's tracker does on a click
(quest details, map, focus, untrack, share, abandon, quest items in combat).
In dungeons and raids it collapses to its header, and it can show only the
quests of the dungeon you are in.

Options window (gear in the header, minimap button or `/fql`), profiles,
export/import, and English, German, Spanish and French.

Themes (beta, first on the General page): Classic (your own setup) or one of
eight looks (wood, tech, parchment, runestone, stained glass, comic, frost,
pixel) for the tracker, the focus frame and notes. Every theme keeps all its
settings for itself and starts from your Classic setup the first time.
"Apply to all Forever addons" puts the other Forever addons on the same theme and colour.
The themes (textures, fonts, colours) come from the embedded library LibForeverThemes in
`Libs/LibForeverThemes` (source: https://github.com/StephanRosin/ForeverThemes, copied in with
its `tools/sync`). Its fonts are under the SIL Open Font License
([Libs/LibForeverThemes/Media/Fonts](Libs/LibForeverThemes/Media/Fonts/)).

Design notes: [docs/specs/](docs/specs/).

## Development

    tests/run                    # Lua 5.1, as in the game
    ./install "<WoW>/_forever_/Interface/AddOns"
    tools/package                # dist/ForeverQuestLog-<version>.zip
    tools/release release "<changelog>"   # bump ## Version first
    python3 tools/make_icons.py  # header and minimap icons (Pillow)
