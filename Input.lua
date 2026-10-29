-- Local, opt-in keyboard input on an ordinary (non-secure) frame. No bindings.
-- API signatures checked against Blizzard SimpleFrameAPIDocumentation (Classic):
-- EnableKeyboard(bool), SetPropagateKeyboardInput(bool; HasRestrictions=true).
-- No propagation mutation during combat; hiding the NON-secure capture frame
-- returns routing to WoW immediately. Reinitialize propagation out of combat.
-- Native event ordering,
-- focus/alt-tab behavior and combat/taint still require the real 20506 client.
local _, addon = ...
local Input = {}
addon.Input = Input
local keys = { W = "U", UP = "U", A = "L", LEFT = "L", S = "D", DOWN = "D",
    D = "R", RIGHT = "R", SPACE = "P" }
local function editing()
    local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if focus then return true end -- Never compete with an edit box, including non-chat search.
    local chat = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    return chat and chat.HasFocus and chat:HasFocus() or false
end
function Input.create(app, root)
    local self = { app = app, root = root, held = {}, serial = 0, focused = false, nextAction = 0,
        reason = "Click PLAY to capture keys" }
    local frame = CreateFrame("Frame", nil, root)
    self.frame = frame
    frame:SetSize(1, 1); frame:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
    self.supported = type(frame.EnableKeyboard) == "function" and type(frame.SetPropagateKeyboardInput) == "function"
    function self:canPlay()
        local net, s = app.net, app.net.state
        local p=s and net.slot and s.players[net.slot]
        return root:IsShown() and not net.combat and not (InCombatLockdown and InCombatLockdown())
            and net.mode ~= "idle" and net.mode ~= "joining" and net.role ~= "spectate" and net.requestedRole ~= "spectate"
            and p ~= nil and not p.protected and (p.ko or 0)<=0 and (p.hp or 100)>0 and s.phase == "play" and not s.paused
    end
    function self:release(reason)
        self.focused, self.held, self.nextAction = false, {}, 0
        self.reason = reason or "Keys released — click PLAY"
        frame:Hide()
        if self.supported and not (InCombatLockdown and InCombatLockdown()) then
            frame:SetPropagateKeyboardInput(true)
        end
    end
    function self:shown()
        -- Reopening clears the stale hidden-window reason, never auto-captures.
        self:release(app.net.role=="spectate" and "Watching only — no captured keys" or "Click PLAY to capture keys")
    end
    function self:grab()
        if not self.supported then self.reason = "Keyboard unavailable — use mouse controls"; return false end
        if not self:canPlay() or editing() or (IsWindowFocused and not IsWindowFocused()) then return false end
        self.focused, self.held, self.nextAction = true, {}, 0
        self.reason = "KEYS LIVE • WASD / arrows + SPACE • Esc releases"
        frame:SetPropagateKeyboardInput(true); frame:Show()
        return true
    end
    function self:action(action)
        if not self:canPlay() then return false end
        return app.net:action(action)
    end
    function self:update(elapsed)
        if not self.focused then return end
        if not self:canPlay() then self:release("Keys released — game inactive"); return end
        if editing() then self:release("Typing — keys released"); return end
        if (IsWindowFocused and not IsWindowFocused()) or (IsAltKeyDown and IsAltKeyDown())
            or (IsControlKeyDown and IsControlKeyDown()) or (IsMetaKeyDown and IsMetaKeyDown()) then
            self:release("Focus changed — keys released"); return
        end
        -- Key-up can be lost when the client loses focus. Classic's KeyCommand
        -- uses IsKeyDown; reconcile physical state without inventing focus APIs.
        for key in pairs(self.held) do
            if IsKeyDown and not IsKeyDown(key) then
                self:release("Key state changed — click PLAY"); return
            end
        end
        -- A long stalled frame must not replay accumulated inputs.
        if elapsed and elapsed > 0.75 then self:release("Window interrupted — click PLAY"); return end
        local selected, order
        for key, n in pairs(self.held) do if not order or n > order then selected, order = key, n end end
        if selected and app.now() >= self.nextAction then
            self.nextAction = app.now() + 0.205
            self:action(keys[selected])
        end
    end
    if self.supported then
        frame:EnableKeyboard(true); frame:SetPropagateKeyboardInput(true)
        frame:SetScript("OnKeyDown", function(_, key)
            if not self.focused or not self:canPlay() or editing() then self:release("Keys released"); return end
            if key == "ESCAPE" then self:release("Esc — keys released"); return end
            if not keys[key] or (IsAltKeyDown and IsAltKeyDown()) or (IsControlKeyDown and IsControlKeyDown())
                or (IsMetaKeyDown and IsMetaKeyDown()) then
                -- Unknown keys, Enter, slash and modifier combinations pass through to WoW.
                self:release("WoW shortcut — click PLAY to recapture"); return
            end
            frame:SetPropagateKeyboardInput(false)
            if not self.held[key] then self.serial = self.serial + 1; self.held[key] = self.serial end
            self:update(0)
        end)
        frame:SetScript("OnKeyUp", function(_, key)
            if InCombatLockdown and InCombatLockdown() then self:release("Combat — keys released"); return end
            local consumed = self.focused and self.held[key] ~= nil and self:canPlay() and not editing()
            self.held[key] = nil
            frame:SetPropagateKeyboardInput(not consumed)
            if self.focused and not self:canPlay() then self:release() end
        end)
    end
    frame:Hide()
    return self
end
