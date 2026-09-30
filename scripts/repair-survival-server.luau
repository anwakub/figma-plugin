local ServerScriptService = game:GetService("ServerScriptService")
local scriptObject = assert(ServerScriptService:FindFirstChild("SurvivalServer"), "SurvivalServer missing")
local code = scriptObject.Source
code = code:gsub('local%s+store%s*=%s*DataStoreService:GetDataStore%("SurvivalPrototypeV1"%)', 'local store\nif game.PlaceId ~= 0 then pcall(function() store = DataStoreService:GetDataStore("SurvivalPrototypeV1") end) end')
code = code:gsub('local store\npcall%(function%(%) store = DataStoreService:GetDataStore%("SurvivalPrototypeV1"%) end%)', 'local store\nif game.PlaceId ~= 0 then pcall(function() store = DataStoreService:GetDataStore("SurvivalPrototypeV1") end) end')
code = code:gsub('pcall%(function%(%) store:SetAsync%("p"%.%.player.UserId, data%) end%)', 'if store then pcall(function() store:SetAsync("p"..player.UserId, data) end) end')
code = code:gsub('pcall%(function%(%) data=store:GetAsync%("p"%.%.player.UserId%) end%)', 'if store then pcall(function() data=store:GetAsync("p"..player.UserId) end) end')
scriptObject.Source = code

local phase2 = assert(ServerScriptService:FindFirstChild("SurvivalPhase2Server"), "SurvivalPhase2Server missing")
local phaseCode = phase2.Source
phaseCode = phaseCode:gsub(
    '{MetalOre=0,SulfurOre=0,Scrap=0,Temperature=20,Radiation=0}',
    '{Wood=0,Stone=0,Food=2,Cloth=0,Hunger=100,Thirst=100,Days=0,MetalOre=0,SulfurOre=0,Scrap=0,Temperature=20,Radiation=0}'
)
phase2.Source = phaseCode
game:GetService("ChangeHistoryService"):SetWaypoint("Repair survival server DataStore fallback")
print("SURVIVAL_SERVER_REPAIRED")
