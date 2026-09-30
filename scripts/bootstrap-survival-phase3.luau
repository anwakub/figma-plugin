-- Phase 3: authoritative tools, inventory/crafting and modular base building.
-- Installs on top of the current SurvivalWorld without rebuilding terrain.
local RS=game:GetService("ReplicatedStorage")
local SSS=game:GetService("ServerScriptService")
local SP=game:GetService("StarterPlayer")
local StarterPack=game:GetService("StarterPack")
local CHS=game:GetService("ChangeHistoryService")
local world=workspace:FindFirstChild("SurvivalWorld")
assert(world,"Run Phase 2 before Phase 3")
CHS:SetWaypoint("Before Survival Phase 3")

local old=RS:FindFirstChild("SurvivalPhase3"); if old then old:Destroy() end
local root=Instance.new("Folder"); root.Name="SurvivalPhase3"; root.Parent=RS
for _,name in {"Gather","Craft","Build","Upgrade","Notify"} do local r=Instance.new("RemoteEvent"); r.Name=name; r.Parent=root end

local oldServer=SSS:FindFirstChild("SurvivalPhase3Server"); if oldServer then oldServer:Destroy() end
local server=Instance.new("Script"); server.Name="SurvivalPhase3Server"; server.Source=[==[
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Debris=game:GetService("Debris")
local root=RS:WaitForChild("SurvivalPhase3")
local world=workspace:WaitForChild("SurvivalWorld")
local resources=world:WaitForChild("Resources")
local builds=world:FindFirstChild("PlayerBuilds") or Instance.new("Folder",world); builds.Name="PlayerBuilds"
local rate={}
local inventoryNames={"Wood","Stone","Food","Cloth","MetalOre","SulfurOre","Scrap"}
local recipes={
 StoneHatchet={cost={Wood=80,Stone=45},tool="Stone Hatchet",power=2,kind="Wood"},
 StonePickaxe={cost={Wood=65,Stone=75},tool="Stone Pickaxe",power=2,kind="Stone"},
 BuildingHammer={cost={Wood=100},tool="Building Hammer",power=1,kind="Build"},
 StoneSpear={cost={Wood=120,Stone=35},tool="Stone Spear",power=1,kind="Combat"},
 Campfire={cost={Wood=75,Stone=30},unlock=true}, Furnace={cost={Stone=180,Wood=80},unlock=true},
}
local buildSpecs={
 Foundation={cost={Wood=100},size=Vector3.new(12,1,12),offset=Vector3.new(0,.5,0)},
 Wall={cost={Wood=60},size=Vector3.new(12,8,1),offset=Vector3.new(0,4,0)},
 Floor={cost={Wood=75},size=Vector3.new(12,.7,12),offset=Vector3.new(0,8,0)},
 Doorway={cost={Wood=70},size=Vector3.new(12,8,1),offset=Vector3.new(0,4,0)},
 Roof={cost={Wood=85},size=Vector3.new(12,.7,12),offset=Vector3.new(0,8,0)},
 Campfire={cost={Wood=75,Stone=30},size=Vector3.new(4,1,4),offset=Vector3.new(0,.5,0)},
 Furnace={cost={Stone=180,Wood=80},size=Vector3.new(5,6,5),offset=Vector3.new(0,3,0)},
}
local function allowed(p,key,delay) rate[p]=rate[p] or {}; local n=os.clock(); if n-(rate[p][key] or 0)<delay then return false end; rate[p][key]=n; return true end
local function notify(p,t,c) root.Notify:FireClient(p,t,c or Color3.fromRGB(225,211,171)) end
local function afford(p,cost) for k,v in pairs(cost) do if (p:GetAttribute(k) or 0)<v then return false end end return true end
local function charge(p,cost) for k,v in pairs(cost) do p:SetAttribute(k,(p:GetAttribute(k) or 0)-v) end end
local function makeTool(name,power,kind)
 local t=Instance.new("Tool"); t.Name=name; t.RequiresHandle=true; t.CanBeDropped=true; t:SetAttribute("GatherPower",power); t:SetAttribute("ToolKind",kind)
 local h=Instance.new("Part"); h.Name="Handle"; h.Size=Vector3.new(.45,3.4,.45); h.Material=Enum.Material.Wood; h.Color=Color3.fromRGB(92,67,46); h.CanCollide=false; h.Parent=t
 local head=Instance.new("Part"); head.Name="Head"; head.Size=kind=="Combat" and Vector3.new(.35,2.4,.35) or Vector3.new(2.2,.65,.65); head.Material=Enum.Material.Slate; head.Color=Color3.fromRGB(105,108,105); head.CanCollide=false; head.CFrame=h.CFrame*CFrame.new(0,1.45,0); head.Parent=t
 local w=Instance.new("WeldConstraint"); w.Part0=h; w.Part1=head; w.Parent=head
 return t
end
local function giveOwned(p)
 local backpack=p:WaitForChild("Backpack")
 if not backpack:FindFirstChild("Rock") and not (p.Character and p.Character:FindFirstChild("Rock")) then makeTool("Rock",1,"Universal").Parent=backpack end
 for key,s in pairs(recipes) do if s.tool and p:GetAttribute("Has"..key) and not backpack:FindFirstChild(s.tool) and not (p.Character and p.Character:FindFirstChild(s.tool)) then makeTool(s.tool,s.power,s.kind).Parent=backpack end end
end
local function setup(p)
 for _,k in inventoryNames do if p:GetAttribute(k)==nil then p:SetAttribute(k,k=="Food" and 2 or 0) end end
 p.CharacterAdded:Connect(function() task.wait(.5); giveOwned(p) end); if p.Character then task.defer(giveOwned,p) end
end
Players.PlayerAdded:Connect(setup); Players.PlayerRemoving:Connect(function(p) rate[p]=nil end); for _,p in Players:GetPlayers() do task.spawn(setup,p) end

local function resourceFromPart(part)
 local n=part
 while n and n~=resources do if n:IsA("Model") and n:GetAttribute("ResourceType") then return n end; n=n.Parent end
end
local function deplete(node)
 node:SetAttribute("Depleted",true)
 for _,v in node:GetDescendants() do if v:IsA("BasePart") then v:SetAttribute("P3T",v.Transparency); v:SetAttribute("P3C",v.CanCollide); v.Transparency=1; v.CanCollide=false end end
 task.delay(node:GetAttribute("RespawnTime") or 70,function() if not node.Parent then return end; node:SetAttribute("Health",node:GetAttribute("MaxHealth") or 8); node:SetAttribute("Depleted",false); for _,v in node:GetDescendants() do if v:IsA("BasePart") then v.Transparency=v:GetAttribute("P3T") or 0; v.CanCollide=v:GetAttribute("P3C")~=false end end end)
end
root.Gather.OnServerEvent:Connect(function(p,target,toolName)
 if typeof(target)~="Instance" or typeof(toolName)~="string" or not allowed(p,"g",.28) then return end
 local node=resourceFromPart(target); local char=p.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart"); if not node or node:GetAttribute("Depleted") or not hrp or (node:GetPivot().Position-hrp.Position).Magnitude>18 then return end
 local tool=char:FindFirstChild(toolName); if not tool or not tool:IsA("Tool") then return end
 local kind=node:GetAttribute("ResourceType"); local toolKind=tool:GetAttribute("ToolKind"); local power=tonumber(tool:GetAttribute("GatherPower")) or 1
 if toolKind~="Build" and toolKind~="Combat" and ((kind=="Wood" and toolKind~="Wood") or (kind~="Wood" and toolKind~="Stone")) then power=1 end
 local hp=(node:GetAttribute("Health") or node:GetAttribute("MaxHealth") or 6)-power; node:SetAttribute("Health",hp)
 local gain=math.random(4,7)*power; if kind=="Berry" then kind="Food"; gain=1 end; p:SetAttribute(kind,(p:GetAttribute(kind) or 0)+gain); notify(p,"+"..gain.." "..kind)
 if hp<=0 then deplete(node); notify(p,"Resource depleted",Color3.fromRGB(240,190,85)) end
end)
root.Craft.OnServerEvent:Connect(function(p,key)
 if typeof(key)~="string" or not allowed(p,"c",.3) then return end; local spec=recipes[key]; if not spec then return end
 if p:GetAttribute("Has"..key) then notify(p,"Already unlocked") return end
 if not afford(p,spec.cost) then notify(p,"Not enough resources",Color3.fromRGB(235,95,75)) return end
 charge(p,spec.cost); p:SetAttribute("Has"..key,true); giveOwned(p); notify(p,"Crafted "..key,Color3.fromRGB(100,225,130))
end)
root.Build.OnServerEvent:Connect(function(p,key,raw,yaw)
 if typeof(key)~="string" or typeof(raw)~="Vector3" or not allowed(p,"b",.22) then return end; local s=buildSpecs[key]; local char=p.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart")
 if not s or not hrp or (raw-hrp.Position).Magnitude>32 then return end
 if (key=="Campfire" or key=="Furnace") and not p:GetAttribute("Has"..key) then notify(p,"Craft the unlock first",Color3.fromRGB(235,95,75)) return end
 if not afford(p,s.cost) then notify(p,"Not enough resources",Color3.fromRGB(235,95,75)) return end
 local g=3; local base=Vector3.new(math.round(raw.X/g)*g,math.round(raw.Y/g)*g,math.round(raw.Z/g)*g); local pos=base+s.offset
 local cf=CFrame.new(pos)*CFrame.Angles(0,math.rad(math.round((tonumber(yaw) or 0)/90)*90),0)
 local overlap=workspace:GetPartBoundsInBox(cf,s.size-Vector3.new(.25,.25,.25)); for _,v in overlap do if v.CanCollide and not v:IsDescendantOf(char) and not v:IsDescendantOf(builds) then notify(p,"Placement blocked",Color3.fromRGB(235,95,75)) return end end
 charge(p,s.cost); local model=Instance.new("Model"); model.Name=key; model:SetAttribute("BuildPiece",true); model:SetAttribute("OwnerUserId",p.UserId); model:SetAttribute("Grade",1); model:SetAttribute("Health",100); model.Parent=builds
 local part=Instance.new("Part"); part.Name="Main"; part.Anchored=true; part.Size=s.size; part.CFrame=cf; part.Material=Enum.Material.WoodPlanks; part.Color=Color3.fromRGB(111,78,49); part.Parent=model; model.PrimaryPart=part
 if key=="Doorway" then part.Transparency=.18; part.CanCollide=true end
 if key=="Campfire" then part.Shape=Enum.PartType.Cylinder; local f=Instance.new("Fire",part); f.Size=5; f.Heat=8 end
 if key=="Furnace" then part.Shape=Enum.PartType.Cylinder; part.Material=Enum.Material.Brick end
 notify(p,"Built "..key,Color3.fromRGB(100,225,130))
end)
root.Upgrade.OnServerEvent:Connect(function(p,target)
 if typeof(target)~="Instance" or not allowed(p,"u",.4) then return end; local model=target:FindFirstAncestorWhichIsA("Model"); local hrp=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
 if not model or not model:GetAttribute("BuildPiece") or model:GetAttribute("OwnerUserId")~=p.UserId or not hrp or (model:GetPivot().Position-hrp.Position).Magnitude>18 then return end
 local grade=model:GetAttribute("Grade") or 1; if grade>=3 then notify(p,"Already armored") return end
 local cost=grade==1 and {Stone=120} or {MetalOre=90}; if not afford(p,cost) then notify(p,"Need more upgrade materials",Color3.fromRGB(235,95,75)) return end; charge(p,cost); grade+=1; model:SetAttribute("Grade",grade); model:SetAttribute("Health",grade==2 and 500 or 1000)
 for _,v in model:GetDescendants() do if v:IsA("BasePart") then v.Material=grade==2 and Enum.Material.Slate or Enum.Material.Metal; v.Color=grade==2 and Color3.fromRGB(104,104,99) or Color3.fromRGB(91,94,91) end end; notify(p,grade==2 and "Upgraded to stone" or "Upgraded to metal",Color3.fromRGB(100,225,130))
end)
]==]; server.Parent=SSS

local oldClient=SP.StarterPlayerScripts:FindFirstChild("SurvivalPhase3Client"); if oldClient then oldClient:Destroy() end
local client=Instance.new("LocalScript"); client.Name="SurvivalPhase3Client"; client.Source=[==[
local Players=game:GetService("Players"); local UIS=game:GetService("UserInputService"); local RS=game:GetService("ReplicatedStorage")
local p=Players.LocalPlayer; local mouse=p:GetMouse(); local root=RS:WaitForChild("SurvivalPhase3"); local selected="Foundation"; local yaw=0
local gui=Instance.new("ScreenGui"); gui.Name="Phase3HUD"; gui.ResetOnSpawn=false; gui.Parent=p:WaitForChild("PlayerGui")
local panel=Instance.new("Frame"); panel.Size=UDim2.fromOffset(280,430); panel.Position=UDim2.new(1,-300,.5,-215); panel.BackgroundColor3=Color3.fromRGB(20,23,23); panel.BackgroundTransparency=.08; panel.Parent=gui; Instance.new("UICorner",panel).CornerRadius=UDim.new(0,10)
local title=Instance.new("TextLabel"); title.Size=UDim2.new(1,0,0,38); title.BackgroundTransparency=1; title.Text="PHASE 3  •  CRAFT & BUILD"; title.TextColor3=Color3.fromRGB(229,213,175); title.Font=Enum.Font.GothamBold; title.TextSize=15; title.Parent=panel
local list=Instance.new("Frame"); list.Size=UDim2.new(1,-20,1,-54); list.Position=UDim2.fromOffset(10,44); list.BackgroundTransparency=1; list.Parent=panel; local layout=Instance.new("UIListLayout",list); layout.Padding=UDim.new(0,5)
local function button(text,callback) local b=Instance.new("TextButton"); b.Size=UDim2.new(1,0,0,30); b.BackgroundColor3=Color3.fromRGB(51,58,55); b.TextColor3=Color3.fromRGB(235,235,225); b.Font=Enum.Font.GothamMedium; b.TextSize=12; b.Text=text; b.Parent=list; Instance.new("UICorner",b).CornerRadius=UDim.new(0,6); b.MouseButton1Click:Connect(callback) end
for _,v in {{"CRAFT  Stone Hatchet  80W 45S","StoneHatchet"},{"CRAFT  Stone Pickaxe  65W 75S","StonePickaxe"},{"CRAFT  Building Hammer  100W","BuildingHammer"},{"CRAFT  Stone Spear  120W 35S","StoneSpear"},{"UNLOCK  Campfire  75W 30S","Campfire"},{"UNLOCK  Furnace  180S 80W","Furnace"}} do button(v[1],function() root.Craft:FireServer(v[2]) end) end
for _,v in {"Foundation","Wall","Floor","Doorway","Roof","Campfire","Furnace"} do button("BUILD  "..v,function() selected=v end) end
local hint=Instance.new("TextLabel"); hint.Size=UDim2.new(1,0,0,48); hint.BackgroundTransparency=1; hint.TextWrapped=true; hint.Text="Equip Hammer • click to build\nR rotate • U upgrade aimed piece"; hint.TextColor3=Color3.fromRGB(184,190,179); hint.TextSize=11; hint.Font=Enum.Font.Gotham; hint.Parent=list
local toast=Instance.new("TextLabel"); toast.Size=UDim2.fromOffset(430,40); toast.Position=UDim2.new(.5,-215,.82,0); toast.BackgroundColor3=Color3.fromRGB(22,25,24); toast.BackgroundTransparency=.15; toast.TextColor3=Color3.new(1,1,1); toast.Font=Enum.Font.GothamBold; toast.TextSize=14; toast.Visible=false; toast.Parent=gui; Instance.new("UICorner",toast).CornerRadius=UDim.new(0,8)
root.Notify.OnClientEvent:Connect(function(t,c) toast.Text=t; toast.TextColor3=c or Color3.new(1,1,1); toast.Visible=true; task.delay(2,function() toast.Visible=false end) end)
local function hook(tool) if not tool:IsA("Tool") then return end; tool.Activated:Connect(function() if tool:GetAttribute("ToolKind")=="Build" then root.Build:FireServer(selected,mouse.Hit.Position,yaw) else root.Gather:FireServer(mouse.Target,tool.Name) end end) end
local function watch(container) for _,v in container:GetChildren() do hook(v) end; container.ChildAdded:Connect(hook) end
watch(p:WaitForChild("Backpack")); p.CharacterAdded:Connect(function(c) watch(c) end); if p.Character then watch(p.Character) end
UIS.InputBegan:Connect(function(i,g) if g then return end; if i.KeyCode==Enum.KeyCode.R then yaw=(yaw+90)%360 elseif i.KeyCode==Enum.KeyCode.U and mouse.Target then root.Upgrade:FireServer(mouse.Target) elseif i.KeyCode==Enum.KeyCode.B then panel.Visible=not panel.Visible end end)
]==]; client.Parent=SP.StarterPlayerScripts

world:SetAttribute("Phase",3); world:SetAttribute("Phase3Systems","Tools, Inventory, Crafting, Building, Upgrades")
CHS:SetWaypoint("Installed Survival Phase 3")
print("PHASE3_COMPLETE",world:GetAttribute("Phase3Systems"))
