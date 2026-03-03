--[[
    VoidBox - Minimap Button
    Uses LibDataBroker + LibDBIcon for standard minimap icon.
    Left-click: toggle frames visibility
    Right-click: open config
]]

local addonName, VB = ...

local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

-- Data broker object
local vbBroker = LDB:NewDataObject("VoidBox", {
    type = "launcher",
    icon = "Interface\\Icons\\Spell_Holy_Heal",
    OnClick = function(self, button)
        if button == "LeftButton" then
            if VB.frames.main then
                if VB.frames.main:IsShown() then
                    VB.frames.main:Hide()
                    if VB.frames.handle then VB.frames.handle:Hide() end
                    VB:Print(VB.L["MINIMAP_FRAMES_HIDDEN"])
                else
                    VB.frames.main:Show()
                    if VB.frames.handle and not VB.config.locked then
                        VB.frames.handle:Show()
                    end
                    VB:Print(VB.L["MINIMAP_FRAMES_SHOWN"])
                end
            end
        elseif button == "RightButton" then
            VB:ShowConfig()
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("|cFF9966FFVoidBox|r")
        tooltip:AddLine(VB.L["MINIMAP_LEFT_CLICK"], 1, 1, 1)
        tooltip:AddLine(VB.L["MINIMAP_RIGHT_CLICK"], 0.7, 0.7, 0.7)
    end,
})

-- Register minimap button after addon is loaded
function VB:InitMinimapButton()
    if not VoidBoxDB.minimap then
        VoidBoxDB.minimap = { hide = false }
    end
    LDBIcon:Register("VoidBox", vbBroker, VoidBoxDB.minimap)
end

-- Show/Hide minimap button
function VB:SetMinimapButtonShown(shown)
    if not VoidBoxDB.minimap then return end
    VoidBoxDB.minimap.hide = not shown
    if shown then
        LDBIcon:Show("VoidBox")
    else
        LDBIcon:Hide("VoidBox")
    end
end

function VB:IsMinimapButtonShown()
    return VoidBoxDB.minimap and not VoidBoxDB.minimap.hide
end
