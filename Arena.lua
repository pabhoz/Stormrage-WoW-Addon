-- Stormrage - arena 1v1 panel (WoW 3.3.5a).
-- Copyright (C) 2026 pabhoz - https://github.com/pabhoz/Stormrage-WoW-Addon
-- Licensed under the GNU General Public License v3.0 or later. See LICENSE.

-- The realm's 1v1 arena (mod-1v1-arena) lives in an arena slot the 3.3.5a client never shows, so its
-- rating is only reachable with ".q1v1 stats". This panel asks for it through the addon channel
-- (Channel.lua) and shows rating, rank and games, with the two queue buttons. A side tab on the
-- PvP window shows the rating too. The module answers in English; the panel reads its lines.

local L = Stormrage.L
local locale = GetLocale()
if locale == "esES" or locale == "esMX" then
	L["Arena 1v1"] = "Arena 1v1"
	L["Your rating and the 1v1 queue"] = "Tu indice y la cola 1v1"
	L["Rating"] = "Indice"
	L["Rank %d"] = "Puesto %d"
	L["This week: %d wins, %d losses"] = "Esta semana: %d victorias, %d derrotas"
	L["Season: %d wins, %d losses"] = "Temporada: %d victorias, %d derrotas"
	L["Unrated queue"] = "Cola sin puntuar"
	L["Rated queue"] = "Cola puntuada"
	L["You have no 1v1 team yet. Rated play creates it the first time, for gold."] =
		"Aun no tienes equipo 1v1. La cola puntuada lo crea la primera vez, por oro."
	L["Create your 1v1 team?\n\nIt costs gold the first time. Then press Rated queue again to join."] =
		"Crear tu equipo 1v1?\n\nCuesta oro la primera vez. Despues pulsa Cola puntuada otra vez para entrar."
	L["This realm has no 1v1 arena."] = "Este reino no tiene arena 1v1."
	L["Asking the realm..."] = "Consultando al reino..."
	L["In the 1v1 queue (%s)."] = "En la cola 1v1 (%s)."
	L["rated"] = "puntuada"
	L["unrated"] = "sin puntuar"
	L["Team created. Press Rated queue again to join."] = "Equipo creado. Pulsa Cola puntuada otra vez para entrar."
	L["Not enough gold to create the team (%s gold)."] = "No tienes oro suficiente para crear el equipo (%s de oro)."
	L["You can't queue in combat."] = "No puedes entrar a la cola en combate."
	L["You can't queue with Deserter."] = "No puedes entrar a la cola con Desertor."
	L["You need level %s to queue."] = "Necesitas nivel %s para entrar a la cola."
	L["1v1: %d"] = "1v1: %d"
end

local Arena = {}
Stormrage.Arena = Arena

local ICON = "Interface\\Icons\\Ability_Warrior_Challange"
local WIDTH = 300

local stats            -- last answer: { rating, rank, seasonGames, seasonWins, weekGames, weekWins }, or false = no team
local frame, tab

---------------------------------------------------------------- the realm's answers

-- "===== Arena 1v1 Statistics =====", "Rating: 152", "Rank: 1", "Season Games: 7"...
local FIELDS = {
	["Rating"] = "rating", ["Rank"] = "rank", ["Season Games"] = "seasonGames",
	["Season Wins"] = "seasonWins", ["Week Games"] = "weekGames", ["Week Wins"] = "weekWins",
}
local function ParseStats(lines)
	local s
	for _, line in ipairs(lines) do
		local key, value = line:match("^%s*([%a ]-):%s*(%d+)%s*$")
		if key and FIELDS[key] then
			s = s or {}
			s[FIELDS[key]] = tonumber(value)
		end
	end
	if s and s.rating then return s end
end
Arena.ParseStats = ParseStats

-- The module's queue messages, in the player's language.
local function Translate(line)
	if line:find("joined the solo 1v1 arena queue") then
		return L["In the 1v1 queue (%s)."]:format(line:find("UnRated") and L["unrated"] or L["rated"])
	elseif line:find("team created successfully") then
		return L["Team created. Press Rated queue again to join."]
	elseif line:find("gold to create a 1v1 arena team") then
		return L["Not enough gold to create the team (%s gold)."]:format(line:match("(%d+) gold") or "?")
	elseif line:find("in combat") then
		return L["You can't queue in combat."]
	elseif line:find("Deserter") then
		return L["You can't queue with Deserter."]
	elseif line:find("You need level") then
		return L["You need level %s to queue."]:format(line:match("level (%d+)") or "?")
	elseif line:find("don't have a 1v1 arena team") then
		return L["You have no 1v1 team yet. Rated play creates it the first time, for gold."]
	elseif line:find("disabled") or line:find("no such command") then
		return L["This realm has no 1v1 arena."]
	end
	return line
end
Arena.Translate = Translate

---------------------------------------------------------------- display

local function SetStatus(text, ok)
	if not frame then return end
	frame.status:SetText(text or "")
	if ok == false then frame.status:SetTextColor(1, 0.35, 0.35) else frame.status:SetTextColor(0.8, 0.8, 0.8) end
end

local function UpdateTab()
	if not tab then return end
	tab.text:SetText(stats and L["1v1: %d"]:format(stats.rating) or "")
end

local function Show()
	UpdateTab()
	if not frame then return end
	if stats then
		frame.rating:SetText(stats.rating)
		frame.rank:SetText(L["Rank %d"]:format(stats.rank or 0))
		local ww, wg = stats.weekWins or 0, stats.weekGames or 0
		local sw, sg = stats.seasonWins or 0, stats.seasonGames or 0
		frame.week:SetText(L["This week: %d wins, %d losses"]:format(ww, wg - ww))
		frame.season:SetText(L["Season: %d wins, %d losses"]:format(sw, sg - sw))
	else
		frame.rating:SetText("-")
		frame.rank:SetText("")
		frame.week:SetText("")
		frame.season:SetText("")
	end
end

local function SetBusy(busy)
	if not frame then return end
	if busy then frame.unrated:Disable() frame.rated:Disable() else frame.unrated:Enable() frame.rated:Enable() end
end

-- Asks the realm for the stats; quiet = no "asking" line (the automatic refreshes).
function Arena.Refresh(quiet)
	if not quiet then SetStatus(L["Asking the realm..."]) end
	Stormrage.Request("q1v1 stats", function(ok, lines, timedOut)
		local parsed = ok and ParseStats(lines)
		if parsed then
			stats = parsed
			if not quiet then SetStatus("") end
		elseif timedOut then
			SetStatus(lines[1], false)
		else
			stats = false
			SetStatus(Translate(lines[1] or ""), lines[1] and lines[1]:find("don't have") and true or false)
		end
		Show()
	end)
end

-- Joins a queue: the realm's answer goes to the status line.
function Arena.Queue(rated)
	SetBusy(true)
	SetStatus(L["Asking the realm..."])
	Stormrage.Request(rated and "q1v1 rated" or "q1v1 unrated", function(ok, lines)
		SetBusy(false)
		local out = {}
		for _, line in ipairs(lines) do out[#out + 1] = Translate(line) end
		SetStatus(table.concat(out, "\n"), ok)
		if rated and ok then Arena.Refresh(true) end
	end)
end

StaticPopupDialogs["STORMRAGE_ARENA_CREATE"] = {
	text = "%s", button1 = YES, button2 = NO,
	OnAccept = function() Arena.Queue(true) end,
	timeout = 0, whileDead = 1, hideOnEscape = 1,
}

---------------------------------------------------------------- window

local function Button(parent, text, width)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	b:SetText(text)
	return b
end

local function CreateWindow()
	frame = CreateFrame("Frame", "StormrageArenaFrame", UIParent)
	frame:SetSize(WIDTH, 210)
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
	title:SetText("|cff8fb8ff" .. L["Arena 1v1"] .. "|r")
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)

	local icon = frame:CreateTexture(nil, "ARTWORK")
	icon:SetSize(44, 44)
	icon:SetPoint("TOPLEFT", 16, -42)
	icon:SetTexture(ICON)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 0)
	label:SetText(L["Rating"])
	frame.rating = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	frame.rating:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
	frame.rank = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	frame.rank:SetPoint("LEFT", frame.rating, "RIGHT", 10, 0)

	frame.week = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.week:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -10)
	frame.season = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	frame.season:SetPoint("TOPLEFT", frame.week, "BOTTOMLEFT", 0, -4)

	frame.unrated = Button(frame, L["Unrated queue"], 128)
	frame.unrated:SetPoint("TOPLEFT", frame.season, "BOTTOMLEFT", -2, -12)
	frame.unrated:SetScript("OnClick", function() Arena.Queue(false) end)
	frame.rated = Button(frame, L["Rated queue"], 128)
	frame.rated:SetPoint("LEFT", frame.unrated, "RIGHT", 8, 0)
	frame.rated:SetScript("OnClick", function()
		if stats == false then
			local d = StaticPopup_Show("STORMRAGE_ARENA_CREATE", L["Create your 1v1 team?\n\nIt costs gold the first time. Then press Rated queue again to join."])
			return d
		end
		Arena.Queue(true)
	end)

	frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.status:SetPoint("TOPLEFT", frame.unrated, "BOTTOMLEFT", 2, -10)
	frame.status:SetPoint("RIGHT", -14, 0)
	frame.status:SetJustifyH("LEFT")

	frame:SetScript("OnShow", function() Arena.Refresh() end)
	frame:Hide()
	tinsert(UISpecialFrames, "StormrageArenaFrame")
	Show()
end

function Arena.Toggle()
	if not frame then CreateWindow() end
	if frame:IsShown() then frame:Hide() else frame:Show() end
end

---------------------------------------------------------------- PvP window tab

-- A side tab on the PvP window: the 1v1 rating at a glance, and a click opens the panel.
local function AttachToPvPFrame()
	if tab or not PVPFrame then return end
	tab = CreateFrame("CheckButton", "StormrageArenaTab", PVPFrame, "SpellBookSkillLineTabTemplate")
	tab:SetNormalTexture(ICON)
	tab:SetPoint("TOPLEFT", PVPFrame, "TOPRIGHT", -32, -65)
	tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	tab.text:SetPoint("TOP", tab, "BOTTOM", 0, -2)
	tab:SetScript("OnClick", function(self)
		self:SetChecked(false)
		Arena.Toggle()
	end)
	tab:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(L["Arena 1v1"])
		if stats then
			GameTooltip:AddLine(("%s: %d  (%s)"):format(L["Rating"], stats.rating, L["Rank %d"]:format(stats.rank or 0)), 1, 1, 1)
			GameTooltip:AddLine(L["This week: %d wins, %d losses"]:format(stats.weekWins or 0, (stats.weekGames or 0) - (stats.weekWins or 0)), 1, 1, 1)
		else
			GameTooltip:AddLine(L["Your rating and the 1v1 queue"], 1, 1, 1)
		end
		GameTooltip:Show()
	end)
	tab:SetScript("OnLeave", GameTooltip_Hide)
	PVPFrame:HookScript("OnShow", function() Arena.Refresh(true) end)
	UpdateTab()
end

---------------------------------------------------------------- events, slash and hub

-- After an arena (or any loading screen) the rating may have moved: refresh what is on screen.
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function()
	AttachToPvPFrame()
	if (frame and frame:IsShown()) or (PVPFrame and PVPFrame:IsShown()) then Arena.Refresh(true) end
end)
AttachToPvPFrame()

SLASH_STORMRAGEARENA1 = "/arena1v1"
SLASH_STORMRAGEARENA2 = "/1v1"
SlashCmdList.STORMRAGEARENA = function() Arena.Toggle() end

Stormrage.Register({
	name = L["Arena 1v1"],
	icon = ICON,
	description = L["Your rating and the 1v1 queue"],
	onClick = function() Arena.Toggle() end,
})
