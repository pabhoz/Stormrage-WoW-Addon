-- Talent profiles panel tests with a simulated 3.3.5a UI and a fake realm.
-- Run from the addon folder: lua5.1 tests/loadouts.lua   (tests/run.sh does it in Docker)

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

-- the realm: answers on the addon channel like AzerothCore's AddonChannelCommandHandler
local realm = { profiles = {}, max = 5, enabled = true, silent = false }
local sent = {}
function SendAddonMessage(prefix, msg, channel, target)
	sent[#sent + 1] = { prefix = prefix, msg = msg, channel = channel, target = target }
	if realm.silent then return end
	local id, cmd = msg:sub(2, 5), msg:sub(6)
	local out = {}
	local function m(line) out[#out + 1] = "m" .. id .. line end
	local ok = true
	if not realm.enabled then
		m("There is no such command.") ok = false
	elseif cmd == "perfil lista" then
		m(("M;%d;%d"):format(#realm.profiles, realm.max))
		for _, p in ipairs(realm.profiles) do m("P;" .. p .. ";0;5;51") end
	elseif cmd:match("^perfil guardar ") then
		local name = cmd:match("^perfil guardar (.+)$")
		realm.profiles[#realm.profiles + 1] = name
		m("Perfil '" .. name .. "' guardado.")
	elseif cmd:match("^perfil borrar ") then
		local name = cmd:match("^perfil borrar (.+)$")
		for i, p in ipairs(realm.profiles) do if p == name then table.remove(realm.profiles, i) end end
		m("Perfil '" .. name .. "' borrado.")
	elseif cmd:match("^perfil cargar ") then
		m("Espera 12 segundos antes de cargar otro perfil.") ok = false
	end
	out[#out + 1] = (ok and "o" or "f") .. id
	for _, reply in ipairs(out) do
		for _, f in ipairs(frames) do
			if f.events.CHAT_MSG_ADDON then f.scripts.OnEvent(f, "CHAT_MSG_ADDON", prefix, reply, "WHISPER", "Thrall") end
		end
	end
end

dofile("Stormrage.lua")
dofile("Loadouts.lua")

local L = Stormrage.Loadouts

-- the hub lists it
local listed
for _, a in ipairs(Stormrage.Addons()) do if a.name == "Perfiles de talentos" then listed = a end end
check(listed and listed.onClick, "the panel registers itself in the hub menu")

-- names
check(L.ValidName("Raid 25"), "plain name is valid")
check(L.ValidName("Sanación PvP"), "accented name is valid")
check(not L.ValidName("a'b"), "a quote is refused")
check(not L.ValidName(""), "empty name is refused")
check(not L.ValidName(("x"):rep(25)), "25 characters is too long")
check(L.ValidName(("ñ"):rep(24)), "24 accented characters fit (counted as characters, not bytes)")

-- list parsing
local list, max = L.ParseList({ "M;2;5", "P;Raid;0;5;51", "P;Arena 2v2;40;31;0" })
check(max == 5 and #list == 2 and list[2].name == "Arena 2v2" and list[2].points[1] == 40, "parses the list reply")

-- open: asks the realm through the addon channel, silently
listed.onClick("LeftButton")
local frame = created.StormrageLoadoutsFrame
check(frame and frame.shown, "the window opens")
check(sent[1].prefix == "AzerothCore" and sent[1].msg:match("^i%d%d%d%dperfil lista$") and sent[1].channel == "WHISPER" and sent[1].target == "Thrall",
	"the list is asked as an addon whisper to oneself")
check(frame.empty.shown, "with no profiles, the empty hint shows")

-- save
frame.input:SetText("  Raid  ")
frame.save.scripts.OnClick(frame.save)
check(sent[#sent - 1].msg:match("perfil guardar Raid$"), "save sends the trimmed name")
check(realm.profiles[1] == "Raid" and frame.status.text:match("guardado"), "save shows the realm's message")
check(sent[#sent].msg:match("perfil lista$"), "and reloads the list")
local row
for _, f in ipairs(frames) do if rawget(f, "profile") then row = f end end
check(row and row.shown and row.name.text == "Raid", "the profile has a row")
check(row.desc.text == "Sagrado 0 / Proteccion 5 / Reprension 51", "with the client's tree names")
check(row.icon.path == "IconRet", "and the icon of its main tree")

-- saving the same name asks before replacing
frame.input:SetText("raid")
local before = #sent
frame.save.scripts.OnClick(frame.save)
check(#sent == before and popups[#popups].which == "STORMRAGE_LOADOUT_REPLACE", "same name asks before replacing")

-- bad name never reaches the realm
frame.input:SetText("a;b")
frame.save.scripts.OnClick(frame.save)
check(#sent == before and frame.status.text:match("Nombre"), "an invalid name is refused locally")

-- load asks first, then shows the realm's refusal in red
row.load.scripts.OnClick(row.load)
local dialog = popups[#popups]
check(dialog.which == "STORMRAGE_LOADOUT_LOAD" and dialog.data == "Raid" and dialog.text:match("primaria"), "load asks for confirmation naming the active spec")
StaticPopupDialogs.STORMRAGE_LOADOUT_LOAD.OnAccept(dialog, dialog.data)
check(sent[#sent - 1].msg:match("perfil cargar Raid$") and frame.status.text:match("Espera"), "load runs and shows the realm's answer")

-- delete
row.delete.scripts.OnClick(row.delete)
dialog = popups[#popups]
StaticPopupDialogs.STORMRAGE_LOADOUT_DELETE.OnAccept(dialog, dialog.data)
check(#realm.profiles == 0 and not row.shown and frame.empty.shown, "delete removes the row")

-- a realm without the module, and one that never answers
realm.enabled = false
L.Refresh()
check(frame.status.text == "Este reino no tiene perfiles de talentos.", "a realm without profiles says so")
realm.enabled, realm.silent = true, true
L.Refresh()
check(not frame.save.enabled, "buttons wait while the realm answers")
now = now + 10
frame.scripts.OnUpdate(frame, 2)
check(frame.status.text == "El reino no respondio." and frame.save.enabled, "after the timeout it says the realm did not answer")

-- replies for someone else's id or prefix are ignored
for _, f in ipairs(frames) do
	if f.events.CHAT_MSG_ADDON then
		f.scripts.OnEvent(f, "CHAT_MSG_ADDON", "AzerothCore", "o9999", "WHISPER", "Thrall")
		f.scripts.OnEvent(f, "CHAT_MSG_ADDON", "Other", "o0001", "WHISPER", "Thrall")
	end
end
check(true, "stray replies do not break anything")

-- talent window tab
PlayerTalentFrame = NewFrame("Frame", "PlayerTalentFrame")
PlayerSpecTab1 = NewFrame("CheckButton", "PlayerSpecTab1")
for _, f in ipairs(frames) do
	if f.events.ADDON_LOADED and f.scripts.OnEvent then f.scripts.OnEvent(f, "ADDON_LOADED", "Blizzard_TalentUI") end
end
check(created.StormrageLoadoutsTab and created.StormrageLoadoutsTab.shown, "a tab appears on the talent window")

SlashCmdList.STORMRAGELOADOUTS("")
check(not frame.shown, "/perfiles toggles the window")

print(("all %d passed"):format(passed))
