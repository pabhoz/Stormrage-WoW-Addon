-- Stormrage - talent profiles panel (WoW 3.3.5a).
-- Copyright (C) 2026 pabhoz - https://github.com/pabhoz/Stormrage-WoW-Addon
-- Licensed under the GNU General Public License v3.0 or later. See LICENSE.

-- A window for the realm's talent profiles (.perfil on the Stormrage server): each
-- profile is one spec (talents, glyphs and action bars) saved on the server and
-- loaded over the active spec. The client keeps its two native specs; this is a
-- library on top of them.
--
-- It talks to the server through AzerothCore's addon command channel: an addon
-- whisper to oneself with prefix "AzerothCore" and body "i" .. 4-char id .. command.
-- The server answers on the same prefix: "m" .. id .. line for each message, then
-- "o" .. id (done) or "f" .. id (failed). Nothing is printed in the chat.

local L = Stormrage.L
local locale = GetLocale()
if locale == "esES" or locale == "esMX" then
	L["Talent profiles"] = "Perfiles de talentos"
	L["Save and load whole specs"] = "Guarda y carga specs completas"
	L["Active spec: %s"] = "Spec activa: %s"
	L["Primary"] = "Primaria"
	L["Secondary"] = "Secundaria"
	L["Loading a profile replaces your active spec. The other one is not touched."] = "Cargar un perfil reemplaza tu spec activa. La otra no se toca."
	L["%d of %d"] = "%d de %d"
	L["Load"] = "Cargar"
	L["Delete"] = "Borrar"
	L["Save active spec"] = "Guardar spec activa"
	L["Profile name"] = "Nombre del perfil"
	L["No profiles yet. Type a name and save your active spec."] = "Aun no tienes perfiles. Escribe un nombre y guarda tu spec activa."
	L["Asking the realm..."] = "Consultando al reino..."
	L["The realm did not answer."] = "El reino no respondio."
	L["This realm has no talent profiles."] = "Este reino no tiene perfiles de talentos."
	L["Name: 1 to 24 letters, numbers, spaces, '-' or '_'."] = "Nombre: de 1 a 24 letras, numeros, espacios, '-' o '_'."
	L["Load |cff00ff00%s|r into your %s spec?\n\nThe talents, glyphs and bars of that spec are replaced. Save them first if you want to keep them."] =
		"Cargar |cff00ff00%s|r en tu spec %s?\n\nSe reemplazan los talentos, glifos y barras de esa spec. Guardala antes si la quieres conservar."
	L["Delete the profile |cff00ff00%s|r?"] = "Borrar el perfil |cff00ff00%s|r?"
	L["Replace the profile |cff00ff00%s|r with your active spec?"] = "Reemplazar el perfil |cff00ff00%s|r con tu spec activa?"
	L["no talents"] = "sin talentos"
	L["Stormrage talent profiles"] = "Perfiles de talentos de Stormrage"
end

local Loadouts = {}
Stormrage.Loadouts = Loadouts

local PREFIX = "AzerothCore"
local TIMEOUT = 6
local MAX_ROWS = 10
local ICON = "Interface\\Icons\\INV_Misc_Book_11"
local WIDTH = 380

local profiles, maxProfiles = {}, 0
local pending, counter = {}, 0

---------------------------------------------------------------- server channel

-- Sends a command (without the dot); done(ok, lines) runs with the server's answer.
local function Request(command, done)
	counter = (counter % 9999) + 1
	local id = ("%04d"):format(counter)
	pending[id] = { lines = {}, done = done, at = GetTime() }
	SendAddonMessage(PREFIX, "i" .. id .. command, "WHISPER", UnitName("player"))
end
Loadouts.Request = Request

local function OnAddonMessage(prefix, msg, _, sender)
	if prefix ~= PREFIX or sender ~= UnitName("player") then return end
	local op, id, body = msg:sub(1, 1), msg:sub(2, 5), msg:sub(6)
	local p = pending[id]
	if not p then return end
	if op == "m" then
		p.lines[#p.lines + 1] = body
	elseif op == "o" or op == "f" then
		pending[id] = nil
		p.done(op == "o", p.lines)
	end
end

local function CheckTimeouts()
	local now = GetTime()
	for id, p in pairs(pending) do
		if now - p.at > TIMEOUT then
			pending[id] = nil
			p.done(false, { L["The realm did not answer."] }, true)
		end
	end
end

---------------------------------------------------------------- helpers

local function Trim(s) return (s or ""):match("^%s*(.-)%s*$") end

-- Same rule as the server: 1-24 characters, letters, digits, space, '-', '_' or any accent.
local function ValidName(name)
	if name == "" or name:find("[^%w _%-\128-\255]") then return false end
	local chars = #name:gsub("[\128-\191]", "")
	return chars <= 24
end
Loadouts.ValidName = ValidName

local function SpecName(group)
	return group == 2 and L["Secondary"] or L["Primary"]
end

-- "Holy 51 / Protection 5 / Retribution 15" with the client's own tree names.
local function Summary(points)
	local parts, total = {}, 0
	for tab = 1, 3 do
		local name = GetTalentTabInfo(tab)
		parts[#parts + 1] = ("%s %d"):format(name or "?", points[tab] or 0)
		total = total + (points[tab] or 0)
	end
	if total == 0 then return L["no talents"] end
	return table.concat(parts, " / ")
end

local function MainTreeIcon(points)
	local best, bestTab = -1, 1
	for tab = 1, 3 do
		if (points[tab] or 0) > best then best, bestTab = points[tab] or 0, tab end
	end
	local _, icon = GetTalentTabInfo(bestTab)
	return icon or ICON
end

local function ActiveSpecPoints()
	local group = GetActiveTalentGroup()
	local points = {}
	for tab = 1, 3 do
		local _, _, spent = GetTalentTabInfo(tab, false, false, group)
		points[tab] = spent or 0
	end
	return group, points
end

-- Parses the reply to "perfil lista": "M;count;max" then "P;name;p1;p2;p3" per profile.
local function ParseList(lines)
	local list, max = {}, 0
	for _, line in ipairs(lines) do
		local kind, rest = line:match("^(%u);(.*)$")
		if kind == "M" then
			max = tonumber(rest:match(";(%d+)$")) or 0
		elseif kind == "P" then
			local name, p1, p2, p3 = rest:match("^(.-);(%d+);(%d+);(%d+)$")
			if name then
				list[#list + 1] = { name = name, points = { tonumber(p1), tonumber(p2), tonumber(p3) } }
			end
		end
	end
	return list, max
end
Loadouts.ParseList = ParseList

---------------------------------------------------------------- window

local frame, rows = nil, {}

local function SetStatus(text, ok)
	if not frame then return end
	frame.status:SetText(text or "")
	if ok == false then
		frame.status:SetTextColor(1, 0.35, 0.35)
	else
		frame.status:SetTextColor(0.8, 0.8, 0.8)
	end
end

local function SetBusy(busy)
	frame.busy = busy
	for _, r in ipairs(rows) do
		if busy then r.load:Disable() r.delete:Disable() else r.load:Enable() r.delete:Enable() end
	end
	if busy then frame.save:Disable() else frame.save:Enable() end
end

local function UpdateHeader()
	if not frame then return end
	local group, points = ActiveSpecPoints()
	frame.spec:SetText(L["Active spec: %s"]:format("|cffffffff" .. SpecName(group) .. "|r - " .. Summary(points)))
end

local function Layout()
	UpdateHeader()
	local shown = math.min(#profiles, MAX_ROWS)
	for i = 1, MAX_ROWS do
		local r = rows[i]
		local p = profiles[i]
		if p and i <= shown then
			r.profile = p
			r.icon:SetTexture(MainTreeIcon(p.points))
			r.name:SetText(p.name)
			r.desc:SetText(Summary(p.points))
			r:Show()
		else
			r.profile = nil
			r:Hide()
		end
	end
	frame.empty:SetShown(#profiles == 0)
	frame.count:SetText(maxProfiles > 0 and L["%d of %d"]:format(#profiles, maxProfiles) or "")
	local listHeight = math.max(shown, 1) * 36
	frame.form:ClearAllPoints()
	frame.form:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -80 - listHeight - 8)
	frame:SetHeight(80 + listHeight + 8 + 80)
end

-- Asks the server for the list; `after` (optional) keeps the status of the action that triggered it.
function Loadouts.Refresh(after)
	if not frame then return end
	SetBusy(true)
	if not after then SetStatus(L["Asking the realm..."]) end
	Request("perfil lista", function(ok, lines, timedOut)
		SetBusy(false)
		if not ok then
			SetStatus(timedOut and L["The realm did not answer."] or L["This realm has no talent profiles."], false)
			return
		end
		profiles, maxProfiles = ParseList(lines)
		Layout()
		if not after then SetStatus("") end
	end)
end

-- Runs a .perfil action and shows the server's own message, then reloads the list.
local function Action(command)
	SetBusy(true)
	SetStatus(L["Asking the realm..."])
	Request(command, function(ok, lines)
		SetBusy(false)
		SetStatus(table.concat(lines, "\n"), ok)
		Loadouts.Refresh(true)
	end)
end

function Loadouts.Load(name) Action("perfil cargar " .. name) end
function Loadouts.Delete(name) Action("perfil borrar " .. name) end
function Loadouts.Save(name) Action("perfil guardar " .. name) end

StaticPopupDialogs["STORMRAGE_LOADOUT_LOAD"] = {
	text = "%s", button1 = YES, button2 = NO,
	OnAccept = function(_, name) Loadouts.Load(name) end,
	timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 1,
}
StaticPopupDialogs["STORMRAGE_LOADOUT_DELETE"] = {
	text = "%s", button1 = YES, button2 = NO,
	OnAccept = function(_, name) Loadouts.Delete(name) end,
	timeout = 0, whileDead = 1, hideOnEscape = 1,
}
StaticPopupDialogs["STORMRAGE_LOADOUT_REPLACE"] = {
	text = "%s", button1 = YES, button2 = NO,
	OnAccept = function(_, name) Loadouts.Save(name) end,
	timeout = 0, whileDead = 1, hideOnEscape = 1,
}

local function Confirm(which, text, name)
	local dialog = StaticPopup_Show(which, text)
	if dialog then dialog.data = name end
end

local function SaveTyped()
	local name = Trim(frame.input:GetText())
	if not ValidName(name) then
		SetStatus(L["Name: 1 to 24 letters, numbers, spaces, '-' or '_'."], false)
		return
	end
	frame.input:ClearFocus()
	for _, p in ipairs(profiles) do
		if p.name:lower() == name:lower() then
			Confirm("STORMRAGE_LOADOUT_REPLACE", L["Replace the profile |cff00ff00%s|r with your active spec?"]:format(p.name), p.name)
			return
		end
	end
	frame.input:SetText("")
	Loadouts.Save(name)
end

local function Button(parent, text, width)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	b:SetText(text)
	return b
end

local function CreateRow(i)
	local r = CreateFrame("Frame", nil, frame)
	r:SetSize(WIDTH - 28, 34)
	r:SetPoint("TOPLEFT", 14, -80 - (i - 1) * 36)
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(30, 30)
	r.icon:SetPoint("LEFT", 0, 0)
	r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	r.delete = Button(r, L["Delete"], 62)
	r.delete:SetPoint("RIGHT", 0, 0)
	r.load = Button(r, L["Load"], 62)
	r.load:SetPoint("RIGHT", r.delete, "LEFT", -4, 0)
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -1)
	r.name:SetPoint("RIGHT", r.load, "LEFT", -6, 0)
	r.name:SetJustifyH("LEFT")
	r.desc = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.desc:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
	r.desc:SetPoint("RIGHT", r.load, "LEFT", -6, 0)
	r.desc:SetJustifyH("LEFT")
	r.load:SetScript("OnClick", function()
		local name = r.profile and r.profile.name
		if not name then return end
		Confirm("STORMRAGE_LOADOUT_LOAD", L["Load |cff00ff00%s|r into your %s spec?\n\nThe talents, glyphs and bars of that spec are replaced. Save them first if you want to keep them."]
			:format(name, SpecName(GetActiveTalentGroup()):lower()), name)
	end)
	r.delete:SetScript("OnClick", function()
		local name = r.profile and r.profile.name
		if name then Confirm("STORMRAGE_LOADOUT_DELETE", L["Delete the profile |cff00ff00%s|r?"]:format(name), name) end
	end)
	r:Hide()
	rows[i] = r
	return r
end

local function CreateWindow()
	frame = CreateFrame("Frame", "StormrageLoadoutsFrame", UIParent)
	frame:SetSize(WIDTH, 240)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0.05, 0.05, 0.1, 0.95)

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 14, -12)
	title:SetText("|cff8fb8ff" .. L["Talent profiles"] .. "|r")
	frame.count = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	frame.count:SetPoint("LEFT", title, "RIGHT", 8, -1)
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)

	frame.spec = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.spec:SetPoint("TOPLEFT", 14, -38)
	frame.spec:SetPoint("RIGHT", -14, 0)
	frame.spec:SetJustifyH("LEFT")
	local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("TOPLEFT", frame.spec, "BOTTOMLEFT", 0, -4)
	hint:SetPoint("RIGHT", -14, 0)
	hint:SetJustifyH("LEFT")
	hint:SetText(L["Loading a profile replaces your active spec. The other one is not touched."])

	frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.empty:SetPoint("TOPLEFT", 14, -90)
	frame.empty:SetPoint("RIGHT", -14, 0)
	frame.empty:SetJustifyH("LEFT")
	frame.empty:SetText(L["No profiles yet. Type a name and save your active spec."])
	frame.empty.SetShown = function(self, show) if show then self:Show() else self:Hide() end end

	for i = 1, MAX_ROWS do CreateRow(i) end

	-- the save form, placed under the list by Layout
	frame.form = CreateFrame("Frame", nil, frame)
	frame.form:SetSize(WIDTH - 28, 70)
	local label = frame.form:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("TOPLEFT", 0, 0)
	label:SetText(L["Profile name"])
	frame.input = CreateFrame("EditBox", "StormrageLoadoutsName", frame.form, "InputBoxTemplate")
	frame.input:SetSize(170, 20)
	frame.input:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 6, -4)
	frame.input:SetAutoFocus(false)
	frame.input:SetMaxLetters(48)
	frame.input:SetScript("OnEnterPressed", SaveTyped)
	frame.input:SetScript("OnEscapePressed", frame.input.ClearFocus)
	frame.save = Button(frame.form, L["Save active spec"], 150)
	frame.save:SetPoint("LEFT", frame.input, "RIGHT", 8, 0)
	frame.save:SetScript("OnClick", SaveTyped)
	frame.status = frame.form:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.status:SetPoint("TOPLEFT", frame.input, "BOTTOMLEFT", -6, -8)
	frame.status:SetPoint("RIGHT", 0, 0)
	frame.status:SetJustifyH("LEFT")

	frame:SetScript("OnShow", function() Loadouts.Refresh() end)
	local elapsed = 0
	frame:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed > 1 then elapsed = 0 CheckTimeouts() end
	end)
	frame:Hide()
	tinsert(UISpecialFrames, "StormrageLoadoutsFrame")
	Layout()
end

function Loadouts.Toggle()
	if not frame then CreateWindow() end
	if frame:IsShown() then frame:Hide() return end
	frame:ClearAllPoints()
	if PlayerTalentFrame and PlayerTalentFrame:IsShown() then
		frame:SetPoint("TOPLEFT", PlayerTalentFrame, "TOPRIGHT", 30, -12)
	else
		frame:SetPoint("CENTER")
	end
	frame:Show()
end

---------------------------------------------------------------- talent window tab

-- A side tab under the native spec tabs of the talent window (Blizzard_TalentUI loads on demand).
local tab
local function AttachToTalentFrame()
	if tab or not PlayerTalentFrame then return end
	tab = CreateFrame("CheckButton", "StormrageLoadoutsTab", PlayerTalentFrame, "SpellBookSkillLineTabTemplate")
	tab:SetNormalTexture(ICON)
	tab:SetScript("OnClick", function(self)
		self:SetChecked(false)
		Loadouts.Toggle()
	end)
	tab:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(L["Stormrage talent profiles"])
		GameTooltip:AddLine(L["Save and load whole specs"], 1, 1, 1)
		GameTooltip:Show()
	end)
	tab:SetScript("OnLeave", GameTooltip_Hide)
	local function Place()
		local below
		for i = 1, 3 do
			local spec = _G["PlayerSpecTab" .. i]
			if spec and spec:IsShown() then below = spec end
		end
		tab:ClearAllPoints()
		if below then
			tab:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -22)
		else
			tab:SetPoint("TOPLEFT", PlayerTalentFrame, "TOPRIGHT", -32, -65)
		end
		tab:Show()
	end
	PlayerTalentFrame:HookScript("OnShow", Place)
	Place()
end

---------------------------------------------------------------- events, slash and hub

local events = CreateFrame("Frame")
events:RegisterEvent("CHAT_MSG_ADDON")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
events:RegisterEvent("PLAYER_TALENT_UPDATE")
events:SetScript("OnEvent", function(_, event, ...)
	if event == "CHAT_MSG_ADDON" then
		OnAddonMessage(...)
	elseif event == "ADDON_LOADED" then
		if ... == "Blizzard_TalentUI" then AttachToTalentFrame() end
	elseif frame and frame:IsShown() then
		UpdateHeader()
	end
end)
if IsAddOnLoaded and IsAddOnLoaded("Blizzard_TalentUI") then AttachToTalentFrame() end

SLASH_STORMRAGELOADOUTS1 = "/perfiles"
SLASH_STORMRAGELOADOUTS2 = "/profiles"
SlashCmdList.STORMRAGELOADOUTS = function() Loadouts.Toggle() end

Stormrage.Register({
	name = L["Talent profiles"],
	icon = ICON,
	description = L["Save and load whole specs"],
	onClick = function() Loadouts.Toggle() end,
})
