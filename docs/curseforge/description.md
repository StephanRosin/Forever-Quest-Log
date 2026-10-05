**Summary**

A quest tracker in the gold style of the Forever addons: drag and resize it, group quests by zone or sort them by level, and keep everything Blizzard's tracker does.

---

# Forever Quest Log

A new quest tracker for the right side of your screen, made for **WoW: Forever**. It looks like Forever Unit Frames, Forever Square Minimap and Forever Progress Bars, it is easy to move and resize, and it keeps everything Blizzard's tracker does on a click. English, Deutsch, Español, Français.

## Your quests at a glance
- **Grouped by zone**, with your current zone on top, or as one list. One click on the header switches.
- **Sorted like Blizzard's tracker** (nearest first) **or by level**, also with one click, and both combine: by level inside each zone.
- The **quest level** in front of every title, in its difficulty colour (grey, green, yellow, orange, red), and tags such as Elite, Dungeon or Raid.
- Every counted objective with its number on the right and a **thin progress bar** under it. Finished objectives are dimmed (or hidden, if you prefer).
- Completed quests show how to turn them in, with a check mark; failed quests say so; missing gold for a quest is shown as well.
- Zones collapse on a click; the header counts your quests like the quest log does (15 / 40), the tooltip tells how many of them you track.
- **Tracked recipes** in their own section, with every reagent and how many you have.

## Nothing lost
- **Left-click** a quest: details on the map. **Shift-click**: stop tracking. **Right-click**: Blizzard's own menu (focus, quest details, show on map, stop tracking, share in a group, abandon).
- Blizzard's own **map buttons** in front of the quests: click to focus a quest, exactly as on the map.
- **Quest items** as buttons next to their quest, usable **in combat**, with cooldown, charges and range colouring. Shift-click links the item.
- Auto-complete quests complete with a click; in a group, hovering shows your party's progress; Shift-click a recipe to untrack it.
- Blizzard's tracker is not modified or hooked, only made invisible, so it cannot break your quest items or other frames. One checkbox gives it back.

## Move it, size it
- **Unlock** it (lock button in the header, right-click on the minimap button or `/fql unlock`): drag the header to move it, drag the corner to resize it, with the size shown while you drag. **Ctrl + drag** moves it even while locked.
- Grows down or up, shrinks to its content if you like, and has a button to sit right under your minimap.
- Scale, inner margin, spacing between quests, and how far it fades while the mouse is elsewhere.

## Make it yours
- **Gold border** with rounded corners and a soft shadow (the Forever look), a flat border in any colour, or none.
- Background as a colour, a gradient or a **texture** (Blizzard's and every texture from LibSharedMedia), with its own opacity.
- **Five text styles**: header, zones, quest titles, objectives and turn-in, each with font (Blizzard's and LibSharedMedia's), size, outline or shadow and colour.
- Progress bars: height, texture, colour and how strong the empty part shows.

## Dungeons and raids
- Collapses to its header when you enter a dungeon or raid (can be switched off); **one click on the arrow** opens it again. Leaving restores it.
- A switch in the header shows **only the quests for the dungeon you are in**, or all of them. It can also be the default.
- Optionally collapses in combat.

## Options
- Its own options window in the style of Forever Unit Frames, opened from the gear in the header, the **minimap button**, Blizzard's **addon compartment** or `/fql`: General, Layout, Appearance, Text, Bars, Instances and Profiles. Only the settings that apply are shown.
- **Profiles** shared between characters, two presets ("Forever" and "Minimal"), and **export / import** of a whole profile as a text string (only read as settings, never run as code).

## Commands
`/fql` (options), `/fql lock`, `/fql unlock`, `/fql reset` (position and size), `/fql status`

## Notes
- Made for WoW: Forever.
- Quest item buttons cannot move in combat (the game does not allow it): while they show, the list waits for the end of combat before it rearranges.
- Feedback and ideas are welcome in the comments.
