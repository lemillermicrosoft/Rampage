-- API mocks are deliberately small: unknown methods fail instead of silently passing.
-- Also exports actual UI frame geometry for ui-preview.cjs, not a separate concept.
-- This is NOT a native renderer, taint/protected-action simulator or TBC client.
Addon = {}
local frames, textures, fonts, sent, messages = {}, {}, {}, {}, {}
local now, grouped, raided, combat, loggedIn = 100, false, false, false, false
local editFocus, windowFocus, altDown, ctrlDown = nil, true, false, false
local methods = {}
local function newObject(kind, name, parent)
    local object = setmetatable({ kind = kind, name = name, parent = parent, shown = true, enabled = true,
        scripts = {}, events = {}, width = 0, height = 0, scale = 1, level = parent and (parent.level+1) or 1 }, { __index = methods })
    return object
end
function methods:SetPoint(...) self.point = {...} end
function methods:GetPoint()
    local p = self.point or {"CENTER"}
    return p[1], p[2] or UIParent, p[3] or p[1], p[4] or 0, p[5] or 0
end
function methods:ClearAllPoints() self.point = nil end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetFrameLevel(level) self.level = level end
function methods:GetFrameLevel() return self.level end
function methods:Show() local changed = not self.shown; self.shown = true; if changed and self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() local changed = self.shown; self.shown = false; if changed and self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsShown() return self.shown and (not self.parent or self.parent:IsShown()) end
function methods:Enable() self.enabled = true end
function methods:Disable() self.enabled = false end
function methods:IsEnabled() return self.enabled end
function methods:SetText(value) self.text = value end
function methods:GetText() return self.text end
function methods:SetColorTexture(r, g, b, a)
    assert(type(r) == "number" and type(g) == "number" and type(b) == "number")
    self.color = {r, g, b, a or 1}
end
function methods:SetAlpha(alpha) self.alpha = alpha end
function methods:SetScale(scale) self.scale = scale end
function methods:GetScale() return self.scale end
function methods:EnableKeyboard(active) self.keyboard = active end
function methods:SetPropagateKeyboardInput(active)
    assert(not combat,"Do not mutate restricted keyboard propagation in combat")
    self.propagate = active
end
function methods:SetFont(path, size, flags) self.fontSize = size end
function methods:SetJustifyH(align) self.align = align end
function methods:SetTextColor(r,g,b,a) self.color = {r,g,b,a or 1} end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:UnregisterEvent(event) self.events[event] = nil end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:GetScript(event) return self.scripts[event] end
function methods:CreateTexture(name, layer)
    local t = newObject("Texture", name, self); t.layer = layer; textures[#textures + 1] = t; return t
end
function methods:CreateFontString(name, layer, template)
    local f = newObject("FontString", name, self); fonts[#fonts + 1] = f; return f
end
for _, method in ipairs({"SetClampedToScreen", "SetFrameStrata",
    "EnableMouse", "SetMovable", "RegisterForDrag", "StartMoving", "StopMovingOrSizing"}) do methods[method] = function() end end
UIParent = newObject("Frame", "UIParent"); UIParent:SetSize(1600,1000)
GameTooltip = { SetOwner=function() end, SetText=function() end, AddLine=function() end, Show=function() end, Hide=function() end }
STANDARD_TEXT_FONT = "MockFont"
SlashCmdList = {}
RampageDB = { best = -42, customKept = "yes", position = {point = "INVALID", x = 1, y = 2} }
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) messages[#messages + 1] = message end }
function CreateFrame(kind, name, parent, template)
    assert(kind == "Frame" or kind == "Button")
    assert(not template or template == "UIPanelButtonTemplate", "unexpected secure or other template")
    local f = newObject(kind, name, parent); frames[#frames + 1] = f; if name then _G[name] = f end; return f
end
function GetTime() return now end
function GetServerTime() return 1800000000 + math.floor(now) end
function GetRealmName() return "Test Realm" end
function GetNormalizedRealmName() return "TestRealm" end
function UnitFullName(unit)
    if unit == "player" or unit == "raid1" then return "Tester", "TestRealm" end
    if unit == "party1" or unit == "raid2" then return "Friend", "OtherRealm" end
    if unit == "party2" or unit == "raid3" then return "Friend", "TestRealm" end
end
function UnitName(unit) return UnitFullName(unit) end
function IsInRaid() return raided end
function IsInGroup() return grouped end
function GetNumGroupMembers() return grouped and 3 or 0 end
function InCombatLockdown() return combat end
function IsLoggedIn() return loggedIn end
function GetCurrentKeyBoardFocus() return editFocus end
function ChatEdit_GetActiveWindow() return nil end
function IsWindowFocused() return windowFocus end
function IsAltKeyDown() return altDown end
function IsControlKeyDown() return ctrlDown end
C_ChatInfo = {
    RegisterAddonMessagePrefix = function(prefix) assert(#prefix <= 16); return true end,
    SendAddonMessage = function(prefix, payload, distribution)
        assert(prefix == "ToastRampage1" and #payload <= 255)
        assert(distribution == "RAID" or distribution == "PARTY")
        sent[#sent + 1] = {payload = payload, distribution = distribution}
    end
}
function SendChatMessage() error("Public chat is forbidden") end
function SetBinding() error("Global keybinds are forbidden") end
function SetOverrideBinding() error("Binding changes are forbidden; use local frame input") end
function PlaySound() error("Unexpected sound") end
local function event(eventName, ...)
    for _, f in ipairs(frames) do
        if f.events[eventName] and f.scripts.OnEvent then f.scripts.OnEvent(f, eventName, ...) end
    end
end
local function step(seconds)
    for _ = 1, math.ceil(seconds / 0.05) do
        now = now + 0.05
        for _, f in ipairs(frames) do if f:IsShown() and f.scripts.OnUpdate then f.scripts.OnUpdate(f, 0.05) end end
    end
end
local function click(b)
    if b:IsShown() and b:IsEnabled() then b.scripts.OnClick(b) end
end

function runWoWSmoke()
    local app, ui = Addon.App, Addon.UI
    check("TOC/WoW mock: load-order, saved-variable sanitation and no forced window", function()
        assert(not app.net and not ui.root)
        event("ADDON_LOADED", "AnotherAddon"); assert(not app.net)
        event("ADDON_LOADED", "Rampage"); assert(SlashCmdList.RAMPAGE); eq(SLASH_RAMPAGE1, "/rampage")
        loggedIn = true; event("PLAYER_LOGIN")
        assert(app.net); eq(app.net.name, "Tester-TestRealm"); eq(RampageDB.best, 0); eq(RampageDB.customKept, "yes")
        eq(app.VERSION, "0.1.0"); assert(not ui.root); eq(#sent, 0)
    end)
    check("WoW mock: solo window, original geometry, buttons, damage and personal best", function()
        SlashCmdList.RAMPAGE("solo"); assert(ui.root:IsShown()); eq(app.net.mode, "solo")
        eq(ui.root:GetWidth(), 900); eq(#ui.monsters, 25); eq(#ui.scores, 25); eq(#ui.floors, 9)
        assert(not app.input.focused); assert(not app.input.frame:IsShown()); eq(RampageDB.useBlasterMaster,false)
        eq(ui.root:GetPoint(), "CENTER") -- invalid persisted anchor ignored
        click(ui.controls[5]); eq(app.net.state.players[1].x, 2)
        step(0.25); click(ui.controls[3]); eq(app.net.state.hp[1], 1); eq(RampageDB.best, 10)
        assert(ui.floors[1].crack:IsShown()); step(0.25); click(ui.controls[3]); eq(app.net.state.hp[1], 0)
        assert(not ui.floors[1]:IsShown()); eq(RampageDB.best, 20); eq(#sent, 0)
    end)
    check("WoW mock: keyboard opt-in, bounded hold repeat, unknown/chat keys propagate", function()
        local input, calls, action = app.input, {}, app.net.action
        app.net.action = function(_, key) calls[#calls+1] = key; return true end
        click(ui.capture); assert(input.focused and input.frame.keyboard)
        local f = input.frame
        f.scripts.OnKeyDown(f,"D"); eq(f.propagate,false); eq(#calls,1)
        for _=1,12 do f.scripts.OnKeyDown(f,"D") end
        eq(#calls,1) -- OS repeat cannot bypass the bounded timer.
        step(1); assert(#calls>=4 and #calls<=5,"repeat must stay about 5 Hz globally")
        f.scripts.OnKeyDown(f,"SPACE"); step(0.3); eq(calls[#calls],"P")
        f.scripts.OnKeyUp(f,"SPACE"); eq(f.propagate,false)
        f.scripts.OnKeyUp(f,"D"); local n=#calls; step(0.5); eq(#calls,n)
        f.scripts.OnKeyDown(f,"I"); eq(f.propagate,true); assert(not input.focused)
        click(ui.capture); f.scripts.OnKeyDown(f,"ENTER"); eq(f.propagate,true); assert(not input.focused)
        click(ui.capture); f.scripts.OnKeyDown(f,"W"); editFocus={}; step(0.05)
        assert(not input.focused); eq(f.propagate,true); assert(next(input.held)==nil)
        assert(not input:grab()); editFocus=nil
        click(ui.capture); f.scripts.OnKeyDown(f,"ESCAPE"); assert(not input.focused); eq(f.propagate,true)
        app.net.action=action
    end)
    check("WoW mock: keyboard alt-tab, long stall, hidden, leaving-world and spectator release", function()
        local input=app.input; local f=input.frame
        assert(input:grab()); f.scripts.OnKeyDown(f,"SPACE"); windowFocus=false; step(0.05)
        assert(not input.focused); assert(next(input.held)==nil); eq(f.propagate,true); windowFocus=true
        assert(input:grab()); altDown=true; f.scripts.OnKeyDown(f,"TAB"); assert(not input.focused); altDown=false
        -- Focus helper is not guaranteed in Classic: physical-key reconciliation
        -- must stop a missed key-up without relying on that mocked helper.
        local focusAPI=IsWindowFocused; IsWindowFocused=nil
        local held=true; IsKeyDown=function(key) eq(key,"SPACE"); return held end
        assert(input:grab()); f.scripts.OnKeyDown(f,"SPACE"); held=false; step(0.05)
        assert(not input.focused); assert(next(input.held)==nil); assert(not f:IsShown())
        IsKeyDown=nil; IsWindowFocused=focusAPI
        assert(input:grab()); IsMetaKeyDown=function() return true end; input:update(0.01)
        assert(not input.focused); IsMetaKeyDown=nil
        assert(input:grab()); input:update(1); assert(not input.focused)
        assert(input:grab()); ui.root:Hide(); assert(not input.focused); eq(f.propagate,true); ui.root:Show()
        assert(input:grab()); event("PLAYER_LEAVING_WORLD"); assert(not input.focused)
        local role,slot=app.net.role,app.net.slot
        assert(input:grab()); app.net.role,app.net.slot="spectate",nil; step(0.05)
        assert(not input.focused); assert(not input:grab()); assert(not input:action("P")); ui.render()
        assert(not ui.controls[3]:IsEnabled()); assert(not ui.capture:IsEnabled())
        app.net.role,app.net.slot=role,slot
        assert(input:grab()) -- leave focused for the combat test
    end)
    check("WoW mock: combat hides/blocks controls, restores only previously open window", function()
        local x = app.net.state.players[1].x
        combat = true; event("PLAYER_REGEN_DISABLED"); assert(not ui.root:IsShown()); assert(app.net.state.paused)
        assert(not app.input.focused); assert(next(app.input.held)==nil); assert(not app.input.frame:IsShown())
        app.net:action("R"); eq(app.net.state.players[1].x, x)
        SlashCmdList.RAMPAGE(""); assert(not ui.root:IsShown())
        step(0.3); combat = false; event("PLAYER_REGEN_ENABLED"); assert(ui.root:IsShown()); assert(not app.net.state.paused)
        SlashCmdList.RAMPAGE(""); assert(not ui.root:IsShown())
        combat = true; event("PLAYER_REGEN_DISABLED"); combat = false; event("PLAYER_REGEN_ENABLED")
        assert(not ui.root:IsShown()); SlashCmdList.RAMPAGE(""); assert(ui.root:IsShown())
    end)
    check("WoW mock: 25-player fixed geometry pools after 500 animated renders", function()
        local frameCount, textureCount, fontCount = #frames, #textures, #fonts
        for slot=2,25 do Addon.Model.addPlayer(app.net.state,slot); app.net.members[slot]={name="Crew"..slot.."-Realm"} end
        for i=1,500 do
            for slot=1,25 do local p=app.net.state.players[slot]; p.hit=i%1000; p.x=1+(slot+i)%7 end
            ui.burst(316,180,12,"hit"); step(0.05); ui.render()
        end
        for slot=2,25 do Addon.Model.removePlayer(app.net.state,slot); app.net.members[slot]=nil end
        eq(#frames, frameCount); eq(#textures, textureCount); eq(#fonts, fontCount)
        print("  Fixed UI allocation fixture: " .. frameCount .. " frames, " .. textureCount .. " textures, " .. fontCount .. " font strings")
    end)
    check("WoW mock: optional audio off/missing/None/failed SFX and no provider fallback", function()
        local t,calls=0,0
        local a={db={},now=function() return t end}; local sound=Addon.Sound.create(a)
        PlaySoundFile=function(_,channel) eq(channel,"SFX"); calls=calls+1; return true,123 end
        assert(not sound:cue("punch")); eq(calls,0)
        a.db.useBlasterMaster=true; assert(not sound:cue("punch")); eq(calls,0)
        BlasterMaster_GetSfxPath=function(role) eq(role,"crit"); return "None" end
        t=3; assert(not sound:cue("punch")); eq(calls,0)
        BlasterMaster_GetSfxPath=function() return nil end; t=6; assert(not sound:cue("punch"))
        BlasterMaster_GetSfxPath=function() return "Interface\\AddOns\\BlasterMaster\\local.ogg" end
        PlaySoundFile=function() calls=calls+1; return false end
        t=9; assert(not sound:cue("punch")); eq(calls,1)
        PlaySoundFile=function() error("provider/client sound failure") end
        t=12; assert(not sound:cue("punch"))
        PlaySoundFile=function(_,channel) eq(channel,"SFX"); calls=calls+1; return true,123 end
        t=15; assert(sound:cue("punch")); assert(not sound:cue("punch")); eq(calls,2)
        a.db.muted=true; t=18; assert(not sound:cue("punch")); eq(calls,2)
        BlasterMaster_GetSfxPath,PlaySoundFile=nil,nil
    end)
    check("WoW mock: sound authoritative transition dedupe, no late/hidden catch-up and spectator quiet", function()
        local t,calls=0,{}
        local state=Addon.Model.new(); Addon.Model.addPlayer(state,1); Addon.Model.start(state)
        local a={db={useBlasterMaster=true},now=function() return t end,
            net={state=state,slot=1,role="play",mode="client",sid="sfx",hostName="Host",inSeq=1}}
        local sound=Addon.Sound.create(a)
        BlasterMaster_GetSfxPath=function(role) return role end
        PlaySoundFile=function(path,channel) calls[#calls+1]=path; eq(channel,"SFX"); return true,1 end
        sound:observe(true); eq(#calls,0) -- late join baseline
        t=0.1; state.players[1].hit=1; sound:observe(true); eq(#calls,1); eq(calls[1],"crit")
        for _=1,25 do sound:observe(true) end; eq(#calls,1)
        t=0.3; state.players[1].hit=2; sound:observe(true); eq(#calls,1)
        t=2; sound:observe(false); state.players[1].hit=30; t=3; sound:observe(true); eq(#calls,1)
        a.net.role,a.net.slot="spectate",nil; t=4; state.players[1].hit=31; state.hp[1],state.hp[2],state.hp[3]=0,0,0
        sound:observe(true); eq(#calls,1)
        t=4.2; state.phase="clear"; sound:observe(true); eq(#calls,2); eq(calls[2],"levelUp")
        t=4.3; sound:observe(true); eq(#calls,2)
        -- A replayed transition cannot fire twice even after a new snapshot object.
        state.phase="play"; sound:observe(true); t=7; sound:observe(true); state.phase="clear"; sound:observe(true); eq(#calls,2)
        state.stage,state.phase=4,"play"; t=7.2; sound:observe(true)
        t=9.5; sound:observe(true); state.phase="victory"; t=9.6; sound:observe(true); eq(calls[#calls],"levelUp")
        local n=#calls; sound:observe(true); eq(#calls,n)
        BlasterMaster_GetSfxPath,PlaySoundFile=nil,nil
    end)
    check("WoW mock: group-channel filtering and canonical cross-realm roster identity", function()
        SlashCmdList.RAMPAGE("leave"); ui.root:Hide()
        grouped = true; event("GROUP_ROSTER_UPDATE")
        assert(app.net.roster["Friend-OtherRealm"] and app.net.roster["Friend-TestRealm"])
        event("CHAT_MSG_ADDON", "OtherPrefix", "R2|A|abc|l|1|0", "PARTY", "Friend-OtherRealm")
        event("CHAT_MSG_ADDON", "ToastRampage1", "R2|A|abc|l|1|0", "GUILD", "Friend-OtherRealm")
        event("CHAT_MSG_ADDON", "ToastRampage1", "R2|A|abc|l|1|0", "PARTY", "Stranger-Realm")
        eq(#app.net:lobbyList(), 0)
        event("CHAT_MSG_ADDON", "ToastRampage1", "R2|A|abc|l|1|0", "PARTY", "Friend-OtherRealm")
        event("CHAT_MSG_ADDON", "ToastRampage1", "R2|A|def|l|1|0", "PARTY", "Friend")
        eq(#app.net:lobbyList(), 2); assert(not ui.root:IsShown())
    end)
    check("WoW mock: visible-only discovery, explicit Join/Spectate and auto-fit", function()
        ui.root:Show(); step(4.1); eq(app.net.mode,"idle")
        local queries=0; for _,m in ipairs(sent) do if m.payload=="R2|Q" then queries=queries+1 end end
        assert(queries>=1 and queries<=2,"open discovery is bounded and does not autojoin")
        local join, chosenRole=app.net.join,nil
        app.net.join=function(_,name,sid,role) chosenRole=role; assert(name and sid); return true end
        ui.render(); click(ui.primary); eq(chosenRole,"play"); click(ui.spectate); eq(chosenRole,"spectate")
        app.net.join=join
        UIParent:SetSize(700,550); event("DISPLAY_SIZE_CHANGED"); assert(ui.root:GetScale()<1)
        UIParent:SetSize(1600,1000); event("UI_SCALE_CHANGED"); eq(ui.root:GetScale(),1)
        ui.root:Hide(); local before=#sent; step(4.1); eq(#sent,before)
    end)
    check("WoW mock: host/start/leave slash commands use only bounded addon messages", function()
        SlashCmdList.RAMPAGE("host"); eq(app.net.mode, "host"); assert(ui.root:IsShown())
        step(0.5); assert(#sent > 0); eq(sent[#sent].distribution, "PARTY")
        SlashCmdList.RAMPAGE("start"); eq(app.net.state.phase, "play")
        raided = true; event("GROUP_ROSTER_UPDATE"); step(0.5); eq(sent[#sent].distribution, "RAID")
        combat = true; event("PLAYER_REGEN_DISABLED"); step(0.5); assert(app.net.state.paused)
        combat = false; event("PLAYER_REGEN_ENABLED"); assert(not app.net.state.paused)
        SlashCmdList.RAMPAGE("leave"); eq(app.net.mode, "idle"); eq(RampageDB.best, 20)
    end)
    check("WoW mock: join stays explicit, group departure resets, help stays local", function()
        SlashCmdList.RAMPAGE("join Friend-OtherRealm"); eq(app.net.mode, "joining")
        step(0.1); assert(string.find(sent[#sent].payload, "R2|J|abc|", 1, true))
        grouped, raided = false, false; event("GROUP_ROSTER_UPDATE"); eq(app.net.mode, "idle")
        local publicBefore = #sent; SlashCmdList.RAMPAGE("help"); assert(#messages >= 3); eq(#sent, publicBefore)
        ui.root.scripts.OnDragStop(ui.root); assert(type(RampageDB.position) == "table")
    end)
end

-- Reusable preview fixtures execute the real addon, then capture its actual shapes.
-- Not gameplay/network evidence and not a screenshot from the WoW client.
function prepareWoWPreview(scene)
    event("ADDON_LOADED", "Rampage"); loggedIn=true; event("PLAYER_LOGIN")
    SlashCmdList.RAMPAGE("solo")
    local app,ui=Addon.App,Addon.UI
    local s=app.net.state
    s.stage=scene=="solo" and 3 or 4; s.boss=8+s.stage*2
    local names={"Deehoc","Toast","Crumb","Sclap","Nick","Waffles","Marmalade","Burnt","Butter","Brioche","Jam","Rye","Bagel","Ciabatta","Sourdough","Muffin","Bun","Pretzel","Pita","Biscuit","Crouton","Pancake","Roll","Croissant","Dough"}
    local count=scene=="solo" and 1 or 25
    for slot=1,count do
        if slot>1 then Addon.Model.addPlayer(s,slot) end
        app.net.members[slot]={name=names[slot].."-ToastRealm"}
        local p=s.players[slot]
        p.x=(slot%3)*2+2; p.y=1+math.floor((slot-1)/3)%3; p.score=100+slot*50
        if slot%4==0 then p.y=0; p.x=1+slot%7 end
    end
    app.net.slot=scene=="solo" and 1 or 12
    if scene=="solo" then s.players[1].x,s.players[1].y,s.players[1].score=2,2,1150 end
    if scene=="boss" or scene=="victory" then
        for i=1,9 do s.hp[i]=0 end
        s.boss=7
        for slot,p in pairs(s.players) do p.x=1+(slot-1)%7; p.y=0 end
    else s.hp[1],s.hp[5],s.hp[9]=0,1,1 end
    if scene=="spectator" then app.net.role,app.net.slot="spectate",nil end
    ui.render(); step(0.1)
    if scene=="victory" then s.phase="victory"; s.boss=0 else s.players[app.net.slot or 1].hit=1 end
    ui.render(); step(0.1)
    if scene~="spectator" and scene~="victory" then app.input:grab() end
    if scene~="solo" then
        -- Match raid presentation without pretending the preview fixture is a
        -- transport simulation. No network ticks execute after this fixture.
        app.net.mode,app.net.hostName,app.net.sid="client","Toast-ToastRealm","preview"
        s._activeCount,s._spectators=count,15
        app.net.status=scene=="spectator" and "Spectating: no avatar, score or gameplay input." or "Joined as player! Shared city, personal score."
    end
    ui.render()
end

function captureWoWPreview()
    local ui=Addon.UI
    local function quote(value)
        local v=tostring(value or ""):gsub("\\","\\\\"):gsub('"','\\"'):gsub("\n","\\n"):gsub("\r","\\r")
        return '"'..v..'"'
    end
    local positions={}
    local function fraction(anchor)
        return string.find(anchor,"LEFT") and 0 or (string.find(anchor,"RIGHT") and 1 or 0.5),
            string.find(anchor,"BOTTOM") and 0 or (string.find(anchor,"TOP") and 1 or 0.5)
    end
    local function position(o)
        if positions[o] then return positions[o] end
        if o==UIParent then return {x=0,y=0,w=o.width,h=o.height,scale=1,alpha=1} end
        local parent=position(o.parent or UIParent)
        local scale=parent.scale*(o.scale or 1)
        local p=o.point or {"BOTTOMLEFT",o.parent,"BOTTOMLEFT",0,0}
        local ref=position(type(p[2])=="table" and p[2] or o.parent or UIParent)
        local ax,ay=fraction(p[1]); local rx,ry=fraction(p[3] or p[1])
        local w,h=o.width*scale,(o.height>0 and o.height or (o.fontSize or 12)*1.3)*scale
        local result={x=ref.x+ref.w*rx+(p[4] or 0)*scale-w*ax,
            y=ref.y+ref.h*ry+(p[5] or 0)*scale-h*ay,w=w,h=h,scale=scale,
            alpha=parent.alpha*(o.alpha or 1)}
        positions[o]=result; return result
    end
    local root=position(ui.root); local records={}
    local function add(o,kind)
        if not o:IsShown() then return end
        local p=position(o); local c=o.color or {1,1,1,1}
        records[#records+1]='{"kind":'..quote(kind)..',"x":'..(p.x-root.x)..',"y":'..(root.h-(p.y-root.y)-p.h)
            ..',"w":'..p.w..',"h":'..p.h..',"r":'..c[1]..',"g":'..c[2]..',"b":'..c[3]
            ..',"alpha":'..p.alpha*(c[4] or 1)..',"level":'..(o.parent and o.parent.level or 1)
            ..',"layer":'..quote(o.layer or "OVERLAY")..',"text":'..quote(o.text)..',"size":'..((o.fontSize or 12)*p.scale)
            ..',"align":'..quote(o.align or "LEFT")..'}'
    end
    for _,o in ipairs(textures) do add(o,"rect") end
    for _,o in ipairs(fonts) do add(o,"text") end
    return '{"width":'..root.w..',"height":'..root.h..',"shapes":['..table.concat(records,",")..']}'
end
