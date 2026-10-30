-- Appended to strict wow-smoke mocks by run.cjs, so this fresh context can drive
-- real adapter events and real two-node Protocol packets without fake net methods.
function runFlowTests()
    local app,ui,N=Addon.App,Addon.UI,Addon.Protocol
    local host,outbound,readSent,readHost,serial=nil,{},1,1,0
    local function pump(seconds)
        for _=1,math.ceil(seconds/0.05) do
            step(0.05)
            if host then
                while readSent<=#sent do host:receive(app.net.name,sent[readSent].payload); readSent=readSent+1 end
                host:tick(0.05)
                while readHost<=#outbound do
                    app.net:receive(host.name,outbound[readHost]); readHost=readHost+1
                end
            end
        end
    end
    local function freshHost(mode)
        host=N.new({name="Friend-OtherRealm",now=function() return now end,
            token=function() serial=serial+1; return "flow"..serial end,
            send=function(payload) outbound[#outbound+1]=payload end})
        host:setRoster({[host.name]=true,[app.net.name]=true},true)
        assert(host:host(mode or "brawl")); return host
    end
    check("flow: closed advertisements never open the UI or auto-admit",function()
        event("ADDON_LOADED","Rampage"); loggedIn=true; event("PLAYER_LOGIN")
        grouped=true; event("GROUP_ROSTER_UPDATE"); freshHost()
        pump(8)
        assert(not ui.root or not ui.root:IsShown()); eq(app.net.mode,"idle")
        eq(host:spectatorCount(),0); eq(host:count(),1)
    end)
    check("flow: explicit opening auto-watches real Brawl host without avatar or keys",function()
        assert(app.openWindow()); pump(25)
        eq(app.net.mode,"client"); eq(app.net.hostName,host.name); eq(app.net.role,"spectate")
        eq(app.net.slot,nil); assert(not app.input.focused); eq(host:spectatorCount(),1)
        local id=app.net.ownMemberID; assert(id and host.participants[id])
        assert(not host.participants[id].slot)
    end)
    check("flow: explicit Join fight consents; Leave fight preserves continuous member ordinal",function()
        local id=app.net.ownMemberID
        local ordinal=host.participants[id].joined
        assert(type(ordinal)=="number" and ordinal>1)
        assert(app.joinFight()); pump(5)
        eq(app.net.role,"play"); assert(app.net.slot); assert(not app.input.focused)
        assert(app.leaveFight()); pump(5)
        eq(app.net.role,"spectate"); eq(app.net.slot,nil)
        eq(host.participants[id].joined,ordinal)
        eq(app.net.ownMemberID,id)
    end)
    check("flow: adding and removing real AI never auto-promotes a watcher",function()
        for _=1,5 do assert(host:addAI()) end
        pump(5); eq(app.net.role,"spectate"); eq(app.net.slot,nil)
        for _=1,5 do assert(host:removeAI()) end
        pump(5); eq(app.net.role,"spectate"); eq(app.net.slot,nil)
    end)
    check("flow: main close retains admitted watch tenure; explicit Leave prevents auto-rejoin",function()
        local id=app.net.ownMemberID
        ui.root:Hide(); pump(3)
        eq(app.net.mode,"client"); assert(host.participants[id]); assert(not app.input.focused)
        ui.root:Show(); app.leaveGame(); pump(10)
        eq(app.net.mode,"idle"); assert(not host.participants[id]); assert(not app.watchEnabled)
        pump(8); eq(app.net.mode,"idle")
        assert(app.openWindow()); pump(20); eq(app.net.mode,"client"); eq(app.net.role,"spectate")
    end)
    check("flow: public Co-op arguments cannot switch or host a live room",function()
        local mode,sid=app.net.mode,app.net.sid
        SlashCmdList.RAMPAGE("host coop"); SlashCmdList.RAMPAGE("solo coop")
        eq(app.net.mode,mode); eq(app.net.sid,sid); eq(app.net.state.mode,"brawl")
    end)
    check("flow: discovery retries are bounded and no keyboard is captured by watching",function()
        local queries=0
        for _,entry in ipairs(sent) do if entry.payload==N.VERSION.."|Q" then queries=queries+1 end end
        assert(queries<=15,"watch loop must not flood discovery")
        assert(not app.input.focused); assert(not app.input:grab())
        app.leaveGame(); pump(3); ui.root:Hide()
    end)
    check("flow: mixed-profile AI metadata is shown by actual crew hover and Settings",function()
        assert(app.soloGame()); assert(Addon.Model.botProfile)
        local profiles={}
        for _=1,5 do assert(app.net:addAI()) end
        local tooltip={}
        local oldSet,oldLine=GameTooltip.SetText,GameTooltip.AddLine
        GameTooltip.SetText=function(_,value) tooltip.title=value end
        GameTooltip.AddLine=function(_,value) tooltip.body=value end
        for slot,p in pairs(app.net.state.players) do if p.bot then
            local profile=Addon.Model.botProfile(p.botID)
            assert(profile and profile.key and profile.label and profile.description)
            profiles[profile.key]=true
            ui.scores[slot].scripts.OnEnter(ui.scores[slot])
            assert(tooltip.body:find(profile.label,1,true) and tooltip.body:find(profile.description,1,true))
            ui.scores[slot].scripts.OnLeave(ui.scores[slot])
        end end
        GameTooltip.SetText,GameTooltip.AddLine=oldSet,oldLine
        local count=0; for _ in pairs(profiles) do count=count+1 end; assert(count>=4)
        ui.setPanel("settings"); assert(ui.settingsRoom:GetText():find("Auto mix",1,true))
        assert(not app.input.focused); ui.setPanel(nil)
        app.leaveGame(); ui.root:Hide()
    end)
end
