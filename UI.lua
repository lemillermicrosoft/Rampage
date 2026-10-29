-- Original Toast arcade art: every silhouette, prop and particle is authored here.
-- Fixed pools: 25 creatures, 25 crew chips, 7 hazard lanes, 9 floors,
-- 72 particles and 4 x 12 boss-cue textures. No presentation code deals damage.
local _, addon = ...
local UI = { WIDTH = 900, HEIGHT = 660, MAX = 25 }
addon.UI = UI
local palette = { {0.37,0.88,0.61}, {1,0.61,0.32}, {0.58,0.69,1}, {1,0.49,0.66}, {0.91,0.79,0.38} }
local bossPalette = { {0.92,0.60,0.25}, {0.56,0.73,0.79}, {0.87,0.35,0.49}, {0.65,0.48,0.85} }
local hazardFlavor = { "CRUMB THROW", "PERMIT BEAM", "GROUND STOMP", "THREE-COLUMN BARRAGE" }
local function laneX(lane) return 31+(lane-1)*95 end
local function rect(parent, x, y, w, h, r, g, b, a, layer, sublevel)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
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
        if self.paint then self.hovered=true; self:paint() end
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(type(title) == "function" and title() or title)
        local detail = type(body) == "function" and body() or body
        if detail then GameTooltip:AddLine(detail, 0.9,0.87,0.77, true) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function(self)
        if self.paint then self.hovered,self.pressed=false,false; self:paint() end
        if GameTooltip then GameTooltip:Hide() end
    end)
end
local function button(parent, label, x, y, width, callback, primary)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 30); b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); b:EnableMouse(true)
    b.base = rect(b, 0,0,width,30, primary and 0.86 or 0.23, primary and 0.43 or 0.21, primary and 0.19 or 0.23)
    b.edge=rect(b,0,29,width,1,1,0.75,0.42,primary and 0.9 or 0.35)
    b.label = text(b,12,3,-8,width-6,"CENTER"); b.label:SetText(label)
    b.primary=primary
    function b:paint()
        local on=self:IsEnabled()
        local c=self.selected and {0.32,0.48,0.39} or self.tint or (self.primary and {0.86,0.43,0.19} or {0.23,0.21,0.23})
        local gain=on and (self.pressed and 0.65 or (self.hovered and 1.28 or 1)) or 1
        self.base:SetColorTexture(c[1]*gain,c[2]*gain,c[3]*gain,1)
        self.edge:SetAlpha(on and (self.selected and 1 or (self.hovered and 0.9 or 0.45)) or 0.2)
        self:SetAlpha((on and 1 or 0.38)*(self.displayAlpha or 1))
    end
    b:SetScript("OnClick", callback)
    b:SetScript("OnMouseDown", function(self) if self:IsEnabled() then self.pressed=true; self:paint() end end)
    b:SetScript("OnMouseUp", function(self) self.pressed=false; self:paint() end)
    b:SetScript("OnEnter", function(self) self.hovered=true; self:paint() end)
    b:SetScript("OnLeave", function(self) self.hovered,self.pressed=false,false; self:paint() end)
    b:paint()
    return b
end
local function label(b, value) b.label:SetText(value) end
local function enabled(b, yes)
    if yes then b:Enable() else b:Disable(); b.pressed,b.hovered=false,false end
    b:paint()
end
local function selected(b, yes) b.selected=yes; b:paint() end
local function show(object, yes) if yes then object:Show() else object:Hide() end end
local function short(name) return (string.match(name or "", "^[^-]+") or name or "") end
local function color(slot) return palette[(slot - 1) % #palette + 1] end
local function modeName(mode) return mode=="brawl" and "BRAWL" or "CO-OP" end
local function health(bar, p, width)
    local fraction=p and math.max(0,math.min(1,(p.hp or 100)/(p.maxHP or 100))) or 0
    bar:SetWidth(math.max(0.1,width*fraction))
    bar:SetColorTexture(fraction<0.35 and 1 or 0.38,fraction<0.35 and 0.35 or 0.88,0.45,1)
end
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
    f.healthBack=rect(f,3,68,42,3,0.08,0.06,0.09)
    f.health=rect(f,3,68,42,3,0.38,0.88,0.45)
    f.hurt=rect(f,-2,0,52,65,1,0.22,0.15,0.3,"OVERLAY"); f.hurt:Hide()
    if boss then f.healthBack:Hide(); f.health:Hide() end
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
    UI.selectedMode="coop"
    UI.primary = button(root,"HOST LOBBY",20,-76,184,function()
        local net, lobby = app.net, UI.displayedLobby
        if net.mode == "idle" then
            if lobby then net:join(lobby.name,lobby.sid,"play",lobby.mode or "coop")
            elseif net.grouped then net:host(UI.selectedMode)
            else net:solo(UI.selectedMode) end
        elseif net.role == "spectate" then if net.setRole then net:setRole("play") end
        elseif net.state and (net.state.phase == "lobby" or net.state.phase == "victory") then net:start()
        elseif app.input then app.input:grab() end
        UI.render()
    end,true)
    UI.join, UI.host, UI.start = UI.primary, UI.primary, UI.primary
    hover(UI.primary,"Play together","JOIN BRAWL explicitly opts into player-versus-player hits. Co-op is the default. Host Lobby allows mode / AI setup before Start. PLAY captures keys; Escape releases them.")
    UI.spectate = button(root,"SPECTATE",212,-76,120,function()
        if app.input then app.input:release("Spectating — no avatar or controls") end
        if app.net.mode == "idle" and UI.displayedLobby then app.net:join(UI.displayedLobby.name,UI.displayedLobby.sid,"spectate",UI.displayedLobby.mode or "coop")
        elseif app.net.setRole then app.net:setRole("spectate") end
        UI.render()
    end)
    hover(UI.spectate,"Watch only","No avatar, input or starting. Up to 40 humans total; AI only uses the 25 actor slots. Switch to Play when an active slot opens.")
    UI.solo = button(root,"Solo practice",340,-76,114,function() app.net:solo(UI.selectedMode); UI.render() end)
    UI.next = button(root,"Next host",462,-76,94,function()
        local list, current = app.net:lobbyList(),0
        for i,l in ipairs(list) do if l.name == UI.lobbyName then current=i end end
        if #list>0 then UI.lobbyName=list[current%#list+1].name end; UI.render()
    end)
    hover(UI.next,"Advanced: choose another host","Lobbies refresh automatically only while this window is open. Joining is always your choice.")
    local function chooseMode(mode)
        if app.net.mode=="idle" then UI.selectedMode=mode
        elseif app.net.setMode and app.net:setMode(mode) then UI.selectedMode=mode end
        UI.render()
    end
    UI.coop=button(root,"CO-OP",564,-76,102,function() chooseMode("coop") end)
    UI.brawl=button(root,"BRAWL",674,-76,110,function() chooseMode("brawl") end)
    hover(UI.coop,"Co-op: team up","Default mode. Smash together; punches never hurt your crew. Boss hazards still hurt.")
    hover(UI.brawl,"Brawl: optional PvP","Punch other monsters for KOs, separate from fame. Choose before Start / replay, with no guests joined. Start a new lobby to change mode with friends. JOIN BRAWL is explicit consent.")
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
    -- Exactly seven pooled lane frames, below creatures / FX. Only thin edge rails
    -- and a street strip are drawn; warnings never cover action controls or art.
    UI.hazardLanes={}
    for lane=1,7 do
        local mark=CreateFrame("Frame",nil,city); mark:SetSize(58,234)
        mark:SetPoint("BOTTOMLEFT",city,"BOTTOMLEFT",2+(lane-1)*95,0)
        mark:SetFrameLevel(city:GetFrameLevel()+5)
        mark.left=rect(mark,0,29,2,205,1,0.65,0.2,0.7)
        mark.right=rect(mark,56,29,2,205,1,0.65,0.2,0.7)
        mark.strip=rect(mark,0,1,58,8,1,0.65,0.2,0.9)
        mark.label=text(mark,10,0,-214,58,"CENTER"); mark:Hide()
        UI.hazardLanes[lane]=mark
    end
    UI.hazardText=text(city,12,10,-68,612,"CENTER")
    UI.bossBarBack = rect(city,134,305,364,5,0.06,0.05,0.08)
    UI.bossBar = rect(city,134,305,364,5,0.95,0.54,0.28)
    UI.bossLabel = text(city,10,10,-52,612,"CENTER")
    UI.floors,UI.rubble={},{}
    for tower=1,3 do
        local x=126+(tower-1)*190
        for floor=1,3 do
            local tile=CreateFrame("Frame",nil,city); tile:SetFrameLevel(city:GetFrameLevel()+2)
            tile:SetSize(80,66); tile:SetPoint("BOTTOMLEFT",city,"BOTTOMLEFT",x-40,31+(floor-1)*68)
            -- Explicit draw layers/sublevels: native WoW must not rely on the
            -- creation-order tie breaking that made the mock look more detailed.
            tile.body=rect(tile,0,0,80,66,0.40,0.34,0.37,1,"BACKGROUND",0)
            tile.trim={rect(tile,0,0,7,66,0.28,0.24,0.29,1,"BORDER",0),
                rect(tile,75,0,5,66,0.23,0.20,0.26,1,"BORDER",0),
                rect(tile,-3,62,86,4,0.74,0.55,0.40,1,"OVERLAY",1),
                rect(tile,0,57,80,5,0.25,0.22,0.26,1,"BORDER",1)}
            tile.bricks={}
            for row=1,4 do
                tile.bricks[row]=rect(tile,row%2==0 and 8 or 51,2+row*12,19,1,0.65,0.47,0.36,0.7,"BORDER",1)
            end
            tile.windows,tile.windowFrames,tile.mullions,tile.sills,tile.glints={},{},{},{},{}
            for w=1,3 do
                local wx=12+(w-1)*22
                tile.windowFrames[w]=rect(tile,wx,16,15,31,0.13,0.16,0.23,1,"ARTWORK",0)
                tile.windows[w]=rect(tile,wx+2,18,11,27,1,0.72-(tower%2)*0.08,0.33,1,"ARTWORK",1)
                tile.mullions[#tile.mullions+1]=rect(tile,wx,29,15,3,0.37,0.28,0.27,1,"OVERLAY",0)
                tile.mullions[#tile.mullions+1]=rect(tile,wx+7,18,1,27,0.37,0.28,0.27,1,"OVERLAY",0)
                tile.sills[w]=rect(tile,wx-1,14,17,2,0.83,0.63,0.43,1,"OVERLAY",1)
                tile.glints[w]=rect(tile,wx+3,34,2,8,1,0.91,0.66,0.7,"ARTWORK",2)
            end
            tile.crack=CreateFrame("Frame",nil,tile); tile.crack:SetSize(80,66); tile.crack:SetPoint("BOTTOMLEFT",tile,"BOTTOMLEFT",0,0)
            tile.crack:SetFrameLevel(tile:GetFrameLevel()+1)
            rect(tile.crack,35,33,5,30,0.09,0.08,0.12); rect(tile.crack,39,25,10,8,0.09,0.08,0.12)
            rect(tile.crack,45,0,5,28,0.09,0.08,0.12)
            UI.floors[(tower-1)*3+floor]=tile
        end
        local roof=UI.floors[(tower-1)*3+3]
        rect(roof,7,67,66,8,0.25,0.20,0.25,1,"BORDER",1); rect(roof,13,75,4,14,0.18,0.18,0.23,1,"BORDER",1)
        text(roof,9,3,-3,74,"CENTER"):SetText(({"CRUMB CO.","TOAST BANK","SNACK HOTEL"})[tower])
        local rubble=CreateFrame("Frame",nil,city); rubble:SetSize(94,25); rubble:SetPoint("BOTTOMLEFT",city,"BOTTOMLEFT",x-47,30)
        for j=1,8 do rect(rubble,(j-1)*11,(j%3)*3,15,6+(j%3)*4,0.51,0.37,0.30) end
        UI.rubble[tower]=rubble
    end
    -- Same ground footprint and scale while shielded or exposed. Foreground to
    -- buildings, behind players; the crown no longer floats above a fixed tower.
    UI.boss=creature(city,2,true); UI.boss.artScale=1.5; UI.boss:SetScale(1.5); UI.boss.badge:SetText("BOSS")
    UI.boss:SetFrameLevel(city:GetFrameLevel()+6)
    UI.boss.shield={rect(UI.boss,-5,2,2,65,0.65,0.86,1,0.85),rect(UI.boss,51,2,2,65,0.65,0.86,1,0.85),
        rect(UI.boss,-5,67,58,2,0.65,0.86,1,0.85)}
    UI.bossGround=CreateFrame("Frame",nil,city); UI.bossGround:SetSize(190,25)
    UI.bossGround:SetFrameLevel(city:GetFrameLevel()+6)
    UI.bossGround.strip=rect(UI.bossGround,0,10,190,2,1,0.84,0.4,0.7)
    UI.bossGround.left=rect(UI.bossGround,0,7,2,8,1,0.84,0.4)
    UI.bossGround.right=rect(UI.bossGround,188,7,2,8,1,0.84,0.4)
    UI.bossGround.center=rect(UI.bossGround,91,9,8,5,1,0.84,0.4)
    UI.bossGround.label=text(UI.bossGround,9,0,-18,190,"CENTER")
    UI.boss.crown=rect(UI.boss,14,59,22,5,1,0.80,0.37)
    for i=1,3 do rect(UI.boss,12+i*6,64,4,6+i%2*3,1,0.80,0.37) end
    UI.monsters={}
    for slot=1,UI.MAX do
        local monster=creature(city,slot); monster.artScale=0.73; monster:SetScale(monster.artScale)
        local n=slot
        hover(monster,function() local m=app.net.members[n]; return m and ((m.bot and "AI: " or "")..m.name) or ("Monster "..n) end,
            function() local s=app.net.state; local p=s and s.players[n]; return p and ((p.bot and "AI • " or "")..(p.hp or 100).." HP • "..(p.kos or 0).." KOs • "..p.score.." fame • lane "..p.x.." • floor "..p.y) or "Waiting for player" end)
        UI.monsters[slot]=monster
    end
    -- Fixed particle frame sits above the city; textures are recycled round-robin.
    UI.fx=CreateFrame("Frame",nil,city); UI.fx:SetSize(632,354); UI.fx:SetPoint("BOTTOMLEFT",city,"BOTTOMLEFT",0,0)
    UI.fx:SetFrameLevel(city:GetFrameLevel()+14); UI.particles={}; UI.particleCursor=0
    for i=1,72 do local t=rect(UI.fx,0,0,5,5,1,0.7,0.4); t:Hide(); UI.particles[i]={texture=t} end
    -- Four targets is the hard ceiling (at least three of seven lanes safe).
    -- Dotted beams/arcs and flat stomp rings use the same fixed texture pool.
    UI.bossCues={}
    for i=1,4 do
        local cue={parts={}}
        for j=1,12 do local t=rect(UI.fx,0,0,5,5,1,0.75,0.4); t:Hide(); cue.parts[j]=t end
        UI.bossCues[i]=cue
    end
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
        chip.tint={c[1]*0.30,c[2]*0.30,c[3]*0.30}; chip:paint()
        hover(chip,function() local m=app.net.members[n]; return m and (n..". "..(m.bot and "AI: " or "")..m.name) or ("Slot "..n.." • open") end,
            function() local s=app.net.state; local p=s and s.players[n]; return p and ((p.bot and "AI • " or "")..(p.hp or 100).." HP • "..(p.kos or 0).." KOs • "..p.score.." fame"..(n==app.net.slot and " • YOU" or "")) or "An active player may join this slot." end)
        chip.healthBack=rect(chip,2,1,30,3,0.06,0.05,0.08)
        chip.health=rect(chip,2,1,30,3,0.38,0.88,0.45)
        UI.scores[slot]=chip
    end
    UI.addAI=button(crew,"+ ADD AI",10,-247,92,function() if app.net.addAI then app.net:addAI() end; UI.render() end)
    UI.removeAI=button(crew,"- AI",110,-247,88,function() if app.net.removeAI then app.net:removeAI() end; UI.render() end)
    hover(UI.addAI,"Add one AI monster","Host / solo only, maximum 5 AI within the 25 actor slots. AI runs on the host. Pick Brawl + Solo practice for a quick fight.")
    hover(UI.removeAI,"Remove one AI monster","Host / solo only. Removes one AI per click, never a human.")
    UI.personal=text(crew,16,12,-286,184); UI.team=text(crew,11,12,-309,184); UI.best=text(crew,10,12,-331,184)
    UI.capture=button(root,"PLAY • GRAB KEYS",20,-500,188,function()
        if app.input.focused then app.input:release() else app.input:grab() end; UI.render()
    end,true)
    UI.captureStatus=text(root,12,222,-507,655)
    UI.healthBack=rect(root,370,104,188,12,0.045,0.04,0.06)
    UI.health=rect(root,370,104,188,12,0.38,0.88,0.45)
    UI.healthLabel=text(root,11,367,-561,194,"CENTER")
    UI.controls={}
    local labels,actions={"A/Left","W/Up","Space","S/Down","D/Right"},{"L","U","P","D","R"}
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
    root:SetScript("OnHide",function() app.input:release("Window hidden — keys released"); UI.baseline=nil; UI.resetBossVisuals(); UI.clearParticles(); if GameTooltip then GameTooltip:Hide() end end)
    root:SetScript("OnShow",function() UI.fit(); UI.nextDiscovery=0; UI.baseline=nil; UI.resetBossVisuals(); UI.clearParticles(); app.input:shown() end)
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
function UI.resetBossVisuals()
    UI.bossVisual=nil
    for _,cue in ipairs(UI.bossCues or {}) do
        cue.lane=nil
        for _,part in ipairs(cue.parts) do part:Hide() end
    end
end
function UI.clearParticles()
    for _,p in ipairs(UI.particles or {}) do p.start=nil; p.texture:Hide() end
end
-- Only interpolate the current, already-authorized patrol segment. Warning,
-- impact and recovery clocks are always the received sample, never local timers.
-- After two nominal snapshots without news, hold rather than invent a new route.
function UI.bossSample(s,net,now)
    local motion=s and s.bossMotion
    if not motion or s.phase~="play" then UI.resetBossVisuals(); return nil end
    local client=net.mode=="client"
    local seq=net.inSeq or 0
    local epoch=s._epoch or net.inputEpoch or 0
    local v=UI.bossVisual
    local reset=not v or v.sid~=net.sid or v.host~=net.hostName or v.mode~=net.mode or v.stage~=s.stage
        or v.epoch~=epoch or seq<(v.seq or 0) or (s.time or 0)<(v.clock or 0)
        or motion.id<(v.id or 0)
        or (client and seq>(v.seq or 0)+1)
    if reset then
        UI.resetBossVisuals()
        UI.baseline=nil; UI.clearParticles()
        v={sid=net.sid,host=net.hostName,mode=net.mode,stage=s.stage,epoch=epoch}
        UI.bossVisual=v
    end
    local fresh=reset or v.state~=s or v.seq~=seq
    local cap=2*(addon.Protocol.SNAPSHOT_INTERVAL or 1.25)
    -- Measure the PREVIOUS sample before replacing its timestamp. Rendering can
    -- stall without ever setting v.stale; delivery alone must not make that gap timely.
    local priorAge=math.max(0,now-(v.sampleAt or now))
    local wasStale=v.stale or (client and priorAge>cap)
    if fresh then
        v.sampleAt=net.lastSnapshot or now
        v.elapsed=0; v.frozen=false
    end
    local age=math.max(0,now-(v.sampleAt or now))
    local stale=client and age>cap
    if not client then v.elapsed=0
    elseif s.paused or net.combat then v.frozen=true
    elseif not v.frozen and not stale then v.elapsed=math.min(age,cap,math.max(0,motion.remaining or 0))
    elseif stale then v.frozen=true end
    local elapsed=client and motion.phase=="patrol" and (v.elapsed or 0) or 0
    -- If pause/staleness arrives without a new sample, freeze the already drawn
    -- point; the model correctly refuses elapsed while paused, so do not rewind.
    if not (client and v.frozen and not fresh and v.position) then
        v.position=addon.Model.bossPosition(s,elapsed)
    end
    v.state,v.seq,v.clock,v.stale=s,seq,s.time or 0,stale
    -- A 0.5s attack can fall between 1.25s worlds. A consecutive, timely
    -- windup->recover sample CONFIRMS impact; show a short static aftermath at
    -- the already locked targets, never predict/replay a launch or apply damage.
    local confirmed=client and fresh and not reset and not wasStale and not stale
        and not s.paused and not net.combat and v.id==motion.id and v.phase=="windup"
        and motion.phase=="recover" and (motion.remaining or 0)>=3
    if confirmed then
        v.confirmedUntil=now+0.65; v.confirmedLanes={}
        for i,cue in ipairs(UI.bossCues) do v.confirmedLanes[i]=cue.lane end
    elseif v.id~=motion.id or motion.phase~="recover" or s.paused or stale then
        v.confirmedUntil,v.confirmedLanes=nil,nil
    end
    -- Lock cue targets once per authoritative id/phase. No late-join, stale or
    -- skipped-world catch-up: those reset the baseline instead.
    local cueChanged=reset or (fresh and wasStale) or v.id~=motion.id or v.phase~=motion.phase
    if fresh and wasStale then UI.baseline=nil; UI.clearParticles() end
    if cueChanged then
        v.id,v.phase=motion.id,motion.phase
        v.origin=motion.phase=="patrol" and v.position or addon.Model.bossPosition(s)
        v.cueChanges=(v.cueChanges or 0)+1
        for i,cue in ipairs(UI.bossCues) do cue.lane=motion.lanes and motion.lanes[i] or nil end
    end
    v.confirmed=v.confirmedUntil and now<v.confirmedUntil and motion.phase=="recover" or false
    return v
end
local function bossPose(boss,motion,position,stage)
    local phase=motion and motion.phase or "recover"
    local direction=motion and motion.toLane< motion.fromLane and -1 or 1
    if motion and phase~="patrol" and motion.lanes and motion.lanes[1] then
        direction=motion.lanes[1]<position and -1 or 1
    end
    local stride=phase=="patrol" and math.sin(position*math.pi*4)*4 or 0
    local leftY,rightY=20,20
    if phase=="windup" then leftY,rightY=36,46
    elseif phase=="attack" then leftY,rightY=24,30
    elseif phase=="recover" then leftY,rightY=13,13 end
    if direction<0 then leftY,rightY=rightY,leftY end
    place(boss.legL,boss,7,1+math.max(0,stride)); place(boss.legR,boss,29,1+math.max(0,-stride))
    place(boss.armL,boss,phase=="attack" and direction<0 and -10 or 0,leftY)
    place(boss.armR,boss,phase=="attack" and direction>0 and 47 or 37,rightY)
    place(boss.pupilL,boss,direction>0 and 17 or 13,45); place(boss.pupilR,boss,direction>0 and 33 or 29,45)
    place(boss.fist,boss,direction>0 and 49 or -16,phase=="windup" and 50 or 28)
    show(boss.fist,phase=="windup" or phase=="attack")
    if stage==3 then
        -- Stomp is leg-driven, unlike the ranged raised-arm release.
        place(boss.legR,boss,phase=="attack" and 35 or 29,phase=="windup" and 16 or 1)
        show(boss.fist,false)
    end
    boss.pose,boss.facing=phase,direction
end
local function bossCues(s,v)
    local motion=s and s.bossMotion
    local phase=motion and motion.phase
    local aftermath=v and v.confirmed
    local live=v and (phase=="windup" or phase=="attack" or aftermath)
    local stage=s and s.stage or 1
    local progress=phase=="attack" and math.max(0,math.min(1,1-(motion.remaining or 0)/0.5)) or 0
    for cueIndex,cue in ipairs(UI.bossCues) do
        local lane=aftermath and v.confirmedLanes[cueIndex] or cue.lane
        local on=live and lane~=nil
        local origin=on and laneX(v.origin) or 0
        local target=on and laneX(lane) or 0
        cue.originX,cue.targetX=origin,target
        for j,part in ipairs(cue.parts) do
            show(part,on and (phase=="attack" or aftermath or j<=3))
            if on then
                local x,y,w,h,alpha
                if aftermath then
                    -- Static impact residue, not an attack launched after the fact.
                    local angle=j*math.pi/6
                    x,y=target+math.cos(angle)*20,36+math.sin(angle)*6
                    w,h,alpha=6,3,0.55
                elseif phase=="windup" then
                    -- Charge gathers at the locked boss hand / raised stomp foot.
                    local facing=UI.boss.facing or 1
                    x,y=origin+facing*43+(j-2)*8,stage==3 and 46+j*4 or 111+j*6
                    w,h,alpha=5+j,5+j,0.65
                elseif stage==3 then
                    if j<=4 then
                        local t=j/4
                        x,y=origin+(target-origin)*t,36
                        w,h,alpha=8,3,0.65
                    else
                        local angle=(j-4)*math.pi/4
                        x,y=target+math.cos(angle)*(16+progress*24),35+math.sin(angle)*(4+progress*6)
                        w,h,alpha=8,3,0.9
                    end
                elseif stage==2 then
                    local t=j/12
                    x,y=origin+(target-origin)*t,100+(42-100)*t
                    w,h,alpha=math.max(5,math.abs(target-origin)/16),5,0.9
                else
                    -- Frozen sample progress still has a visible dotted trajectory;
                    -- no delayed local impact is scheduled after a snapshot arrives.
                    local t=j==1 and 0 or j==12 and 1 or math.max(0,math.min(1,(j-1)/11*0.85+progress*0.15))
                    x,y=origin+(target-origin)*t,100*(1-t)+38*t+math.sin(t*math.pi)*(stage==4 and 80 or 55)
                    w,h,alpha=j==12 and 12 or 5,j==12 and 12 or 5,j==12 and 1 or 0.6
                end
                part:SetSize(w,h); place(part,UI.fx,x-w/2,y-h/2)
                part:SetColorTexture(1,stage==3 and 0.48 or 0.78,stage==2 and 0.88 or 0.34,alpha)
            end
        end
    end
end
function UI.render()
    if not UI.root or not UI.root:IsShown() then return end
    local app,now=UI.app,UI.app.now(); local net,s=app.net,app.net.state
    local idle=net.mode=="idle"; local spectator=net.role=="spectate"; local count=net:count()
    local bossVisual=UI.bossSample(s,net,now)
    local watch=net.spectatorCount and net:spectatorCount() or 0
    local lobby=UI.selectedLobby(); UI.displayedLobby=lobby
    local lobbyFull=lobby and lobby.count-(lobby.bots or 0)+(lobby.spectators or 0)>=40
    local activeFull=lobby and lobby.count>=25 and (lobby.bots or 0)==0
    local canPlay=app.input:canPlay()
    local gameMode=s and s.mode or UI.selectedMode
    local bots=net.botCount and net:botCount() or 0
    if idle then label(UI.primary,lobby and (lobbyFull and "GAME FULL" or (activeFull and "PLAYERS FULL" or (lobby.mode=="brawl" and "JOIN BRAWL" or "JOIN CO-OP"))) or (net.grouped and "HOST LOBBY" or "PLAY SOLO"))
    elseif spectator then label(UI.primary,s and s.mode=="brawl" and "JOIN BRAWL" or "SWITCH TO PLAY")
    elseif s and s.phase=="victory" then label(UI.primary,"PLAY AGAIN")
    elseif s and s.phase=="lobby" then label(UI.primary,"START GAME")
    else label(UI.primary,app.input.focused and "PLAYING • KEYS LIVE" or "PLAY • GRAB KEYS") end
    local owner=net.mode=="host" or net.mode=="solo"
    local hasGuests=false
    if net.mode=="host" then
        for id,member in pairs(net.participants or {}) do if id~=1 and member then hasGuests=true; break end end
    end
    local canSetMode=not net.combat and (idle or owner and not hasGuests and s and (s.phase=="lobby" or s.phase=="victory"))
    enabled(UI.coop,canSetMode); enabled(UI.brawl,canSetMode)
    selected(UI.coop,gameMode~="brawl"); selected(UI.brawl,gameMode=="brawl")
    enabled(UI.addAI,owner and not spectator and not net.combat and bots<5 and count<25)
    enabled(UI.removeAI,owner and not spectator and not net.combat and bots>0)
    enabled(UI.primary,not net.combat and (idle and (not lobby or not lobbyFull and not activeFull) or spectator and (count<25 or bots>0) and net.mode~="joining"
        or not spectator and (canPlay or owner and s and (s.phase=="lobby" or s.phase=="victory"))))
    label(UI.spectate,idle and lobbyFull and "GAME FULL" or "SPECTATE")
    enabled(UI.spectate,not net.combat and (idle and lobby~=nil and not lobbyFull or net.mode=="client" and not spectator))
    enabled(UI.solo,idle and not net.combat); enabled(UI.next,idle and lobby~=nil); enabled(UI.leave,not idle)
    local lobbyLine=lobby and ("FOUND  "..modeName(lobby.mode).."  •  "..short(lobby.name).."  •  "..lobby.count.."/25 actors ("..(lobby.bots or 0).." AI)  •  "..(lobby.spectators or 0).." watching  •  "..lobby.phase)
        or (modeName(UI.selectedMode)..(net.grouped and " ready. Find a lobby or host your own. Joining is always opt-in." or " ready. Solo practice, then + ADD AI. Brawl enables PvP; Co-op never does."))
    if lobbyFull then lobbyLine=lobbyLine.."  •  FULL (40/40)"
    elseif activeFull then lobbyLine=lobbyLine.."  •  Players full — SPECTATE to watch" end
    UI.lobby:SetText(idle and lobbyLine or (modeName(gameMode).."  •  "..(spectator and "WATCHING" or string.upper(net.mode)).."  •  "..(net.hostName and short(net.hostName) or "Your pocket city").."  •  "..count.."/25 actors ("..bots.." AI)  •  "..watch.." spectators"))
    UI.crewTitle:SetText("THE CREW  "..count.." / 25"); UI.crewSub:SetText(bots.." / 5 AI • "..watch.." watching")
    for slot=1,25 do
        local member=net.members[slot]; local p=s and s.players[slot]; local chip=UI.scores[slot]
        local isBot=(p and p.bot) or (member and member.bot)
        label(chip,member and ((isBot and "AI" or (slot==net.slot and ">" or ""))..tostring(slot)) or "-")
        chip.displayAlpha=member and 1 or 0.25; chip:paint()
        show(chip.healthBack,p~=nil); show(chip.health,p~=nil); health(chip.health,p,30)
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
            if not first and m.hp and (p.hp or 100)<m.hp then m.hurtUntil=now+0.35 end
            m.hit,m.x,m.y,m.hp=p.hit,p.x,p.y,p.hp or 100
            local walking=now<(m.moveUntil or 0); local bob=walking and math.sin(now*30+slot)*2 or math.sin(now*3+slot)*0.7
            local ko,invuln=(p.ko or 0)>0,(p.invuln or 0)>0
            place(m,UI.city,m.drawX,m.drawY+bob); m:Show()
            m:SetAlpha(ko and 0.3 or (invuln and (0.65+0.25*math.sin(now*12)) or (slot==net.slot and 1 or (siblings>8 and 0.85 or 1))))
            m:SetFrameLevel(UI.city:GetFrameLevel()+(slot==net.slot and 12 or 8+row%3))
            show(m.halo,slot==net.slot and not spectator)
            m.badge:SetText(ko and ("KO "..math.ceil(p.ko).."s") or ((isBot and "AI " or "")..(slot==net.slot and "YOU" or tostring(slot))))
            health(m.health,p,42); show(m.hurt,not ko and now<(m.hurtUntil or 0))
            m.badge:SetTextColor(slot==net.slot and 1 or 0.9,slot==net.slot and 0.88 or 0.83,slot==net.slot and 0.40 or 0.74)
            place(m.legL,m,7,walking and 1+math.sin(now*30)*3 or 1)
            place(m.legR,m,29,walking and 1-math.sin(now*30)*3 or 1)
            place(m.armL,m,0,p.y>0 and 36+math.sin(now*10)*3 or 20)
            place(m.armR,m,37,p.y>0 and 30-math.sin(now*10)*3 or 20)
            show(m.fist,not ko and now<(m.punchUntil or 0))
        else m:Hide(); m.hit=nil; m.x=nil; m.y=nil; m.hp=nil; m.hurtUntil=nil end
    end
    local localP=s and net.slot and s.players[net.slot]
    UI.personal:SetText(spectator and "SPECTATOR" or (localP and (localP.score.."  YOUR FAME") or "READY TO SMASH?"))
    UI.team:SetText(localP and not spectator and ((localP.kos or 0).." KOs • "..(s and addon.Model.total(s) or 0).." team fame") or ((s and addon.Model.total(s) or 0).." team fame"))
    UI.best:SetText("Personal best  "..(app.db.best or 0))
    local showHealth=localP~=nil and not spectator
    show(UI.healthBack,showHealth); show(UI.health,showHealth); show(UI.healthLabel,showHealth)
    health(UI.health,localP,188)
    if showHealth then
        UI.healthLabel:SetText((localP.ko or 0)>0 and ("KO - respawn in "..math.ceil(localP.ko).."s")
            or ((localP.hp or 100).." / "..(localP.maxHP or 100).." HP"..((localP.invuln or 0)>0 and (" • SHIELD "..math.ceil(localP.invuln).."s") or "")))
    end
    local alive=s and addon.Model.cityAlive(s)
    local previous=UI.baseline
    local same=previous and s and previous.stage==s.stage and previous.sid==net.sid
        and previous.epoch==(s._epoch or net.inputEpoch or 0) and (net.inSeq or 0)>=(previous.seq or 0)
        and (net.mode~="client" or (net.inSeq or 0)<=(previous.seq or 0)+1)
    for i=1,9 do
        local hp=s and s.phase~="lobby" and (s.hp[i] or 0) or 2; local tile=UI.floors[i]
        show(tile,hp>0); show(tile.crack,hp==1)
        tile.body:SetColorTexture(hp==2 and 0.40 or 0.27,hp==2 and 0.34 or 0.23,hp==2 and 0.37 or 0.26,1)
        -- Damage cracks/darkens the facade without erasing its window detail.
        for _,w in ipairs(tile.windows) do w:SetAlpha(hp==2 and 0.9+math.sin(now*1.3+i)*0.08 or 0.65) end
        for _,glint in ipairs(tile.glints) do glint:SetAlpha(hp==2 and 1 or 0.6) end
        if same and previous.hp[i] and hp<previous.hp[i] then
            local tower=math.floor((i-1)/3)+1; local floor=(i-1)%3+1
            UI.burst(126+(tower-1)*190,48+(floor-1)*68,hp==0 and 14 or 7,hp==0 and "dust" or "hit")
        end
    end
    for i=1,3 do show(UI.rubble[i],s and s.phase~="lobby" and not addon.Model.towerAlive(s,i)) end
    local boss=UI.boss; local stage=s and s.stage or 1; local bc=bossPalette[stage]
    for _,part in ipairs(boss.tint) do part[1]:SetColorTexture(bc[1]*part[2],bc[2]*part[2],bc[3]*part[2],1) end
    local bossShown=s and s.phase=="play"
    local position=bossVisual and bossVisual.position or 4
    local center=laneX(position)
    show(boss,bossShown); boss:SetAlpha(alive and 0.92 or 1)
    boss.artScale=1.5; boss:SetScale(boss.artScale); show(boss.halo,not alive)
    boss.drawLane,boss.drawCenterX,boss.drawX,boss.drawY=position,center,center-24*boss.artScale,32
    place(boss,UI.city,boss.drawX,boss.drawY)
    bossPose(boss,s and s.bossMotion,position,stage)
    for _,part in ipairs(boss.shield) do show(part,alive) end
    show(UI.bossGround,bossShown); place(UI.bossGround,UI.city,center-95,0)
    UI.bossGround.label:SetText(alive and "SHIELDED / MOVING" or "GROUND PUNCH REACH")
    local inReach=not alive and localP and localP.y==0 and math.abs(localP.x-position)<=1
    UI.bossGround.strip:SetColorTexture(inReach and 0.45 or 1,inReach and 1 or 0.84,0.4,0.8)
    boss.badge:SetText(alive and "SHIELDED" or "BOSS")
    local bossHP=s and (s.bossHP or s.boss) or 10
    UI.bossBar:SetWidth(math.max(1,364*bossHP/(8+stage*2)))
    UI.bossBar:SetColorTexture(alive and 0.64 or 0.98,alive and 0.61 or 0.40,alive and 0.65 or 0.26,1)
    UI.bossLabel:SetText(bossShown and (alive and "SHIELD UP • flatten every floor; boss still moves and attacks"
        or (bossHP.." HP • EXPOSED! Hit near boss on ground (gold bracket), SPACE")) or "25 MONSTERS • 4 CITIES • ONE VERY TOASTY TEAM")
    local hazard=s and s.phase=="play" and s.hazard
    local warning=hazard and hazard.phase=="warning"
    local impact=hazard and hazard.phase=="impact"
    local ground=s and (addon.Model.bossAttackKind and addon.Model.bossAttackKind(s)=="ground" or stage==3)
    local dangerous={}
    if warning or impact then for _,lane in ipairs(hazard.lanes or {}) do dangerous[lane]=true end end
    for lane,mark in ipairs(UI.hazardLanes) do
        show(mark,dangerous[lane]==true)
        if dangerous[lane] then
            local red,green,blue=impact and 1 or bc[1],impact and 0.2 or math.max(0.55,bc[2]),impact and 0.12 or bc[3]
            mark.left:SetColorTexture(red,green,blue,0.65); mark.right:SetColorTexture(red,green,blue,0.65)
            mark.left:SetHeight(ground and 35 or 205); mark.right:SetHeight(ground and 35 or 205)
            mark.label:ClearAllPoints(); mark.label:SetPoint("TOPLEFT",mark,"TOPLEFT",0,ground and -172 or -214)
            mark.strip:SetColorTexture(red,green,blue,0.95)
            mark:SetAlpha(impact and 1 or 0.9)
            mark.label:SetText(impact and "HIT!" or ("! "..math.ceil(hazard.remaining or 0).."s"))
        end
    end
    local sample=net.mode=="client" and " • last sample" or ""
    if s and s.paused then sample=" • PAUSED"
    elseif bossVisual and bossVisual.stale then sample=" • STALE: pose held" end
    local height=ground and "GROUND ONLY" or "ALL HEIGHTS"
    if warning then UI.hazardText:SetText(hazardFlavor[stage].." IN "..math.ceil(hazard.remaining or 0).."s • "..height..sample)
    elseif impact then UI.hazardText:SetText(hazardFlavor[stage].." • IMPACT! "..height..sample)
    elseif s and s.bossMotion then
        UI.hazardText:SetText((s.bossMotion.phase=="patrol" and "BOSS PATROLLING • watch its next windup"
            or bossVisual and bossVisual.confirmed and "IMPACT CONFIRMED • boss recovering" or "BOSS RECOVERING • catch it on the ground")..sample)
    elseif hazard then UI.hazardText:SetText("BOSS RECOVERING • next warning in "..math.ceil(hazard.remaining or 0).."s"..sample)
    else UI.hazardText:SetText(s and s.phase=="lobby" and "Choose Co-op / Brawl, add AI, then START GAME" or "") end
    bossCues(s,bossVisual)
    UI.hazardText:SetTextColor(impact and 1 or 0.98,impact and 0.4 or 0.78,impact and 0.3 or 0.45)
    show(UI.banner,s and (s.phase=="victory" or s.phase=="clear" or s.paused))
    if s and s.paused then UI.banner.title:SetText("RAID FIRST. SMASH LATER."); UI.banner.sub:SetText("Host in combat — everyone is paused")
    elseif s and s.phase=="victory" then UI.banner.title:SetText("TOAST WINS!"); UI.banner.sub:SetText("ZERO MORE BOSSES • "..addon.Model.total(s).." TEAM FAME")
    elseif s and s.phase=="clear" then UI.banner.title:SetText("BOSS FLATTENED!"); UI.banner.sub:SetText((4-s.stage).." more bosses • next city incoming") end
    if previous and s and previous.phase~=s.phase and (s.phase=="clear" or s.phase=="victory") then
        UI.burst(316,185,s.phase=="victory" and 50 or 25,s.phase=="victory" and "victory" or "dust")
    elseif previous and s and previous.stage~=s.stage then UI.burst(316,260,24,"victory") end
    UI.stageText:SetText(s and (modeName(gameMode).." • CITY "..s.stage.." / 4   •   "..string.upper(addon.Model.BOSSES[stage])) or "SMASH THE CITY. MAKE TOAST PROUD.")
    enabled(UI.capture,canPlay or app.input.focused); selected(UI.capture,app.input.focused)
    label(UI.capture,app.input.focused and "RELEASE KEYS • ESC" or "PLAY • GRAB KEYS")
    UI.captureStatus:SetText(spectator and "WATCH ONLY • no avatar, no captured keys" or (localP and (localP.ko or 0)>0 and ("KO • respawn in "..math.ceil(localP.ko).."s • click PLAY when ready") or app.input.reason))
    UI.captureStatus:SetTextColor(app.input.focused and 0.50 or 0.83,app.input.focused and 0.96 or 0.79,app.input.focused and 0.65 or 0.70)
    for _,b in ipairs(UI.controls) do enabled(b,canPlay) end
    label(UI.audio,app.db.useBlasterMaster and "Local BM: ON" or "Local BM: OFF")
    selected(UI.audio,app.db.useBlasterMaster); selected(UI.mute,app.db.muted)
    label(UI.mute,app.db.muted and "UNMUTE RAMPAGE" or "Mute Rampage")
    UI.hint:SetText(spectator and "Enjoy the chaos. Switch to Play above when there is space; this never happens automatically."
        or ("WASD / arrows: walk & climb • Space: punch • Esc: release • dodge marked lanes!\n"..(gameMode=="brawl" and "BRAWL: hit rivals; KOs are not fame. Fast respawn + shield. " or "CO-OP: crew punches are safe. ").."Climb 2, 4, 6; flatten towers, then boss."))
    UI.status:SetText((net.status or "").."  •  Drag title to move • Close hides; Leave exits")
    UI.baseline=s and {stage=s.stage,phase=s.phase,sid=net.sid,epoch=s._epoch or net.inputEpoch or 0,seq=net.inSeq or 0,hp={}} or nil
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
