local addonName, addon = ...
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, _, name)
    if name ~= addonName then return end
    RampageDB = RampageDB or {}
    SLASH_RAMPAGE1 = "/rampage"
    SlashCmdList.RAMPAGE = function()
        print("|cffffaa44Rampage|r: <Toast> has just FOUR MORE BOSSES! First playable coming soon.")
    end
    frame:UnregisterEvent("ADDON_LOADED")
end)
