-- API mocks are deliberately small: unknown methods fail instead of silently passing.
-- Also exports actual UI frame geometry for ui-preview.cjs, not a separate concept.
-- This is NOT a native renderer, taint/protected-action simulator or TBC client.
Addon = {}
local frames, textures, fonts, sent, messages = {}, {}, {}, {}, {}
local now, grouped, raided, combat, loggedIn = 100, false, false, false, false
local editFocus, windowFocus, altDown, ctrlDown = nil, true, false, false
local unitCombat={}
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
function UnitAffectingCombat(unit) return unitCombat[unit] or false end
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
-- Exact engine contract fixtures, not a second movement implementation. Only
-- their setup is synthetic; poses/geometry and position math are the real UI/M.
local function bossFixture(s,phase,remaining,fromLane,toLane,lanes,id)
    s.bossMotion={id=id or 1,phase=phase,remaining=remaining,fromLane=fromLane,toLane=toLane,lanes=lanes or {}}
    s.hazard={id=id or 1,phase=phase=="windup" and "warning" or phase=="attack" and "impact" or "idle",
        remaining=remaining,lanes=lanes or {}}
end

function runWoWSmoke()
    local app, ui = Addon.App, Addon.UI
    check("TOC/WoW mock: load-order, saved-variable sanitation and no forced window", function()
        assert(not app.net and not ui.root)
        event("ADDON_LOADED", "AnotherAddon"); assert(not app.net)
        event("ADDON_LOADED", "Rampage"); assert(SlashCmdList.RAMPAGE); eq(SLASH_RAMPAGE1, "/rampage")
        loggedIn = true; event("PLAYER_LOGIN")
        assert(app.net); eq(app.net.name, "Tester-TestRealm"); eq(RampageDB.best, 0); eq(RampageDB.customKept, "yes")
        eq(app.VERSION, assert(EXPECTED_VERSION, "TOC version required by runner")); assert(not ui.root); eq(#sent, 0)
    end)
    check("WoW mock: solo window, original geometry, buttons, damage and personal best", function()
        SlashCmdList.RAMPAGE("solo"); assert(ui.root:IsShown()); eq(app.net.mode, "solo")
        eq(ui.root:GetWidth(), 900); eq(#ui.monsters, 25); eq(#ui.scores, 25); eq(#ui.floors, 9)
        assert(not app.input.focused); assert(not app.input.frame:IsShown()); eq(RampageDB.useBlasterMaster,false)
        eq(app.net.state.mode,"coop"); assert(ui.coop.selected and not ui.brawl.selected)
        assert(string.find(ui.captureStatus:GetText(),"Click PLAY",1,true))
        assert(not string.find(ui.captureStatus:GetText(),"Window hidden",1,true))
        local labels={"A/Left","W/Up","Space","S/Down","D/Right"}
        for i,b in ipairs(ui.controls) do eq(b.label:GetText(),labels[i]); assert(not b.label:GetText():find("[^%z\1-\127]")) end
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
        -- Every known physical key is consumed while the local capture is live.
        -- This is mock routing evidence, not attribution of WoW's red target text.
        for _,key in ipairs({"A","LEFT","W","UP","SPACE","S","DOWN","D","RIGHT"}) do
            assert(input:grab()); f.scripts.OnKeyDown(f,key); eq(f.propagate,false)
            f.scripts.OnKeyUp(f,key); eq(f.propagate,false); input:release()
        end
        click(ui.capture); f.scripts.OnKeyDown(f,"ENTER"); eq(f.propagate,true); assert(not input.focused)
        click(ui.capture); f.scripts.OnKeyDown(f,"W"); editFocus={}; step(0.05)
        assert(not input.focused); eq(f.propagate,true); assert(next(input.held)==nil)
        assert(not input:grab()); editFocus=nil
        click(ui.capture); f.scripts.OnKeyDown(f,"ESCAPE"); assert(not input.focused); eq(f.propagate,true)
        app.net.action=action
    end)
    check("WoW mock: chosen controls persist across cities without held replay or safety recapture", function()
        local net,input=app.net,app.input; local f=input.frame
        local oldState,oldAction=net.state,net.action
        local calls=0; net.action=function() calls=calls+1; return true end
        local function fresh(capture)
            input:release(); net.state=Addon.Model.new(); Addon.Model.addPlayer(net.state,1); Addon.Model.start(net.state)
            if capture then assert(input:grab()) end
        end
        local function clear()
            net.state.phase,net.state.wait="clear",0.2
            net:notice(); input:update(0.01)
        end
        local function nextCity()
            Addon.Model.tick(net.state,0.2); net:notice(); input:update(0.01)
            eq(net.state.stage,2); eq(net.state.phase,"play")
        end
        fresh(true); f.scripts.OnKeyDown(f,"D"); local before=calls
        clear(); assert(input.focused and f:IsShown()); assert(not input:canPlay()); assert(next(input.held)==nil)
        f.scripts.OnKeyDown(f,"D"); f.scripts.OnKeyDown(f,"SPACE"); eq(f.propagate,false); eq(calls,before)
        nextCity(); assert(input.focused); eq(calls,before)
        f.scripts.OnKeyDown(f,"D"); f.scripts.OnKeyDown(f,"SPACE"); eq(calls,before) -- OS repeat blocked until key-up
        f.scripts.OnKeyUp(f,"D"); f.scripts.OnKeyUp(f,"SPACE"); eq(f.propagate,false)
        f.scripts.OnKeyDown(f,"D"); eq(calls,before+1); f.scripts.OnKeyUp(f,"D")
        fresh(false); clear(); nextCity(); assert(not input.focused) -- mouse selection stays mouse
        for _,reason in ipairs({"escape","close","combat","chat","shortcut","focus"}) do
            fresh(true); clear(); assert(input.focused)
            if reason=="escape" then f.scripts.OnKeyDown(f,"ESCAPE")
            elseif reason=="close" then ui.root:Hide(); ui.root:Show()
            elseif reason=="combat" then combat=true; event("PLAYER_REGEN_DISABLED"); combat=false; event("PLAYER_REGEN_ENABLED")
            elseif reason=="chat" then editFocus={}; input:update(0.01); editFocus=nil
            elseif reason=="shortcut" then f.scripts.OnKeyDown(f,"I")
            else windowFocus=false; input:update(0.01); windowFocus=true end
            assert(not input.focused,reason); nextCity(); assert(not input.focused,reason.." recaptured")
        end
        input:release(); net.state,net.action=oldState,oldAction
    end)
    check("WoW mock: keyboard alt-tab, long stall, hidden, leaving-world and spectator release", function()
        local input=app.input; local f=input.frame
        assert(input:grab()); f.scripts.OnKeyDown(f,"SPACE"); windowFocus=false; step(0.05)
        assert(not input.focused); assert(next(input.held)==nil); eq(f.propagate,true); windowFocus=true
        assert(input:grab()); altDown=true; f.scripts.OnKeyDown(f,"TAB"); assert(not input.focused); altDown=false
        assert(input:grab()); ctrlDown=true; f.scripts.OnKeyDown(f,"D"); assert(not input.focused); eq(f.propagate,true); ctrlDown=false
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
        assert(not ui.health:IsShown() and not ui.healthBack:IsShown() and not ui.healthLabel:IsShown())
        eq(ui.personal:GetText(),"SPECTATOR")
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
        eq(#ui.hazardLanes,7); eq(#ui.particles,72); eq(#ui.bossCues,4)
        for _,cue in ipairs(ui.bossCues) do eq(#cue.parts,12) end
        for slot=2,25 do Addon.Model.addPlayer(app.net.state,slot); app.net.members[slot]={name="Crew"..slot.."-Realm"} end
        for i=1,500 do
            for slot=1,25 do local p=app.net.state.players[slot]; p.hit=i%1000; p.x=1+(slot+i)%7 end
            app.net.state.stage=1+(i-1)%4
            bossFixture(app.net.state,i%3==0 and "attack" or "windup",i%3==0 and 0.3 or 6,4,4,{1,3,7},i)
            -- Exactly 500 UI renders; no adapter OnUpdate secretly doubles them.
            now=now+0.05; ui.burst(316,180,12,"hit"); ui.render()
        end
        for slot=2,25 do Addon.Model.removePlayer(app.net.state,slot); app.net.members[slot]=nil end
        app.net.state.stage=1; bossFixture(app.net.state,"patrol",5,4,5,{})
        eq(#frames, frameCount); eq(#textures, textureCount); eq(#fonts, fontCount)
        print("  Fixed UI allocation fixture: " .. frameCount .. " frames, " .. textureCount .. " textures, " .. fontCount .. " font strings; exactly 500 renders, 48 boss-cue textures")
    end)
    check("WoW mock: authoritative HP / KO / shield cues and seven warning / impact / recovery lanes", function()
        local s=app.net.state; local p=s.players[1]
        p.hp,p.maxHP,p.ko,p.invuln,p.kos=100,100,0,0,2
        bossFixture(s,"windup",6,4,4,{1,3,7}); ui.render()
        local framesBefore,texturesBefore,fontsBefore=#frames,#textures,#fonts
        assert(ui.hazardLanes[1]:IsShown() and ui.hazardLanes[3]:IsShown() and ui.hazardLanes[7]:IsShown())
        assert(not ui.hazardLanes[2]:IsShown()); assert(ui.hazardText:GetText():find("IN 6s",1,true))
        local flavors={}
        for stage=1,4 do s.stage=stage; ui.render(); flavors[ui.hazardText:GetText()]=true end
        local flavorCount=0; for _ in pairs(flavors) do flavorCount=flavorCount+1 end; eq(flavorCount,4)
        s.stage=1; ui.render(); p.hp=35; ui.render(); assert(ui.monsters[1].hurt:IsShown()); eq(ui.health:GetWidth(),188*0.35)
        assert(ui.team:GetText():find("2 KOs",1,true)); assert(ui.personal:GetText():find("YOUR FAME",1,true))
        assert(app.input:grab()); p.hp,p.ko=0,3; app.input:update(0.01); ui.render()
        assert(not app.input.focused and not app.input:action("P")); assert(not ui.controls[3]:IsEnabled())
        assert(ui.healthLabel:GetText():find("respawn in 3s",1,true)); assert(ui.monsters[1].badge:GetText():find("KO",1,true))
        p.hp,p.ko,p.invuln=100,0,2; ui.render(); assert(ui.controls[3]:IsEnabled()); assert(not app.input.focused)
        assert(ui.healthLabel:GetText():find("SHIELD 2s",1,true))
        bossFixture(s,"attack",0.3,4,4,{1,3,7}); ui.render(); assert(ui.hazardText:GetText():find("IMPACT",1,true))
        for _=1,20 do ui.render() end; eq(p.hp,100) -- UI never inflicts damage.
        bossFixture(s,"recover",4,4,4,{}); ui.render(); assert(ui.hazardText:GetText():find("BOSS RECOVERING",1,true))
        for _,mark in ipairs(ui.hazardLanes) do assert(not mark:IsShown()) end
        eq(#frames,framesBefore); eq(#textures,texturesBefore); eq(#fonts,fontsBefore)
        p.invuln,p.kos=0,0; s.hazard=nil
    end)
    check("WoW mock: boss actual ground center matches model while shielded and exposed", function()
        local net=app.net; local old=net.state
        local s=Addon.Model.new(); Addon.Model.addPlayer(s,1); Addon.Model.start(s); net.state=s
        for _,remaining in ipairs({5,3.75,2.5,0}) do
            bossFixture(s,"patrol",remaining,2,4,{},1); ui.render()
            eq(ui.boss.drawLane,Addon.Model.bossPosition(s))
            eq(ui.boss.drawCenterX,31+(Addon.Model.bossPosition(s)-1)*95)
            eq(ui.boss.point[4]*ui.boss.artScale+24*ui.boss.artScale,ui.boss.drawCenterX)
            eq(ui.boss.point[5]*ui.boss.artScale,32); eq(ui.boss.artScale,1.5)
            assert(ui.boss.shield[1]:IsShown()); assert(ui.bossGround:IsShown())
        end
        for i=1,9 do s.hp[i]=0 end
        bossFixture(s,"recover",5,5,5,{},2); ui.render()
        eq(ui.boss.drawLane,5); eq(ui.boss.artScale,1.5); assert(not ui.boss.shield[1]:IsShown())
        eq(ui.bossGround.point[4],ui.boss.drawCenterX-95); eq(ui.bossGround.strip:GetWidth(),190)
        assert(ui.bossLabel:GetText():find("Hit near boss",1,true)); assert(not ui.bossLabel:GetText():find("3–5",1,true))
        -- Owner rendering is exact even when the wall clock advances without a
        -- model tick; it never uses the client's interpolation argument.
        bossFixture(s,"patrol",4,2,4,{},3); ui.render(); local ownerX=ui.boss.drawLane
        now=now+1; ui.render(); eq(ui.boss.drawLane,ownerX)
        net.state=old; ui.resetBossVisuals()
    end)
    check("WoW mock: guest interpolation only known patrol, endpoint cap, pause and stale freeze", function()
        local net=app.net
        local oldState,oldMode,oldSeq,oldSnap=net.state,net.mode,net.inSeq,net.lastSnapshot
        local s=Addon.Model.new(); Addon.Model.addPlayer(s,1); Addon.Model.start(s)
        net.state,net.mode,net.inSeq,net.lastSnapshot=s,"client",10,now
        bossFixture(s,"patrol",5,2,4,{},8); ui.resetBossVisuals(); ui.render()
        eq(ui.boss.drawLane,Addon.Model.bossPosition(s))
        now=now+1; ui.render(); eq(ui.boss.drawLane,Addon.Model.bossPosition(s,1))
        local x=ui.boss.drawLane; s.paused=true; now=now+0.5; ui.render(); eq(ui.boss.drawLane,x)
        assert(ui.hazardText:GetText():find("PAUSED",1,true))
        s.paused=false; net.inSeq=11; net.lastSnapshot=now; ui.render()
        now=now+2.4; ui.render(); x=ui.boss.drawLane
        now=now+0.2; ui.render(); eq(ui.boss.drawLane,x); assert(ui.hazardText:GetText():find("STALE",1,true))
        now=now+10; ui.render(); eq(ui.boss.drawLane,x)
        net.inSeq=12; net.lastSnapshot=now; bossFixture(s,"patrol",0.2,2,4,{},8); ui.render()
        now=now+1; ui.render(); eq(ui.boss.drawLane,4); eq(s.bossMotion.phase,"patrol"); eq(s.bossMotion.remaining,0.2)
        net.inSeq=13; net.lastSnapshot=now; bossFixture(s,"windup",7,4,4,{2},8); ui.render()
        local arm=ui.boss.armR.point[5]; now=now+1; ui.render()
        eq(ui.boss.drawLane,4); eq(ui.boss.armR.point[5],arm); eq(s.bossMotion.remaining,7)
        assert(ui.hazardText:GetText():find("IN 7s",1,true)); assert(ui.hazardText:GetText():find("last sample",1,true))
        net.state,net.mode,net.inSeq,net.lastSnapshot=oldState,oldMode,oldSeq,oldSnap; ui.resetBossVisuals()
    end)
    check("WoW mock: four causal attack poses, locked cues, no damage or per-frame launch", function()
        local net=app.net; local old=net.state
        local s=Addon.Model.new(); Addon.Model.addPlayer(s,1); Addon.Model.start(s); net.state=s
        s.players[1].invuln=0
        ui.baseline=nil
        for stage=1,4 do
            s.stage=stage; bossFixture(s,"patrol",3,2,4,{},20+stage); ui.render()
            local patrolArm=ui.boss.armR.point[5]
            bossFixture(s,"windup",6,4,4,stage==4 and {2,4,6} or {3},20+stage); ui.render()
            local windupArm=ui.boss.armR.point[5]; assert(windupArm~=patrolArm)
            assert(ui.bossCues[1].parts[1]:IsShown()); assert(not ui.bossCues[1].parts[12]:IsShown())
            eq(ui.bossCues[1].originX,31+3*95)
            local marked=s.bossMotion.lanes[1]
            if stage==3 then eq(ui.hazardLanes[marked].left:GetHeight(),35); assert(ui.hazardText:GetText():find("GROUND ONLY",1,true))
            else eq(ui.hazardLanes[marked].left:GetHeight(),205); assert(ui.hazardText:GetText():find("ALL HEIGHTS",1,true)) end
            local lanes=s.bossMotion.lanes
            bossFixture(s,"attack",0.3,4,4,lanes,20+stage); ui.render()
            assert(ui.boss.armR.point[5]~=windupArm); assert(ui.bossCues[1].parts[12]:IsShown())
            local changes=ui.bossVisual.cueChanges; local hp=s.players[1].hp; local cursor=ui.particleCursor
            local safe=0; for _,mark in ipairs(ui.hazardLanes) do if not mark:IsShown() then safe=safe+1 end end
            assert(safe>=3)
            for _=1,20 do now=now+0.03; ui.render() end
            eq(ui.bossVisual.cueChanges,changes); eq(s.players[1].hp,hp); eq(s.bossMotion.remaining,0.3)
            eq(ui.particleCursor,cursor)
            bossFixture(s,"recover",5,4,4,{},20+stage); ui.render()
            eq(ui.boss.armR.point[5],13); assert(not ui.bossCues[1].parts[1]:IsShown())
        end
        net.state=old; ui.resetBossVisuals()
    end)
    check("WoW mock: timely recovery confirms skipped impact with one harmless residue, never old launch", function()
        local net=app.net
        local oldState,oldMode,oldSeq,oldSnap=net.state,net.mode,net.inSeq,net.lastSnapshot
        local s=Addon.Model.new(); Addon.Model.addPlayer(s,1); Addon.Model.start(s)
        net.state,net.mode,net.inSeq,net.lastSnapshot=s,"client",30,now
        bossFixture(s,"windup",0.8,5,5,{3},7); ui.resetBossVisuals(); ui.render()
        local hp=s.players[1].hp; local cursor=ui.particleCursor
        now=now+1.25; net.inSeq=31; net.lastSnapshot=now
        bossFixture(s,"recover",4.8,5,5,{},7); ui.render()
        assert(ui.bossVisual.confirmed); assert(ui.bossCues[1].parts[12]:IsShown())
        eq(ui.bossCues[1].targetX,31+2*95); eq(ui.boss.pose,"recover")
        assert(ui.hazardText:GetText():find("IMPACT CONFIRMED",1,true))
        local untilTime=ui.bossVisual.confirmedUntil
        for _=1,10 do now=now+0.03; ui.render() end
        eq(ui.bossVisual.confirmedUntil,untilTime); eq(s.players[1].hp,hp); eq(ui.particleCursor,cursor)
        now=now+0.4; ui.render(); assert(not ui.bossVisual.confirmed)
        assert(not ui.bossCues[1].parts[12]:IsShown())
        -- No cue for late joining recovery, a skipped/stale world, or a pause.
        ui.resetBossVisuals(); ui.render(); assert(not ui.bossVisual.confirmed)
        net.inSeq=32; net.lastSnapshot=now; bossFixture(s,"windup",1,5,5,{3},8); ui.render()
        net.inSeq=34; net.lastSnapshot=now; bossFixture(s,"recover",4,5,5,{},8); ui.render(); assert(not ui.bossVisual.confirmed)
        net.inSeq=35; net.lastSnapshot=now; bossFixture(s,"windup",1,5,5,{3},9); ui.render()
        now=now+3; ui.render(); net.inSeq=36; net.lastSnapshot=now
        bossFixture(s,"recover",4,5,5,{},9); ui.render(); assert(not ui.bossVisual.confirmed)
        net.inSeq=37; net.lastSnapshot=now; bossFixture(s,"windup",1,5,5,{3},10); ui.render()
        net.inSeq=38; net.lastSnapshot=now; bossFixture(s,"recover",4,5,5,{},10); s.paused=true; ui.render()
        assert(not ui.bossVisual.confirmed); eq(s.players[1].hp,hp)
        net.state,net.mode,net.inSeq,net.lastSnapshot=oldState,oldMode,oldSeq,oldSnap; ui.resetBossVisuals()
    end)
    check("WoW mock: unrendered stale sample suppresses late residue while exact-age boundary stays timely", function()
        local net=app.net
        local oldState,oldMode,oldSeq,oldSnap=net.state,net.mode,net.inSeq,net.lastSnapshot
        local s=Addon.Model.new(); Addon.Model.addPlayer(s,1); Addon.Model.start(s)
        net.state,net.mode=s,"client"
        local function sample(gap)
            net.inSeq,net.lastSnapshot=10,now; s.time=20
            bossFixture(s,"windup",0.8,5,5,{3},7); ui.resetBossVisuals(); ui.render()
            ui.burst(100,100,1,"hit")
            now=now+gap -- deliberately NO intermediate render to set v.stale
            net.inSeq,net.lastSnapshot=11,now; s.time=21.25
            bossFixture(s,"recover",4.8,5,5,{},7); ui.render()
            return ui.bossVisual.confirmed
        end
        assert(not sample(4),"stalled rendering must not confirm a four-second-old warning")
        for _,p in ipairs(ui.particles) do assert(not p.start,"stale baseline particles must clear") end
        assert(sample(2.5),"exact 2.5-second age cap remains timely")
        assert(not sample(2.501),"strictly over cap suppresses without an intermediate render")
        assert(sample(1.25),"ordinary consecutive snapshot confirmation remains")
        net.state,net.mode,net.inSeq,net.lastSnapshot=oldState,oldMode,oldSeq,oldSnap; ui.resetBossVisuals()
    end)
    check("WoW mock: snapshot gaps, epoch, replay and hidden resets cannot catch up old boss FX", function()
        local net=app.net
        local oldState,oldMode,oldSeq,oldSnap=net.state,net.mode,net.inSeq,net.lastSnapshot
        local s=Addon.Model.new(); Addon.Model.addPlayer(s,1); Addon.Model.start(s)
        s._epoch=3; s.time=40; net.state,net.mode,net.inSeq,net.lastSnapshot=s,"client",20,now
        bossFixture(s,"attack",0.2,5,5,{1,3,6},41); ui.resetBossVisuals(); ui.baseline=nil; ui.render()
        local cursor=ui.particleCursor; eq(ui.bossVisual.cueChanges,1)
        net.inSeq=23; net.lastSnapshot=now; bossFixture(s,"recover",2,5,5,{},41); ui.render()
        eq(ui.bossVisual.cueChanges,1); assert(not ui.bossCues[1].parts[1]:IsShown()); eq(ui.particleCursor,cursor)
        net.inSeq=24; s._epoch=4; bossFixture(s,"patrol",5,2,3,{},1); ui.render()
        eq(ui.bossVisual.cueChanges,1); eq(ui.boss.drawLane,2)
        s.time=0; bossFixture(s,"windup",7,3,3,{4},1); ui.render(); eq(ui.bossVisual.cueChanges,1)
        s.stage=2; bossFixture(s,"patrol",5,4,6,{},1); ui.render()
        eq(ui.bossVisual.cueChanges,1); assert(not ui.bossCues[1].parts[1]:IsShown())
        ui.root:Hide(); assert(not ui.bossVisual); ui.root:Show(); ui.render()
        eq(ui.bossVisual.cueChanges,1); eq(ui.particleCursor,cursor)
        net.state,net.mode,net.inSeq,net.lastSnapshot=oldState,oldMode,oldSeq,oldSnap; ui.resetBossVisuals()
    end)
    check("WoW mock: consistent hover / pressed / disabled / selected button treatment", function()
        local b=ui.capture; ui.render(); local normal=b.base.color[1]
        b.scripts.OnEnter(b); assert(b.hovered and b.base.color[1]>normal)
        b.scripts.OnMouseDown(b); assert(b.pressed and b.base.color[1]<normal)
        b.scripts.OnMouseUp(b); assert(not b.pressed)
        b.scripts.OnLeave(b); assert(not b.hovered); eq(b.base.color[1],normal)
        click(b); ui.render(); assert(app.input.focused and b.selected); click(b); assert(not b.selected)
        app.net.state.players[1].ko=1; ui.render(); assert(not b:IsEnabled()); eq(b.alpha,0.38)
        app.net.state.players[1].ko=0; ui.render()
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
        event("CHAT_MSG_ADDON", "OtherPrefix", "R4|A|abc|l|1|0|c|0", "PARTY", "Friend-OtherRealm")
        event("CHAT_MSG_ADDON", "ToastRampage1", "R4|A|abc|l|1|0|c|0", "GUILD", "Friend-OtherRealm")
        event("CHAT_MSG_ADDON", "ToastRampage1", "R4|A|abc|l|1|0|c|0", "PARTY", "Stranger-Realm")
        eq(#app.net:lobbyList(), 0)
        event("CHAT_MSG_ADDON", "ToastRampage1", "R4|A|abc|l|1|0|c|0", "PARTY", "Friend-OtherRealm")
        event("CHAT_MSG_ADDON", "ToastRampage1", "R4|A|def|l|1|0|c|0", "PARTY", "Friend")
        eq(#app.net:lobbyList(), 2); assert(not ui.root:IsShown())
    end)
    check("WoW mock: local hurt audio is opt-in, authoritative, rare and spectator-quiet", function()
        local t,calls=0,0
        local state=Addon.Model.new(); Addon.Model.addPlayer(state,1); Addon.Model.start(state)
        local a={db={useBlasterMaster=true},now=function() return t end,
            net={state=state,slot=1,role="play",mode="solo",name="Local"}}
        local sound=Addon.Sound.create(a)
        BlasterMaster_GetSfxPath=function(role) eq(role,"combatStart"); return role end
        PlaySoundFile=function() calls=calls+1; return true end
        sound:observe(true); t=0.1; state.players[1].hp=90; sound:observe(true); eq(calls,1)
        t=0.2; state.players[1].hp=80; sound:observe(true); eq(calls,1)
        t=3; sound:observe(true); t=3.1; state.players[1].hp=70; sound:observe(true); eq(calls,1)
        t=4.2; state.players[1].hp=60; sound:observe(true); eq(calls,2)
        a.net.role,a.net.slot="spectate",nil; t=4.3; state.players[1].hp=50; sound:observe(true); eq(calls,2)
        BlasterMaster_GetSfxPath,PlaySoundFile=nil,nil
    end)
    check("WoW mock: visible-only discovery, explicit Join/Spectate and auto-fit", function()
        ui.root:Show(); step(4.1); eq(app.net.mode,"idle")
        local queries=0; for _,m in ipairs(sent) do if m.payload=="R4|Q" then queries=queries+1 end end
        assert(queries>=1 and queries<=2,"open discovery is bounded and does not autojoin")
        local join, chosenRole=app.net.join,nil
        app.net.join=function(_,name,sid,role) chosenRole=role; assert(name and sid); return true end
        ui.render(); click(ui.primary); eq(chosenRole,"play"); click(ui.spectate); eq(chosenRole,"spectate")
        app.net.join=join
        UIParent:SetSize(700,550); event("DISPLAY_SIZE_CHANGED"); assert(ui.root:GetScale()<1)
        UIParent:SetSize(1600,1000); event("UI_SCALE_CHANGED"); eq(ui.root:GetScale(),1)
        ui.root:Hide(); local before=#sent; step(4.1); eq(#sent,before)
    end)
    check("WoW mock: discovered capacity gates new admission, not existing spectator role switches", function()
        local net=app.net
        local oldList,oldJoin,oldRole=net.lobbyList,net.join,net.setRole
        local oldMode,oldState,oldNetRole,oldSlot=net.mode,net.state,net.role,net.slot
        local lobby={name="Friend-OtherRealm",sid="capacity",phase="play",count=24,spectators=16}
        local joins,roles={},{}
        net.lobbyList=function() return {lobby} end
        net.join=function(_,name,sid,role) eq(name,lobby.name); eq(sid,lobby.sid); joins[#joins+1]=role; return true end
        net.setRole=function(_,role) roles[#roles+1]=role; return true end
        net.mode,net.state,net.role,net.slot="idle",nil,nil,nil; ui.root:Show(); ui.render()
        -- 24 active +16 observers: total capacity is full despite a free active slot.
        assert(not ui.primary:IsEnabled() and not ui.spectate:IsEnabled())
        eq(ui.primary.label:GetText(),"GAME FULL"); eq(ui.spectate.label:GetText(),"GAME FULL")
        assert(string.find(ui.lobby:GetText(),"FULL (40/40)",1,true))
        click(ui.primary); click(ui.spectate); eq(#joins,0)
        -- 25 active +0 observers: player admission is disabled, explicit Spectate remains.
        lobby.count,lobby.spectators=25,0; ui.render()
        assert(not ui.primary:IsEnabled() and ui.spectate:IsEnabled()); eq(ui.primary.label:GetText(),"PLAYERS FULL")
        eq(ui.spectate.label:GetText(),"SPECTATE"); assert(string.find(ui.lobby:GetText(),"SPECTATE to watch",1,true))
        click(ui.primary); eq(#joins,0); click(ui.spectate); eq(joins[1],"spectate")
        -- 24 +15: both admission choices work; phase=play proves join-in-progress UI.
        lobby.count,lobby.spectators=24,15; ui.render()
        assert(ui.primary:IsEnabled() and ui.spectate:IsEnabled()); eq(ui.primary.label:GetText(),"JOIN CO-OP")
        click(ui.primary); eq(joins[2],"play"); click(ui.spectate); eq(joins[3],"spectate")
        -- Existing observers do not consume new total capacity when becoming active.
        lobby.spectators=16; net.mode,net.role="client","spectate"
        net.state=Addon.Model.new(); net.state.phase="play"; net.state._activeCount,net.state._spectators=24,16
        ui.render(); assert(ui.primary:IsEnabled()); eq(ui.primary.label:GetText(),"SWITCH TO PLAY")
        click(ui.primary); eq(roles[1],"play"); eq(#joins,3)
        -- Ordinary ongoing game remains joinable after the full-lobby display clears.
        net.mode,net.state,net.role="idle",nil,nil; lobby.count,lobby.spectators=3,2; ui.render()
        assert(ui.primary:IsEnabled() and ui.spectate:IsEnabled()); eq(ui.primary.label:GetText(),"JOIN CO-OP")
        click(ui.primary); eq(joins[4],"play")
        -- AI consumes actor slots, never an actual 40-person group seat.
        lobby.count,lobby.spectators,lobby.bots=24,16,5; ui.render()
        assert(ui.primary:IsEnabled() and ui.spectate:IsEnabled())
        -- A full actor roster with filler AI must still admit a human: engine
        -- automatically vacates one AI without consuming another real seat.
        lobby.count,lobby.spectators,lobby.bots=25,0,5; ui.render()
        assert(ui.primary:IsEnabled()); eq(ui.primary.label:GetText(),"JOIN CO-OP")
        net.mode,net.role,net.state="client","spectate",Addon.Model.new()
        net.state._activeCount,net.state._botCount,net.state._spectators=25,5,20
        ui.render(); assert(ui.primary:IsEnabled()); click(ui.primary); eq(roles[2],"play")
        lobby.bots=nil
        net.lobbyList,net.join,net.setRole=oldList,oldJoin,oldRole
        net.mode,net.state,net.role,net.slot=oldMode,oldState,oldNetRole,oldSlot
        ui.root:Hide()
    end)
    check("WoW mock: host/start/leave slash commands use only bounded addon messages", function()
        SlashCmdList.RAMPAGE("host"); eq(app.net.mode, "host"); assert(ui.root:IsShown())
        step(0.5); assert(#sent > 0); eq(sent[#sent].distribution, "PARTY")
        SlashCmdList.RAMPAGE("start"); eq(app.net.state.phase, "play")
        raided = true; event("GROUP_ROSTER_UPDATE"); step(1.5); eq(sent[#sent].distribution, "RAID")
        combat = true; event("PLAYER_REGEN_DISABLED"); step(0.5); assert(app.net.state.paused)
        combat = false; event("PLAYER_REGEN_ENABLED"); assert(not app.net.state.paused)
        SlashCmdList.RAMPAGE("leave"); eq(app.net.mode, "idle"); eq(RampageDB.best, 20)
    end)
    check("WoW mock: join stays explicit, group departure resets, help stays local", function()
        SlashCmdList.RAMPAGE("join Friend-OtherRealm"); eq(app.net.mode, "joining")
        step(0.1); assert(string.find(sent[#sent].payload, "R4|J|abc|", 1, true))
        grouped, raided = false, false; event("GROUP_ROSTER_UPDATE"); eq(app.net.mode, "idle")
        local publicBefore = #sent; SlashCmdList.RAMPAGE("help"); assert(#messages >= 3); eq(#sent, publicBefore)
        ui.root.scripts.OnDragStop(ui.root); assert(type(RampageDB.position) == "table")
    end)
    check("WoW mock: default Co-op, explicit solo Brawl, owner AI limits and no fake roster", function()
        local net=app.net
        ui.root:Show(); ui.render(); eq(ui.selectedMode,"coop")
        assert(ui.coop.selected and not ui.brawl.selected); assert(not ui.addAI:IsEnabled())
        click(ui.brawl); assert(ui.brawl.selected and not ui.coop.selected); click(ui.solo)
        eq(net.mode,"solo"); eq(net.state.mode,"brawl"); eq(net:botCount(),0)
        assert(ui.lobby:GetText():find("BRAWL",1,true)); assert(not ui.brawl:IsEnabled() and not ui.coop:IsEnabled())
        for i=1,5 do click(ui.addAI); eq(net:botCount(),i); eq(net:count(),i+1) end
        click(ui.addAI); eq(net:botCount(),5); assert(not ui.addAI:IsEnabled()); assert(ui.removeAI:IsEnabled())
        local ai=0
        for slot,p in pairs(net.state.players) do if p.bot then
            ai=ai+1; assert(net.members[slot].bot); assert(ui.scores[slot].label:GetText():find("AI",1,true))
            assert(ui.monsters[slot].badge:GetText():find("AI",1,true)); assert(not net.roster[net.members[slot].name])
        end end
        eq(ai,5); assert(ui.crewSub:GetText():find("5 / 5 AI",1,true))
        for slot=7,25 do Addon.Model.addPlayer(net.state,slot); net.members[slot]={name="Human"..slot.."-Realm"} end
        ui.render(); eq(net:count(),25); assert(not ui.addAI:IsEnabled())
        for slot=7,25 do Addon.Model.removePlayer(net.state,slot); net.members[slot]=nil end
        ui.render()
        click(ui.removeAI); eq(net:botCount(),4); click(ui.addAI); eq(net:botCount(),5)
        local mode=net.mode; net.mode="client"; ui.render(); assert(not ui.addAI:IsEnabled() and not ui.removeAI:IsEnabled())
        net.mode=mode; net.state.phase="victory"; ui.render(); assert(ui.coop:IsEnabled())
        click(ui.coop); eq(net.state.mode,"coop"); click(ui.primary); eq(net.state.phase,"play"); eq(net.state.mode,"coop")
        click(ui.leave); eq(net.mode,"idle")
        -- Grouped primary hosts a lobby, not an instant match: mode remains editable.
        grouped=true; event("GROUP_ROSTER_UPDATE"); net.lobbies={}; ui.render(); click(ui.primary)
        eq(net.mode,"host"); eq(net.state.phase,"lobby"); eq(net.state.mode,"coop")
        assert(ui.brawl:IsEnabled()); click(ui.brawl); eq(net.state.mode,"brawl")
        net.participants[2]={name="Friend-OtherRealm"}; ui.render()
        assert(not ui.coop:IsEnabled() and not ui.brawl:IsEnabled())
        click(ui.coop); eq(net.state.mode,"brawl"); assert(not net:setMode("coop"))
        net.state.phase="victory"; ui.render(); assert(not ui.coop:IsEnabled())
        net.participants[2]=nil; net.state.phase="lobby"; ui.render(); assert(ui.coop:IsEnabled())
        assert(app.rosterUnits["Friend-OtherRealm"]=="party1")
        unitCombat.party1=true; assert(net.env.inCombat("Friend-OtherRealm")); assert(not net.env.inCombat("NoSuch-Realm"))
        unitCombat.party1=nil; assert(not net.env.inCombat("Friend-OtherRealm"))
        click(ui.addAI); eq(net:botCount(),1); click(ui.primary); eq(net.state.phase,"play")
        assert(not ui.coop:IsEnabled()); click(ui.coop); eq(net.state.mode,"brawl")
        click(ui.leave); grouped=false; event("GROUP_ROSTER_UPDATE")
    end)
    check("WoW mock: Brawl join and observer switch have explicit consent labels", function()
        local net=app.net
        local list,join,setRole=net.lobbyList,net.join,net.setRole
        local lobby={name="Host-Realm",sid="brawl",mode="brawl",phase="play",count=4,spectators=2,bots=2}
        net.lobbyList=function() return {lobby} end
        local role,mode
        net.join=function(_,name,sid,r,m) eq(name,lobby.name); eq(sid,lobby.sid); role,mode=r,m; return true end
        ui.render(); eq(ui.primary.label:GetText(),"JOIN BRAWL"); assert(ui.lobby:GetText():find("2 AI",1,true))
        click(ui.primary); eq(role,"play"); eq(mode,"brawl")
        role=nil; click(ui.spectate); eq(role,"spectate"); eq(mode,"brawl")
        role=nil; SlashCmdList.RAMPAGE("join Host-Realm"); eq(role,nil); eq(net.mode,"idle")
        net.mode,net.role,net.state="client","spectate",Addon.Model.new("brawl"); net.state.mode="brawl"
        net.setRole=function(_,r) role=r; return true end
        ui.render(); eq(ui.primary.label:GetText(),"JOIN BRAWL"); assert(not ui.capture:IsEnabled() and not ui.health:IsShown())
        role=nil; SlashCmdList.RAMPAGE("play"); eq(role,nil); click(ui.primary); eq(role,"play")
        net.lobbyList,net.join,net.setRole=list,join,setRole; net:leave(); ui.render()
    end)
end

-- Reusable preview fixtures execute the real addon, then capture its actual shapes.
-- Not gameplay/network evidence and not a screenshot from the WoW client.
function prepareWoWPreview(scene)
    event("ADDON_LOADED", "Rampage"); loggedIn=true; event("PLAYER_LOGIN")
    SlashCmdList.RAMPAGE((scene=="brawl" or scene=="ko") and "solo brawl" or "solo")
    local app,ui=Addon.App,Addon.UI
    local s=app.net.state
    local motionScene=scene=="boss-patrol" or scene=="boss-windup" or scene=="boss-impact"
    s.stage=scene=="solo" and 3 or scene=="hazard" and 2 or motionScene and 1 or 4; s.boss=8+s.stage*2
    local names={"Deehoc","Toast","Crumb","Sclap","Nick","Waffles","Marmalade","Burnt","Butter","Brioche","Jam","Rye","Bagel","Ciabatta","Sourdough","Muffin","Bun","Pretzel","Pita","Biscuit","Crouton","Pancake","Roll","Croissant","Dough"}
    local chaos=scene=="brawl" or scene=="hazard" or scene=="ko"
    local count=scene=="solo" and 1 or (chaos or motionScene) and 6 or 25
    if chaos then for _=1,5 do app.net:addAI() end end
    for slot=1,count do
        if slot>1 and not s.players[slot] then Addon.Model.addPlayer(s,slot) end
        if not (chaos and slot>1) then app.net.members[slot]={name=names[slot].."-ToastRealm"} end
        local p=s.players[slot]
        p.x=(slot%3)*2+2; p.y=1+math.floor((slot-1)/3)%3; p.score=100+slot*50
        if chaos then p.hp,p.kos=100-slot*9,s.mode=="brawl" and slot%3 or 0; if slot>1 then p.bot=true end end
        if slot%4==0 then p.y=0; p.x=1+slot%7 end
    end
    app.net.slot=(scene=="solo" or chaos or motionScene) and 1 or 12
    if scene=="solo" then s.players[1].x,s.players[1].y,s.players[1].score=2,2,1150 end
    if scene=="boss" or scene=="victory" or (motionScene and scene~="boss-patrol") then
        for i=1,9 do s.hp[i]=0 end
        s.boss=7
        for slot,p in pairs(s.players) do p.x=1+(slot-1)%7; p.y=0 end
    else s.hp[1],s.hp[5],s.hp[9]=0,1,1 end
    if scene=="spectator" then app.net.role,app.net.slot="spectate",nil end
    if chaos then
        -- Match the real stage patterns: Permitron pair or simultaneous barrage.
        bossFixture(s,"windup",6,4,4,s.stage==2 and {3,4} or {2,3,4},3)
        for slot,p in pairs(s.players) do p.x,p.y=slot,0 end
        s.players[1].invuln=0
    end
    if scene=="ko" then s.players[1].hp,s.players[1].ko=0,2.4 end
    ui.render(); step(0.1)
    if scene=="victory" then s.phase="victory"; s.boss=0 else s.players[app.net.slot or 1].hit=1 end
    ui.render(); step(0.1)
    if scene~="spectator" and scene~="victory" then app.input:grab() end
    if motionScene then
        -- Real model position + real UI geometry, deterministic sample with no
        -- transport simulation and no subsequent adapter ticks. Three different
        -- ground positions make a static floating-boss regression obvious.
        for slot,p in pairs(s.players) do p.x,p.y=slot,0; p.invuln=0 end
        if scene=="boss-patrol" then bossFixture(s,"patrol",2.5,2,3,{},7)
        elseif scene=="boss-windup" then bossFixture(s,"windup",5,4,4,{2},8)
        else bossFixture(s,"attack",0.2,5,5,{3},9) end
        ui.baseline=nil; ui.resetBossVisuals()
    end
    if scene~="solo" and not chaos then
        -- Match raid presentation without pretending the preview fixture is a
        -- transport simulation. No network ticks execute after this fixture.
        app.net.mode,app.net.hostName,app.net.sid="client","Toast-ToastRealm","preview"
        app.net.inSeq,app.net.lastSnapshot=1,now
        s._activeCount,s._spectators=count,motionScene and 0 or 15
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
