-- Stormrage - the flying mount for the old continents, chosen in the Mounts tab (WoW 3.3.5a).
-- Copyright (C) 2026 pabhoz - https://github.com/pabhoz/Stormrage-WoW-Addon
-- Licensed under the GNU General Public License v3.0 or later. See LICENSE.

-- On the realm's old continents a flying mount only takes off through the realm's own spell, "Alas de
-- los Condenados" (mod-azeroth-flight), which uses one mount the character chose. The choice lives where
-- mounts already are: the Mounts tab of the character window. Select a flying mount there and a button
-- "Usar en Azeroth" sets it; a line on the model says which one the spell uses now.
--
-- Through the addon channel (Channel.lua): ".volar lista" answers "M;<chosen spell or 0>" and
-- "V;<spell>;<speed>" per flying mount; ".volar elegir <spell>" chooses it without mounting.

local L = Stormrage.L
local locale = GetLocale()
if locale == "esES" or locale == "esMX" then
	L["Use in Azeroth"] = "Usar en Azeroth"
	L["Used in Azeroth"] = "Se usa en Azeroth"
	L["In Azeroth: %s"] = "En Azeroth: %s"
	L["In Azeroth: your fastest"] = "En Azeroth: tu montura mas rapida"
	L["Flying mount"] = "Montura de vuelo"
	L["Choose it in the Mounts tab"] = "Eligela en la pestana Monturas"
	L["Wings of the Damned will use %s in Kalimdor and the Eastern Kingdoms."] =
		"Alas de los Condenados usara %s en Kalimdor y los Reinos del Este."
	L["Wings of the Damned takes you up on this mount in Kalimdor and the Eastern Kingdoms."] =
		"Alas de los Condenados te sube a esta montura en Kalimdor y los Reinos del Este."
end

local Flight = {}
Stormrage.Flight = Flight

local ICON = "Interface\\Icons\\Ability_Druid_FlightForm"

local flying, chosen = nil, 0   -- the realm's answer: flying[spell] = speed; chosen = spell or 0
local button, line

---------------------------------------------------------------- the realm's answers

local function ParseList(lines)
	local out
	for _, l in ipairs(lines) do
		local c = l:match("^M;(%d+)$")
		if c then
			out = { chosen = tonumber(c), flying = {} }
		elseif out then
			local spell, speed = l:match("^V;(%d+);(%-?%d+)$")
			if spell then out.flying[tonumber(spell)] = tonumber(speed) end
		end
	end
	return out
end
Flight.ParseList = ParseList

---------------------------------------------------------------- the Mounts tab

-- The mount selected in the Mounts tab: its spell, or nil when the tab is not on mounts.
local function SelectedSpell()
	local frame = PetPaperDollFrameCompanionFrame
	if not frame or frame.mode ~= "MOUNT" or not PetPaperDollFrame_FindCompanionIndex then return end
	local index = PetPaperDollFrame_FindCompanionIndex(frame.idMount, "MOUNT")
	if not index or index == 0 then return end
	local _, _, spell = GetCompanionInfo("MOUNT", index)
	return spell
end

local function SpellName(spell)
	return (GetSpellInfo(spell)) or ("#" .. spell)
end

-- The button shows only on flying mounts; on the chosen one it says so and does nothing.
local function Update()
	if not button then return end
	local spell = SelectedSpell()
	if not flying or not spell then
		button:Hide() line:Hide()
		return
	end
	if chosen ~= 0 and flying[chosen] then
		line:SetText(L["In Azeroth: %s"]:format(SpellName(chosen)))
	else
		line:SetText(L["In Azeroth: your fastest"])
	end
	line:Show()
	if not flying[spell] then
		button:Hide()
	elseif spell == chosen then
		button:SetText(L["Used in Azeroth"])
		button:Disable()
		button:Show()
	else
		button:SetText(L["Use in Azeroth"])
		button:Enable()
		button:Show()
	end
end
Flight.Update = Update

function Flight.Refresh()
	Stormrage.Request("volar lista", function(ok, lines)
		local parsed = ok and ParseList(lines)
		if parsed then
			flying, chosen = parsed.flying, parsed.chosen
		else
			flying = nil   -- no flying mount, or a realm without the module: nothing to show
		end
		Update()
	end)
end

function Flight.Choose(spell)
	button:Disable()
	Stormrage.Request("volar elegir " .. spell, function(ok)
		if ok then
			chosen = spell
			DEFAULT_CHAT_FRAME:AddMessage("|cff70ea6c[Stormrage]|r " ..
				L["Wings of the Damned will use %s in Kalimdor and the Eastern Kingdoms."]:format(SpellName(spell)))
			Update()
		else
			Flight.Refresh()
		end
	end)
end

local function Attach()
	if button or not CompanionModelFrame or not PetPaperDollFrame_UpdateCompanions then return end
	button = CreateFrame("Button", "StormrageFlightButton", CompanionModelFrame, "UIPanelButtonTemplate")
	button:SetSize(130, 22)
	button:SetPoint("BOTTOM", CompanionModelFrame, "BOTTOM", 0, 6)
	button:SetScript("OnClick", function()
		local spell = SelectedSpell()
		if spell and flying and flying[spell] and spell ~= chosen then Flight.Choose(spell) end
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(L["Use in Azeroth"])
		GameTooltip:AddLine(L["Wings of the Damned takes you up on this mount in Kalimdor and the Eastern Kingdoms."], 1, 1, 1, true)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	button:Hide()

	line = CompanionModelFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	line:SetPoint("TOP", CompanionModelFrame, "TOP", 0, -6)
	line:Hide()

	-- Every selection, page or tab change in the window goes through this one function.
	hooksecurefunc("PetPaperDollFrame_UpdateCompanions", Update)
	PetPaperDollFrameCompanionFrame:HookScript("OnShow", Flight.Refresh)
end
Attach()

---------------------------------------------------------------- opening it

-- The character window on its Mounts tab.
function Flight.Open()
	if not (PetPaperDollFrame and PetPaperDollFrame:IsShown()) then ToggleCharacter("PetPaperDollFrame") end
	if PetPaperDollFrame_SetTab then PetPaperDollFrame_SetTab(3) end
end

-- A mount learned while the tab is open shows up in the realm's list.
local events = CreateFrame("Frame")
events:RegisterEvent("COMPANION_LEARNED")
events:SetScript("OnEvent", function()
	if PetPaperDollFrameCompanionFrame and PetPaperDollFrameCompanionFrame:IsShown() then Flight.Refresh() end
end)

SLASH_STORMRAGEFLIGHT1 = "/vuelo"
SLASH_STORMRAGEFLIGHT2 = "/montura"
SlashCmdList.STORMRAGEFLIGHT = function() Flight.Open() end

Stormrage.Register({
	name = L["Flying mount"],
	icon = ICON,
	description = L["Choose it in the Mounts tab"],
	onClick = function() Flight.Open() end,
})
