-- Stormrage - talking to the realm (WoW 3.3.5a).
-- Copyright (C) 2026 pabhoz - https://github.com/pabhoz/Stormrage-WoW-Addon
-- Licensed under the GNU General Public License v3.0 or later. See LICENSE.

-- AzerothCore's addon command channel, shared by the hub's panels (talent profiles, arena 1v1):
-- an addon whisper to oneself with prefix "AzerothCore" and body "i" .. 4-char id .. command.
-- The server answers on the same prefix: "m" .. id .. line for each line of each message, then
-- "o" .. id (done) or "f" .. id (failed). Nothing is printed in the chat.

local L = Stormrage.L
local locale = GetLocale()
if locale == "esES" or locale == "esMX" then
	L["The realm did not answer."] = "El reino no respondio."
end

local PREFIX = "AzerothCore"
local TIMEOUT = 6
local pending, counter = {}, 0

-- Sends a command (without the dot); done(ok, lines, timedOut) runs with the server's answer.
function Stormrage.Request(command, done)
	counter = (counter % 9999) + 1
	local id = ("%04d"):format(counter)
	pending[id] = { lines = {}, done = done, at = GetTime() }
	SendAddonMessage(PREFIX, "i" .. id .. command, "WHISPER", UnitName("player"))
end

-- Gives up on requests the realm never answered (a realm without the command says "f").
function Stormrage.CheckRequests()
	local now = GetTime()
	for id, p in pairs(pending) do
		if now - p.at > TIMEOUT then
			pending[id] = nil
			p.done(false, { L["The realm did not answer."] }, true)
		end
	end
end

local channel = CreateFrame("Frame")
channel:RegisterEvent("CHAT_MSG_ADDON")
channel:SetScript("OnEvent", function(_, _, prefix, msg, _, sender)
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
end)
local elapsed = 0
channel:SetScript("OnUpdate", function(_, dt)
	elapsed = elapsed + dt
	if elapsed > 1 then elapsed = 0 Stormrage.CheckRequests() end
end)
