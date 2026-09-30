-- Phase 2: a larger Rust-inspired procedural survival island.
-- Keeps Phase 1 in ServerStorage and creates a new live SurvivalWorld.
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Lighting = game:GetService("Lighting")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

ChangeHistoryService:SetWaypoint("Before Survival Phase 2")
-- Make the Phase 1 core safe in an unpublished place where DataStore access can fail.
local coreServer = ServerScriptService:FindFirstChild("SurvivalServer")
if coreServer then
    coreServer.Source = coreServer.Source:gsub(
        'local%s+store%s*=%s*DataStoreService:GetDataStore%("SurvivalPrototypeV1"%)',
        'local store\nif game.PlaceId ~= 0 then pcall(function() store = DataStoreService:GetDataStore("SurvivalPrototypeV1") end) end'
    )
end
local old = Workspace:FindFirstChild("SurvivalWorld")
if old then
    old.Name = "SurvivalWorld_Phase1_Archive"
    old.Parent = ServerStorage
end
local previous = Workspace:FindFirstChild("SurvivalWorld_Phase2")
if previous then previous.Name = "SurvivalWorld_Phase2_Old"; previous.Parent = ServerStorage end

local function folder(parent, name)
    local x=Instance.new("Folder"); x.Name=name; x.Parent=parent; return x
end
local function part(parent,name,size,cf,color,material)
    local p=Instance.new("Part"); p.Name=name; p.Anchored=true; p.Size=size; p.CFrame=cf
    p.Color=color; p.Material=material or Enum.Material.SmoothPlastic; p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
    p.Parent=parent; return p
end
local function cylinder(parent,name,size,cf,color,material)
    local p=part(parent,name,size,cf*CFrame.Angles(0,0,math.pi/2),color,material); p.Shape=Enum.PartType.Cylinder; return p
end
local function ball(parent,name,size,cf,color,material)
    local p=part(parent,name,size,cf,color,material); p.Shape=Enum.PartType.Ball; return p
end
local function prompt(root,action,object)
    local pr=Instance.new("ProximityPrompt"); pr.ActionText=action; pr.ObjectText=object; pr.HoldDuration=.35; pr.MaxActivationDistance=11; pr.RequiresLineOfSight=false; pr.Parent=root
end
local function modelResource(parent,name,kind,health,respawn)
    local m=Instance.new("Model"); m.Name=name; m:SetAttribute("ResourceType",kind); m:SetAttribute("Health",health); m:SetAttribute("MaxHealth",health); m:SetAttribute("RespawnTime",respawn); m.Parent=parent; return m
end

-- A cylinder between two points.  Building trunks and branches from short,
-- tapered segments avoids the straight "telephone pole" silhouette.
local function limb(parent,name,a,b,width,color,material)
    local delta=b-a; local mid=(a+b)*.5
    local p=part(parent,name,Vector3.new(delta.Magnitude,width,width),CFrame.lookAt(mid,b)*CFrame.Angles(0,math.pi/2,0),color,material)
    p.Shape=Enum.PartType.Cylinder; return p
end

local world=folder(Workspace,"SurvivalWorld"); world:SetAttribute("Phase",2); world:SetAttribute("MapSize",3072); world:SetAttribute("Style","Rust-inspired seamless procedural island")
local terrain=Workspace.Terrain
local center=Vector3.new(3600,0,0); local half=1536
-- Phase maps own their terrain. Clear the old voxel terrain so the new island
-- is one continuous landmass rather than sitting on the previous tiled map.
terrain:Clear()
terrain:FillBlock(CFrame.new(center.X,-30,center.Z),Vector3.new(3800,52,3800),Enum.Material.Water)

local function biomeAt(x,z)
    local nx=(x-center.X)/half; local nz=(z-center.Z)/half
    local moisture=math.noise(x/720,z/720,91)+math.noise(x/240,z/240,19)*.28
    if nz < -.38 or (nz < -.12 and nx < -.52) then return "Snow" end
    if nx > .22 and nz > -.28 and moisture < .38 then return "Desert" end
    return "Temperate"
end
local function heightAt(x,z)
    local nx=(x-center.X)/half; local nz=(z-center.Z)/half
    local radial=math.sqrt((nx*.94)^2+(nz*1.08)^2)
    local continent=1-radial
    local macro=math.noise(x/760,z/760,13)*30
    local detail=math.noise(x/230,z/230,31)*15+math.noise(x/88,z/88,57)*4
    -- Two broad mountain chains with ridged noise, leaving flatter buildable valleys.
    local ridgeNoise=1-math.abs(math.noise(x/470,z/470,77))
    local ridgeA=math.max(0,1-math.abs((nx*.72+nz)-.03)*2.7)
    local ridgeB=math.max(0,1-math.abs((nx-nz*.42)+.34)*3.8)
    local mountain=(ridgeA^2*ridgeNoise*105+ridgeB^3*(.55+ridgeNoise*.45)*70)*math.clamp(continent*2.3,0,1)
    -- A hard western coastal shelf produces Rust-like sea cliffs.
    local cliffMask=math.clamp((-.34-nx)*5,0,1)*math.clamp((nz+.48)*2.2,0,1)*math.clamp((.7-nz)*2.2,0,1)
    local cliff=cliffMask*(34+math.max(0,math.noise(x/180,z/180,8))*24)
    local h=14+continent*34+macro+detail+mountain+cliff
    if radial>.78 then h=h-((radial-.78)/.22)^1.65*92 end
    return math.clamp(h,-18,168)
end
local function terrainMaterial(x,y,z)
    local b=biomeAt(x,z)
    local slope=math.max(math.abs(heightAt(x+12,z)-heightAt(x-12,z)),math.abs(heightAt(x,z+12)-heightAt(x,z-12)))
    if slope>15 then return Enum.Material.Rock end
    if y>76 and b=="Snow" then return Enum.Material.Snow end
    if b=="Desert" then return y<20 and Enum.Material.Sand or Enum.Material.Sandstone end
    if y<8 then return Enum.Material.Sand end
    if y>105 then return Enum.Material.Rock end
    return Enum.Material.Grass
end

-- Write smooth voxels in chunks. Occupancy fades across the surface voxel,
-- eliminating the visible square slabs produced by thousands of FillBlocks.
local resolution=4; local chunkSize=192; local minY=-56; local maxY=176
for x0=center.X-half,center.X+half-resolution,chunkSize do
    for z0=center.Z-half,center.Z+half-resolution,chunkSize do
        local x1=math.min(x0+chunkSize,center.X+half); local z1=math.min(z0+chunkSize,center.Z+half)
        local region=Region3.new(Vector3.new(x0,minY,z0),Vector3.new(x1,maxY,z1)):ExpandToGrid(resolution)
        local size=region.Size/resolution; local materials={}; local occupancy={}
        local corner=region.CFrame.Position-region.Size*.5
        for xi=1,size.X do
            materials[xi]={}; occupancy[xi]={}
            local wx=corner.X+(xi-.5)*resolution
            for yi=1,size.Y do
                materials[xi][yi]={}; occupancy[xi][yi]={}
                local wy=corner.Y+(yi-.5)*resolution
                for zi=1,size.Z do
                    local wz=corner.Z+(zi-.5)*resolution; local surface=heightAt(wx,wz)
                    local fill=math.clamp((surface-wy)/resolution+.5,0,1)
                    materials[xi][yi][zi]=terrainMaterial(wx,surface,wz)
                    occupancy[xi][yi][zi]=fill
                end
            end
        end
        terrain:WriteVoxels(region,resolution,materials,occupancy)
    end
end

local resources=folder(world,"Resources"); local decor=folder(world,"NaturalDecor"); local roads=folder(world,"RoadNetwork"); local monuments=folder(world,"Monuments"); folder(world,"PlayerBuilds")
local rng=Random.new(82491)
local function ground(x,z) return heightAt(x,z)+2 end

local function pine(index,pos,dead)
    local m=modelResource(resources,"Pine_"..index,"Wood",8,85); local s=rng:NextNumber(.9,1.35)
    local bark=dead and Color3.fromRGB(91,72,55) or Color3.fromRGB(76,57,42)
    local height=rng:NextNumber(32,46)*s; local lean=Vector3.new(rng:NextNumber(-1.2,1.2),0,rng:NextNumber(-1.2,1.2))*s
    local joints={pos}
    for section=1,5 do
        local t=section/5; local wobble=Vector3.new(math.noise(index,section)*1.2,0,math.noise(section,index)*1.2)*s
        joints[section+1]=pos+Vector3.new(lean.X*t,height*t,lean.Z*t)+wobble
        local seg=limb(m,section==1 and "Trunk" or "TrunkSegment",joints[section],joints[section+1],(3.5-2.15*t)*s,bark,Enum.Material.Wood)
        if section==1 then m.PrimaryPart=seg; prompt(seg,"Chop",dead and "Dry Pine" or "Pine Tree") end
    end
    -- Dense Christmas-tree silhouette: broad skirt, narrowing middle and pointed crown.
    local crownStart=dead and 2 or 1
    local tiers=dead and 7 or 9
    for tier=crownStart,tiers do
        local t=.12+tier*(.76/tiers); local origin=pos+Vector3.new(lean.X*t,height*t,lean.Z*t)
        local radius=(1-t)^.72*13.5*s+1.1*s
        local count=dead and rng:NextInteger(3,4) or rng:NextInteger(6,8)
        for j=1,count do
            local angle=(j/count)*math.pi*2+tier*1.37+rng:NextNumber(-.34,.34)
            local length=radius*rng:NextNumber(.82,1.08)
            local tip=origin+Vector3.new(math.cos(angle)*length,-length*rng:NextNumber(.10,.20),math.sin(angle)*length)
            limb(m,"Branch",origin,tip,math.max(.28,.72-tier*.045)*s,bark,Enum.Material.Wood)
            if not dead or rng:NextNumber()<.32 then
                for tuft=1,(dead and 1 or 4) do
                    local u=.30+tuft*.16; local p=origin:Lerp(tip,u)+Vector3.new(0,rng:NextNumber(-.35,.45),0)
                    local tuftLength=math.max(2.2,length*(.33-tuft*.025))
                    local needles=ball(m,"NeedleCluster",Vector3.new(tuftLength,2.25*s,3.35*s),CFrame.new(p)*CFrame.Angles(rng:NextNumber(-.12,.12),-angle,rng:NextNumber(-.10,.10)),dead and Color3.fromRGB(91,77,56) or Color3.fromRGB(29+rng:NextInteger(0,12),72+rng:NextInteger(0,18),43+rng:NextInteger(0,8)),Enum.Material.Grass)
                    needles.CanCollide=false
                end
            end
        end
    end
    if not dead then
        -- Compact upper crown closes the gaps and gives every pine a clear tip.
        for i=1,4 do
            local y=height*(.78+i*.052); local crownRadius=(5-i)*1.25*s
            for j=1,5 do
                local a=j*math.pi*2/5+i*.61
                local needles=ball(m,"CrownNeedles",Vector3.new(crownRadius*1.15,2.3*s,crownRadius),CFrame.new(pos+Vector3.new(lean.X*y/height+math.cos(a)*crownRadius*.38,y,lean.Z*y/height+math.sin(a)*crownRadius*.38))*CFrame.Angles(0,a,0),Color3.fromRGB(31+rng:NextInteger(0,10),76+rng:NextInteger(0,14),45),Enum.Material.Grass)
                needles.CanCollide=false
            end
        end
    end
    -- Broken dry crown and exposed branch stubs make dead variants recognizable.
    if dead then
        for j=1,5 do local y=height*(.25+j*.11); local a=j*2.19; local o=pos+Vector3.new(lean.X*y/height,y,lean.Z*y/height); limb(m,"BrokenStub",o,o+Vector3.new(math.cos(a)*rng:NextNumber(2,4)*s,rng:NextNumber(-1,.5)*s,math.sin(a)*rng:NextNumber(2,4)*s),.42*s,bark,Enum.Material.Wood) end
    end
    return m
end
local function deciduous(index,pos)
    local m=modelResource(resources,"Beech_"..index,"Wood",6,75); local s=rng:NextNumber(.85,1.25)
    local trunk=cylinder(m,"Trunk",Vector3.new(3.8*s,18*s,3.8*s),CFrame.new(pos+Vector3.new(0,9*s,0)),Color3.fromRGB(91,67,45),Enum.Material.Wood); m.PrimaryPart=trunk; prompt(trunk,"Chop","Beech Tree")
    for i=1,5 do local a=i*2.31; cylinder(m,"Branch",Vector3.new(1.2*s,10*s,1.2*s),CFrame.new(pos+Vector3.new(math.cos(a)*2.1*s,16*s,math.sin(a)*2.1*s))*CFrame.Angles(0,-a,math.rad(48)),Color3.fromRGB(88,64,43),Enum.Material.Wood) end
    for i=1,8 do local a=i*2.17; local r=(i%3)*2.5*s; local leaf=ball(m,"Canopy",Vector3.new(rng:NextNumber(8,13)*s,rng:NextNumber(7,11)*s,rng:NextNumber(8,13)*s),CFrame.new(pos+Vector3.new(math.cos(a)*r,18*s+(i%2)*4*s,math.sin(a)*r)),Color3.fromRGB(55+rng:NextInteger(0,20),98+rng:NextInteger(0,24),52),Enum.Material.Grass); leaf.CanCollide=false end
end
local oreColors={Stone=Color3.fromRGB(101,105,103),MetalOre=Color3.fromRGB(79,94,99),SulfurOre=Color3.fromRGB(154,137,58)}
local function oreNode(index,pos,kind)
    local m=modelResource(resources,kind.."Node_"..index,kind,kind=="Stone" and 8 or 9,80)
    local yaw=rng:NextNumber(0,math.pi*2); local baseColor=oreColors[kind]
    local core=ball(m,"Core",Vector3.new(9.5,5.3,8.2),CFrame.new(pos+Vector3.new(0,2.15,0))*CFrame.Angles(rng:NextNumber(-.18,.18),yaw,rng:NextNumber(-.16,.16)),baseColor,Enum.Material.Slate)
    m.PrimaryPart=core; prompt(core,"Mine",kind:gsub("Ore"," Ore"))
    -- Overlapping flattened masses give the rounded, fractured Rust node profile.
    for j=1,8 do
        local a=yaw+j*2.399; local radius=rng:NextNumber(2.0,4.1)
        ball(m,"RockLobe",Vector3.new(rng:NextNumber(3.2,5.8),rng:NextNumber(2.2,4.3),rng:NextNumber(3.0,5.4)),CFrame.new(pos+Vector3.new(math.cos(a)*radius,rng:NextNumber(1.25,3.75),math.sin(a)*radius*.78))*CFrame.Angles(rng:NextNumber(-.45,.45),a,rng:NextNumber(-.35,.35)),baseColor:Lerp(Color3.new(1,1,1),rng:NextNumber(0,.11)),Enum.Material.Rock)
    end
    local veinColor=kind=="SulfurOre" and Color3.fromRGB(192,164,49) or kind=="MetalOre" and Color3.fromRGB(91,112,119) or Color3.fromRGB(135,139,134)
    for j=1,4 do
        local a=yaw+j*1.71; local vein=ball(m,"MineralVein",Vector3.new(rng:NextNumber(.35,.7),rng:NextNumber(1.4,2.7),rng:NextNumber(2.2,3.6)),CFrame.new(pos+Vector3.new(math.cos(a)*4.35,rng:NextNumber(2,4),math.sin(a)*3.5))*CFrame.Angles(rng:NextNumber(-.8,.8),a,rng:NextNumber(-.8,.8)),veinColor,Enum.Material.Slate); vein.CanCollide=false
    end
    local hot=ball(m,"Hotspot",Vector3.new(.58,.58,.18),CFrame.new(pos+Vector3.new(math.cos(yaw)*4.7,3.2,math.sin(yaw)*3.8)),Color3.fromRGB(255,196,72),Enum.Material.Neon); hot.CanCollide=false
end
local function hemp(index,pos)
    local m=modelResource(resources,"Hemp_"..index,"Cloth",2,35); local stem=cylinder(m,"Stem",Vector3.new(.35,3.8,.35),CFrame.new(pos+Vector3.new(0,1.9,0)),Color3.fromRGB(66,102,47),Enum.Material.Grass); stem.CanCollide=false; m.PrimaryPart=stem; prompt(stem,"Harvest","Hemp")
    for j=1,7 do local a=j*.9; local leaf=part(m,"Leaf",Vector3.new(.18,2.6,.7),CFrame.new(pos+Vector3.new(math.cos(a)*.65,2.2+((j%2)*.7),math.sin(a)*.65))*CFrame.Angles(0,-a,math.rad(25)),Color3.fromRGB(68,126,55),Enum.Material.Grass); leaf.CanCollide=false end
end

-- Biome-aware population: dense temperate forest, sparse desert, young/dead snow pines.
for i=1,420 do
    local x=center.X+rng:NextNumber(-1370,1370); local z=center.Z+rng:NextNumber(-1370,1370); local b=biomeAt(x,z); local pos=Vector3.new(x,ground(x,z),z)
    if heightAt(x,z)>1 then
        if b=="Temperate" then if i%3==0 then deciduous(i,pos) else pine(i,pos,false) end
        elseif b=="Snow" and i%2==0 then pine(i,pos,i%5==0)
        elseif b=="Desert" and i%9==0 then pine(i,pos,true) end
    end
end
for i=1,180 do
    local x=center.X+rng:NextNumber(-1400,1400); local z=center.Z+rng:NextNumber(-1400,1400)
    if heightAt(x,z)>2 then local b=biomeAt(x,z); local kind=(i%7==0 and "SulfurOre") or (i%4==0 and "MetalOre") or "Stone"; if b=="Snow" and i%5==0 then kind="MetalOre" end; oreNode(i,Vector3.new(x,ground(x,z),z),kind) end
end
for i=1,110 do local x=center.X+rng:NextNumber(-1250,500); local z=center.Z+rng:NextNumber(-1180,1250); if biomeAt(x,z)=="Temperate" then hemp(i,Vector3.new(x,ground(x,z),z)) end end

-- Ring road plus monument spurs, matching Rust's readable road hierarchy.
local roadPoints={Vector3.new(-1120,0,-710),Vector3.new(-310,0,-1180),Vector3.new(760,0,-900),Vector3.new(1190,0,-120),Vector3.new(850,0,850),Vector3.new(-180,0,1140),Vector3.new(-1090,0,650)}
local function roadSegment(a,b,width)
    a=a+center; b=b+center
    local flatLength=(Vector3.new(b.X,0,b.Z)-Vector3.new(a.X,0,a.Z)).Magnitude
    local steps=math.max(1,math.ceil(flatLength/18))
    local previous=Vector3.new(a.X,heightAt(a.X,a.Z)+.18,a.Z)
    for step=1,steps do
        local t=step/steps; local x=a.X+(b.X-a.X)*t; local z=a.Z+(b.Z-a.Z)*t
        local current=Vector3.new(x,heightAt(x,z)+.18,z); local delta=current-previous; local mid=(previous+current)*.5
        local cf=CFrame.lookAt(mid,current); local p=part(roads,"Asphalt",Vector3.new(width,.72,delta.Magnitude+1.2),cf,Color3.fromRGB(49,51,50),Enum.Material.Asphalt); p.CanCollide=true
        for _,side in {-1,1} do
            local shoulder=part(roads,"RoadShoulder",Vector3.new(2.6,.38,delta.Magnitude+1.5),cf*CFrame.new(side*(width/2+1.3),-.24,0),Color3.fromRGB(98,82,62),Enum.Material.Ground); shoulder.CanCollide=true
        end
        previous=current
    end
end
for i=1,#roadPoints do roadSegment(roadPoints[i],roadPoints[i%#roadPoints+1],18) end

local function crate(pos,index)
    local m=modelResource(resources,"RoadsideBarrel_"..index,"Scrap",3,55); local body=cylinder(m,"Barrel",Vector3.new(3.2,4.5,3.2),CFrame.new(pos+Vector3.new(0,2.25,0)),Color3.fromRGB(55,103,122),Enum.Material.Metal); m.PrimaryPart=body; prompt(body,"Salvage","Roadside Barrel")
    for y=-1,1,2 do cylinder(m,"Band",Vector3.new(3.35,.22,3.35),CFrame.new(pos+Vector3.new(0,2.25+y*1.4,0)),Color3.fromRGB(42,45,43),Enum.Material.Metal) end
end
for i,p in ipairs(roadPoints) do local x=center.X+p.X+rng:NextNumber(-28,28); local z=center.Z+p.Z+rng:NextNumber(-28,28); crate(Vector3.new(x,ground(x,z),z),i) end

local function monumentPad(name,rel,size,color)
    local m=Instance.new("Model"); m.Name=name; m:SetAttribute("RadiationZone",true); m.Parent=monuments; local x=center.X+rel.X; local z=center.Z+rel.Z; local y=ground(x,z)
    local pad=part(m,"ConcretePad",size,CFrame.new(x,y,z),color or Color3.fromRGB(92,94,90),Enum.Material.Concrete); m.PrimaryPart=pad; return m,Vector3.new(x,y,z)
end
local gas,gp=monumentPad("OxumStyleGasStation",Vector3.new(-860,0,-510),Vector3.new(72,2,54))
part(gas,"Shop",Vector3.new(35,18,30),CFrame.new(gp+Vector3.new(10,10,6)),Color3.fromRGB(118,111,96),Enum.Material.Concrete)
part(gas,"Canopy",Vector3.new(40,2,18),CFrame.new(gp+Vector3.new(-15,12,-12)),Color3.fromRGB(122,42,34),Enum.Material.Metal)
for i=-1,1 do part(gas,"Pump",Vector3.new(2,5,2),CFrame.new(gp+Vector3.new(i*8,3,-12)),Color3.fromRGB(155,48,39),Enum.Material.Metal) end
local dish,dp=monumentPad("SatelliteDish",Vector3.new(730,0,-720),Vector3.new(96,2,82))
local mast=cylinder(dish,"DishMast",Vector3.new(5,28,5),CFrame.new(dp+Vector3.new(0,14,0)),Color3.fromRGB(80,83,80),Enum.Material.Metal)
local bowl=part(dish,"Dish",Vector3.new(32,2,32),CFrame.new(dp+Vector3.new(0,29,0))*CFrame.Angles(math.rad(28),0,0),Color3.fromRGB(127,132,129),Enum.Material.Metal); bowl.Shape=Enum.PartType.Cylinder
local mine,mp=monumentPad("MiningOutpost",Vector3.new(820,0,620),Vector3.new(105,2,75))
part(mine,"Warehouse",Vector3.new(58,24,40),CFrame.new(mp+Vector3.new(8,13,4)),Color3.fromRGB(88,83,73),Enum.Material.CorrodedMetal)
for i=1,4 do part(mine,"Container",Vector3.new(20,8,8),CFrame.new(mp+Vector3.new(-35,i*2-5,i*12-26))*CFrame.Angles(0,(i%2)*math.pi/2,0),i%2==0 and Color3.fromRGB(114,52,39) or Color3.fromRGB(47,78,83),Enum.Material.Metal) end

local spawnX=center.X-1180; local spawnZ=center.Z+690
local spawn=Instance.new("SpawnLocation"); spawn.Name="BeachSpawn_Phase2"; spawn.Size=Vector3.new(12,1,12); spawn.CFrame=CFrame.new(spawnX,ground(spawnX,spawnZ)+2,spawnZ); spawn.Anchored=true; spawn.Neutral=true; spawn.Transparency=.35; spawn.Material=Enum.Material.WoodPlanks; spawn.Color=Color3.fromRGB(132,103,70); spawn.Parent=world

Lighting.ClockTime=17.2; Lighting.Brightness=2.2; Lighting.EnvironmentDiffuseScale=.42; Lighting.EnvironmentSpecularScale=.65; Lighting.OutdoorAmbient=Color3.fromRGB(116,123,130)
local atmosphere=Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere",Lighting); atmosphere.Density=.31; atmosphere.Offset=.08; atmosphere.Color=Color3.fromRGB(198,209,215); atmosphere.Decay=Color3.fromRGB(91,104,111); atmosphere.Glare=.12; atmosphere.Haze=1.7

-- Climate/radiation layer. Core gather/craft/build remains in SurvivalServer.
local oldPhase=ServerScriptService:FindFirstChild("SurvivalPhase2Server"); if oldPhase then oldPhase.Disabled=true; oldPhase.Name="SurvivalPhase2Server_Old" end
local climate=Instance.new("Script"); climate.Name="SurvivalPhase2Server"; climate.Source=[==[
local Players=game:GetService("Players")
local center=Vector3.new(3600,0,0)
local monumentCenters={Vector3.new(2740,0,-510),Vector3.new(4330,0,-720),Vector3.new(4420,0,620)}
local function setup(p)
 for k,v in pairs({Wood=0,Stone=0,Food=2,Cloth=0,Hunger=100,Thirst=100,Days=0,MetalOre=0,SulfurOre=0,Scrap=0,Temperature=20,Radiation=0}) do if p:GetAttribute(k)==nil then p:SetAttribute(k,v) end end
end
Players.PlayerAdded:Connect(setup); for _,p in Players:GetPlayers() do setup(p) end
while task.wait(2) do
 for _,p in Players:GetPlayers() do
  local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart"); local hum=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
  if root then
   local rel=root.Position-center; local temp=20
   if rel.Z < -585 then temp=-8 elseif rel.X>340 and rel.Z>-430 then temp=37 end
   if game.Lighting.ClockTime<6 or game.Lighting.ClockTime>20 then temp-=9 end
   local rad=0; for _,c in monumentCenters do local d=(Vector3.new(root.Position.X,0,root.Position.Z)-c).Magnitude; rad=math.max(rad,math.clamp(100-d*1.25,0,100)) end
   p:SetAttribute("Temperature",temp); p:SetAttribute("Radiation",math.floor(rad))
   if hum and (temp < -12 or temp > 43 or rad>70) then hum:TakeDamage(rad>70 and 4 or 2) end
  end
 end
end
]==]; climate.Parent=ServerScriptService

local scripts=StarterPlayer:WaitForChild("StarterPlayerScripts"); local oldHud=scripts:FindFirstChild("SurvivalPhase2HUD"); if oldHud then oldHud.Disabled=true; oldHud.Name="SurvivalPhase2HUD_Old" end
local hud=Instance.new("LocalScript"); hud.Name="SurvivalPhase2HUD"; hud.Source=[==[
local p=game:GetService("Players").LocalPlayer
local gui=Instance.new("ScreenGui"); gui.Name="Phase2Status"; gui.ResetOnSpawn=false; gui.Parent=p:WaitForChild("PlayerGui")
local box=Instance.new("TextLabel"); box.Size=UDim2.fromOffset(420,68); box.Position=UDim2.new(.5,-210,0,18); box.BackgroundColor3=Color3.fromRGB(18,22,23); box.BackgroundTransparency=.12; box.TextColor3=Color3.fromRGB(230,224,203); box.Font=Enum.Font.GothamBold; box.TextSize=14; box.Parent=gui
Instance.new("UICorner",box).CornerRadius=UDim.new(0,10)
local function update() box.Text=string.format("PHASE 2  |  TEMP %d°C  RAD %d%%\nMETAL %d   SULFUR %d   SCRAP %d",p:GetAttribute("Temperature") or 20,p:GetAttribute("Radiation") or 0,p:GetAttribute("MetalOre") or 0,p:GetAttribute("SulfurOre") or 0,p:GetAttribute("Scrap") or 0) end
for _,a in {"Temperature","Radiation","MetalOre","SulfurOre","Scrap"} do p:GetAttributeChangedSignal(a):Connect(update) end; update()
]==]; hud.Parent=scripts

local camera=Workspace.CurrentCamera; camera.CFrame=CFrame.new(center+Vector3.new(-1650,1050,1650),center+Vector3.new(0,25,0)); camera.Focus=CFrame.new(center)
ChangeHistoryService:SetWaypoint("Created Survival Phase 2")
print("PHASE2_COMPLETE",#resources:GetChildren(),#monuments:GetChildren(),world:GetAttribute("MapSize"))
