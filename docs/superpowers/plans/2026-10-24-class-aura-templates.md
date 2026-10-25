# Recommended Auras (2.8.0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An Auras-tab button opens a window that adds a starter set of screen auras for the player's class (druid, mage), grouped by talent spec.

**Architecture:** `Templates.lua` holds the per-class data and the logic (spec detection, item availability, building entries through the importer's cleaning). `TemplatesWindow.lua` only displays it. `Config.lua` gets the button and a way to select an aura from outside; `Share.lua` exposes its aura cleaning and dialog helpers; `Core.lua` gets `/vb spec`.

**Tech Stack:** WoW addon Lua (Retail-codebase clients: Forever 1.60, Classic Era 1.15.9, TBC Anniversary 2.5.6, Retail 12.1.5), no build step, no test harness.

**Spec:** `docs/superpowers/specs/2026-10-24-class-aura-templates-design.md`

## Ground rules for this repo

- Work on branch `feature/class-aura-templates` (already created).
- Repo: `D:\DEV\VoidBox`. Each game's `Interface\AddOns\VoidBox` is a junction to it, so `/reload` in game loads the working tree. WoW must be restarted (not just `/reload`) when a file is added to the `.toc`.
- No unit tests exist and no Lua interpreter is installed. Verification is in game: `/console scriptErrors 1` once, then `/reload`; a Lua error pops up a dialog. Each task ends with the in-game check it allows.
- Commit messages: plain, no `Co-Authored-By` or other AI attribution lines (they reach the public CurseForge changelog).
- 4-space indentation, `local addonName, VB = ...` header, comments in the existing voice (why, not what).

## File structure

| File | Change | Responsibility |
|---|---|---|
| `Share.lua` | modify | expose `VB:CleanScreenAura`, `VB:MakeDialog`, `VB:MakeButton` |
| `Templates.lua` | create | `VB.AURA_TEMPLATES` data; `VB:GetTalentSpec`, `VB:PrintTalentSpec`, `VB:KnowsSpell`, `VB:TemplateFormSpell`, `VB:TemplateItemState`, `VB:BuildTemplateAura`, `VB:AddTemplateAuras` |
| `TemplatesWindow.lua` | create | `VB:ShowTemplatesWindow` and the window |
| `Config.lua` | modify | `VB:SelectScreenAura`; the "Recommended auras" button; list height |
| `Core.lua` | modify | `/vb spec` |
| `Locales.lua` | modify | English + French strings |
| `VoidBox.toc` | modify | the two files; version 2.8.0 |
| `CHANGELOG.md`, `README.md` | modify | release notes |

---

### Task 1: Expose the aura cleaning and the dialog helpers (Share.lua)

**Files:**
- Modify: `Share.lua:252-281` (after `CleanAura`), `Share.lua:390-448` (`MakeDialog`, `MakeButton`)

- [ ] **Step 1: Expose `CleanAura`**

Right after the `end` that closes `local function CleanAura(a)` (line 281), add:

```lua

-- For Templates.lua: a recommended aura goes through the same cleaning as an
-- imported one, so it ends up exactly like an aura made by hand
function VB:CleanScreenAura(a)
    return CleanAura(a)
end
```

- [ ] **Step 2: Make the dialog helpers shared**

Replace the line `local function MakeDialog(name, title, height)` with:

```lua
-- Shared with TemplatesWindow.lua
function VB:MakeDialog(name, title, height)
```

Replace the line `local function MakeButton(parent, text, width)` with:

```lua
function VB:MakeButton(parent, text, width)
```

Then, right after the `end` closing `VB:MakeButton`, add the local names the rest of `Share.lua` uses:

```lua
local function MakeDialog(...) return VB:MakeDialog(...) end
local function MakeButton(...) return VB:MakeButton(...) end
```

`MakeTextBox` stays between them and does not use either, so its position does not matter. Check that no call to `MakeDialog` / `MakeButton` sits above these two lines:

Run: `grep -n "MakeDialog\|MakeButton" Share.lua`
Expected: the `function VB:` definitions, the two `local function` aliases, then only calls at higher line numbers (the export and import dialogs, around lines 476-532).

- [ ] **Step 3: In game, check nothing broke**

`/reload` on any client, then `/vb config` > Profiles tab, click Export, then Import. Expected: both dialogs open as before, no Lua error.

- [ ] **Step 4: Commit**

```bash
git add Share.lua
git commit -m "Share: expose aura cleaning and dialog helpers"
```

---

### Task 2: Template data (Templates.lua)

**Files:**
- Create: `Templates.lua`
- Modify: `VoidBox.toc` (file list)

- [ ] **Step 1: Create `Templates.lua` with the header and the data**

```lua
--[[
    VoidBox - Recommended auras (2.8.0)

    A starter set of screen auras per class, grouped by talent spec, offered
    by the Auras tab's "Recommended auras" window (TemplatesWindow.lua): what
    a newcomer misses most next to WeakAuras.

    An item only holds what differs from VB:NewScreenAura. Adding one goes
    through the importer's cleaning (VB:CleanScreenAura), so it ends up
    exactly like an aura made by hand.

    IDs are rank 1 on the Classic ruleset (Era, Forever, TBC Anniversary). An
    item whose spell this client does not have at all (Molten Armor before
    TBC) is not offered. Specs are talent trees, in the game's order.
      requires : the spell that must be known for the aura to make sense (a
                 talent granting a proc); defaults to the spell itself
      form     : "cat" / "bear", resolved when the aura is added
      note     : a limit worth telling (TEMPLATE_NOTE_<note> in the tooltip)
]]

local addonName, VB = ...

VB.AURA_TEMPLATES = {
    DRUID = {
        common = {
            { spell = 16870, requires = 16864, glow = true, sound = "bell" },     -- Clearcasting (Omen of Clarity)
            { spell = 1126, show = "missing", combat = "out", note = "GROUP_BUFF" }, -- Mark of the Wild
            { spell = 467, show = "missing", combat = "out" },                    -- Thorns
        },
        specs = {
            { key = "BALANCE", items = {
                { spell = 8921, show = "missing", unit = "target", kind = "HARMFUL",
                  combat = "in", hostileTarget = true },                          -- Moonfire
                { spell = 5570, show = "missing", unit = "target", kind = "HARMFUL",
                  combat = "in", hostileTarget = true },                          -- Insect Swarm
                { spell = 770, show = "missing", unit = "target", kind = "HARMFUL",
                  combat = "in", hostileTarget = true },                          -- Faerie Fire
            } },
            { key = "FERAL", groups = {
                { key = "CAT", items = {
                    { spell = 5221, source = "usable", form = "cat" },            -- Shred
                    { spell = 1822, show = "missing", unit = "target", kind = "HARMFUL",
                      combat = "in", hostileTarget = true, form = "cat" },        -- Rake
                    { spell = 1079, unit = "target", kind = "HARMFUL", display = "bar",
                      countdown = true, form = "cat" },                           -- Rip
                    { spell = 5217, countdown = true, form = "cat" },             -- Tiger's Fury
                } },
                { key = "BEAR", items = {
                    { spell = 99, show = "missing", unit = "target", kind = "HARMFUL",
                      combat = "in", hostileTarget = true, form = "bear" },       -- Demoralizing Roar
                    { spell = 16857, show = "missing", unit = "target", kind = "HARMFUL",
                      combat = "in", hostileTarget = true, form = "bear" },       -- Faerie Fire (Feral)
                } },
            } },
            { key = "RESTORATION", items = {
                { spell = 17116, glow = true },                                   -- Nature's Swiftness
                { spell = 29166, countdown = true },                              -- Innervate
            } },
        },
    },

    MAGE = {
        common = {
            { spell = 1459, show = "missing", combat = "out", note = "GROUP_BUFF" }, -- Arcane Intellect
            { spell = 12536, requires = 11213, glow = true, sound = "bell" },     -- Clearcasting (Arcane Concentration)
        },
        specs = {
            { key = "ARCANE", items = {
                { spell = 6117, show = "missing", combat = "out" },               -- Mage Armor
                { spell = 12042, countdown = true },                              -- Arcane Power
                { spell = 12043, glow = true },                                   -- Presence of Mind
                { spell = 36032, requires = 30451, kind = "HARMFUL", mine = false }, -- Arcane Blast (TBC), its stacks on me
            } },
            { key = "FIRE", items = {
                { spell = 30482, show = "missing", combat = "out" },              -- Molten Armor (TBC)
                { spell = 11129 },                                                -- Combustion
                { spell = 22959, requires = 11095, unit = "target", kind = "HARMFUL", mine = false,
                  display = "bar", countdown = true },                            -- Fire Vulnerability (Improved Scorch)
            } },
            { key = "FROST", items = {
                { spell = 7302, show = "missing", combat = "out" },               -- Ice Armor
                { spell = 12472, countdown = true },                              -- Icy Veins (TBC)
                { spell = 11426, show = "missing", combat = "in" },               -- Ice Barrier
                { spell = 12579, requires = 11180, unit = "target", kind = "HARMFUL", mine = false }, -- Winter's Chill
            } },
        },
    },
}
```

(Stacks are on by default in `VB:NewScreenAura`, so Combustion, Arcane Blast, Fire Vulnerability and Winter's Chill show their count without saying so.)

- [ ] **Step 2: Add it to the toc**

In `VoidBox.toc`, after the line `Auras.lua`, add:

```
Templates.lua
```

- [ ] **Step 3: In game, check it loads**

Restart WoW (a new file in the toc), log in. Expected: no Lua error at login, and `/vb` prints the usual help. (The addon table is private, so the data itself is checked through the window in Task 7.)

- [ ] **Step 4: Commit**

```bash
git add Templates.lua VoidBox.toc
git commit -m "Templates: recommended auras for druid and mage"
```

---

### Task 3: Spec detection and /vb spec

**Files:**
- Modify: `Templates.lua` (append)
- Modify: `Core.lua:1640-1646` (slash dispatch, next to `auratest`)
- Modify: `Locales.lua` (append the four SPEC strings now; the rest in Task 6)

- [ ] **Step 1: Append spec detection to `Templates.lua`**

```lua

-------------------------------------------------
-- Spec = the talent tree with the most points
-- Two return layouts: the current one starts with a numeric tab ID (id, name,
-- description, icon, pointsSpent, ...), the old one with the name (name,
-- icon, pointsSpent, ...). WoW Forever has no specializations; whether its
-- talent trees answer is what /vb spec shows.
-------------------------------------------------
local function Plain(v)
    return not (issecretvalue and issecretvalue(v))
end

local function TabInfo(tab)
    local ok, a, b, c, _, e = pcall(GetTalentTabInfo, tab)
    if not ok then return nil, 0 end
    local name, points
    if type(a) == "number" then name, points = b, e else name, points = a, c end
    if type(points) ~= "number" or not Plain(points) or points < 0 then points = 0 end
    return name, points
end

local function NumTabs()
    if type(GetNumTalentTabs) ~= "function" or type(GetTalentTabInfo) ~= "function" then return 0 end
    local ok, n = pcall(GetNumTalentTabs)
    if not ok or type(n) ~= "number" or not Plain(n) then return 0 end
    return n
end

-- The tree index, or nil (no points spent, no talent trees). Ties: the first.
function VB:GetTalentSpec()
    local best, bestPoints = nil, 0
    for tab = 1, NumTabs() do
        local _, points = TabInfo(tab)
        if points > bestPoints then best, bestPoints = tab, points end
    end
    return best
end

function VB:PrintTalentSpec()
    local L = VB.L
    local n = NumTabs()
    if n == 0 then
        VB:Print(L["SPEC_NO_TALENTS"])
        return
    end
    VB:Print(L["SPEC_TITLE"])
    for tab = 1, n do
        local name, points = TabInfo(tab)
        VB:Print(("  %d. %s: %d"):format(tab, tostring(name), points))
    end
    local spec = VB:GetTalentSpec()
    VB:Print(L["SPEC_DETECTED"]:format(spec and tostring(spec) or L["SPEC_NONE"]))
end
```

- [ ] **Step 2: Wire `/vb spec` in `Core.lua`**

In `SlashCmdList["VOIDBOX"]`, right before the line `    elseif msg == "dispeldebug" then`, add:

```lua
    elseif msg == "spec" then
        VB:PrintTalentSpec()
```

- [ ] **Step 3: Add the SPEC strings to `Locales.lua`**

Append at the end of `Locales.lua`:

```lua

-------------------------------------------------
-- Recommended auras (v2.8.0). English and French; other locales fall back
-- to English.
-------------------------------------------------
SetDefault("SPEC_TITLE", "Talent trees:")
SetDefault("SPEC_DETECTED", "Detected spec: %s")
SetDefault("SPEC_NONE", "none")
SetDefault("SPEC_NO_TALENTS", "This client has no talent trees to read.")
SetLocale("frFR", "SPEC_TITLE", "Arbres de talents :")
SetLocale("frFR", "SPEC_DETECTED", "Spé détectée : %s")
SetLocale("frFR", "SPEC_NONE", "aucune")
SetLocale("frFR", "SPEC_NO_TALENTS", "Ce jeu n'a pas d'arbres de talents lisibles.")
```

- [ ] **Step 4: In game**

`/reload`, then `/vb spec` on the TBC mage. Expected: three lines (Arcanes, Feu, Givre) with the right points, then "Spé détectée : N" matching the most-filled tree. On a character with no talent points: "aucune". Note the result on Forever when it is playable (not blocking this task).

- [ ] **Step 5: Commit**

```bash
git add Templates.lua Core.lua Locales.lua
git commit -m "Templates: detect the spec from talent points, /vb spec"
```

---

### Task 4: Availability rules (Templates.lua)

**Files:**
- Modify: `Templates.lua` (append)

- [ ] **Step 1: Append known-spell, form and state logic**

```lua

-------------------------------------------------
-- Which items to offer, and how
-------------------------------------------------

-- A talent's rank by name (its rank-1 spell has the talent's name), 0 when
-- not taken. Talents are not always in the spellbook (passives).
local function TalentRank(name)
    if type(GetNumTalents) ~= "function" or type(GetTalentInfo) ~= "function" then return 0 end
    for tab = 1, NumTabs() do
        local okN, n = pcall(GetNumTalents, tab)
        if okN and type(n) == "number" and Plain(n) then
            for i = 1, n do
                local ok, tName, _, _, _, rank = pcall(GetTalentInfo, tab, i)
                if ok and tName == name and type(rank) == "number" and Plain(rank) then return rank end
            end
        end
    end
    return 0
end

-- Known as this exact ID, as a passive, as another rank of the same name in
-- the spellbook (ranked spellbooks), or as a talent with points in it
function VB:KnowsSpell(spellID)
    if VB:IsSpellKnownByID(spellID) then return true end
    if type(IsPlayerSpell) == "function" then
        local ok, known = pcall(IsPlayerSpell, spellID)
        if ok and VB:SafeBool(known) then return true end
    end
    local name = VB:GetSpellName(spellID)
    if not name then return false end
    local found = false
    VB:ForEachKnownSpell(function(id, n)
        if not found and (n or VB:GetSpellName(id)) == name then found = true end
    end)
    return found or TalentRank(name) > 0
end

-- Forms by key: the first one known wins (Dire Bear Form replaces Bear Form
-- at 40 and is another spell)
local FORMS = {
    cat = { 768 },          -- Cat Form
    bear = { 9634, 5487 },  -- Dire Bear Form, Bear Form
}

-- The form's spell ID for this character, else its first one (for the
-- tooltip's name), nil for an unknown key
function VB:TemplateFormSpell(key, knownOnly)
    local ids = FORMS[key]
    if not ids then return nil end
    for _, id in ipairs(ids) do
        if VB:KnowsSpell(id) then return id end
    end
    if knownOnly then return nil end
    return ids[1]
end

-- "absent" (not on this client: not offered), "added" (an aura on the same
-- spell, kind of trigger, mode and unit exists), "unlearned", or "ok"
function VB:TemplateItemState(item)
    if not VB:GetSpellName(item.spell) then return "absent" end
    local source, show, unit = item.source or "spell", item.show or "present", item.unit or "player"
    for _, e in ipairs(VB.screenAuras or {}) do
        if e.spellID == item.spell and (e.source or "spell") == source
            and (e.show or "present") == show and (e.unit or "player") == unit then
            return "added"
        end
    end
    if not VB:KnowsSpell(item.requires or item.spell) then return "unlearned" end
    return "ok"
end
```

- [ ] **Step 2: In game**

`/reload`: no Lua error. The states themselves are checked through the window in Task 7 (the addon table is private, `/run` cannot reach it).

- [ ] **Step 3: Commit**

```bash
git add Templates.lua
git commit -m "Templates: which recommended auras exist, are learned or added"
```

---

### Task 5: Building and adding the auras (Templates.lua, Config.lua)

**Files:**
- Modify: `Templates.lua` (append)
- Modify: `Config.lua:1895` (add `VB:SelectScreenAura` before `VB:RefreshScreenAurasTab`)

- [ ] **Step 1: Append building and adding to `Templates.lua`**

```lua

-------------------------------------------------
-- Adding
-------------------------------------------------
local COPIED = { "source", "show", "unit", "kind", "mine", "combat", "group", "hostileTarget",
                 "inRange", "display", "countdown", "stacks", "glow", "sound", "color" }

-- The entry for an item (not stored), or nil when the client refuses it
function VB:BuildTemplateAura(item)
    local raw = VB:NewScreenAura(item.spell)
    for _, key in ipairs(COPIED) do
        if item[key] ~= nil then raw[key] = item[key] end
    end
    -- A form not learned yet: no form condition rather than a wrong one
    raw.form = item.form and VB:TemplateFormSpell(item.form, true) or nil
    return VB:CleanScreenAura(raw)
end

local GAP = 8

-- On screen an entry is `size` wide, a bar four times that (Auras.lua SizeOf)
local function WidthOf(entry)
    if entry.display == "bar" and entry.show ~= "missing" and entry.show ~= "expiring" then
        return entry.size * 4
    end
    return entry.size
end

-- Adds the items' auras in one row centred above the character, selects the
-- first, says how many. Returns that count.
function VB:AddTemplateAuras(items)
    if InCombatLockdown() then
        VB:Print(VB.L["CANNOT_CONFIG_COMBAT"])
        return 0
    end
    local entries, total = {}, 0
    for _, item in ipairs(items) do
        local entry = VB:BuildTemplateAura(item)
        if entry then
            entries[#entries + 1] = entry
            total = total + WidthOf(entry)
        end
    end
    total = total + GAP * math.max(0, #entries - 1)
    local first, x = #VB.screenAuras + 1, -total / 2
    for _, entry in ipairs(entries) do
        local w = WidthOf(entry)
        entry.x, entry.y = math.floor(x + w / 2 + 0.5), 150
        x = x + w + GAP
        VB.screenAuras[#VB.screenAuras + 1] = entry
    end
    if #entries > 0 then
        VB:RebuildScreenAuras()
        if VB.SelectScreenAura then VB:SelectScreenAura(first) end
    end
    VB:Print(VB.L["TEMPLATES_ADDED"]:format(#entries))
    return #entries
end
```

- [ ] **Step 2: Add `VB:SelectScreenAura` to `Config.lua`**

Right before the line `function VB:RefreshScreenAurasTab()`, add:

```lua
-- For Templates.lua: show this aura selected in the tab (refreshes it)
function VB:SelectScreenAura(index)
    selectedAura = index
    VB:RefreshScreenAurasTab()
end

```

- [ ] **Step 3: Add the TEMPLATES_ADDED string**

Append to `Locales.lua`:

```lua
SetDefault("TEMPLATES_ADDED", "%d aura(s) added.")
SetLocale("frFR", "TEMPLATES_ADDED", "%d aura(s) ajoutée(s).")
```

- [ ] **Step 4: In game**

`/reload`. No window yet; the next task exercises this. Expected now: no Lua error.

- [ ] **Step 5: Commit**

```bash
git add Templates.lua Config.lua Locales.lua
git commit -m "Templates: build recommended auras through the importer's cleaning"
```

---

### Task 6: The window (TemplatesWindow.lua) and its strings

**Files:**
- Create: `TemplatesWindow.lua`
- Modify: `VoidBox.toc`, `Locales.lua`

- [ ] **Step 1: Create `TemplatesWindow.lua`**

```lua
--[[
    VoidBox - Recommended auras window (2.8.0)

    Lists VB.AURA_TEMPLATES for the player's class: "All specs" and a tab per
    talent tree, check rows, then Add (N). Opens on the detected spec. The
    rules (which items exist here, are learned, already added) and the adding
    live in Templates.lua; this file only shows them.
]]

local addonName, VB = ...

local ROW_HEIGHT = 24
local LIST_WIDTH = 405
local GREY = 0.6

local dialog            -- built on first use
local checked = {}      -- item -> true; kept across tabs while the window is open
local states = {}       -- item -> VB:TemplateItemState, computed when it opens
local rowPool, headerPool = {}, {}

local function Templates() return VB.AURA_TEMPLATES[VB.playerClass] end

-- Every item of the class in list order, with its tab (0 = All specs)
local function ForEachItem(fn)
    local t = Templates()
    if not t then return end
    for _, item in ipairs(t.common or {}) do fn(item, 0) end
    for index, spec in ipairs(t.specs or {}) do
        for _, item in ipairs(spec.items or {}) do fn(item, index) end
        for _, group in ipairs(spec.groups or {}) do
            for _, item in ipairs(group.items) do fn(item, index) end
        end
    end
end

local function ModeText(item)
    local key
    if item.source == "usable" then
        key = "TEMPLATE_USABLE"
    else
        key = "TEMPLATE_" .. (item.show or "present"):upper() .. "_" .. (item.unit == "target" and "TARGET" or "SELF")
    end
    return VB.L[key] or ""
end

local function LabelOf(item)
    return (VB:GetSpellName(item.spell) or tostring(item.spell)) .. " - " .. ModeText(item)
end

local function ShowTip(row)
    local item, L = row.item, VB.L
    local function Line(text) GameTooltip:AddLine(text, 0.8, 0.8, 0.8, true) end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(LabelOf(item), 1, 1, 1)
    if item.form then
        Line(L["TEMPLATE_TIP_FORM"]:format(VB:GetSpellName(VB:TemplateFormSpell(item.form)) or item.form))
    end
    if item.combat == "in" then Line(L["TEMPLATE_TIP_IN_COMBAT"]) end
    if item.combat == "out" then Line(L["TEMPLATE_TIP_OUT_COMBAT"]) end
    if item.hostileTarget then Line(L["TEMPLATE_TIP_HOSTILE"]) end
    if item.glow then Line(L["TEMPLATE_TIP_GLOW"]) end
    if item.sound and item.sound ~= "none" then Line(L["TEMPLATE_TIP_SOUND"]) end
    if item.requires and item.requires ~= item.spell then
        Line(L["TEMPLATE_TIP_REQUIRES"]:format(VB:GetSpellName(item.requires) or tostring(item.requires)))
    end
    if item.note then GameTooltip:AddLine(L["TEMPLATE_NOTE_" .. item.note], 1, 0.82, 0, true) end
    if states[item] == "unlearned" then GameTooltip:AddLine(L["TEMPLATE_UNLEARNED"], 1, 0.5, 0.5) end
    if states[item] == "added" then GameTooltip:AddLine(L["TEMPLATE_ADDED_ALREADY"], 1, 0.5, 0.5) end
    GameTooltip:Show()
end

local function GetRow(i)
    local row = rowPool[i]
    if row then return row end
    row = CreateFrame("Frame", nil, dialog.listChild)
    row:SetSize(LIST_WIDTH, ROW_HEIGHT)
    row:EnableMouse(true)
    row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.check:SetSize(22, 22)
    row.check:SetPoint("LEFT", 0, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", row.check, "RIGHT", 2, 0)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.label:SetJustifyH("LEFT")
    row.check:SetScript("OnClick", function(self)
        checked[row.item] = self:GetChecked() and true or nil
        dialog.UpdateCount()
    end)
    row:SetScript("OnEnter", ShowTip)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row.check:SetScript("OnEnter", function() ShowTip(row) end)
    row.check:SetScript("OnLeave", GameTooltip_Hide)
    rowPool[i] = row
    return row
end

local function ShowTab(tab)
    local L, t = VB.L, Templates()
    for _, button in ipairs(dialog.tabs) do
        if button.tab == tab then button:LockHighlight() else button:UnlockHighlight() end
    end
    for _, row in ipairs(rowPool) do row:Hide() end
    for _, header in ipairs(headerPool) do header:Hide() end

    local child = dialog.listChild
    local y, rows, headers = 0, 0, 0
    local function AddHeader(text)
        headers = headers + 1
        local h = headerPool[headers] or child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        headerPool[headers] = h
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", 4, -y - 4)
        h:SetText(text)
        h:Show()
        y = y + 22
    end
    local function AddItem(item)
        local state = states[item]
        if state == "absent" then return end
        rows = rows + 1
        local row = GetRow(rows)
        row.item = item
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row.icon:SetTexture(VB:GetSpellIcon(item.spell))
        local text = LabelOf(item)
        if state == "unlearned" then text = text .. "  (" .. L["TEMPLATE_UNLEARNED"] .. ")" end
        if state == "added" then text = text .. "  (" .. L["TEMPLATE_ADDED_ALREADY"] .. ")" end
        row.label:SetText(text)
        local c = state == "ok" and 1 or GREY
        row.label:SetTextColor(c, c, c)
        row.icon:SetDesaturated(state ~= "ok")
        row.check:SetChecked(checked[item] and true or false)
        row.check:SetEnabled(state ~= "added")
        row:Show()
        y = y + ROW_HEIGHT
    end

    if tab == 0 then
        for _, item in ipairs(t.common or {}) do AddItem(item) end
    else
        local spec = t.specs[tab]
        for _, item in ipairs(spec.items or {}) do AddItem(item) end
        for _, group in ipairs(spec.groups or {}) do
            AddHeader(L["TEMPLATE_GROUP_" .. group.key] or group.key)
            for _, item in ipairs(group.items) do AddItem(item) end
        end
    end
    if rows == 0 then AddHeader(L["TEMPLATE_EMPTY"]) end
    child:SetHeight(math.max(y, 1))
end

local function Build()
    local L, t = VB.L, Templates()
    local f = VB:MakeDialog("VoidBoxTemplatesDialog", L["TEMPLATES_TITLE"], 470)
    dialog = f

    -- Tabs: All specs, then the talent trees in the game's order
    local entries = { { tab = 0, text = L["TEMPLATE_SPEC_ALL"] } }
    for i, spec in ipairs(t.specs) do
        entries[#entries + 1] = { tab = i, text = L["TEMPLATE_SPEC_" .. spec.key] or spec.key }
    end
    local width = math.floor((LIST_WIDTH + 20 - (#entries - 1) * 4) / #entries)
    f.tabs = {}
    for i, e in ipairs(entries) do
        local b = VB:MakeButton(f, e.text, width)
        b:SetNormalFontObject("GameFontNormalSmall")
        b:SetHighlightFontObject("GameFontHighlightSmall")
        b:SetPoint("TOPLEFT", 15 + (i - 1) * (width + 4), -40)
        b.tab = e.tab
        b:SetScript("OnClick", function() ShowTab(e.tab) end)
        f.tabs[i] = b
    end

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 15, -75)
    scroll:SetSize(LIST_WIDTH, 340)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(LIST_WIDTH, 1)
    scroll:SetScrollChild(child)
    f.listChild = child

    local addBtn = VB:MakeButton(f, "", 140)
    addBtn:SetPoint("BOTTOMRIGHT", -15, 12)
    local cancelBtn = VB:MakeButton(f, CANCEL)
    cancelBtn:SetPoint("RIGHT", addBtn, "LEFT", -8, 0)
    cancelBtn:SetScript("OnClick", function() f:Hide() end)

    f.UpdateCount = function()
        local n = 0
        for _ in pairs(checked) do n = n + 1 end
        addBtn:SetText(L["TEMPLATES_ADD"]:format(n))
        addBtn:SetEnabled(n > 0)
    end
    addBtn:SetScript("OnClick", function()
        local list = {}
        ForEachItem(function(item) if checked[item] then list[#list + 1] = item end end)
        f:Hide()
        VB:AddTemplateAuras(list)
    end)
end

-- Opens on the detected spec (the first one when none), with "All specs" and
-- that spec's available items checked
function VB:ShowTemplatesWindow()
    local t = Templates()
    if not t then
        VB:Print(VB.L["TEMPLATES_NONE"])
        return
    end
    if not dialog then Build() end
    wipe(checked)
    wipe(states)
    local spec = VB:GetTalentSpec()
    if spec and not t.specs[spec] then spec = nil end
    ForEachItem(function(item, tab)
        local state = VB:TemplateItemState(item)
        states[item] = state
        if state == "ok" and (tab == 0 or tab == spec) then checked[item] = true end
    end)
    dialog.UpdateCount()
    ShowTab(spec or 1)
    dialog:Show()
end
```

- [ ] **Step 2: Add it to the toc**

In `VoidBox.toc`, after the line `Share.lua`, add:

```
TemplatesWindow.lua
```

- [ ] **Step 3: Add the window strings**

Append to `Locales.lua`:

```lua
SetDefault("TEMPLATES_BUTTON", "Recommended auras...")
SetDefault("TEMPLATES_TITLE", "Recommended auras")
SetDefault("TEMPLATES_NONE", "No recommended auras for this class yet.")
SetDefault("TEMPLATES_ADD", "Add (%d)")
SetDefault("TEMPLATE_SPEC_ALL", "All specs")
SetDefault("TEMPLATE_SPEC_BALANCE", "Balance")
SetDefault("TEMPLATE_SPEC_FERAL", "Feral Combat")
SetDefault("TEMPLATE_SPEC_RESTORATION", "Restoration")
SetDefault("TEMPLATE_SPEC_ARCANE", "Arcane")
SetDefault("TEMPLATE_SPEC_FIRE", "Fire")
SetDefault("TEMPLATE_SPEC_FROST", "Frost")
SetDefault("TEMPLATE_GROUP_CAT", "Cat")
SetDefault("TEMPLATE_GROUP_BEAR", "Bear")
SetDefault("TEMPLATE_USABLE", "usable")
SetDefault("TEMPLATE_PRESENT_SELF", "active")
SetDefault("TEMPLATE_PRESENT_TARGET", "on target")
SetDefault("TEMPLATE_MISSING_SELF", "missing")
SetDefault("TEMPLATE_MISSING_TARGET", "missing on target")
SetDefault("TEMPLATE_EXPIRING_SELF", "running out")
SetDefault("TEMPLATE_EXPIRING_TARGET", "running out on target")
SetDefault("TEMPLATE_UNLEARNED", "not learned yet")
SetDefault("TEMPLATE_ADDED_ALREADY", "already added")
SetDefault("TEMPLATE_EMPTY", "Nothing for this game version.")
SetDefault("TEMPLATE_TIP_FORM", "Only in %s")
SetDefault("TEMPLATE_TIP_IN_COMBAT", "In combat only")
SetDefault("TEMPLATE_TIP_OUT_COMBAT", "Out of combat only")
SetDefault("TEMPLATE_TIP_HOSTILE", "Hostile target only")
SetDefault("TEMPLATE_TIP_GLOW", "Glows")
SetDefault("TEMPLATE_TIP_SOUND", "Plays a sound")
SetDefault("TEMPLATE_TIP_REQUIRES", "Needs %s")
SetDefault("TEMPLATE_NOTE_GROUP_BUFF", "Shows as missing while you have the group version of this buff instead.")

SetLocale("frFR", "TEMPLATES_BUTTON", "Auras conseillées...")
SetLocale("frFR", "TEMPLATES_TITLE", "Auras conseillées")
SetLocale("frFR", "TEMPLATES_NONE", "Pas encore d'auras conseillées pour cette classe.")
SetLocale("frFR", "TEMPLATES_ADD", "Ajouter (%d)")
SetLocale("frFR", "TEMPLATE_SPEC_ALL", "Toutes spés")
SetLocale("frFR", "TEMPLATE_SPEC_BALANCE", "Équilibre")
SetLocale("frFR", "TEMPLATE_SPEC_FERAL", "Combat farouche")
SetLocale("frFR", "TEMPLATE_SPEC_RESTORATION", "Restauration")
SetLocale("frFR", "TEMPLATE_SPEC_ARCANE", "Arcanes")
SetLocale("frFR", "TEMPLATE_SPEC_FIRE", "Feu")
SetLocale("frFR", "TEMPLATE_SPEC_FROST", "Givre")
SetLocale("frFR", "TEMPLATE_GROUP_CAT", "Félin")
SetLocale("frFR", "TEMPLATE_GROUP_BEAR", "Ours")
SetLocale("frFR", "TEMPLATE_USABLE", "utilisable")
SetLocale("frFR", "TEMPLATE_PRESENT_SELF", "actif")
SetLocale("frFR", "TEMPLATE_PRESENT_TARGET", "sur la cible")
SetLocale("frFR", "TEMPLATE_MISSING_SELF", "absent")
SetLocale("frFR", "TEMPLATE_MISSING_TARGET", "absent sur la cible")
SetLocale("frFR", "TEMPLATE_EXPIRING_SELF", "bientôt fini")
SetLocale("frFR", "TEMPLATE_EXPIRING_TARGET", "bientôt fini sur la cible")
SetLocale("frFR", "TEMPLATE_UNLEARNED", "pas encore appris")
SetLocale("frFR", "TEMPLATE_ADDED_ALREADY", "déjà ajoutée")
SetLocale("frFR", "TEMPLATE_EMPTY", "Rien pour cette version du jeu.")
SetLocale("frFR", "TEMPLATE_TIP_FORM", "Seulement en %s")
SetLocale("frFR", "TEMPLATE_TIP_IN_COMBAT", "En combat seulement")
SetLocale("frFR", "TEMPLATE_TIP_OUT_COMBAT", "Hors combat seulement")
SetLocale("frFR", "TEMPLATE_TIP_HOSTILE", "Cible hostile seulement")
SetLocale("frFR", "TEMPLATE_TIP_GLOW", "Lueur")
SetLocale("frFR", "TEMPLATE_TIP_SOUND", "Joue un son")
SetLocale("frFR", "TEMPLATE_TIP_REQUIRES", "Nécessite %s")
SetLocale("frFR", "TEMPLATE_NOTE_GROUP_BUFF", "S'affiche comme absente quand tu as la version de groupe de ce buff à la place.")
```

- [ ] **Step 4: In game**

Restart WoW (a new file in the toc). Expected: no Lua error at login. Nothing opens the window yet; Task 7 adds the button and exercises it.

- [ ] **Step 5: Commit**

```bash
git add TemplatesWindow.lua VoidBox.toc Locales.lua
git commit -m "Templates: the recommended auras window"
```

---

### Task 7: The button in the Auras tab (Config.lua)

**Files:**
- Modify: `Config.lua:1651-1656` (list height), after the list block (button)

The input row (line ~1597) is full (input, Add, drop zone, "By debuff type": 466 px of the tab's width), so the button goes under the list rather than next to Add as the spec says; the list loses 26 px.

- [ ] **Step 1: Shorten the list**

In `VB:CreateScreenAurasTab`, change:

```lua
    scrollFrame:SetSize(440, 140)
```
to
```lua
    scrollFrame:SetSize(440, 114)
```
and
```lua
    scrollChild:SetSize(440, 140)
```
to
```lua
    scrollChild:SetSize(440, 114)
```

- [ ] **Step 2: Add the button**

Right after the line `    content.auraScrollChild = scrollChild`, add:

```lua

    -- === Recommended auras (Templates.lua, TemplatesWindow.lua) ===
    local recBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    recBtn:SetSize(170, 22)
    recBtn:SetPoint("TOPLEFT", 12, -216)
    recBtn:SetText(L["TEMPLATES_BUTTON"])
    recBtn:SetScript("OnClick", function() VB:ShowTemplatesWindow() end)
    if not VB.AURA_TEMPLATES[VB.playerClass] then
        recBtn:Disable()
        if recBtn.SetMotionScriptsWhileDisabled then recBtn:SetMotionScriptsWhileDisabled(true) end
        recBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["TEMPLATES_NONE"], 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        recBtn:SetScript("OnLeave", GameTooltip_Hide)
    end
```

- [ ] **Step 3: In game, the full flow on the TBC mage**

`/reload`, `/vb config` > Auras.
1. The list is a bit shorter, the button sits under it, above the editor, nothing overlaps.
2. Click it. The window opens on the detected spec's tab, its available items checked, "Toutes spés" items checked; TBC-only items (Arcane Blast, Molten Armor, Icy Veins) listed; untaken talents greyed with "pas encore appris"; "Ajouter (N)" counts all tabs.
3. Switch tabs: checks are kept. Hover rows: tooltips list form / combat / requires / note.
4. Add. Chat says "N aura(s) ajoutée(s)."; the auras appear in the list, the first selected, on screen in a centred row (drag them while the tab is open).
5. Reopen the window: those items now say "déjà ajoutée", greyed, their checkbox disabled.
6. Log a character of another class (or Retail): the button is greyed, its tooltip says no recommended auras yet.

- [ ] **Step 4: Commit**

```bash
git add Config.lua
git commit -m "Auras tab: Recommended auras button"
```

---

### Task 8: Version, changelog, readme

**Files:**
- Modify: `VoidBox.toc` (`## Version`), `CHANGELOG.md` (top), `README.md` (features)

- [ ] **Step 1: Bump the version**

In `VoidBox.toc`: `## Version: 2.7.1` becomes `## Version: 2.8.0`.

- [ ] **Step 2: Changelog entry**

Insert under `# VoidBox`, before `## v2.7.1 (2026-10-21)`:

```markdown
## v2.8.0 (unreleased)

Screen auras (Auras tab):

- **Recommended auras.** A new button under the auras list opens a window
  with a starter set for your class, one tab per talent spec plus "All
  specs". It opens on your spec (the tree with the most points), with what
  you can already use checked; spells you have not learned yet are greyed
  but can be added, and auras you already have are marked. Druid and mage
  for now; Classic Era, TBC Anniversary and WoW Forever.
- `/vb spec` shows the talent points the addon reads and the detected spec.
```

- [ ] **Step 3: README**

In `README.md`, find the screen auras feature list and add one line in its style:

```markdown
- Recommended auras per class and spec (druid, mage), added in one click
```

Run: `grep -n -i "aura" README.md` to find the list, and add the line at its end.

- [ ] **Step 4: Commit**

```bash
git add VoidBox.toc CHANGELOG.md README.md
git commit -m "v2.8.0 notes: recommended auras"
```

---

### Task 9: Full in-game verification

No code. Run each check; anything failing goes back to the task that owns it.

- [ ] **TBC Anniversary, mage** (the full flow of Task 7 step 3), plus in combat on a dummy or mob: Fire Vulnerability / Winter's Chill stacks on the target, Arcane Blast stacks on you, Clearcasting proc glows and plays the bell, Arcane Intellect "missing" only out of combat.
- [ ] **Classic Era / Hardcore, druid Wondersog**: `/vb spec`; TBC-only items absent (none in the druid list, so all listed); add the Feral set: Shred icon only in Cat Form while usable; Demoralizing Roar resolves to Dire Bear Form if known (tooltip of the added aura's form in the editor), else Bear Form.
- [ ] **Regressions**: export one template-made aura with Share and import it back (adds a copy); a class without templates shows the greyed button; Retail loads with no error and the greyed button.
- [ ] **WoW Forever** (when playable, not blocking the release): `/vb spec` output noted in the spec; window opens (on the first spec if detection fails); Clearcasting shows in combat.
- [ ] **Commit any fixes** with plain messages; then the branch is ready to merge.
