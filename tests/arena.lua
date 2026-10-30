-- Arena 1v1 panel tests with a simulated 3.3.5a UI and a fake realm running mod-1v1-arena.
-- Run from the addon folder: lua5.1 tests/arena.lua   (tests/run.sh does it in Docker)

local passed = 0
local function check(cond, msg)
	if not cond then error("FAIL: " .. msg, 2) end
	passed = passed + 1
	print("ok  " .. msg)
end

local noop = function() end
local function Stub(t) return setmetatable(t or {}, { __index = function() return noop end }) end

local frames, created = {}, {}
local function NewFrame(kind, name)
	local f = Stub({ scripts = {}, events = {}, shown = true, name = name, enabled = true })
	function f:SetScript(k, fn) self.scripts[k] = fn end
	function f:HookScript(k, fn) self.scripts[k] = fn end
	function f:RegisterEvent(e) self.events[e] = true end
	function f:Hide() self.shown = false end
	function f:Show() self.shown = true if self.scripts.OnShow then self.scripts.OnShow(self) end end
	function f:IsShown() return self.shown end
	function f:Enable() self.enabled = true end
	function f:Disable() self.enabled = false end
	function f:SetText(t) self.text = t end
	function f:GetText() return self.text end
	function f:CreateFontString()
		local fs = Stub({})
		function fs:SetText(t) self.text = t end
		function fs:Show() self.shown = true end
		function fs:Hide() self.shown = false end
		return fs
	end
	function f:CreateTexture()
		local t = Stub({})
		function t:SetTexture(p) self.path = p end
		return t
	end
	frames[#frames + 1] = f
	if name then _G[name] = f created[name] = f end
	return f
end
function CreateFrame(kind, name) return NewFrame(kind, name) end

function GetLocale() return "esES" end
function GetCursorPosition() return 0, 0 end
function GetTime() return now end
now = 100
function UnitName() return "Thrall" end
function GetActiveTalentGroup() return 1 end
local TREES = { { "Sagrado", "IconHoly" }, { "Proteccion", "IconProt" }, { "Reprension", "IconRet" } }
function GetTalentTabInfo(tab) return TREES[tab][1], TREES[tab][2], tab == 3 and 51 or 10 end
DEFAULT_CHAT_FRAME = { AddMessage = noop }
UIParent = Stub({ GetEffectiveScale = function() return 1 end })
Minimap = Stub({})
GameTooltip = Stub({})
YES, NO, OKAY = "Si", "No", "Ok"
StaticPopupDialogs, UISpecialFrames, SlashCmdList = {}, {}, {}
local popups = {}
function StaticPopup_Show(which, text)
	local d = { which = which, text = text }
	popups[#popups + 1] = d
	return d
end
function tinsert(t, v) t[#t + 1] = v end

-- the realm: answers ".q1v1 ..." on the addon channel like AzerothCore + mod-1v1-arena
local realm = { team = false, rating = 152, gold = true, enabled = true, silent = false }
local sent = {}
function SendAddonMessage(prefix, msg, channel, target)
	sent[#sent + 1] = { prefix = prefix, msg = msg, channel = channel, target = target }
	if realm.silent then return end
	local id, cmd = msg:sub(2, 5), msg:sub(6)
	local out, ok = {}, true
	local function m(text) for line in (text .. "\n"):gmatch("(.-)\n") do out[#out + 1] = "m" .. id .. line end end
	if not realm.enabled then
		m("There is no such command.") ok = false
	elseif cmd == "q1v1 stats" then
		if realm.team then
			m("===== Arena 1v1 Statistics =====\nRating: " .. realm.rating .. "\nRank: 1\nSeason Games: 12\nSeason Wins: 9\nWeek Games: 7\nWeek Wins: 7")
		else
			m("You don't have a 1v1 arena team.") ok = false
		end
	elseif cmd == "q1v1 rated" then
		if not realm.team then
			if not realm.gold then m("You need 40 gold to create a 1v1 arena team.") ok = false
			else realm.team = true m("Arena 1v1 team created successfully. Use the command again to join the rated queue.") end
		else
			m("You have joined the solo 1v1 arena queue Rated.")
		end
	elseif cmd == "q1v1 unrated" then
		m("You have joined the solo 1v1 arena queue UnRated.")
	end
	out[#out + 1] = (ok and "o" or "f") .. id
	for _, reply in ipairs(out) do
		for _, f in ipairs(frames) do
			if f.events.CHAT_MSG_ADDON then f.scripts.OnEvent(f, "CHAT_MSG_ADDON", prefix, reply, "WHISPER", "Thrall") end
		end
	end
end

PVPFrame = NewFrame("Frame", "PVPFrame")
PVPFrame.shown = false

dofile("Stormrage.lua")
dofile("Channel.lua")
dofile("Arena.lua")

local A = Stormrage.Arena

-- the hub lists it, and the PvP window gets its tab
local listed
for _, a in ipairs(Stormrage.Addons()) do if a.name == "Arena 1v1" then listed = a end end
check(listed and listed.onClick, "the panel registers itself in the hub menu")
check(created.StormrageArenaTab, "a tab appears on the PvP window")

-- parsing the module's answers
local s = A.ParseStats({ "===== Arena 1v1 Statistics =====", "Rating: 152", "Rank: 1", "Season Games: 7", "Season Wins: 7", "Week Games: 7", "Week Wins: 7" })
check(s and s.rating == 152 and s.rank == 1 and s.weekWins == 7, "parses .q1v1 stats")
check(A.ParseStats({ "You don't have a 1v1 arena team." }) == nil, "no stats without a team")
check(A.Translate("You have joined the solo 1v1 arena queue UnRated.") == "En la cola 1v1 (sin puntuar).", "queue message in Spanish")
check(A.Translate("You need 40 gold to create a 1v1 arena team.") == "No tienes oro suficiente para crear el equipo (40 de oro).", "gold message with the price")

-- open without a team: says so, and rated asks before creating the team
listed.onClick("LeftButton")
local frame = created.StormrageArenaFrame
check(frame and frame.shown and sent[#sent].msg:match("^i%d%d%d%dq1v1 stats$") and sent[#sent].target == "Thrall", "opening asks the stats silently")
check(frame.rating.text == "-" and frame.status.text:match("Aun no tienes equipo"), "without a team it explains how to get one")
local before = #sent
frame.rated.scripts.OnClick(frame.rated)
local dialog = popups[#popups]
check(#sent == before and dialog.which == "STORMRAGE_ARENA_CREATE", "rated asks before creating the team")
realm.gold = false
StaticPopupDialogs.STORMRAGE_ARENA_CREATE.OnAccept(dialog)
check(frame.status.text:match("40 de oro") and frame.rated.enabled, "not enough gold is shown and buttons come back")
realm.gold = true
StaticPopupDialogs.STORMRAGE_ARENA_CREATE.OnAccept(dialog)
check(frame.status.text:match("Equipo creado") and frame.rating.text == 152, "the team is created and the rating shows")
check(frame.week.text == "Esta semana: 7 victorias, 0 derrotas" and frame.season.text == "Temporada: 9 victorias, 3 derrotas", "week and season records")

-- queues
frame.rated.scripts.OnClick(frame.rated)
check(sent[#sent - 1].msg:match("q1v1 rated$") and frame.status.text == "En la cola 1v1 (puntuada).", "rated queue joins")
frame.unrated.scripts.OnClick(frame.unrated)
check(sent[#sent].msg:match("q1v1 unrated$") and frame.status.text == "En la cola 1v1 (sin puntuar).", "unrated queue joins")

-- after an arena the shown numbers refresh by themselves, and the tab shows the rating
realm.rating = 170
for _, f in ipairs(frames) do
	if f.events.PLAYER_ENTERING_WORLD then f.scripts.OnEvent(f, "PLAYER_ENTERING_WORLD") end
end
check(frame.rating.text == 170 and created.StormrageArenaTab.text.text == "1v1: 170", "a loading screen refreshes the rating")

-- a realm without the module, and one that never answers
realm.enabled = false
A.Refresh()
check(frame.status.text == "Este reino no tiene arena 1v1.", "a realm without 1v1 says so")
realm.enabled, realm.silent = true, true
A.Refresh()
now = now + 10
for _, f in ipairs(frames) do if f.scripts.OnUpdate then f.scripts.OnUpdate(f, 2) end end
check(frame.status.text == "El reino no respondio.", "after the timeout it says the realm did not answer")

SlashCmdList.STORMRAGEARENA("")
check(not frame.shown, "/1v1 toggles the window")

print(("all %d passed"):format(passed))
