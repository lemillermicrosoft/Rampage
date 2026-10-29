-- Original Toast arcade art: every silhouette, prop and particle is authored here.
-- Fixed pools: 25 creatures, 25 crew chips, 9 floors and 72 reusable effect shapes.
local _, addon = ...
local UI = { WIDTH = 900, HEIGHT = 660, MAX = 25 }
addon.UI = UI
local palette = { {0.37,0.88,0.61}, {1,0.61,0.32}, {0.58,0.69,1}, {1,0.49,0.66}, {0.91,0.79,0.38} }
local bossPalette = { {0.92,0.60,0.25}, {0.56,0.73,0.79}, {0.87,0.35,0.49}, {0.65,0.48,0.85} }
local function rect(parent, x, y, w, h, r, g, b, a, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, y); t:SetSize(w, h)
    t:SetColorTexture(r, g, b, a or 1)
    return t
end
local function place(t, parent, x, y)
    -- WoW offsets are in the anchored object's scale; preserve city coordinates.
    local scale = t.artScale or 1
    t:ClearAllPoints(); t:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x/scale, y/scale)
end
local function text(parent, size, x, y, width, align)
    local t = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetFont(STANDARD_TEXT_FONT, size, ""); t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    t:SetWidth(width); t:SetJustifyH(align or "LEFT"); t:SetTextColor(0.96,0.89,0.73)
    return t
end
local function hover(frame, title, body)
    frame:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(type(title) == "function" and title() or title)
        local detail = type(body) == "function" and body() or body
        if detail then GameTooltip:AddLine(detail, 0.9,0.87,0.77, true) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end
local function button(parent, label, x, y, width, callback, primary)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 30); b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); b:EnableMouse(true)
    b.base = rect(b, 0,0,width,30, primary and 0.86 or 0.23, primary and 0.43 or 0.21, primary and 0.19 or 0.23)
    rect(b,0,29,width,1,1,0.75,0.42,primary and 0.9 or 0.35)
    b.label = text(b,12,3,-8,width-6,"CENTER"); b.label:SetText(label)
    b:SetScript("OnClick", callback)
    b:SetScript("OnMouseDown", function(self) self.base:SetAlpha(0.65) end)
    b:SetScript("OnMouseUp", function(self) self.base:SetAlpha(1) end)
    return b
end
local function label(b, value) b.label:SetText(value) end
local function enabled(b, yes)
    if yes then b:Enable(); b:SetAlpha(1) else b:Disable(); b:SetAlpha(0.38) end
end
local function show(object, yes) if yes then object:Show() else object:Hide() end end
local function short(name) return (string.match(name or "", "^[^-]+") or name or "") end
local function color(slot) return palette[(slot - 1) % #palette + 1] end
local function creature(parent, slot, boss)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(48,64); f:SetFrameLevel(parent:GetFrameLevel() + (boss and 3 or 8)); f:EnableMouse(true)
    local c, variant = color(slot), (slot-1)%4
    f.tint = {}
    local function skin(x,y,w,h,shade,owner)
        local t = rect(owner or f,x,y,w,h,c[1]*(shade or 1),c[2]*(shade or 1),c[3]*(shade or 1))
        f.tint[#f.tint+1] = {t,shade or 1}; return t
    end
    f.shadow = rect(f,1,-1,47,4,0.035,0.025,0.04,0.65,"BACKGROUND")
    f.halo = rect(f,-5,-3,58,3,1,0.87,0.42,1,"BACKGROUND")
    -- Stepped silhouettes: heavy shoulders, short legs, tail, snout, ears/horns.
    f.tail = skin(-9,10,17,7,0.66); skin(-13,14,7,6,0.66)
    skin(5,11,37,27,0.72); skin(9,7,29,37); skin(4,30,39,12)
    skin(8,41,31,13); skin(12,52,24,6)
    f.belly = rect(f,15,13,17,19,c[1]*0.73,c[2]*0.8,c[3]*0.7)
    skin(variant == 1 and 30 or 5,52,7,10,0.8); skin(variant == 2 and 18 or 32,54,6,10,0.8)
    if variant == 0 then skin(0,24,10,18,0.8); skin(36,23,12,18,0.8)
    elseif variant == 1 then skin(33,39,13,10); skin(-6,20,10,5,0.9)
    elseif variant == 2 then skin(0,31,7,17,0.8); skin(41,31,7,17,0.8)
    else skin(1,51,11,8); skin(35,51,11,8) end
    rect(f,12,44,9,8,1,0.94,0.72); rect(f,29,44,9,8,1,0.94,0.72)
    f.pupilL = rect(f,17,45,4,5,0.07,0.065,0.10); f.pupilR = rect(f,33,45,4,5,0.07,0.065,0.10)
    rect(f,10,52,13,3,0.10,0.09,0.13); rect(f,28,53,13,3,0.10,0.09,0.13)
    rect(f,21,32,20,7,0.13,0.065,0.10); rect(f,24,35,4,4,1,0.91,0.67); rect(f,34,35,4,4,1,0.91,0.67)
    f.legL = skin(7,1,13,12,0.85); f.legR = skin(29,1,13,12,0.85)
    f.armL = skin(0,20,12,19,0.86); f.armR = skin(37,20,12,19,0.86)
    f.fist = skin(44,28,15,15); f.fist:Hide()
    f.badge = text(f,10,-5,-68,58,"CENTER")
    f.badge:SetText(tostring(slot)); f.hit = nil
    return f
end
function UI.fit()
    if not UI.root then return end
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    if w and h and w > 0 and h > 0 then UI.root:SetScale(math.min(1, (w-30)/UI.WIDTH, (h-40)/UI.HEIGHT)) end
end
function UI.selectedLobby()
    local list = UI.app.net:lobbyList()
    for _, lobby in ipairs(list) do if lobby.name == UI.lobbyName then return lobby end end
    if list[1] then UI.lobbyName = list[1].name end
    return list[1]
end
function UI.create(app)
    if UI.root then return UI.root end
    local root = CreateFrame("Frame", "ToastRampageWindow", UIParent)
    UI.root, UI.app = root, app
    root:SetSize(UI.WIDTH,UI.HEIGHT); root:SetPoint("CENTER"); root:SetClampedToScreen(true)
    root:SetFrameStrata("DIALOG"); root:EnableMouse(true); root:SetMovable(true); root:RegisterForDrag("LeftButton")
    root:SetScript("OnDragStart", function(self) if not app.net.combat then self:StartMoving() end end)
    root:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        app.db.position = {point=point,relativePoint=relativePoint,x=x,y=y}
    end)
    local p, anchors = app.db.position, {CENTER=true,TOP=true,BOTTOM=true,LEFT=true,RIGHT=true,TOPLEFT=true,TOPRIGHT=true,BOTTOMLEFT=true,BOTTOMRIGHT=true}
    if type(p)=="table" and anchors[p.point] and anchors[p.relativePoint] and type(p.x)=="number" and type(p.y)=="number"
        and math.abs(p.x)<10000 and math.abs(p.y)<10000 then
        root:ClearAllPoints(); root:SetPoint(p.point,UIParent,p.relativePoint,p.x,p.y)
    end
    rect(root,0,0,900,660,0.09,0.073,0.091,0.99,"BACKGROUND")
    rect(root,1,1,898,2,0.55,0.31,0.21); rect(root,0,656,900,4,0.98,0.59,0.28)
    rect(root,18,609,45,33,0.74,0.35,0.18); rect(root,23,614,35,26,0.98,0.73,0.4)
    rect(root,29,620,5,4,0.25,0.14,0.13); rect(root,45,620,5,4,0.25,0.14,0.13)
    text(root,11,76,-17,540):SetText("< TOAST >  /  POCKET ARCADE")
    text(root,24,75,-32,650):SetText("RAMPAGE: FOUR MORE BOSSES!")
    UI.close = button(root,"X",850,-16,30,function() root:Hide() end)
    hover(UI.close,"Close window","Releases keyboard. Does not leave the game. /rampage reopens it.")
    UI.primary = button(root,"HOST & START",20,-76,184,function()
        local net, lobby = app.net, UI.displayedLobby
        if net.mode == "idle" then
            if lobby then net:join(lobby.name,lobby.sid,"play")
            elseif net.grouped then if net:host() then net:start() end
            else net:solo() end
        elseif net.role == "spectate" then if net.setRole then net:setRole("play") end
        elseif net.state and (net.state.phase == "lobby" or net.state.phase == "victory") then net:start()
        elseif app.input then app.input:grab() end
        UI.render()
    end,true)
    UI.join, UI.host, UI.start = UI.primary, UI.primary, UI.primary
    hover(UI.primary,"Play together","JOIN GAME opts you into the selected lobby. Host & Start opens a game immediately. PLAY explicitly captures keys; Escape returns them to WoW.")
    UI.spectate = button(root,"SPECTATE",212,-76,120,function()
        if app.input then app.input:release("Spectating — no avatar or controls") end
        if app.net.mode == "idle" and UI.displayedLobby then app.net:join(UI.displayedLobby.name,UI.displayedLobby.sid,"spectate")
        elseif app.net.setRole then app.net:setRole("spectate") end
        UI.render()
    end)
    hover(UI.spectate,"Watch only","Up to 15 spectators in a full 40-player raid. No avatar, input or starting. Switch to Play when one of the 25 active slots opens.")
    UI.solo = button(root,"Solo practice",340,-76,114,function() app.net:solo(); UI.render() end)
    UI.next = button(root,"Next host",462,-76,94,function()
        local list, current = app.net:lobbyList(),0
        for i,l in ipairs(list) do if l.name == UI.lobbyName then current=i end end
        if #list>0 then UI.lobbyName=list[current%#list+1].name end; UI.render()
    end)
    hover(UI.next,"Advanced: choose another host","Lobbies refresh automatically only while this window is open. Joining is always your choice.")
    UI.leave = button(root,"Leave",792,-76,88,function()
        if app.input then app.input:release("Left game — keys released") end
        app.persist(); app.net:leave(); UI.render()
    end)
    UI.lobby = text(root,12,21,-116,859)
    local city = CreateFrame("Frame",nil,root); UI.city=city
    city:SetSize(632,354); city:SetPoint("BOTTOMLEFT",root,"BOTTOMLEFT",20,174)
    -- Warm dusk bands, long-distance skyline, lamps and a raised two-tone street.
    for i=0,11 do rect(city,0,i*29.5,632,30,0.19+i*0.012,0.13+i*0.006,0.21+i*0.005,1,"BACKGROUND") end
    rect(city,543,244,52,50,0.98,0.63,0.34,0.85,"BACKGROUND")
    rect(city,536,254,66,28,0.98,0.63,0.34,0.85,"BACKGROUND")
    for i=1,19 do
        local x, h = (i-1)*35, 37+(i*17)%55
        rect(city,x,28,28,h,0.13,0.14,0.20,1,"BACKGROUND")
        for row=1,3 do rect(city,x+7,30+row*15,3,4,0.71,0.40,0.28,0.45,"BACKGROUND") end
    end
    rect(city,0,0,632,30,0.11,0.12,0.15); rect(city,0,26,632,5,0.61,0.45,0.32)
    for i=1,9 do rect(city,17+(i-1)*73,10,29,2,0.82,0.65,0.43) end
    for _,x in ipairs({43,227,409,595}) do
        rect(city,x,30,3,51,0.18,0.19,0.22); rect(city,x-5,79,13,5,1,0.74,0.36)
        rect(city,x-10,74,23,16,1,0.66,0.27,0.08)
    end
    UI.stageText = text(city,13,12,-10,608,"CENTER")
    UI.bossBarBack = rect(city,134,305,364,5,0.06,0.05,0.08)
    UI.bossBar = rect(city,134,305,364,5,0.95,0.54,0.28)
    UI.bossLabel = text(city,10,10,-52,612,"CENTER")
    UI.floors,UI.rubble={},{}
    for tower=1,3 do
        local x=126+(tower-1)*190
        for floor=1,3 do
            local tile=CreateFrame("Frame",nil,city); tile:SetFrameLevel(city:GetFrameLevel()+2)
            tile:SetSize(80,66); tile:SetPoint("BOTTOMLEFT",city,"BOTTOMLEFT",x-40,31+(floor-1)*68)
            tile.body=rect(tile,0,0,80,66,0.40,0.34,0.37)
            rect(tile,0,0,7,66,0.28,0.24,0.29); rect(tile,75,0,5,66,0.23,0.20,0.26)
            rect(tile,-3,62,86,4,0.74,0.55,0.40); rect(tile,0,57,80,5,0.25,0.22,0.26)
            tile.windows={}
            for w=1,3 do
                rect(tile,12+(w-1)*22,16,15,31,0.13,0.16,0.23)
                tile.windows[w]=rect(tile,14+(w-1)*22,18,11,27,1,0.72-(tower%2)*0.08,0.33)
                rect(tile,12+(w-1)*22,29,15,3,0.37,0.28,0.27)
            end
            tile.crack=CreateFrame("Frame",nil,tile); tile.crack:SetSize(80,66); tile.crack:SetPoint("BOTTOMLEFT",tile,"BOTTOMLEFT",0,0)
            rect(tile.crack,35,33,5,30,0.09,0.08,0.12); rect(tile.crack,39,25,10,8,0.09,0.08,0.12)
            rect(tile.crack,45,0,5,28,0.09,0.08,0.12)
            UI.floors[(tower-1)*3+floor]=tile
        end
        local roof=UI.floors[(tower-1)*3+3]
        rect(roof,7,67,66,8,0.25,0.20,0.25); rect(roof,13,75,4,14,0.18,0.18,0.23)
        text(roof,9,3,-3,74,"CENTER"):SetText(({"CRUMB CO.","TOAST BANK","SNACK HOTEL"})[tower])
        local rubble=CreateFrame("Frame",nil,city); rubble:SetSize(94,25); rubble:SetPoint("BOTTOMLEFT",city,"BOTTOMLEFT",x-47,30)
        for j=1,8 do rect(rubble,(j-1)*11,(j%3)*3,15,6+(j%3)*4,0.51,0.37,0.30) end
        UI.rubble[tower]=rubble
    end
    UI.boss=creature(city,2,true); UI.boss:SetScale(1.5); UI.boss.badge:SetText("BOSS")
    UI.boss.crown=rect(UI.boss,14,59,22,5,1,0.80,0.37)
    for i=1,3 do rect(UI.boss,12+i*6,64,4,6+i%2*3,1,0.80,0.37) end
    UI.monsters={}
    for slot=1,UI.MAX do
        local monster=creature(city,slot); monster.artScale=0.73; monster:SetScale(monster.artScale)
        local n=slot
        hover(monster,function() local m=app.net.members[n]; return m and m.name or ("Monster "..n) end,
            function() local s=app.net.state; local p=s and s.players[n]; return p and (p.score.." fame • lane "..p.x.." • floor "..p.y) or "Waiting for player" end)
        UI.monsters[slot]=monster
    end
    -- Fixed particle frame sits above the city; textures are recycled round-robin.
    UI.fx=CreateFrame("Frame",nil,city); UI.fx:SetSize(632,354); UI.fx:SetPoint("BOTTOMLEFT",city,"BOTTOMLEFT",0,0)
    UI.fx:SetFrameLevel(city:GetFrameLevel()+14); UI.particles={}; UI.particleCursor=0
    for i=1,72 do local t=rect(UI.fx,0,0,5,5,1,0.7,0.4); t:Hide(); UI.particles[i]={texture=t} end
    UI.banner=CreateFrame("Frame",nil,city); UI.banner:SetSize(430,66); UI.banner:SetPoint("BOTTOMLEFT",city,"BOTTOMLEFT",101,145)
    UI.banner:SetFrameLevel(city:GetFrameLevel()+20); rect(UI.banner,0,0,430,66,0.12,0.075,0.12,0.94)
    rect(UI.banner,0,64,430,2,1,0.66,0.30); UI.banner.title=text(UI.banner,23,8,-10,414,"CENTER")
    UI.banner.sub=text(UI.banner,11,8,-39,414,"CENTER"); UI.banner:Hide()
    local crew=CreateFrame("Frame",nil,root); UI.crew=crew
    crew:SetSize(208,354); crew:SetPoint("BOTTOMLEFT",root,"BOTTOMLEFT",672,174)
    rect(crew,0,0,208,354,0.14,0.12,0.15,1,"BACKGROUND")
    UI.crewTitle=text(crew,14,12,-12,184); UI.crewSub=text(crew,11,12,-33,184)
    UI.scores={}
    for slot=1,25 do
        local c,n=color(slot),slot
        local chip=button(crew,tostring(slot),10+((slot-1)%5)*38,-59-math.floor((slot-1)/5)*37,34,function() end)
        chip.base:SetColorTexture(c[1]*0.30,c[2]*0.30,c[3]*0.30,1)
        hover(chip,function() local m=app.net.members[n]; return m and (n..". "..m.name) or ("Slot "..n.." • open") end,
            function() local s=app.net.state; local p=s and s.players[n]; return p and (p.score.." fame"..(n==app.net.slot and " • YOU" or "")) or "An active player may join this slot." end)
        UI.scores[slot]=chip
    end
    UI.personal=text(crew,19,12,-257,184); UI.team=text(crew,12,12,-286,184); UI.best=text(crew,11,12,-309,184)
    UI.capture=button(root,"PLAY • GRAB KEYS",20,-500,188,function()
        if app.input.focused then app.input:release() else app.input:grab() end; UI.render()
    end,true)
    UI.captureStatus=text(root,12,222,-507,655)
    UI.controls={}
    local labels,actions={"A / ←","W / ↑","SPACE","S / ↓","D / →"},{"L","U","P","D","R"}
    for i=1,5 do
        local action=actions[i]
        UI.controls[i]=button(root,labels[i],20+(i-1)*65,-542,59,function() app.input:action(action); UI.render() end)
        hover(UI.controls[i],"Mouse fallback: "..action,"Keyboard is primary: click PLAY, then hold WASD / arrows or Space. One action at a time, about five per second.")
    end
    UI.audio=button(root,"Local BM: OFF",575,-542,145,function()
        app.db.useBlasterMaster=not app.db.useBlasterMaster; UI.render()
    end)
    hover(UI.audio,"Use local BlasterMaster (optional)",function()
        return "Default OFF. Uses your installed provider's crit / combatStart / levelUp mappings, including None and volume variants. No audio files bundled. "..(app.sound and app.sound.status or "")
    end)
    UI.mute=button(root,"Mute",728,-542,152,function() app.db.muted=not app.db.muted; UI.render() end)
    UI.hint=text(root,12,21,-585,858)
    UI.status=text(root,10,21,-622,858)
    app.input=addon.Input.create(app,root)
    root:SetScript("OnHide",function() app.input:release("Window hidden — keys released"); UI.baseline=nil; if GameTooltip then GameTooltip:Hide() end end)
    root:SetScript("OnShow",function() UI.fit(); UI.nextDiscovery=0; UI.baseline=nil end)
    UI.fit(); root:Hide(); return root
end
function UI.burst(x,y,count,style)
    local now=UI.app.now()
    for i=1,count do
        UI.particleCursor=UI.particleCursor%#UI.particles+1
        local p=UI.particles[UI.particleCursor]
        local angle=i*2.39996
        p.x,p.y,p.vx,p.vy,p.start,p.duration=x,y,math.cos(angle)*(25+i%5*12),28+(i%7)*12,now,0.38+(i%5)*0.10
        p.confetti=style=="victory"
        if p.confetti then p.vy=-15-(i%5)*15; p.duration=1.7 end
        local c=p.confetti and color(i) or (style=="hit" and {1,0.83,0.41} or {0.77,0.56,0.38})
        p.texture:SetColorTexture(c[1],c[2],c[3],1); p.texture:SetSize(style=="hit" and 3 or 5,style=="hit" and 11 or 5)
        place(p.texture,UI.fx,x,y); p.texture:Show()
    end
end
function UI.effects(now)
    for _,p in ipairs(UI.particles) do
        if p.start then
            local age=now-p.start
            if age>=p.duration then p.texture:Hide(); p.start=nil
            else place(p.texture,UI.fx,p.x+p.vx*age,math.max(30,p.y+p.vy*age-(p.confetti and 5 or 85)*age*age)); p.texture:SetAlpha(1-age/p.duration) end
        end
    end
end
function UI.render()
    if not UI.root or not UI.root:IsShown() then return end
    local app,now=UI.app,UI.app.now(); local net,s=app.net,app.net.state
    local idle=net.mode=="idle"; local spectator=net.role=="spectate"; local count=net:count()
    local watch=net.spectatorCount and net:spectatorCount() or 0
    local lobby=UI.selectedLobby(); UI.displayedLobby=lobby
    local lobbyFull=lobby and lobby.count+(lobby.spectators or 0)>=40
    local activeFull=lobby and lobby.count>=25
    local canPlay=app.input:canPlay()
    if idle then label(UI.primary,lobby and (lobbyFull and "GAME FULL" or (activeFull and "PLAYERS FULL" or "JOIN GAME")) or (net.grouped and "HOST & START" or "PLAY SOLO"))
    elseif spectator then label(UI.primary,"SWITCH TO PLAY")
    elseif s and s.phase=="victory" then label(UI.primary,"PLAY AGAIN")
    elseif s and s.phase=="lobby" then label(UI.primary,"START GAME")
    else label(UI.primary,app.input.focused and "PLAYING • KEYS LIVE" or "PLAY • GRAB KEYS") end
    local owner=net.mode=="host" or net.mode=="solo"
    enabled(UI.primary,not net.combat and (idle and (not lobby or not lobbyFull and not activeFull) or spectator and count<25 and net.mode~="joining"
        or not spectator and (canPlay or owner and s and (s.phase=="lobby" or s.phase=="victory"))))
    label(UI.spectate,idle and lobbyFull and "GAME FULL" or "SPECTATE")
    enabled(UI.spectate,not net.combat and (idle and lobby~=nil and not lobbyFull or net.mode=="client" and not spectator))
    enabled(UI.solo,idle and not net.combat); enabled(UI.next,idle and lobby~=nil); enabled(UI.leave,not idle)
    local lobbyLine=lobby and ("FOUND  "..short(lobby.name).."  •  "..lobby.count.."/25 playing  •  "..(lobby.spectators or 0).." watching  •  "..lobby.phase)
        or (net.grouped and "Looking for group lobbies… or host a new game. Joining is always opt-in." or "Solo ready. Join a party / raid to find friends automatically.")
    if lobbyFull then lobbyLine=lobbyLine.."  •  FULL (40/40)"
    elseif activeFull then lobbyLine=lobbyLine.."  •  Players full — SPECTATE to watch" end
    UI.lobby:SetText(idle and lobbyLine or ((spectator and "WATCHING" or string.upper(net.mode)).."  •  "..(net.hostName and short(net.hostName) or "Your pocket city").."  •  "..count.."/25 monsters  •  "..watch.." spectators • 40 total max"))
    UI.crewTitle:SetText("THE CREW  "..count.." / 25"); UI.crewSub:SetText(watch.." watching • hover a slot")
    for slot=1,25 do
        local member=net.members[slot]; local p=s and s.players[slot]; local chip=UI.scores[slot]
        label(chip,member and ((slot==net.slot and ">" or "")..tostring(slot)) or "·")
        chip:SetAlpha(member and 1 or 0.25)
        chip.label:SetTextColor(slot==net.slot and 1 or 0.87,slot==net.slot and 0.84 or 0.82,slot==net.slot and 0.40 or 0.75)
        local m=UI.monsters[slot]
        if p then
            local changed=m.x~=p.x or m.y~=p.y
            if changed then m.moveUntil=now+0.22 end
            local siblings,rank=0,0
            for other=1,25 do local q=s.players[other]; if q and q.x==p.x and q.y==p.y then siblings=siblings+1; if other<slot then rank=rank+1 end end end
            -- A bounded 5x5 fan, not an ever-growing horizontal spill into other lanes.
            local columns=math.min(5,siblings); local row=math.floor(rank/5)
            local dx=((rank%5)-(columns-1)/2)*12
            local targetX=31+(p.x-1)*95+dx-17
            local targetY=32+(p.y>0 and ((p.y-1)*68+22) or 0)+row*9
            local first=m.hit==nil or not UI.baseline
            if first then m.drawX,m.drawY=targetX,targetY end
            m.drawX=m.drawX+(targetX-m.drawX)*0.55; m.drawY=m.drawY+(targetY-m.drawY)*0.55
            if not first and m.hit~=p.hit then m.punchUntil=now+0.19; UI.burst(targetX+43,targetY+26,5,"hit") end
            m.hit,m.x,m.y=p.hit,p.x,p.y
            local walking=now<(m.moveUntil or 0); local bob=walking and math.sin(now*30+slot)*2 or math.sin(now*3+slot)*0.7
            place(m,UI.city,m.drawX,m.drawY+bob); m:Show(); m:SetAlpha(slot==net.slot and 1 or (siblings>8 and 0.85 or 1))
            m:SetFrameLevel(UI.city:GetFrameLevel()+(slot==net.slot and 12 or 8+row%3))
            show(m.halo,slot==net.slot); m.badge:SetText(slot==net.slot and "YOU" or tostring(slot))
            m.badge:SetTextColor(slot==net.slot and 1 or 0.9,slot==net.slot and 0.88 or 0.83,slot==net.slot and 0.40 or 0.74)
            place(m.legL,m,7,walking and 1+math.sin(now*30)*3 or 1)
            place(m.legR,m,29,walking and 1-math.sin(now*30)*3 or 1)
            place(m.armL,m,0,p.y>0 and 36+math.sin(now*10)*3 or 20)
            place(m.armR,m,37,p.y>0 and 30-math.sin(now*10)*3 or 20)
            show(m.fist,now<(m.punchUntil or 0))
        else m:Hide(); m.hit=nil; m.x=nil; m.y=nil end
    end
    local localP=s and net.slot and s.players[net.slot]
    UI.personal:SetText(spectator and "SPECTATOR" or (localP and (localP.score.."  YOUR FAME") or "READY TO SMASH?"))
    UI.team:SetText((s and addon.Model.total(s) or 0).." team fame")
    UI.best:SetText("Personal best  "..(app.db.best or 0))
    local alive=s and addon.Model.cityAlive(s)
    local previous=UI.baseline
    local same=previous and s and previous.stage==s.stage and previous.sid==net.sid
    for i=1,9 do
        local hp=s and s.phase~="lobby" and (s.hp[i] or 0) or 2; local tile=UI.floors[i]
        show(tile,hp>0); show(tile.crack,hp==1)
        tile.body:SetColorTexture(hp==2 and 0.40 or 0.27,hp==2 and 0.34 or 0.23,hp==2 and 0.37 or 0.26,1)
        for _,w in ipairs(tile.windows) do w:SetAlpha(hp==2 and 0.9+math.sin(now*1.3+i)*0.08 or 0.23) end
        if same and previous.hp[i] and hp<previous.hp[i] then
            local tower=math.floor((i-1)/3)+1; local floor=(i-1)%3+1
            UI.burst(126+(tower-1)*190,48+(floor-1)*68,hp==0 and 14 or 7,hp==0 and "dust" or "hit")
        end
    end
    for i=1,3 do show(UI.rubble[i],s and s.phase~="lobby" and not addon.Model.towerAlive(s,i)) end
    local boss=UI.boss; local stage=s and s.stage or 1; local bc=bossPalette[stage]
    for _,part in ipairs(boss.tint) do part[1]:SetColorTexture(bc[1]*part[2],bc[2]*part[2],bc[3]*part[2],1) end
    show(boss,s and s.phase=="play"); boss:SetAlpha(alive and 0.6 or 1)
    boss.artScale=alive and 0.80 or 1.5; boss:SetScale(boss.artScale); show(boss.halo,not alive)
    place(boss,UI.city,alive and 351 or 267,alive and 218 or 32+math.sin(now*3)*2)
    boss.badge:SetText(alive and "SHIELDED" or "BOSS")
    UI.bossBar:SetWidth(math.max(1,364*(s and s.boss or 10)/(8+stage*2)))
    UI.bossBar:SetColorTexture(alive and 0.64 or 0.98,alive and 0.61 or 0.40,alive and 0.65 or 0.26,1)
    UI.bossLabel:SetText(s and s.phase=="play" and (alive and "SHIELD UP • flatten every floor to expose the creature" or (s.boss.." HP • EXPOSED! Ground lanes 3–5 + SPACE")) or "25 MONSTERS • 4 CITIES • ONE VERY TOASTY TEAM")
    show(UI.banner,s and (s.phase=="victory" or s.phase=="clear" or s.paused))
    if s and s.paused then UI.banner.title:SetText("RAID FIRST. SMASH LATER."); UI.banner.sub:SetText("Host in combat — everyone is paused")
    elseif s and s.phase=="victory" then UI.banner.title:SetText("TOAST WINS!"); UI.banner.sub:SetText("ZERO MORE BOSSES • "..addon.Model.total(s).." TEAM FAME")
    elseif s and s.phase=="clear" then UI.banner.title:SetText("BOSS FLATTENED!"); UI.banner.sub:SetText((4-s.stage).." more bosses • next city incoming") end
    if previous and s and previous.phase~=s.phase and (s.phase=="clear" or s.phase=="victory") then
        UI.burst(316,185,s.phase=="victory" and 50 or 25,s.phase=="victory" and "victory" or "dust")
    elseif previous and s and previous.stage~=s.stage then UI.burst(316,260,24,"victory") end
    UI.stageText:SetText(s and ("CITY "..s.stage.." / 4   •   "..string.upper(addon.Model.BOSSES[stage])) or "SMASH THE CITY. MAKE TOAST PROUD.")
    enabled(UI.capture,canPlay); label(UI.capture,app.input.focused and "RELEASE KEYS • ESC" or "PLAY • GRAB KEYS")
    UI.captureStatus:SetText(spectator and "WATCH ONLY • no avatar, no captured keys" or app.input.reason)
    UI.captureStatus:SetTextColor(app.input.focused and 0.50 or 0.83,app.input.focused and 0.96 or 0.79,app.input.focused and 0.65 or 0.70)
    for _,b in ipairs(UI.controls) do enabled(b,canPlay) end
    label(UI.audio,app.db.useBlasterMaster and "Local BM: ON" or "Local BM: OFF")
    label(UI.mute,app.db.muted and "UNMUTE RAMPAGE" or "Mute Rampage")
    UI.hint:SetText(spectator and "Enjoy the chaos. Switch to Play above when there is space; this never happens automatically."
        or "WASD / arrows to walk & climb • hold SPACE to punch • Esc releases keys\nClimb towers in lanes 2, 4, 6. Smash each floor twice. Down to street; flatten all towers, then punch the boss.")
    UI.status:SetText((net.status or "").."  •  Drag title to move • Close hides; Leave exits")
    UI.baseline=s and {stage=s.stage,phase=s.phase,sid=net.sid,hp={}} or nil
    if s then for i=1,9 do UI.baseline.hp[i]=s.hp[i] end end
    UI.effects(now)
end
function UI.update(elapsed)
    if not UI.root or not UI.root:IsShown() then return end
    local net,now=UI.app.net,UI.app.now()
    if net.mode=="idle" and net.grouped and not net.combat and now>=(UI.nextDiscovery or 0) then
        UI.nextDiscovery=now+4; net:discover()
    end
end
function UI.toggle(app)
    if app.net.combat then app.net:notice("Window unavailable in combat. Raid first!"); return false end
    local root=UI.create(app)
    if root:IsShown() then root:Hide() else root:Show(); UI.render() end
    return true
end
function UI.combat(active)
    if not UI.root then return end
    if UI.app.input then UI.app.input:release("Combat — keys released") end
    if active then UI.restoreAfterCombat=UI.root:IsShown(); UI.root:StopMovingOrSizing(); UI.root:Hide()
    elseif UI.restoreAfterCombat then UI.restoreAfterCombat=false; UI.root:Show(); UI.render() end
end
