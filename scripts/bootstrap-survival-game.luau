-- Bootstrap a playable multiplayer survival prototype in the current place.
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

assert(not ReplicatedStorage:FindFirstChild("SurvivalGame"), "SurvivalGame already exists")
ChangeHistoryService:SetWaypoint("Before creating survival game")

local function folder(parent, name)
    local value = Instance.new("Folder"); value.Name = name; value.Parent = parent; return value
end
local function source(parent, className, name, code)
    local value = Instance.new(className); value.Name = name; value.Source = code; value.Parent = parent; return value
end

local root = folder(ReplicatedStorage, "SurvivalGame")
local remotes = folder(root, "Remotes")
for _, name in {"Craft", "Build", "Consume", "Notify"} do
    local remote = Instance.new("RemoteEvent"); remote.Name = name; remote.Parent = remotes
end

source(root, "ModuleScript", "Config", [==[
local Config = {}
Config.MaxHunger = 100
Config.MaxThirst = 100
Config.DecayInterval = 5
Config.HungerDecay = 0.55
Config.ThirstDecay = 0.85
Config.StarveDamage = 5
Config.Grid = 4
Config.MaxBuildDistance = 45
Config.Recipes = {
    StoneHatchet = {cost={Wood=30, Stone=20}, title="Stone Hatchet"},
    StonePickaxe = {cost={Wood=25, Stone=30}, title="Stone Pickaxe"},
    Spear = {cost={Wood=45, Stone=15}, title="Stone Spear"},
}
Config.Builds = {
    Foundation = {cost={Wood=60}, size=Vector3.new(12,1,12), color=Color3.fromRGB(112,83,57), material=Enum.Material.WoodPlanks},
    Wall = {cost={Wood=35}, size=Vector3.new(12,8,1), color=Color3.fromRGB(105,78,53), material=Enum.Material.WoodPlanks},
    Campfire = {cost={Wood=25,Stone=15}, size=Vector3.new(4,1,4), color=Color3.fromRGB(75,70,65), material=Enum.Material.Slate},
}
return Config
]==])

source(ServerScriptService, "Script", "SurvivalServer", [==[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local root = ReplicatedStorage:WaitForChild("SurvivalGame")
local Config = require(root:WaitForChild("Config"))
local Remotes = root:WaitForChild("Remotes")
local world = workspace:WaitForChild("SurvivalWorld")
local resources = world:WaitForChild("Resources")
local builds = world:WaitForChild("PlayerBuilds")
local store
pcall(function() store = DataStoreService:GetDataStore("SurvivalPrototypeV1") end)
local rate = {}

local function notify(player, text, color)
    Remotes.Notify:FireClient(player, text, color or Color3.fromRGB(236,215,155))
end
local function allowed(player, key, delay)
    rate[player] = rate[player] or {}
    local now = os.clock()
    if now - (rate[player][key] or 0) < delay then return false end
    rate[player][key] = now; return true
end
local function setDefault(player, name, value)
    if player:GetAttribute(name) == nil then player:SetAttribute(name, value) end
end
local function inventory(player)
    return {Wood=player:GetAttribute("Wood") or 0, Stone=player:GetAttribute("Stone") or 0, Food=player:GetAttribute("Food") or 0, Cloth=player:GetAttribute("Cloth") or 0}
end
local function canAfford(player, cost)
    for name, amount in pairs(cost) do if (player:GetAttribute(name) or 0) < amount then return false end end
    return true
end
local function charge(player, cost)
    for name, amount in pairs(cost) do player:SetAttribute(name, (player:GetAttribute(name) or 0)-amount) end
end
local function save(player)
    local data=inventory(player); data.HasStoneHatchet=player:GetAttribute("HasStoneHatchet"); data.HasStonePickaxe=player:GetAttribute("HasStonePickaxe"); data.HasSpear=player:GetAttribute("HasSpear")
    if store then pcall(function() store:SetAsync("p"..player.UserId, data) end) end
end
local function load(player)
    local data
    if store then pcall(function() data=store:GetAsync("p"..player.UserId) end) end
    data = typeof(data)=="table" and data or {}
    for name, default in pairs({Wood=0,Stone=0,Food=2,Cloth=0}) do player:SetAttribute(name, tonumber(data[name]) or default) end
    for _,name in {"HasStoneHatchet","HasStonePickaxe","HasSpear"} do player:SetAttribute(name, data[name]==true) end
end
local function setupPlayer(player)
    load(player)
    setDefault(player,"Hunger",Config.MaxHunger); setDefault(player,"Thirst",Config.MaxThirst); setDefault(player,"Days",0)
    player.CharacterAdded:Connect(function(character)
        player:SetAttribute("Hunger",Config.MaxHunger); player:SetAttribute("Thirst",Config.MaxThirst)
        character:WaitForChild("Humanoid").Died:Connect(function() notify(player,"You died. Gather supplies and try again.",Color3.fromRGB(235,100,90)) end)
    end)
end
Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player) save(player); rate[player]=nil end)
for _,player in Players:GetPlayers() do task.spawn(setupPlayer,player) end
game:BindToClose(function() for _,player in Players:GetPlayers() do save(player) end end)

local function respawnNode(node)
    node:SetAttribute("Depleted",true)
    for _,part in node:GetDescendants() do if part:IsA("BasePart") then part.Transparency=1; part.CanCollide=false end end
    local prompt=node:FindFirstChildWhichIsA("ProximityPrompt",true); if prompt then prompt.Enabled=false end
    task.delay(node:GetAttribute("RespawnTime") or 35,function()
        if not node.Parent then return end
        node:SetAttribute("Health",node:GetAttribute("MaxHealth")); node:SetAttribute("Depleted",false)
        for _,part in node:GetDescendants() do if part:IsA("BasePart") then part.Transparency=part:GetAttribute("OriginalTransparency") or 0; part.CanCollide=part:GetAttribute("OriginalCanCollide")~=false end end
        if prompt then prompt.Enabled=true end
    end)
end
local function bindNode(node)
    local prompt=node:FindFirstChildWhichIsA("ProximityPrompt",true); if not prompt then return end
    prompt.Triggered:Connect(function(player)
        if node:GetAttribute("Depleted") or not allowed(player,"gather",0.35) then return end
        local character=player.Character; local pivot=node:GetPivot().Position
        if not character or (character:GetPivot().Position-pivot).Magnitude>14 then return end
        local kind=node:GetAttribute("ResourceType"); local power=1
        if kind=="Wood" and player:GetAttribute("HasStoneHatchet") then power=2 end
        if kind=="Stone" and player:GetAttribute("HasStonePickaxe") then power=2 end
        local health=(node:GetAttribute("Health") or 3)-power; node:SetAttribute("Health",health)
        local amount=math.random(3,6)*power
        if kind=="Berry" then player:SetAttribute("Food",(player:GetAttribute("Food") or 0)+1); notify(player,"Collected berries")
        else player:SetAttribute(kind,(player:GetAttribute(kind) or 0)+amount); notify(player,"+"..amount.." "..kind) end
        if health<=0 then respawnNode(node) end
    end)
end
for _,node in resources:GetChildren() do bindNode(node) end

Remotes.Craft.OnServerEvent:Connect(function(player, recipeName)
    if typeof(recipeName)~="string" or not allowed(player,"craft",0.4) then return end
    local recipe=Config.Recipes[recipeName]; if not recipe then return end
    if player:GetAttribute("Has"..recipeName) then notify(player,"Already crafted",Color3.fromRGB(220,175,90)); return end
    if not canAfford(player,recipe.cost) then notify(player,"Not enough resources",Color3.fromRGB(235,100,90)); return end
    charge(player,recipe.cost); player:SetAttribute("Has"..recipeName,true); notify(player,"Crafted "..recipe.title,Color3.fromRGB(110,225,135))
end)
Remotes.Consume.OnServerEvent:Connect(function(player)
    if not allowed(player,"consume",0.5) then return end
    local food=player:GetAttribute("Food") or 0
    if food<1 then notify(player,"No berries to eat",Color3.fromRGB(235,100,90)); return end
    player:SetAttribute("Food",food-1); player:SetAttribute("Hunger",math.min(Config.MaxHunger,(player:GetAttribute("Hunger") or 0)+28)); player:SetAttribute("Thirst",math.min(Config.MaxThirst,(player:GetAttribute("Thirst") or 0)+8)); notify(player,"Ate berries")
end)
Remotes.Build.OnServerEvent:Connect(function(player, buildName, rawPosition, yaw)
    if typeof(buildName)~="string" or typeof(rawPosition)~="Vector3" or not allowed(player,"build",0.35) then return end
    local spec=Config.Builds[buildName]; local character=player.Character
    if not spec or not character or (character:GetPivot().Position-rawPosition).Magnitude>Config.MaxBuildDistance then return end
    if not canAfford(player,spec.cost) then notify(player,"Not enough resources",Color3.fromRGB(235,100,90)); return end
    local g=Config.Grid; local baseY=rawPosition.Y+spec.size.Y/2; local pos=Vector3.new(math.round(rawPosition.X/g)*g,baseY,math.round(rawPosition.Z/g)*g)
    local overlap=workspace:GetPartBoundsInBox(CFrame.new(pos),spec.size-Vector3.new(0.2,0.2,0.2))
    for _,part in overlap do if part.CanCollide and not part:IsDescendantOf(character) then notify(player,"Space is blocked",Color3.fromRGB(235,100,90)); return end end
    charge(player,spec.cost)
    local part=Instance.new("Part"); part.Name=player.Name.."_"..buildName; part.Anchored=true; part.Size=spec.size; part.Material=spec.material; part.Color=spec.color; part.CFrame=CFrame.new(pos)*CFrame.Angles(0,math.rad(tonumber(yaw) or 0),0); part:SetAttribute("OwnerUserId",player.UserId); part.Parent=builds
    if buildName=="Campfire" then
        part.Shape=Enum.PartType.Cylinder; part.CFrame*=CFrame.Angles(0,0,math.pi/2)
        local fire=Instance.new("Fire"); fire.Size=5; fire.Heat=7; fire.Parent=part
        local light=Instance.new("PointLight"); light.Color=Color3.fromRGB(255,145,67); light.Range=18; light.Brightness=2; light.Shadows=true; light.Parent=part
    end
    notify(player,"Built "..buildName,Color3.fromRGB(110,225,135))
end)

task.spawn(function()
    while true do
        task.wait(Config.DecayInterval)
        for _,player in Players:GetPlayers() do
            local hunger=math.max(0,(player:GetAttribute("Hunger") or 0)-Config.HungerDecay)
            local thirst=math.max(0,(player:GetAttribute("Thirst") or 0)-Config.ThirstDecay)
            player:SetAttribute("Hunger",hunger); player:SetAttribute("Thirst",thirst)
            if hunger<=0 or thirst<=0 then local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid"); if humanoid then humanoid:TakeDamage(Config.StarveDamage) end end
        end
    end
end)
task.spawn(function()
    while true do
        task.wait(1); Lighting.ClockTime=(Lighting.ClockTime+0.012)%24
    end
end)
]==])

source(StarterPlayer.StarterPlayerScripts, "LocalScript", "SurvivalClient", [==[
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local player=Players.LocalPlayer
local root=ReplicatedStorage:WaitForChild("SurvivalGame")
local Remotes=root:WaitForChild("Remotes")
local gui=Instance.new("ScreenGui"); gui.Name="SurvivalHUD"; gui.ResetOnSpawn=false; gui.Parent=player:WaitForChild("PlayerGui")
local function round(frame,r) local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r); c.Parent=frame end
local function stroke(frame,color) local s=Instance.new("UIStroke"); s.Color=color; s.Transparency=.45; s.Parent=frame end
local panel=Instance.new("Frame"); panel.Size=UDim2.fromOffset(330,168); panel.Position=UDim2.new(0,18,1,-186); panel.BackgroundColor3=Color3.fromRGB(19,23,25); panel.BackgroundTransparency=.12; panel.Parent=gui; round(panel,12); stroke(panel,Color3.fromRGB(152,130,93))
local title=Instance.new("TextLabel"); title.Size=UDim2.new(1,-24,0,28); title.Position=UDim2.fromOffset(12,8); title.BackgroundTransparency=1; title.Text="WILDERNESS // DAY 1"; title.Font=Enum.Font.GothamBold; title.TextSize=15; title.TextColor3=Color3.fromRGB(228,215,184); title.TextXAlignment=Enum.TextXAlignment.Left; title.Parent=panel
local function bar(name,y,color,attr)
    local label=Instance.new("TextLabel"); label.Size=UDim2.fromOffset(72,20); label.Position=UDim2.fromOffset(12,y); label.BackgroundTransparency=1; label.Font=Enum.Font.GothamMedium; label.TextSize=12; label.TextColor3=Color3.fromRGB(220,224,218); label.TextXAlignment=Enum.TextXAlignment.Left; label.Parent=panel
    local bg=Instance.new("Frame"); bg.Size=UDim2.fromOffset(226,12); bg.Position=UDim2.fromOffset(91,y+4); bg.BackgroundColor3=Color3.fromRGB(47,52,53); bg.Parent=panel; round(bg,6)
    local fill=Instance.new("Frame"); fill.Size=UDim2.fromScale(1,1); fill.BackgroundColor3=color; fill.Parent=bg; round(fill,6)
    local function update() local value=math.floor(player:GetAttribute(attr) or 0); label.Text=name.." "..value; fill.Size=UDim2.fromScale(math.clamp(value/100,0,1),1) end
    player:GetAttributeChangedSignal(attr):Connect(update); update()
end
bar("HEALTH",40,Color3.fromRGB(180,70,61),"Health")
bar("HUNGER",66,Color3.fromRGB(203,154,65),"Hunger")
bar("THIRST",92,Color3.fromRGB(65,151,205),"Thirst")
local resources=Instance.new("TextLabel"); resources.Size=UDim2.new(1,-24,0,38); resources.Position=UDim2.fromOffset(12,121); resources.BackgroundTransparency=1; resources.Font=Enum.Font.GothamMedium; resources.TextSize=13; resources.TextColor3=Color3.fromRGB(215,218,205); resources.TextXAlignment=Enum.TextXAlignment.Left; resources.Parent=panel
local function updateResources() resources.Text=string.format("WOOD %d    STONE %d    FOOD %d    CLOTH %d",player:GetAttribute("Wood") or 0,player:GetAttribute("Stone") or 0,player:GetAttribute("Food") or 0,player:GetAttribute("Cloth") or 0) end
for _,a in {"Wood","Stone","Food","Cloth"} do player:GetAttributeChangedSignal(a):Connect(updateResources) end; updateResources()
local menu=Instance.new("Frame"); menu.Size=UDim2.fromOffset(250,310); menu.Position=UDim2.new(1,-268,.5,-155); menu.BackgroundColor3=Color3.fromRGB(20,24,25); menu.BackgroundTransparency=.08; menu.Parent=gui; round(menu,12); stroke(menu,Color3.fromRGB(152,130,93))
local heading=Instance.new("TextLabel"); heading.Size=UDim2.new(1,-20,0,36); heading.Position=UDim2.fromOffset(10,8); heading.BackgroundTransparency=1; heading.Text="SURVIVAL CRAFTING"; heading.Font=Enum.Font.GothamBold; heading.TextSize=16; heading.TextColor3=Color3.fromRGB(228,215,184); heading.Parent=menu
local list=Instance.new("UIListLayout"); list.Padding=UDim.new(0,8); list.HorizontalAlignment=Enum.HorizontalAlignment.Center; list.Parent=menu
heading.LayoutOrder=0
local function button(text,order,callback)
    local b=Instance.new("TextButton"); b.Size=UDim2.new(1,-20,0,38); b.LayoutOrder=order; b.BackgroundColor3=Color3.fromRGB(52,61,59); b.TextColor3=Color3.fromRGB(239,235,216); b.Font=Enum.Font.GothamMedium; b.TextSize=13; b.Text=text; b.Parent=menu; round(b,7); b.Activated:Connect(callback); return b
end
button("Craft Stone Hatchet  30W 20S",1,function() Remotes.Craft:FireServer("StoneHatchet") end)
button("Craft Stone Pickaxe  25W 30S",2,function() Remotes.Craft:FireServer("StonePickaxe") end)
button("Craft Stone Spear  45W 15S",3,function() Remotes.Craft:FireServer("Spear") end)
button("Eat Berries",4,function() Remotes.Consume:FireServer() end)
local buildMode=nil; local yaw=0
button("Place Foundation  60W",5,function() buildMode="Foundation" end)
button("Place Wall  35W",6,function() buildMode="Wall" end)
button("Place Campfire  25W 15S",7,function() buildMode="Campfire" end)
local hint=Instance.new("TextLabel"); hint.Size=UDim2.new(0,520,0,32); hint.Position=UDim2.new(.5,-260,1,-44); hint.BackgroundColor3=Color3.fromRGB(17,21,22); hint.BackgroundTransparency=.15; hint.Text="Gather with prompts • Build: choose item, click ground • R rotates • X cancels"; hint.TextColor3=Color3.fromRGB(232,224,199); hint.Font=Enum.Font.GothamMedium; hint.TextSize=13; hint.Parent=gui; round(hint,8)
local toast=Instance.new("TextLabel"); toast.Size=UDim2.fromOffset(360,44); toast.Position=UDim2.new(.5,-180,.15,0); toast.BackgroundColor3=Color3.fromRGB(22,27,27); toast.BackgroundTransparency=.08; toast.Visible=false; toast.TextColor3=Color3.new(1,1,1); toast.Font=Enum.Font.GothamBold; toast.TextSize=14; toast.Parent=gui; round(toast,9)
Remotes.Notify.OnClientEvent:Connect(function(text,color) toast.Text=text; toast.TextColor3=color; toast.Visible=true; task.delay(2.5,function() if toast.Text==text then toast.Visible=false end end) end)
local mouse=player:GetMouse()
mouse.Button1Down:Connect(function() if buildMode and mouse.Hit then Remotes.Build:FireServer(buildMode,mouse.Hit.Position,yaw); buildMode=nil end end)
UserInputService.InputBegan:Connect(function(input,processed) if processed then return end; if input.KeyCode==Enum.KeyCode.R and buildMode then yaw=(yaw+90)%360 elseif input.KeyCode==Enum.KeyCode.X then buildMode=nil end end)
task.spawn(function() while true do task.wait(.2); local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid"); player:SetAttribute("Health",humanoid and humanoid.Health or 0); title.Text="WILDERNESS // "..string.format("%02d:%02d",math.floor(game.Lighting.ClockTime),math.floor((game.Lighting.ClockTime%1)*60)) end end)
]==])

-- Build a contained resource field east of the villa.
local old = Workspace:FindFirstChild("SurvivalWorld")
if old then old:Destroy() end
local world = folder(Workspace, "SurvivalWorld")
local resources = folder(world, "Resources")
folder(world, "PlayerBuilds")
local mapCenter = Vector3.new(390, 0, 40)

local ground = Instance.new("Part")
ground.Name="SurvivalGround"; ground.Anchored=true; ground.Size=Vector3.new(260,2,260); ground.Position=mapCenter+Vector3.new(0,-1,0); ground.Material=Enum.Material.Ground; ground.Color=Color3.fromRGB(75,89,61); ground.Parent=world
local spawn=Instance.new("SpawnLocation"); spawn.Name="SurvivalSpawn"; spawn.Anchored=true; spawn.Neutral=true; spawn.Size=Vector3.new(8,1,8); spawn.Position=mapCenter+Vector3.new(0,1,0); spawn.Material=Enum.Material.Slate; spawn.Color=Color3.fromRGB(87,92,88); spawn.Parent=world

local function prompt(parent, action, object)
    local p=Instance.new("ProximityPrompt"); p.ActionText=action; p.ObjectText=object; p.HoldDuration=.55; p.MaxActivationDistance=11; p.RequiresLineOfSight=false; p.Parent=parent
end
local function tree(index,pos)
    local model=Instance.new("Model"); model.Name="Tree_"..index; model:SetAttribute("ResourceType","Wood"); model:SetAttribute("Health",6); model:SetAttribute("MaxHealth",6); model:SetAttribute("RespawnTime",40); model.Parent=resources
    local trunk=Instance.new("Part"); trunk.Name="Trunk"; trunk.Anchored=true; trunk.Size=Vector3.new(3,18,3); trunk.Position=pos+Vector3.new(0,9,0); trunk.Material=Enum.Material.Wood; trunk.Color=Color3.fromRGB(92,67,43); trunk.Parent=model; trunk:SetAttribute("OriginalTransparency",0); trunk:SetAttribute("OriginalCanCollide",true); prompt(trunk,"Chop","Pine tree")
    for tier=1,4 do local leaves=Instance.new("Part"); leaves.Name="Needles"; leaves.Anchored=true; leaves.CanCollide=false; leaves.Shape=Enum.PartType.Ball; leaves.Size=Vector3.new(14-tier*1.8,7,14-tier*1.8); leaves.Position=pos+Vector3.new(0,10+tier*3.1,0); leaves.Material=Enum.Material.Grass; leaves.Color=Color3.fromRGB(39,76+tier*3,49); leaves.Parent=model; leaves:SetAttribute("OriginalTransparency",0); leaves:SetAttribute("OriginalCanCollide",false) end
end
local function rock(index,pos)
    local model=Instance.new("Model"); model.Name="Rock_"..index; model:SetAttribute("ResourceType","Stone"); model:SetAttribute("Health",7); model:SetAttribute("MaxHealth",7); model:SetAttribute("RespawnTime",45); model.Parent=resources
    local ore=Instance.new("Part"); ore.Name="Stone"; ore.Anchored=true; ore.Size=Vector3.new(7,5,6); ore.Position=pos+Vector3.new(0,2.5,0); ore.Orientation=Vector3.new(12,index*31,8); ore.Material=Enum.Material.Slate; ore.Color=Color3.fromRGB(92,96,93); ore.Parent=model; ore:SetAttribute("OriginalTransparency",0); ore:SetAttribute("OriginalCanCollide",true); prompt(ore,"Mine","Stone node")
end
local function berry(index,pos)
    local model=Instance.new("Model"); model.Name="BerryBush_"..index; model:SetAttribute("ResourceType","Berry"); model:SetAttribute("Health",2); model:SetAttribute("MaxHealth",2); model:SetAttribute("RespawnTime",25); model.Parent=resources
    local bush=Instance.new("Part"); bush.Name="Bush"; bush.Anchored=true; bush.CanCollide=false; bush.Shape=Enum.PartType.Ball; bush.Size=Vector3.new(6,4,6); bush.Position=pos+Vector3.new(0,2,0); bush.Material=Enum.Material.Grass; bush.Color=Color3.fromRGB(48,91,47); bush.Parent=model; bush:SetAttribute("OriginalTransparency",0); bush:SetAttribute("OriginalCanCollide",false); prompt(bush,"Gather","Berry bush")
    for n=1,7 do local fruit=Instance.new("Part"); fruit.Name="Berry"; fruit.Anchored=true; fruit.CanCollide=false; fruit.Shape=Enum.PartType.Ball; fruit.Size=Vector3.one*.45; fruit.Position=bush.Position+Vector3.new(math.sin(n*2)*2,(n%3)-.2,math.cos(n*2)*2); fruit.Material=Enum.Material.Neon; fruit.Color=Color3.fromRGB(160,35,47); fruit.Parent=model; fruit:SetAttribute("OriginalTransparency",0); fruit:SetAttribute("OriginalCanCollide",false) end
end
local rng=Random.new(2468)
for i=1,34 do local angle=rng:NextNumber(0,math.pi*2); local radius=rng:NextNumber(28,118); tree(i,mapCenter+Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius)) end
for i=1,20 do local angle=rng:NextNumber(0,math.pi*2); local radius=rng:NextNumber(24,115); rock(i,mapCenter+Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius)) end
for i=1,16 do local angle=rng:NextNumber(0,math.pi*2); local radius=rng:NextNumber(20,110); berry(i,mapCenter+Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius)) end

game:GetService("Lighting").ClockTime=8.5
game:GetService("Lighting").Brightness=2
game:GetService("Selection"):Set({world})
ChangeHistoryService:SetWaypoint("Survival prototype created")
print("SURVIVAL_BOOTSTRAP_COMPLETE", #resources:GetChildren(), "resource nodes")
