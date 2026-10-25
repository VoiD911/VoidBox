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
      form     : "cat" / "bear" / a warrior stance, resolved when the aura is added
      also     : other spells that count as the same aura, best first (any
                 mage armor; Arcane Intellect or Arcane Brilliance). The aura
                 is made on the first one known, the others in entry.also
      label    : the window's name for an "any of these" aura (TEMPLATE_LABEL_<label>)
      tbc      : only on TBC (its ID is another spell on Era / Forever)
      spell    : may be { era = id, tbc = id } where the two clients differ
      always   : never hidden as not learned (a proc no one spell grants)
      note     : a limit worth telling (TEMPLATE_NOTE_<note> in the tooltip)
    Buffs someone else can give you (Arcane Intellect, Innervate...) set
    mine = false. Each aura added keeps its requires as entry.needs: it stays
    hidden until that spell is known (Auras.lua NeedsOK).
]]

local addonName, VB = ...

-- (shorthand for the many "missing on the target, in combat" debuffs)
local function OnTarget(spell, extra)
    local item = { spell = spell, show = "missing", unit = "target", kind = "HARMFUL",
                   combat = "in", hostileTarget = true }
    for k, v in pairs(extra or {}) do item[k] = v end
    return item
end

VB.AURA_TEMPLATES = {
    DRUID = {
        common = {
            { spell = 16870, requires = 16864, glow = true, sound = "bell" },     -- Clearcasting (Omen of Clarity)
            { spell = 1126, also = { 21849 }, show = "missing", combat = "out", mine = false }, -- Mark / Gift of the Wild
            { spell = 467, show = "missing", combat = "out", mine = false },      -- Thorns
        },
        specs = {
            { key = "BALANCE", items = {
                OnTarget(8921),                                                   -- Moonfire
                OnTarget(5570),                                                   -- Insect Swarm
                OnTarget(770),                                                    -- Faerie Fire
            } },
            { key = "FERAL", groups = {
                { key = "CAT", items = {
                    { spell = 5221, source = "usable", form = "cat" },            -- Shred
                    OnTarget(1822, { form = "cat" }),                             -- Rake
                    { spell = 1079, unit = "target", kind = "HARMFUL", display = "bar",
                      countdown = true, form = "cat" },                           -- Rip
                    { spell = 5217, countdown = true, form = "cat" },             -- Tiger's Fury
                } },
                { key = "BEAR", items = {
                    OnTarget(99, { form = "bear" }),                              -- Demoralizing Roar
                    OnTarget(16857, { form = "bear" }),                           -- Faerie Fire (Feral) (not on Forever)
                } },
            } },
            { key = "RESTORATION", items = {
                { spell = 17116, glow = true },                                   -- Nature's Swiftness
                { spell = 29166, countdown = true, mine = false },                -- Innervate
            } },
        },
    },

    MAGE = {
        common = {
            { spell = 1459, also = { 23028 }, show = "missing", combat = "out", mine = false }, -- Arcane Intellect / Brilliance
            { spell = 30482, also = { 6117, 7302, 168 }, show = "missing", combat = "out",
              label = "ANY_ARMOR" },                                              -- Molten, Mage, Ice, Frost Armor
            { spell = 12536, requires = 11213, glow = true, sound = "bell" },     -- Clearcasting (Arcane Concentration)
        },
        specs = {
            { key = "ARCANE", items = {
                { spell = 12042, countdown = true },                              -- Arcane Power
                { spell = 12043, glow = true },                                   -- Presence of Mind
                { spell = 36032, requires = 30451, kind = "HARMFUL", mine = false }, -- Arcane Blast (TBC), its stacks on me
            } },
            { key = "FIRE", items = {
                { spell = 11129 },                                                -- Combustion
                { spell = 22959, requires = 11095, unit = "target", kind = "HARMFUL", mine = false,
                  display = "bar", countdown = true },                            -- Fire Vulnerability (Improved Scorch)
            } },
            { key = "FROST", items = {
                { spell = 12472, tbc = true, countdown = true },                  -- Icy Veins (12472 is Cold Snap on Era / Forever)
                { spell = 11426, show = "missing", combat = "in" },               -- Ice Barrier
                { spell = 12579, requires = 11180, unit = "target", kind = "HARMFUL", mine = false }, -- Winter's Chill
            } },
        },
    },

    WARRIOR = {
        common = {
            { spell = 6673, show = "missing", combat = "in", mine = false },      -- Battle Shout
            { spell = 5308, source = "usable" },                                  -- Execute
        },
        specs = {
            { key = "ARMS", items = {
                { spell = 7384, source = "usable", form = "battle" },             -- Overpower
                OnTarget(772),                                                    -- Rend
                { spell = 12294, source = "usable" },                             -- Mortal Strike
                { spell = { era = 12292, tbc = 12328 }, countdown = true },       -- Sweeping Strikes (IDs swapped in TBC)
            } },
            { key = "FURY", items = {
                { spell = 23881, source = "usable" },                             -- Bloodthirst
                { spell = 12880, requires = 12317 },                              -- Enrage (talent)
                { spell = 12966, requires = 12319 },                              -- Flurry (talent)
                { spell = { era = 12328, tbc = 12292 }, countdown = true },       -- Death Wish (IDs swapped in TBC)
                { spell = 1680, source = "usable", form = "berserker" },          -- Whirlwind
            } },
            { key = "PROTECTION", items = {
                { spell = 7386, unit = "target", kind = "HARMFUL", mine = false,
                  display = "bar", countdown = true },                            -- Sunder Armor, its stacks
                OnTarget(1160, { mine = false }),                                 -- Demoralizing Shout
                OnTarget(6343, { mine = false }),                                 -- Thunder Clap
                { spell = 6572, source = "usable", form = "defensive" },          -- Revenge
                { spell = 2565, countdown = true },                               -- Shield Block
            } },
        },
    },

    PALADIN = {
        common = {
            { spell = 19740, also = { 19742, 20217, 1038, 19977, 20911, 25782, 25894, 25898, 25895, 25890, 25899 },
              show = "missing", combat = "out", mine = false, label = "ANY_BLESSING" }, -- any Blessing, Greater too
            { spell = 465, also = { 7294, 19746, 19876, 19888, 19891, 20218, 32223 },
              show = "missing", mine = false, label = "ANY_AURA" },               -- any Aura
            { spell = 20154, also = { 21082, 20165, 20166, 20164, 20375, 31892, 31801 },
              show = "missing", combat = "in", label = "ANY_SEAL" },              -- any Seal
        },
        specs = {
            { key = "HOLY", items = {
                { spell = 20216, glow = true },                                   -- Divine Favor
                { spell = 31834, requires = 31833 },                              -- Light's Grace (TBC)
            } },
            { key = "PROTECTION", items = {
                { spell = 25780, show = "missing" },                              -- Righteous Fury
                { spell = 20925, show = "missing", combat = "in" },               -- Holy Shield
            } },
            { key = "RETRIBUTION", items = {
                { spell = 20050, requires = 20049 },                              -- Vengeance (talent)
                { spell = 24275, source = "usable" },                             -- Hammer of Wrath
            } },
        },
    },

    HUNTER = {
        common = {
            { spell = 13165, also = { 13163, 5118, 13159, 20043, 13161, 34074 },
              show = "missing", label = "ANY_ASPECT" },                           -- any Aspect
            OnTarget(1130, { mine = false }),                                     -- Hunter's Mark
        },
        specs = {
            { key = "BEAST_MASTERY", items = {
                { spell = 19574, countdown = true },                              -- Bestial Wrath
                { spell = 34026, source = "usable" },                             -- Kill Command (TBC)
            } },
            { key = "MARKSMANSHIP", items = {
                { spell = 19506, show = "missing", combat = "out", mine = false }, -- Trueshot Aura
                { spell = 3045, countdown = true },                               -- Rapid Fire
                OnTarget(1978),                                                   -- Serpent Sting
            } },
            { key = "SURVIVAL", items = {
                { spell = 1495, source = "usable" },                              -- Mongoose Bite
                { spell = 19306, source = "usable" },                             -- Counterattack
                { spell = 19263, countdown = true },                              -- Deterrence
            } },
        },
    },

    ROGUE = {
        common = {
            { spell = 5171, display = "bar", countdown = true },                  -- Slice and Dice
            { spell = 2983, countdown = true },                                   -- Sprint
        },
        specs = {
            { key = "ASSASSINATION", items = {
                { spell = 14177, glow = true },                                   -- Cold Blood
                OnTarget(1943),                                                   -- Rupture
            } },
            { key = "COMBAT", items = {
                { spell = 13750, countdown = true },                              -- Adrenaline Rush
                { spell = 13877, countdown = true },                              -- Blade Flurry
                { spell = 14251, source = "usable" },                             -- Riposte
            } },
            { key = "SUBTLETY", items = {
                { spell = 16511, unit = "target", kind = "HARMFUL" },             -- Hemorrhage, its charges
                { spell = 14278, countdown = true },                              -- Ghostly Strike
            } },
        },
    },

    PRIEST = {
        common = {
            { spell = 1243, also = { 21562 }, show = "missing", combat = "out", mine = false }, -- Fortitude / Prayer
            { spell = 588, show = "missing" },                                    -- Inner Fire
        },
        specs = {
            { key = "DISCIPLINE", items = {
                { spell = 14752, also = { 27681 }, show = "missing", combat = "out", mine = false }, -- Divine Spirit / Prayer
                { spell = 14751, glow = true },                                   -- Inner Focus
                { spell = 10060, countdown = true, mine = false },                -- Power Infusion
            } },
            { key = "HOLY", items = {
                { spell = 34754, requires = 34753, glow = true, sound = "bell" }, -- Clearcasting (Holy Concentration, TBC)
                { spell = 33151, requires = 33150, glow = true },                 -- Surge of Light (TBC)
            } },
            { key = "SHADOW", items = {
                { spell = 15473, show = "missing" },                              -- Shadowform
                OnTarget(589),                                                    -- Shadow Word: Pain
                OnTarget(34914),                                                  -- Vampiric Touch (TBC)
                OnTarget(15286),                                                  -- Vampiric Embrace
                { spell = 15258, requires = 15257, unit = "target", kind = "HARMFUL", mine = false }, -- Shadow Vulnerability (Shadow Weaving)
            } },
        },
    },

    SHAMAN = {
        common = {
            { spell = 324, also = { 24398 }, show = "missing", label = "ANY_SHIELD" }, -- Lightning / Water Shield
        },
        specs = {
            { key = "ELEMENTAL", items = {
                { spell = 16246, requires = 16164, glow = true, sound = "bell" }, -- Clearcasting (Elemental Focus)
                { spell = 16166, glow = true },                                   -- Elemental Mastery
                OnTarget(8050),                                                   -- Flame Shock
            } },
            { key = "ENHANCEMENT", items = {
                { spell = 16257, requires = 16256 },                              -- Flurry (talent)
                { spell = 17364, source = "usable" },                             -- Stormstrike
                { spell = 30823, countdown = true },                              -- Shamanistic Rage (TBC)
            } },
            { key = "RESTORATION", items = {
                { spell = 16188, glow = true },                                   -- Nature's Swiftness
            } },
        },
    },

    WARLOCK = {
        common = {
            { spell = 28176, also = { 706, 687 }, show = "missing", label = "ANY_ARMOR" }, -- Fel / Demon Armor, Demon Skin
        },
        specs = {
            { key = "AFFLICTION", items = {
                { spell = 17941, requires = 18094, glow = true, sound = "bell" }, -- Shadow Trance (Nightfall)
                OnTarget(172),                                                    -- Corruption
                OnTarget(980),                                                    -- Curse of Agony (Bane of Agony on Forever)
                OnTarget(30108),                                                  -- Unstable Affliction (TBC)
                OnTarget(18265),                                                  -- Siphon Life
            } },
            { key = "DEMONOLOGY", items = {
                { spell = 19028, show = "missing" },                              -- Soul Link
            } },
            { key = "DESTRUCTION", items = {
                OnTarget(348),                                                    -- Immolate
                { spell = 34936, requires = 34935, glow = true },                 -- Backlash (TBC)
                { spell = 17962, source = "usable" },                             -- Conflagrate
                { spell = 17794, requires = 17793, unit = "target", kind = "HARMFUL", mine = false }, -- Shadow Vulnerability (Improved Shadow Bolt)
            } },
        },
    },
}

-- Retail (12.x): its own spells and specs. Specs are GetSpecialization's
-- order. Many auras are buffs or debuffs with an ID of their own, not the
-- spell's: requires names the spell (so the aura waits until it is learned);
-- procs the addon cannot tie to one spell are always = true (never hidden).
-- IDs checked against wago.tools' SpellName for 12.1.5.70575; the debuff on
-- the player picked by spell (Stagger) is left out: Midnight hides it in combat.
VB.AURA_TEMPLATES_RETAIL = {
    DRUID = {
        common = {
            { spell = 1126, show = "missing", combat = "out", mine = false },     -- Mark of the Wild
        },
        specs = {
            { key = "BALANCE", items = {
                OnTarget(164812, { requires = 8921 }),                            -- Moonfire
                OnTarget(164815, { requires = 93402 }),                           -- Sunfire
                { spell = 48517, always = true },                                 -- Eclipse (Solar)
                { spell = 48518, always = true },                                 -- Eclipse (Lunar)
            } },
            { key = "FERAL", items = {
                OnTarget(155722, { requires = 1822 }),                            -- Rake
                { spell = 1079, unit = "target", kind = "HARMFUL", display = "bar", countdown = true }, -- Rip
                { spell = 5217, countdown = true },                               -- Tiger's Fury
                { spell = 135700, always = true, glow = true },                   -- Clearcasting
                { spell = 145152, always = true },                                -- Bloodtalons
            } },
            { key = "GUARDIAN", items = {
                { spell = 192081, show = "missing", combat = "in" },              -- Ironfur
                OnTarget(192090, { requires = 77758 }),                           -- Thrash
                OnTarget(164812, { requires = 8921 }),                            -- Moonfire
            } },
            { key = "RESTORATION", items = {
                { spell = 16870, always = true, glow = true },                    -- Clearcasting
                { spell = 114108, always = true },                                -- Soul of the Forest
            } },
        },
    },

    MAGE = {
        common = {
            { spell = 1459, show = "missing", combat = "out", mine = false },     -- Arcane Intellect
        },
        specs = {
            { key = "ARCANE", items = {
                { spell = 263725, always = true, glow = true, sound = "bell" },   -- Clearcasting
                { spell = 365362, always = true, countdown = true },              -- Arcane Surge
            } },
            { key = "FIRE", items = {
                { spell = 48107, always = true },                                 -- Heating Up
                { spell = 48108, always = true, glow = true, sound = "bell" },    -- Hot Streak!
                { spell = 190319, countdown = true },                             -- Combustion
            } },
            { key = "FROST", items = {
                { spell = 44544, always = true, glow = true },                    -- Fingers of Frost
                { spell = 190446, always = true, glow = true, sound = "bell" },   -- Brain Freeze
                { spell = 12472, countdown = true },                              -- Icy Veins
            } },
        },
    },

    WARRIOR = {
        common = {
            { spell = 6673, show = "missing", combat = "in", mine = false },      -- Battle Shout
        },
        specs = {
            { key = "ARMS", items = {
                OnTarget(262115, { always = true }),                              -- Deep Wounds
                { spell = 260708, countdown = true },                             -- Sweeping Strikes
                { spell = 208086, requires = 167105, unit = "target", kind = "HARMFUL", countdown = true }, -- Colossus Smash
            } },
            { key = "FURY", items = {
                { spell = 184362, always = true },                                -- Enrage
                { spell = 1719, countdown = true },                               -- Recklessness
                { spell = 85739, always = true },                                 -- Whirlwind (its buff)
            } },
            { key = "PROTECTION", items = {
                { spell = 132404, requires = 2565, show = "missing", combat = "in" }, -- Shield Block
                { spell = 190456 },                                               -- Ignore Pain
                { spell = 107574, countdown = true },                             -- Avatar
            } },
        },
    },

    PALADIN = {
        common = {
            { spell = 465, also = { 317920, 32223 }, show = "missing", mine = false, label = "ANY_AURA" }, -- any Aura
        },
        specs = {
            { key = "HOLY", items = {
                { spell = 54149, always = true, glow = true },                    -- Infusion of Light
                { spell = 223819, always = true, glow = true },                   -- Divine Purpose
            } },
            { key = "PROTECTION", items = {
                { spell = 132403, requires = 53600, show = "missing", combat = "in" }, -- Shield of the Righteous
                { spell = 188370, requires = 26573 },                             -- Consecration
                { spell = 31884, countdown = true },                              -- Avenging Wrath
            } },
            { key = "RETRIBUTION", items = {
                { spell = 31884, countdown = true },                              -- Avenging Wrath
                { spell = 223819, always = true, glow = true },                   -- Divine Purpose
            } },
        },
    },

    HUNTER = {
        common = {
            { spell = 186257, countdown = true },                                 -- Aspect of the Cheetah
        },
        specs = {
            { key = "BEAST_MASTERY", items = {
                { spell = 19574, countdown = true },                              -- Bestial Wrath
                { spell = 272790, always = true, unit = "pet", mine = false },    -- Frenzy (on the pet)
                { spell = 268877, always = true },                                -- Beast Cleave
            } },
            { key = "MARKSMANSHIP", items = {
                { spell = 288613, countdown = true },                             -- Trueshot
                { spell = 257622, always = true },                                -- Trick Shots
                { spell = 194594, always = true, glow = true },                   -- Lock and Load
            } },
            { key = "SURVIVAL", items = {
                OnTarget(259491, { always = true }),                              -- Serpent Sting
                { spell = 360966, countdown = true },                             -- Spearhead
            } },
        },
    },

    ROGUE = {
        common = {
            { spell = 315496, display = "bar", countdown = true },                -- Slice and Dice
            { spell = 2823, also = { 315584, 8679, 381664 }, show = "missing", combat = "out",
              label = "ANY_POISON" },                                             -- any poison
        },
        specs = {
            { key = "ASSASSINATION", items = {
                OnTarget(1943),                                                   -- Rupture
                OnTarget(703),                                                    -- Garrote
            } },
            { key = "OUTLAW", items = {
                { spell = 13750, countdown = true },                              -- Adrenaline Rush
                { spell = 13877, countdown = true },                              -- Blade Flurry
                { spell = 195627, always = true, glow = true },                   -- Opportunity
            } },
            { key = "SUBTLETY", items = {
                { spell = 185422, requires = 185313, countdown = true },          -- Shadow Dance
                { spell = 121471, countdown = true },                             -- Shadow Blades
            } },
        },
    },

    PRIEST = {
        common = {
            { spell = 21562, show = "missing", combat = "out", mine = false },    -- Power Word: Fortitude
        },
        specs = {
            { key = "DISCIPLINE", items = {
                { spell = 194384, always = true },                                -- Atonement
                { spell = 10060, countdown = true, mine = false },                -- Power Infusion
            } },
            { key = "HOLY", items = {
                { spell = 114255, always = true, glow = true },                   -- Surge of Light
                { spell = 196490, always = true },                                -- Sanctified Prayers
            } },
            { key = "SHADOW", items = {
                { spell = 232698, show = "missing" },                             -- Shadowform
                OnTarget(589),                                                    -- Shadow Word: Pain
                OnTarget(34914),                                                  -- Vampiric Touch
                { spell = 194249, requires = 228260, countdown = true },          -- Voidform
            } },
        },
    },

    DEATHKNIGHT = {
        common = {},
        specs = {
            { key = "BLOOD", items = {
                { spell = 195181, requires = 195182, show = "missing", combat = "in" }, -- Bone Shield
                OnTarget(55078, { requires = 50842 }),                            -- Blood Plague
            } },
            { key = "FROST", items = {
                { spell = 51124, always = true, glow = true },                    -- Killing Machine
                { spell = 59052, always = true, glow = true },                    -- Rime
                OnTarget(55095, { requires = 49184 }),                            -- Frost Fever
            } },
            { key = "UNHOLY", items = {
                OnTarget(191587, { requires = 77575 }),                           -- Virulent Plague
                { spell = 194311, requires = 85948, unit = "target", kind = "HARMFUL" }, -- Festering Wound, its stacks
                { spell = 81340, always = true, glow = true },                    -- Sudden Doom
            } },
        },
    },

    SHAMAN = {
        common = {
            { spell = 192106, also = { 52127, 974 }, show = "missing", label = "ANY_SHIELD" }, -- Lightning / Water / Earth Shield
        },
        specs = {
            { key = "ELEMENTAL", items = {
                OnTarget(188389),                                                 -- Flame Shock
                { spell = 77762, always = true, glow = true },                    -- Lava Surge
            } },
            { key = "ENHANCEMENT", items = {
                { spell = 344179, always = true },                                -- Maelstrom Weapon, its stacks
                OnTarget(188389),                                                 -- Flame Shock
            } },
            { key = "RESTORATION", items = {
                { spell = 53390, always = true },                                 -- Tidal Waves
                { spell = 378081, glow = true },                                  -- Nature's Swiftness
            } },
        },
    },

    WARLOCK = {
        common = {},
        specs = {
            { key = "AFFLICTION", items = {
                OnTarget(146739, { requires = 172 }),                             -- Corruption
                OnTarget(980),                                                    -- Agony
                OnTarget(30108),                                                  -- Unstable Affliction (check in game)
            } },
            { key = "DEMONOLOGY", items = {
                { spell = 264173, always = true },                                -- Demonic Core, its stacks
            } },
            { key = "DESTRUCTION", items = {
                OnTarget(157736, { requires = 348 }),                             -- Immolate
                { spell = 117828, always = true },                                -- Backdraft
            } },
        },
    },

    MONK = {
        common = {},
        specs = {
            { key = "BREWMASTER", items = {
                { spell = 215479, always = true, show = "missing", combat = "in" }, -- Shuffle
            } },
            { key = "WINDWALKER", items = {
                { spell = 116768, always = true, glow = true },                   -- Blackout Kick!
                { spell = 202090, always = true },                                -- Teachings of the Monastery
            } },
            { key = "MISTWEAVER", items = {
                { spell = 116680, glow = true },                                  -- Thunder Focus Tea
                { spell = 119611, requires = 115151 },                            -- Renewing Mist
            } },
        },
    },

    DEMONHUNTER = {
        common = {},
        specs = {
            { key = "HAVOC", items = {
                { spell = 162264, requires = 191427, countdown = true },          -- Metamorphosis
            } },
            { key = "VENGEANCE", items = {
                { spell = 203819, requires = 203720, show = "missing", combat = "in" }, -- Demon Spikes
                { spell = 207771, requires = 204021, unit = "target", kind = "HARMFUL", countdown = true }, -- Fiery Brand
                { spell = 187827, countdown = true },                             -- Metamorphosis
            } },
        },
    },

    EVOKER = {
        common = {},
        specs = {
            { key = "DEVASTATION", items = {
                { spell = 359618, always = true, glow = true },                   -- Essence Burst
                { spell = 375802, always = true },                                -- Burnout
            } },
            { key = "PRESERVATION", items = {
                { spell = 369299, always = true, glow = true },                   -- Essence Burst
            } },
            { key = "AUGMENTATION", items = {
                { spell = 395152, countdown = true },                             -- Ebon Might
            } },
        },
    },
}

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
-- On Retail the specialization itself (Forever.lua's shim)
function VB:GetTalentSpec()
    if (VB.tocVersion or 0) >= 100000 then return VB:GetPlayerSpecIndex() end
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
    if (VB.tocVersion or 0) >= 100000 then n = 0 end   -- (Retail: specializations, below)
    if n == 0 then
        local spec = VB:GetTalentSpec()
        if spec then
            VB:Print(L["SPEC_DETECTED"]:format(tostring(spec)))
        else
            VB:Print(L["SPEC_NO_TALENTS"])
        end
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
    battle = { 2457 },      -- warrior stances
    defensive = { 71 },
    berserker = { 2458 },
}

-- The client's ruleset for the templates: "era" (Classic Era, WoW Forever),
-- "tbc" (TBC Anniversary), or "retail" (its own lists, AURA_TEMPLATES_RETAIL)
local function Flavor()
    local toc = VB.tocVersion or 0
    if toc >= 100000 then return "retail" end
    if toc >= 20000 then return "tbc" end
    return "era"
end

-- This class's templates on this client, or nil
function VB:GetAuraTemplates()
    if Flavor() == "retail" then return VB.AURA_TEMPLATES_RETAIL[VB.playerClass] end
    return VB.AURA_TEMPLATES[VB.playerClass]
end

-- The item's own spell on this client ({ era, tbc } where they differ), nil
-- where it has none (a TBC-only item elsewhere: its ID can be another spell)
function VB:TemplateItemSpell(item)
    if item.tbc and Flavor() ~= "tbc" then return nil end
    if type(item.spell) == "table" then return item.spell[Flavor()] end
    return item.spell
end

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

-- The item's spells this client has, best first: its spell, then its also
function VB:TemplateItemSpells(item)
    local list = {}
    local own = VB:TemplateItemSpell(item)
    if own and VB:GetSpellName(own) then list[1] = own end
    for _, id in ipairs(item.also or {}) do
        if VB:GetSpellName(id) then list[#list + 1] = id end
    end
    return list
end

-- The spell the aura is made on: the first one known, else the first one
-- this client has (nil when it has none)
function VB:TemplatePrimary(item)
    local spells = VB:TemplateItemSpells(item)
    for _, id in ipairs(spells) do
        if VB:KnowsSpell(id) then return id end
    end
    return spells[1]
end

-- "absent" (not on this client: not offered), "added" (an aura on one of its
-- spells, same kind of trigger, mode and unit exists), "unlearned", or "ok"
function VB:TemplateItemState(item)
    local spells = VB:TemplateItemSpells(item)
    if #spells == 0 then return "absent" end
    local mine = {}
    for _, id in ipairs(spells) do mine[id] = true end
    local source, show, unit = item.source or "spell", item.show or "present", item.unit or "player"
    for _, e in ipairs(VB.screenAuras or {}) do
        if mine[e.spellID] and (e.source or "spell") == source
            and (e.show or "present") == show and (e.unit or "player") == unit then
            return "added"
        end
    end
    if item.always then
        return "ok"
    elseif item.requires then
        if not VB:KnowsSpell(item.requires) then return "unlearned" end
    elseif not VB:KnowsSpell(VB:TemplatePrimary(item)) then
        return "unlearned"
    end
    return "ok"
end

-------------------------------------------------
-- Adding
-------------------------------------------------
local COPIED = { "source", "show", "unit", "kind", "mine", "combat", "group", "hostileTarget",
                 "inRange", "display", "countdown", "stacks", "glow", "sound", "color" }

-- The entry for an item (not stored), or nil when the client refuses it
function VB:BuildTemplateAura(item)
    local primary = VB:TemplatePrimary(item)
    if not primary then return nil end
    local raw = VB:NewScreenAura(primary)
    for _, key in ipairs(COPIED) do
        if item[key] ~= nil then raw[key] = item[key] end
    end
    -- The item's other spells count as the same aura (Auras.lua ResolveIDs)
    local also = {}
    for _, id in ipairs(VB:TemplateItemSpells(item)) do
        if id ~= primary then also[#also + 1] = id end
    end
    raw.also = #also > 0 and also or nil
    -- A form not learned yet: no form condition rather than a wrong one
    raw.form = item.form and VB:TemplateFormSpell(item.form, true) or nil
    -- Quiet until its spell is known (Auras.lua NeedsOK); a proc tied to no
    -- one spell (always) is never held back
    raw.needs = not item.always and (item.requires or primary) or nil
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
-- first, says how many. Returns that count. With a group name the row is a
-- new screen group of that name (Auras.lua), moved and sized as one.
function VB:AddTemplateAuras(items, groupName)
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
    -- In a group the row sits on the group's centre (placed at 0, 150)
    local key = groupName and #entries > 0 and VB:NewScreenGroup(groupName, 0, 150) or nil
    local first, x = #VB.screenAuras + 1, -total / 2
    for _, entry in ipairs(entries) do
        local w = WidthOf(entry)
        entry.x, entry.y = math.floor(x + w / 2 + 0.5), key and 0 or 150
        entry.screenGroup = key
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
