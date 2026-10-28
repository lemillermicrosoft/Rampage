-- Original rectangles, horns and angry eyebrows; no borrowed game art or audio.
local _, addon = ...
local UI = {}
addon.UI = UI
local colors = { {0.35, 0.9, 0.55}, {1, 0.55, 0.24}, {0.55, 0.65, 1}, {1, 0.45, 0.75} }
local bossColors = { {0.85, 0.55, 0.18}, {0.6, 0.7, 0.85}, {0.9, 0.3, 0.45}, {0.65, 0.4, 0.95} }
local function rect(parent, x, y, w, h, r, g, b, a, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, y); t:SetSize(w, h)
    t:SetColorTexture(r, g, b, a or 1)
    return t
end
local function text(parent, size, x, y, width, align)
    local t = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetFont(STANDARD_TEXT_FONT, size, "")
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); t:SetWidth(width)
    t:SetJustifyH(align or "LEFT"); t:SetTextColor(0.92, 0.93, 0.96)
    return t
end
local function button(parent, label, x, y, width, callback)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 28); b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetText(label); b:SetScript("OnClick", callback)
    return b
end
local function enabled(buttonFrame, yes)
    if yes then buttonFrame:Enable() else buttonFrame:Disable() end
end

function UI.create(app)
    if UI.root then return UI.root end
    local root = CreateFrame("Frame", "ToastRampageWindow", UIParent)
    UI.root, UI.app = root, app
    root:SetSize(720, 610); root:SetPoint("CENTER"); root:SetClampedToScreen(true)
    root:SetFrameStrata("DIALOG"); root:EnableMouse(true); root:SetMovable(true)
    root:RegisterForDrag("LeftButton")
    root:SetScript("OnDragStart", function(self) if not app.net.combat then self:StartMoving() end end)
    root:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        app.db.position = { point = point, relativePoint = relativePoint, x = x, y = y }
    end)
    local pos = app.db.position
    local anchors = { CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
        TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }
    if type(pos) == "table" and anchors[pos.point] and anchors[pos.relativePoint]
        and type(pos.x) == "number" and type(pos.y) == "number"
        and math.abs(pos.x) < 10000 and math.abs(pos.y) < 10000 then
        root:ClearAllPoints(); root:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    end
    rect(root, 0, 0, 720, 610, 0.055, 0.065, 0.095, 0.98, "BACKGROUND")
    rect(root, 0, 606, 720, 4, 1, 0.55, 0.2)
    text(root, 22, 20, -16, 660):SetText("<Toast> presents: FOUR MORE BOSSES!")
    text(root, 12, 21, -44, 660):SetText("RAMPAGE  •  Original pocket-sized co-op chaos  •  Drag to move  •  /rampage")
    button(root, "X", 680, -12, 26, function() root:Hide() end)
    UI.solo = button(root, "Solo practice", 20, -73, 110, function() app.net:solo(); UI.render() end)
    UI.host = button(root, "Host", 136, -73, 70, function() app.net:host(); UI.render() end)
    UI.find = button(root, "Find lobbies", 212, -73, 104, function() app.net:discover(); UI.render() end)
    UI.join = button(root, "Join selected", 322, -73, 112, function()
        local lobby = UI.displayedLobby
        if lobby then app.net:join(lobby.name, lobby.sid) end
        UI.render()
    end)
    UI.start = button(root, "Start / replay", 440, -73, 115, function() app.net:start(); UI.render() end)
    UI.leave = button(root, "Leave", 561, -73, 76, function() app.net:leave(); UI.render() end)
    UI.next = button(root, "Next host", 610, -108, 90, function()
        local list, current = app.net:lobbyList(), 0
        for i, lobby in ipairs(list) do if lobby.name == UI.lobbyName then current = i end end
        if #list > 0 then UI.lobbyName = list[current % #list + 1].name end
        UI.render()
    end)
    UI.lobby = text(root, 12, 22, -113, 580)
    UI.scores = {}
    for i = 1, 4 do
        UI.scores[i] = text(root, 12, 22 + (i - 1) * 174, -145, 170)
        UI.scores[i]:SetTextColor(unpack(colors[i]))
    end
    local city = CreateFrame("Frame", nil, root)
    UI.city = city
    city:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 24, 168); city:SetSize(672, 266)
    rect(city, 0, 0, 672, 266, 0.09, 0.13, 0.2, 1, "BACKGROUND")
    -- Tiny fixed skyline, moon and road marks; every shape is authored here.
    rect(city, 604, 219, 21, 21, 0.9, 0.88, 0.6, 0.8, "BACKGROUND")
    for i = 1, 12 do
        rect(city, i * 53 - 26, 15, 34, 20 + (i % 3) * 16, 0.12, 0.18, 0.25, 1, "BACKGROUND")
    end
    rect(city, 0, 0, 672, 17, 0.24, 0.25, 0.29)
    for i = 1, 7 do rect(city, 42 + (i - 1) * 95, 5, 24, 3, 0.65, 0.64, 0.45) end
    UI.stageText = text(city, 14, 12, -9, 648, "CENTER")
    UI.floors = {}
    for tower = 1, 3 do
        local x = 52 + (addon.Model.TOWERS[tower] - 1) * 95
        for floor = 1, 3 do
            local tile = CreateFrame("Frame", nil, city)
            tile:SetSize(62, 58); tile:SetPoint("BOTTOMLEFT", city, "BOTTOMLEFT", x - 31, 18 + (floor - 1) * 60)
            tile.body = rect(tile, 0, 0, 62, 58, 0.36, 0.42, 0.51)
            rect(tile, 0, 55, 62, 3, 0.6, 0.67, 0.75)
            tile.windows = {}
            for w = 1, 3 do tile.windows[w] = rect(tile, 9 + (w - 1) * 18, 20, 10, 16, 1, 0.84, 0.4) end
            tile.crack = rect(tile, 29, 0, 5, 47, 0.06, 0.07, 0.09)
            UI.floors[(tower - 1) * 3 + floor] = tile
        end
    end
    UI.rubble = {}
    for tower = 1, 3 do
        local x = 52 + (addon.Model.TOWERS[tower] - 1) * 95
        UI.rubble[tower] = rect(city, x - 34, 17, 68, 8, 0.42, 0.38, 0.34)
    end
    local boss = CreateFrame("Frame", nil, city)
    UI.boss = boss; boss:SetSize(78, 94); boss:SetPoint("BOTTOMLEFT", city, "BOTTOMLEFT", 299, 18)
    boss.body = rect(boss, 9, 6, 60, 67, 0.8, 0.5, 0.2)
    rect(boss, 0, 26, 12, 33, 0.7, 0.32, 0.17); rect(boss, 66, 26, 12, 33, 0.7, 0.32, 0.17)
    rect(boss, 12, 72, 10, 19, 1, 0.84, 0.3); rect(boss, 34, 78, 10, 16, 1, 0.84, 0.3)
    rect(boss, 56, 72, 10, 19, 1, 0.84, 0.3)
    rect(boss, 20, 48, 12, 10, 1, 1, 0.8); rect(boss, 46, 48, 12, 10, 1, 1, 0.8)
    rect(boss, 25, 49, 5, 6, 0.1, 0.06, 0.06); rect(boss, 48, 49, 5, 6, 0.1, 0.06, 0.06)
    rect(boss, 25, 23, 28, 8, 0.12, 0.06, 0.06)
    UI.monsters = {}
    for slot = 1, 4 do
        local monster = CreateFrame("Frame", nil, city)
        monster:SetSize(32, 43); monster:SetFrameLevel(city:GetFrameLevel() + 5)
        local c = colors[slot]
        rect(monster, 5, 5, 22, 24, c[1], c[2], c[3]); rect(monster, 3, 28, 26, 12, c[1], c[2], c[3])
        rect(monster, 3, 38, 6, 5 + slot, c[1], c[2], c[3]); rect(monster, 23, 38, 6, 5 + slot, c[1], c[2], c[3])
        rect(monster, 4, 0, 9, 8, c[1], c[2], c[3]); rect(monster, 20, 0, 9, 8, c[1], c[2], c[3])
        rect(monster, 8, 30, 5, 5, 1, 1, 1); rect(monster, 20, 30, 5, 5, 1, 1, 1)
        rect(monster, 10, 31, 3, 3, 0.05, 0.05, 0.05); rect(monster, 22, 31, 3, 3, 0.05, 0.05, 0.05)
        rect(monster, 12, 21, 9, 3, 0.1, 0.1, 0.1)
        monster.fist = rect(monster, 27, 16, 22, 12, c[1], c[2], c[3])
        monster.flash = rect(monster, 46, 12, 9, 21, 1, 0.95, 0.6, 0.9, "OVERLAY")
        monster.label = text(monster, 10, -5, -48, 44, "CENTER")
        monster.label:SetText(tostring(slot)); monster.hit, monster.untilTime = -1, 0
        UI.monsters[slot] = monster
    end
    UI.hint = text(root, 13, 24, -453, 672, "CENTER")
    UI.status = text(root, 12, 24, -494, 672, "CENTER")
    UI.controls = {}
    local labels, actions, widths = { "< Left", "^ Climb", "PUNCH!", "v Down", "Right >" }, { "L", "U", "P", "D", "R" }, { 90, 90, 150, 90, 90 }
    local x = 73
    for i = 1, 5 do
        local action = actions[i]
        UI.controls[i] = button(root, labels[i], x, -548, widths[i], function() app.net:action(action); UI.render() end)
        x = x + widths[i] + 8
    end
    UI.footer = text(root, 10, 22, -589, 676, "CENTER")
    UI.footer:SetText("Mouse clicks only • No global keybinds, chat or sound spam • Close hides; Leave exits • Combat pauses the host")
    root:Hide()
    return root
end

function UI.selectedLobby()
    local list = UI.app.net:lobbyList()
    if #list == 0 then return nil end
    for _, lobby in ipairs(list) do if lobby.name == UI.lobbyName then return lobby end end
    UI.lobbyName = list[1].name
    return list[1]
end

function UI.render()
    if not UI.root or not UI.root:IsShown() then return end
    local app, now = UI.app, UI.app.now()
    local net, s = app.net, app.net.state
    local idle = net.mode == "idle"
    enabled(UI.solo, idle and not net.combat); enabled(UI.host, idle and net.grouped and not net.combat)
    enabled(UI.find, net.grouped); enabled(UI.leave, not idle)
    enabled(UI.start, (net.mode == "host" or net.mode == "solo") and s and (s.phase == "lobby" or s.phase == "victory") and not net.combat)
    local lobby = UI.selectedLobby()
    UI.displayedLobby = lobby
    enabled(UI.join, idle and lobby ~= nil and not net.combat); enabled(UI.next, lobby ~= nil)
    UI.lobby:SetText(lobby and ("Selected: " .. lobby.name .. "  [" .. lobby.count .. "/4, " .. lobby.phase .. "]") or "No lobby found. Group up, ask a friend to Host, then click Find.")
    if not idle then UI.lobby:SetText("Mode: " .. net.mode .. (net.hostName and ("  •  Host: " .. net.hostName) or "") .. "  •  Best: " .. (app.db.best or 0)) end
    for slot = 1, 4 do
        local member, p = net.members[slot], s and s.players[slot]
        UI.scores[slot]:SetText(member and (slot .. ". " .. (string.match(member.name, "^[^-]+") or member.name) .. (slot == net.slot and " (you)" or "") .. "\n" .. (p and p.score or 0) .. " fame") or (slot .. ". open slot"))
        local monster = UI.monsters[slot]
        if p then
            monster:Show(); monster:ClearAllPoints()
            monster:SetPoint("BOTTOMLEFT", UI.city, "BOTTOMLEFT", 52 + (p.x - 1) * 95 - 16 + (slot - 2.5) * 9,
                18 + (p.y > 0 and ((p.y - 1) * 60 + 15) or 0))
            if monster.hit ~= p.hit then monster.hit, monster.untilTime = p.hit, now + 0.18 end
            if now < monster.untilTime then monster.fist:Show(); monster.flash:Show() else monster.fist:Hide(); monster.flash:Hide() end
        else monster:Hide() end
    end
    local alive = s and addon.Model.cityAlive(s)
    for i = 1, 9 do
        local hp = s and s.hp[i] or 2
        if s and s.phase == "lobby" then hp = 2 end
        local tile = UI.floors[i]
        if hp and hp > 0 then
            tile:Show(); tile.body:SetColorTexture(hp == 2 and 0.36 or 0.24, hp == 2 and 0.42 or 0.27, hp == 2 and 0.51 or 0.32, 1)
            if hp == 1 then tile.crack:Show() else tile.crack:Hide() end
            for _, window in ipairs(tile.windows) do window:SetAlpha(hp == 2 and 1 or 0.25) end
        else tile:Hide() end
    end
    for i = 1, 3 do
        if s and s.phase ~= "lobby" and not addon.Model.towerAlive(s, i) then UI.rubble[i]:Show() else UI.rubble[i]:Hide() end
    end
    if s and s.phase == "play" and not alive then
        UI.boss:Show(); UI.boss.body:SetColorTexture(unpack(bossColors[s.stage]))
    else UI.boss:Hide() end
    local canPlay = s and s.phase == "play" and not s.paused and not net.combat and net.mode ~= "joining"
    for _, control in ipairs(UI.controls) do enabled(control, canPlay) end
    if not s then
        UI.stageText:SetText("SMASH THE CITY. BUILD TOAST'S FAME.")
        UI.hint:SetText("Solo starts immediately. For co-op: Host → friends Find + Join → host Start.")
    elseif s.paused then
        UI.stageText:SetText("PAUSED — HOST IS IN COMBAT")
        UI.hint:SetText("Raid first, tiny monsters second. The game resumes when the host leaves combat.")
    elseif s.phase == "lobby" then
        UI.stageText:SetText("LOBBY • " .. net:count() .. "/4 MONSTERS • FOUR MORE BOSSES!")
        UI.hint:SetText("Host clicks Start when ready. Friends can also join a game already in progress.")
    elseif s.phase == "victory" then
        UI.stageText:SetText("TOAST WINS! ZERO MORE BOSSES! • " .. addon.Model.total(s) .. " team fame")
        UI.hint:SetText("Four fictional bosses flattened. Everyone wins! Host: Start / replay for another round.")
    elseif s.phase == "clear" then
        UI.stageText:SetText("BOSS FLATTENED! " .. (4 - s.stage) .. " MORE BOSSES!")
        UI.hint:SetText("Next city in a moment… Your fame carries through all four stages.")
    else
        UI.stageText:SetText(s.stage .. "/4 • " .. addon.Model.BOSSES[s.stage] .. (alive and " • SHIELDED" or (" • " .. s.boss .. " HP")))
        UI.hint:SetText(alive and "Walk onto a tower (lanes 2, 4, 6). Climb + PUNCH each floor twice. Down to walk.\nFlatten all three towers to expose the boss!" or "BOSS EXPOSED! Stand on the ground in the middle three lanes (3–5) and PUNCH!")
    end
    UI.status:SetText(net.status)
end

function UI.toggle(app)
    if app.net.combat then app.net:notice("Window unavailable in combat. Raid first!"); return false end
    local root = UI.create(app)
    if root:IsShown() then root:Hide() else root:Show(); UI.render() end
    return true
end

function UI.combat(active)
    if not UI.root then return end
    if active then
        UI.restoreAfterCombat = UI.root:IsShown()
        UI.root:StopMovingOrSizing(); UI.root:Hide()
    elseif UI.restoreAfterCombat then
        UI.restoreAfterCombat = false; UI.root:Show(); UI.render()
    end
end
