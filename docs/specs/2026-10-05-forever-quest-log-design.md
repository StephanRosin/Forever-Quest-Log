# Forever Quest Log — design

Status: approved mockup (Design canvas "Forever Quest Tracker", 2026-10-01/05), build 1.60.1.70205.

A replacement for Blizzard's objective tracker on the right side of the screen, for WoW Forever
(Interface 16001) only. It looks like the other Forever addons (Forever Unit Frames, Forever Square
Minimap, Forever Progress Bars) and keeps everything Blizzard's tracker does for quests and
tracked recipes.

## Why an own list, not a reskin

Blizzard's tracker must not be touched by addon code. Its quest item buttons call
`UseQuestLogSpecialItem` with a `questLogIndex` read from an attribute that the tracker's layout
code writes. Anything that makes that layout run tainted (overriding `ShouldDisplayQuest`,
writing fields, calling `SetCollapsed`, re-parenting so `OnHide` runs) risks blocked item use. The
right managed frame container also holds the boss and arena frames (protected), so a tainted
`Layout` of that container is worse still.

A reskin could only touch C-side widget state (anchors, scale, alpha, font objects). That cannot
give zone groups, levels, own progress bars or separate fonts for titles and objectives, which the
approved mockup has. So the addon draws its own list and hides Blizzard's tracker.

## Hiding Blizzard's tracker

`ObjectiveTrackerFrame:SetScale(0.001)` and `:SetAlpha(0)`: pure C calls, no script fires, no
Blizzard Lua runs in our context. Blizzard keeps updating it (secure); its regions are too small
to click. The right container lays it out as almost zero high on its next (secure) layout, so the
quest timer and durability frames move up. Re-applied after `PLAYER_ENTERING_WORLD`, Edit Mode
exit and when the scale is found reset (cheap check in the tracker's update). Never `Hide`,
`SetParent`, `ClearAllPoints`, field writes or method calls on it.

Option "Use Blizzard's tracker" (General page) switches our list off and leaves Blizzard's alone;
takes effect after `/reload`.

## What it shows

Sections, each with a header that collapses it:

- **Quests**: the quest watch list (`C_QuestLog.GetNumQuestWatches` /
  `GetQuestIDForQuestWatchIndex`), optionally grouped by the quest log header (zone) the quest sits
  under, sorted by the watch order (Blizzard's, by proximity) or by level.
- **Professions**: tracked recipes (`C_TradeSkillUI.GetRecipesTracked(false/true)`) with their
  required reagents and counts, as Blizzard's `ProfessionsRecipeTracker`.

Per quest:

- Blizzard's POI button (`POIButtonTemplate`, style in progress / complete, selected when super
  tracked): click super-tracks, as on the map.
- `[level]` in difficulty colour (`C_QuestLog.GetQuestDifficultyLevel`,
  `GetDifficultyColor(C_PlayerInfo.GetContentDifficultyQuestForPlayer(id))`), title, a tag
  (Elite / Dungeon / Raid / Group / PvP from `C_QuestLog.GetQuestTagInfo`).
- Objectives (`GetQuestLogLeaderBoard`, with `C_QuestLog.GetQuestObjectives` for counts), a thin
  bar under each counted objective; finished ones dimmed. Progress-bar objectives show
  `GetQuestProgressBarPercent`.
- Complete: "Ready for turn-in" (or the quest's completion text, or the waypoint text), auto-complete
  quests "Click to complete". Failed: "Failed". Required money: own / required.
- The waypoint line for the super-tracked quest (`C_QuestLog.GetNextWaypointText`).
- Quest item: a secure button (`SecureActionButtonTemplate`, `type=item`) with icon, charges,
  cooldown and range colouring.

Timed quests keep Blizzard's own `QuestTimerFrame` (Forever's tracker shows no timer bar either:
`Camelot/Blizzard_QuestObjectiveTrackerOverride.lua`).

## Interaction (same as Blizzard's)

Quest title row:

| Input | Action |
|---|---|
| Left click | `QuestMapFrame_OpenToQuestDetails(id)`; auto-complete + complete: `ShowQuestComplete(id)` |
| Shift (QUESTWATCHTOGGLE) + left | `C_QuestLog.RemoveQuestWatch(id)` if `QuestUtil.CanRemoveQuestWatch()` |
| Chat link modifier with open chat | `ChatFrameUtil.TryInsertQuestLinkForQuestID(id)` |
| Right click | context menu: super track / stop, view in quest log, show on map, stop tracking, share (group), abandon (`QuestMapQuestOptions_AbandonQuest`) |
| Hover in a group | `GameTooltip:SetQuestPartyProgress(id)` |

Recipe row: click opens the recipe (`C_TradeSkillUI.OpenRecipe`), RECIPEWATCHTOGGLE untracks,
chat link modifier links it, right click menu (view, untrack).

## Frame

- Own frame, `UIParent` child, strata LOW: header bar (drag handle, title "Quests", count
  `n/MAX_QUEST_WATCHES`, group-by-zone toggle, sort toggle, dungeon filter chip, lock, options,
  collapse), scrolling body, resize grip bottom right.
- Unlocked: drag the header to move, drag the grip to resize; position, width and height saved.
  Ctrl + drag works while locked (as Forever Square Minimap). Snaps to 1 px.
- Grow direction: down (anchored at its top) or up (anchored at its bottom). Height is the maximum;
  with "fit content" the frame shrinks to its content.
- Look: border NONE / FLAT / GOLD (Forever Unit Frames' ring, corners and shadow), size,
  colour, corner radius, shadow; background SOLID / GRADIENT / TEXTURE (Blizzard backgrounds and
  LibSharedMedia `background`), colour and opacity.
- Text, five styles each with font (Blizzard + LibSharedMedia), size, outline (none / outline /
  thick / shadow) and colour: header, zone headers, quest titles, objectives, completed
  objectives / turn-in. Level colours stay difficulty colours (option: plain title colour).
- Progress bars: on/off, texture, colour, height.

## Item buttons and combat

Item buttons are secure, so they cannot be shown, hidden or moved in combat. They are parented to
`UIParent` (our frame stays unprotected, so it can still be dragged, collapsed and scrolled in
combat) and placed at the absolute position of their row. Layout changes in combat do not move
them; they are re-placed after `PLAYER_REGEN_ENABLED`. While our frame is collapsed, scrolled away
or faded they are set to alpha 0 (allowed in combat) and, out of combat, hidden.

## Instances

- Collapse in dungeons and raids (default on): on entering (`PLAYER_ENTERING_WORLD`,
  `IsInInstance()` party/raid) the frame collapses to its header once; the collapse button opens
  it again. Leaving restores the state from before.
- Only this dungeon's quests (default off, header chip toggles it per visit): quests whose quest
  log header equals the instance name (`GetInstanceInfo()`), compared case-insensitively, or that
  carry the dungeon/raid tag and whose map is the instance's map. Implemented as a display filter
  in our list; the watch list is not changed.
- Collapse in combat (default off).

## Settings, profiles, sharing

As Forever Progress Bars: profiles account wide, active profile per character, presets read-only,
export/import string (`FQL1:`), language (auto, en, de, es, fr). Per-character UI state
(collapsed sections and zones, collapse before entering an instance) lives in
`ForeverQuestLogChar`, not in the profile.

## Options window

Forever Unit Frames style (Options/Style.lua, Widgets.lua): pages General, Layout, Appearance,
Text, Bars, Instances, Profiles. Opened by `/fql`, the minimap button, the addon compartment and
the gear in the header.

## Diagnostics

`/fql status`: version, build, whether Blizzard's tracker is hidden (its scale and alpha), watch
count, item buttons pending after combat, and `issecurevariable` checks on Blizzard tracker fields
our code must never write (`ObjectiveTrackerFrame.isCollapsed`, `.dirty`,
`QuestObjectiveTracker.isDirty`, `RightManagedFrameContainer.showingFrames`).

## Open, to verify in game

- Whether `ObjectiveTrackerFrame` gets its scale reset (Edit Mode, layout switch).
- Whether `ShowQuestComplete`, `QuestMapFrame_OpenToQuestDetails`, `MenuUtil` work from addon code
  in Forever without taint messages (they are not protected).
- The instance-quest match by quest log header for Forever's dungeons.
