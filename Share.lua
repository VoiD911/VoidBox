--[[
    VoidBox - Share (export / import)

    A configuration travels as one line of text, "!VB:1!" + Base64 of a small
    serialized table, like WeakAuras strings. It can hold the active profile
    (appearance), the click bindings, the tracked buffs and the screen auras.

    Import never runs anything: the text is parsed as data only (no
    loadstring), with size and depth limits, and every field is checked
    against what VoidBox itself would store before it is applied. Macros are
    listed to the player before importing, since a macro runs when clicked.
    No compression: VoidBox settings are small, and this keeps the addon free
    of extra libraries.
]]

local addonName, VB = ...

local PREFIX = "!VB:1!"
local MAX_TEXT = 200000     -- characters accepted in an import
local MAX_DEPTH = 8
local MAX_ENTRIES = 3000

-------------------------------------------------
-- Serializer: T...E tables, S<len>:<bytes>, N<number>;, B0/B1
-------------------------------------------------
local function Serialize(v, out, depth)
    local t = type(v)
    if t == "table" then
        if depth > MAX_DEPTH then error("too deep") end
        out[#out + 1] = "T"
        for k, val in pairs(v) do
            local kt, vt = type(k), type(val)
            if (kt == "string" or kt == "number")
               and (vt == "table" or vt == "string" or vt == "number" or vt == "boolean") then
                Serialize(k, out, depth + 1)
                Serialize(val, out, depth + 1)
            end
        end
        out[#out + 1] = "E"
    elseif t == "string" then
        out[#out + 1] = "S" .. #v .. ":" .. v
    elseif t == "number" then
        out[#out + 1] = "N" .. string.format("%.17g", v) .. ";"
    elseif t == "boolean" then
        out[#out + 1] = v and "B1" or "B0"
    end
end

local entries
local function Parse(s, pos, depth)
    local tag = s:sub(pos, pos)
    if tag == "S" then
        local colon = s:find(":", pos + 1, true)
        local len = colon and tonumber(s:sub(pos + 1, colon - 1))
        if not len or len < 0 or len > 65535 or len % 1 ~= 0 then error("bad string") end
        local str = s:sub(colon + 1, colon + len)
        if #str ~= len then error("short string") end
        return str, colon + len + 1
    elseif tag == "N" then
        local semi = s:find(";", pos + 1, true)
        local n = semi and tonumber(s:sub(pos + 1, semi - 1))
        if not n or n ~= n or n == math.huge or n == -math.huge then error("bad number") end
        return n, semi + 1
    elseif tag == "B" then
        local b = s:sub(pos + 1, pos + 1)
        if b ~= "0" and b ~= "1" then error("bad boolean") end
        return b == "1", pos + 2
    elseif tag == "T" then
        if depth > MAX_DEPTH then error("too deep") end
        local t = {}
        pos = pos + 1
        while true do
            if pos > #s then error("unterminated table") end
            if s:sub(pos, pos) == "E" then return t, pos + 1 end
            local k, v
            k, pos = Parse(s, pos, depth + 1)
            if type(k) ~= "string" and type(k) ~= "number" then error("bad key") end
            v, pos = Parse(s, pos, depth + 1)
            t[k] = v
            entries = entries + 1
            if entries > MAX_ENTRIES then error("too many entries") end
        end
    end
    error("bad tag")
end

-------------------------------------------------
-- Base64
-------------------------------------------------
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64DEC = {}
for i = 1, 64 do B64DEC[B64:byte(i)] = i - 1 end

local function ToBase64(data)
    local out = {}
    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
            .. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end

local function FromBase64(str)
    str = str:gsub("[^%w%+/=]", "")
    if #str == 0 or #str % 4 ~= 0 then return nil end
    local out = {}
    for i = 1, #str, 4 do
        local s1, s2, s3, s4 = str:byte(i, i + 3)
        local d1, d2 = B64DEC[s1], B64DEC[s2]
        local d3 = s3 ~= 61 and B64DEC[s3] or nil
        local d4 = s4 ~= 61 and B64DEC[s4] or nil
        if not d1 or not d2 or (s3 ~= 61 and not d3) or (s4 ~= 61 and not d4) then return nil end
        local n = d1 * 262144 + d2 * 4096 + (d3 or 0) * 64 + (d4 or 0)
        out[#out + 1] = string.char(math.floor(n / 65536))
            .. (d3 and string.char(math.floor(n / 256) % 256) or "")
            .. (d4 and string.char(n % 256) or "")
    end
    return table.concat(out)
end

-------------------------------------------------
-- Export
-------------------------------------------------
local function AddonVersion()
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return get and get(addonName, "Version") or "?"
end

-- parts = { profile = bool, bindings = bool, buffs = bool, auras = bool }
function VB:ExportString(parts)
    local data = {
        addon = "VoidBox",
        version = AddonVersion(),
        client = VB.tocVersion,
        class = VB.playerClass,
        profileName = VB:GetActiveProfileName(),
        charName = UnitName("player"),
    }
    if parts.profile then
        data.profile = {}
        for _, key in ipairs(VB.profileKeys) do data.profile[key] = VB:CopyTable(VB.config[key]) end
        data.profile.hideExhaustionDebuffs = VB.config.hideExhaustionDebuffs
    end
    if parts.bindings then data.bindings = VB:CopyTable(VB.clickCastings) end
    if parts.buffs then data.buffs = VB:CopyTable(VB.customBuffs) end
    if parts.auras then data.auras = VB:CopyTable(VB.screenAuras) end

    local out = {}
    Serialize(data, out, 0)
    return PREFIX .. ToBase64(table.concat(out))
end

-------------------------------------------------
-- Import: decode, then rebuild every value from what VoidBox expects
-------------------------------------------------
local function Str(v, maxLen) return type(v) == "string" and #v <= (maxLen or 200) and v or nil end
local function Num(v, lo, hi)
    if type(v) ~= "number" then return nil end
    if lo and v < lo then v = lo end
    if hi and v > hi then v = hi end
    return v
end
local function Bool(v) if type(v) == "boolean" then return v end return nil end
local function SpellExists(id) return type(id) == "number" and VB:GetSpellName(id) ~= nil end

local function CleanPosition(p)
    if type(p) ~= "table" or not Str(p.point, 20) then return nil end
    return { point = p.point, relPoint = Str(p.relPoint, 20) or p.point,
             x = Num(p.x, -5000, 5000) or 0, y = Num(p.y, -5000, 5000) or 0 }
end

local function CleanProfile(src)
    if type(src) ~= "table" then return nil end
    local profile = {}
    local keys = {}
    for _, k in ipairs(VB.profileKeys) do keys[#keys + 1] = k end
    keys[#keys + 1] = "hideExhaustionDebuffs"
    for _, key in ipairs(keys) do
        local v, default = src[key], VB.defaults[key]
        if key:find("[Pp]osition$") then
            profile[key] = CleanPosition(v)
        elseif default == nil then
            -- no default to compare with: plain values only
            if type(v) ~= "table" then profile[key] = v end
        elseif type(v) == type(default) and type(v) ~= "table" then
            if type(v) == "string" then v = Str(v, 300) end
            profile[key] = v
        end
    end
    return profile
end

local ACTIONS = { spell = true, macro = true, target = true, focus = true,
                  togglemenu = true, assist = true, follow = true, rez = true }

-- Returns the cleaned binding, or nil plus a reason ("unknown" spell)
local function CleanBinding(b)
    if type(b) ~= "table" or not ACTIONS[b.action] then return nil end
    local mods = Str(b.mods, 20) or ""
    if not VB.MOD_PREFIXES[mods] then return nil end
    local clean = { mods = mods, action = b.action,
                    display = Str(b.display, 60), name = Str(b.name, 80) }
    if b.combo then
        -- The combo is written into a secure snippet between quotes: key
        -- characters only, nothing that could close the string
        clean.combo = Str(b.combo, 40)
        if not clean.combo or not clean.combo:match("^[%w%-%[%]%.,;/`=+*]+$") then return nil end
    elseif VB.MOUSE_KEY_IDS[b.mouse] then
        clean.mouse = b.mouse
    else
        return nil
    end
    if b.action == "spell" then
        -- Old bindings may hold a spell name instead of an ID
        -- (one line only: a name ends up in /cast macro text)
        local named = Str(b.value, 80) and b.value:match("^[^\n\r;]+$")
        if not SpellExists(b.value) and not named then return nil, "unknown" end
        clean.value = b.value
        clean.rankLocked = Bool(b.rankLocked) or nil
    elseif b.action == "macro" then
        clean.value = Str(b.value, 1023)
        if not clean.value then return nil end
    end
    if b.hostileAction == "spell" and SpellExists(b.hostileValue) then
        clean.hostileAction, clean.hostileValue = "spell", b.hostileValue
        clean.hostileRankLocked = Bool(b.hostileRankLocked) or nil
    elseif b.hostileAction == "macro" and Str(b.hostileValue, 1023) then
        clean.hostileAction, clean.hostileValue = "macro", b.hostileValue
        clean.hostileName = Str(b.hostileName, 80)
    end
    return clean
end

local function OneOf(v, list, default)
    for _, item in ipairs(list) do
        if (type(item) == "table" and item.value or item) == v then return v end
    end
    return default
end

local function CleanAura(a)
    if type(a) ~= "table" then return nil end
    local isType = a.source == "type"
    local source = OneOf(a.source, { "spell", "type", "usable" }, "spell")
    if not isType and not SpellExists(a.spellID) then return nil, "unknown" end
    local clean = VB:NewScreenAura(SpellExists(a.spellID) and a.spellID or nil)
    clean.source = source
    clean.dispelType = OneOf(a.dispelType, VB.AURA_DISPEL_TYPES, "any")
    clean.unit = OneOf(a.unit, { "player", "target" }, "player")
    clean.kind = OneOf(a.kind, { "HELPFUL", "HARMFUL" }, "HELPFUL")
    clean.show = OneOf(a.show, { "present", "missing", "expiring" }, "present")
    clean.expire = math.floor(Num(a.expire, 1, 60) or 5)
    clean.display = OneOf(a.display, { "icon", "bar", "frame", "disc" }, "icon")
    if Bool(a.countdown) ~= nil then clean.countdown = a.countdown end
    if SpellExists(a.form) then clean.form = a.form end
    if Bool(a.stacks) ~= nil then clean.stacks = a.stacks end
    clean.color = OneOf(a.color, VB.AURA_COLORS, "yellow")
    clean.sound = OneOf(a.sound, VB.AURA_SOUNDS, "none")
    clean.size = math.floor(Num(a.size, 16, 400) or 48)
    clean.x = Num(a.x, -3000, 3000) or 0
    clean.y = Num(a.y, -3000, 3000) or 150
    if Bool(a.mine) ~= nil then clean.mine = a.mine end
    if Bool(a.glow) ~= nil then clean.glow = a.glow end
    if Bool(a.enabled) ~= nil then clean.enabled = a.enabled end
    return clean
end

-- Decodes and cleans an import text. Returns a plan or nil, error.
function VB:ReadImportString(text)
    if type(text) ~= "string" then return nil end
    text = strtrim(text)
    if #text > MAX_TEXT or text:sub(1, #PREFIX) ~= PREFIX then return nil end
    local raw = FromBase64(text:sub(#PREFIX + 1))
    if not raw then return nil end
    entries = 0
    local ok, data = pcall(Parse, raw, 1, 0)
    if not ok or type(data) ~= "table" or data.addon ~= "VoidBox" then return nil end

    local plan = {
        from = { class = Str(data.class, 20) or "?", version = Str(data.version, 20) or "?",
                 client = Num(data.client) or 0, profileName = Str(data.profileName, 30) or "Import",
                 charName = Str(data.charName, 30) },
        unknown = 0,
        macros = {},
    }
    local function note(clean, why)
        if why == "unknown" then plan.unknown = plan.unknown + 1 end
        return clean
    end

    plan.profile = CleanProfile(data.profile)

    if type(data.bindings) == "table" then
        plan.bindings = {}
        for _, b in ipairs(data.bindings) do
            local clean = note(CleanBinding(b))
            if clean then
                plan.bindings[#plan.bindings + 1] = clean
                if clean.action == "macro" then
                    plan.macros[#plan.macros + 1] = { name = clean.name, body = clean.value }
                end
                if clean.hostileAction == "macro" then
                    plan.macros[#plan.macros + 1] = { name = clean.hostileName, body = clean.hostileValue }
                end
            end
        end
    end

    if type(data.buffs) == "table" then
        plan.buffs = {}
        for _, id in ipairs(data.buffs) do
            if SpellExists(id) then plan.buffs[#plan.buffs + 1] = id
            else plan.unknown = plan.unknown + 1 end
        end
    end

    if type(data.auras) == "table" then
        plan.auras = {}
        for _, a in ipairs(data.auras) do
            local clean = note(CleanAura(a))
            if clean then plan.auras[#plan.auras + 1] = clean end
        end
    end

    if not (plan.profile or plan.bindings or plan.buffs or plan.auras) then return nil end
    return plan
end

-- Named after the character who exported it (renamable in the Profiles tab)
local function ImportProfileName(plan)
    local base = plan.from.charName or plan.from.profileName
    return VB:SuggestProfileName(base and (base:gsub("[|\n\r]", "")) or nil)
end

-- parts says which of the plan's sections the player kept
function VB:ApplyImport(plan, parts)
    if InCombatLockdown() then
        VB:Print(VB.L["CANNOT_CONFIG_COMBAT"])
        return false
    end
    if parts.bindings and plan.bindings then
        wipe(VB.clickCastings)
        for _, b in ipairs(plan.bindings) do VB.clickCastings[#VB.clickCastings + 1] = b end
        VB:ApplyClickCastingsToAllFrames()
        if VB.RefreshBindingsList then VB:RefreshBindingsList() end
    end
    if parts.buffs and plan.buffs then
        wipe(VB.customBuffs)
        for _, id in ipairs(plan.buffs) do VB.customBuffs[#VB.customBuffs + 1] = id end
        VB:RefreshCustomBuffs()
    end
    if parts.auras and plan.auras then
        wipe(VB.screenAuras)
        for _, a in ipairs(plan.auras) do VB.screenAuras[#VB.screenAuras + 1] = a end
        VB:RebuildScreenAuras()
        if VB.RefreshScreenAurasTab then VB:RefreshScreenAurasTab() end
    end
    if parts.profile and plan.profile then
        local name = ImportProfileName(plan)
        if RAID_CLASS_COLORS and RAID_CLASS_COLORS[plan.from.class] then
            plan.profile._class = plan.from.class
        end
        VoidBoxDB.profiles[name] = plan.profile
        VB:SwitchProfile(name)
        if VB.RefreshProfilesTab then VB:RefreshProfilesTab() end
    end
    VB:Print(VB.L["SHARE_DONE"])
    return true
end

-------------------------------------------------
-- Dialogs
-------------------------------------------------
local function MakeDialog(name, title, height)
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(460, height)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.98)
    f:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()
    local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    t:SetPoint("TOP", 0, -10)
    t:SetText("|cFF9966FFVoidBox|r - " .. title)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    tinsert(UISpecialFrames, name)
    return f
end

local function MakeTextBox(parent, top, height)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 15, top)
    scroll:SetSize(405, height)
    local bg = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
    bg:SetPoint("TOPLEFT", scroll, -4, 4)
    bg:SetPoint("BOTTOMRIGHT", scroll, 4, -4)
    bg:SetColorTexture(0.05, 0.05, 0.05, 1)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetMaxLetters(0)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontNormal)
    box:SetWidth(400)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(box)
    return box
end

local function MakeButton(parent, text, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 110, 24)
    b:SetText(text)
    return b
end

local PARTS = { "profile", "bindings", "buffs", "auras" }
local PART_LABELS = {
    profile = "SHARE_PART_PROFILE", bindings = "SHARE_PART_BINDINGS",
    buffs = "SHARE_PART_BUFFS", auras = "SHARE_PART_AURAS",
}

local function MakePartChecks(parent, top, onChange)
    local checks = {}
    for i, part in ipairs(PARTS) do
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 12 + ((i - 1) % 2) * 215, top - math.floor((i - 1) / 2) * 26)
        cb.text:SetText(VB.L[PART_LABELS[part]])
        cb:SetChecked(true)
        cb:SetScript("OnClick", onChange)
        checks[part] = cb
    end
    return checks
end

local function CheckedParts(checks)
    local parts, any = {}, false
    for part, cb in pairs(checks) do
        parts[part] = cb:GetChecked() and cb:IsShown() and true or false
        any = any or parts[part]
    end
    return parts, any
end

local exportDialog
function VB:ShowExportDialog()
    if not exportDialog then
        local f = MakeDialog("VoidBoxExportDialog", VB.L["SHARE_EXPORT"], 360)
        local function Refresh()
            local parts, any = CheckedParts(f.checks)
            f.box:SetText(any and VB:ExportString(parts) or "")
            f.box:HighlightText()
            f.box:SetFocus()
        end
        f.checks = MakePartChecks(f, -40, Refresh)
        local help = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        help:SetPoint("TOPLEFT", 15, -100)
        help:SetText(VB.L["SHARE_EXPORT_HELP"])
        f.box = MakeTextBox(f, -120, 220)
        f.box:SetScript("OnMouseUp", function(self) self:HighlightText() end)
        f.Refresh = Refresh
        exportDialog = f
    end
    exportDialog:Show()
    exportDialog.Refresh()
end

local importDialog
function VB:ShowImportDialog()
    if InCombatLockdown() then
        VB:Print(VB.L["CANNOT_CONFIG_COMBAT"])
        return
    end
    if not importDialog then
        local f = MakeDialog("VoidBoxImportDialog", VB.L["SHARE_IMPORT"], 480)
        local help = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        help:SetPoint("TOPLEFT", 15, -40)
        help:SetText(VB.L["SHARE_IMPORT_HELP"])
        f.box = MakeTextBox(f, -60, 110)

        local checkBtn = MakeButton(f, VB.L["SHARE_CHECK"])
        checkBtn:SetPoint("TOPLEFT", 15, -182)

        f.checks = MakePartChecks(f, -212, function() end)
        for _, cb in pairs(f.checks) do cb:Hide() end

        local summary = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        summary:SetPoint("TOPLEFT", 15, -268)
        summary:SetWidth(430)
        summary:SetJustifyH("LEFT")
        summary:SetJustifyV("TOP")
        summary:SetHeight(165)
        summary:SetWordWrap(true)
        f.summary = summary

        local importBtn = MakeButton(f, VB.L["SHARE_IMPORT"])
        importBtn:SetPoint("BOTTOM", 0, 12)
        importBtn:Disable()
        f.importBtn = importBtn

        local function Reset()
            f.plan = nil
            importBtn:Disable()
            for _, cb in pairs(f.checks) do cb:Hide() end
            summary:SetText("")
        end
        f.box:SetScript("OnTextChanged", function(_, userInput) if userInput then Reset() end end)

        checkBtn:SetScript("OnClick", function()
            Reset()
            local plan = VB:ReadImportString(f.box:GetText())
            if not plan then
                summary:SetText("|cFFFF5555" .. VB.L["SHARE_INVALID"] .. "|r")
                return
            end
            f.plan = plan
            local L = VB.L
            local lines = { L["SHARE_SUMMARY_FROM"]:format(plan.from.class, plan.from.version,
                                                             tostring(plan.from.client)) }
            if plan.profile then
                f.checks.profile:Show(); f.checks.profile:SetChecked(true)
                lines[#lines + 1] = L["SHARE_SUMMARY_PROFILE"]:format(ImportProfileName(plan))
            end
            if plan.bindings then
                f.checks.bindings:Show(); f.checks.bindings:SetChecked(true)
                lines[#lines + 1] = L["SHARE_SUMMARY_BINDINGS"]:format(#plan.bindings)
            end
            if plan.buffs then
                f.checks.buffs:Show(); f.checks.buffs:SetChecked(true)
                lines[#lines + 1] = L["SHARE_SUMMARY_BUFFS"]:format(#plan.buffs)
            end
            if plan.auras then
                f.checks.auras:Show(); f.checks.auras:SetChecked(true)
                lines[#lines + 1] = L["SHARE_SUMMARY_AURAS"]:format(#plan.auras)
            end
            if plan.from.class ~= VB.playerClass and (plan.bindings or plan.buffs or plan.auras) then
                lines[#lines + 1] = "|cFFFFCC00" .. L["SHARE_OTHER_CLASS"]:format(plan.from.class) .. "|r"
            end
            if plan.unknown > 0 then
                lines[#lines + 1] = "|cFFFFCC00" .. L["SHARE_UNKNOWN_SPELLS"]:format(plan.unknown) .. "|r"
            end
            if #plan.macros > 0 then
                lines[#lines + 1] = "|cFFFF5555" .. L["SHARE_MACROS_WARNING"]:format(#plan.macros) .. "|r"
                for i, m in ipairs(plan.macros) do
                    if i > 4 then lines[#lines + 1] = "  ..." break end
                    local first = (m.body or ""):match("^[^\n]*") or ""
                    lines[#lines + 1] = "  - " .. (m.name or "?") .. ": |cFFAAAAAA" .. first:sub(1, 60) .. "|r"
                end
            end
            summary:SetText(table.concat(lines, "\n"))
            importBtn:Enable()
        end)

        importBtn:SetScript("OnClick", function()
            if not f.plan then return end
            local parts, any = CheckedParts(f.checks)
            if not any then
                VB:Print(VB.L["SHARE_NOTHING"])
                return
            end
            if VB:ApplyImport(f.plan, parts) then f:Hide() end
        end)
        f.Reset = Reset
        importDialog = f
    end
    importDialog.box:SetText("")
    importDialog.Reset()
    importDialog:Show()
    importDialog.box:SetFocus()
end
