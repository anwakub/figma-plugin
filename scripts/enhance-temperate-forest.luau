-- Dense temperate forest pass inspired by the supplied reference image.
-- Adds gatherable broadleaf trees, ferns, shrubs, flowers and fallen wood.
local Workspace=game:GetService("Workspace")
local Lighting=game:GetService("Lighting")
local CHS=game:GetService("ChangeHistoryService")
local world=Workspace:FindFirstChild("SurvivalWorld"); assert(world,"SurvivalWorld is missing")
local resources=world:FindFirstChild("Resources"); assert(resources,"Resources is missing")
CHS:SetWaypoint("Before Temperate Forest Detail")
local old=world:FindFirstChild("TemperateForestDetail"); if old then old:Destroy() end
local detail=Instance.new("Folder"); detail.Name="TemperateForestDetail"; detail.Parent=world
Workspace.Terrain.Decoration=true
Workspace.Terrain.WaterWaveSize=.12; Workspace.Terrain.WaterWaveSpeed=8; Workspace.Terrain.WaterReflectance=.32; Workspace.Terrain.WaterTransparency=.22
local rng=Random.new(349821); local center=Vector3.new(3600,0,0)

local function part(parent,name,size,cf,color,material,collide)
 local p=Instance.new("Part"); p.Name=name; p.Anchored=true; p.CanCollide=collide==true; p.CanQuery=true; p.Size=size; p.CFrame=cf; p.Color=color; p.Material=material or Enum.Material.Grass; p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth; p.Parent=parent; return p
end
local function ball(parent,name,size,cf,color,material)
 local p=part(parent,name,size,cf,color,material,false); p.Shape=Enum.PartType.Ball; return p
end
local function limb(parent,a,b,width,color)
 local d=b-a; local p=part(parent,"Branch",Vector3.new(d.Magnitude,width,width),CFrame.lookAt((a+b)*.5,b)*CFrame.Angles(0,math.pi/2,0),color,Enum.Material.Wood,true); p.Shape=Enum.PartType.Cylinder; return p
end
local rayParams=RaycastParams.new(); rayParams.FilterType=Enum.RaycastFilterType.Exclude; rayParams.FilterDescendantsInstances={detail,resources,world:FindFirstChild("RoadNetwork"),world:FindFirstChild("Monuments")}
local function groundAt(x,z)
 local hit=Workspace:Raycast(Vector3.new(x,220,z),Vector3.new(0,-360,0),rayParams)
 if hit and hit.Instance==Workspace.Terrain and hit.Material~=Enum.Material.Water and hit.Position.Y>4 then return hit.Position,hit.Normal,hit.Material end
end
local function temperatePoint(radius)
 for _=1,35 do
  local x=center.X+rng:NextNumber(-radius,radius); local z=center.Z+rng:NextNumber(-radius,radius)
  local nx=(x-center.X)/1536; local nz=z/1536
  if not (nz<-.35 or (nz<-.10 and nx<-.5)) and not (nx>.20 and nz>-.28) then
   local p,n,m=groundAt(x,z); if p and (m==Enum.Material.Grass or m==Enum.Material.Ground or m==Enum.Material.LeafyGrass) then return p,n end
  end
 end
end

local barkPalette={Color3.fromRGB(67,55,42),Color3.fromRGB(79,65,48),Color3.fromRGB(91,76,57)}
local leafPalette={Color3.fromRGB(35,88,42),Color3.fromRGB(45,104,50),Color3.fromRGB(57,116,55),Color3.fromRGB(68,126,60)}
local function broadleaf(index,pos)
 local m=Instance.new("Model"); m.Name="Broadleaf_"..index; m:SetAttribute("ResourceType","Wood"); m:SetAttribute("Health",10); m:SetAttribute("MaxHealth",10); m:SetAttribute("RespawnTime",95); m.Parent=resources
 local scale=rng:NextNumber(.82,1.28); local height=rng:NextNumber(27,39)*scale; local bark=barkPalette[rng:NextInteger(1,#barkPalette)]
 local lean=Vector3.new(rng:NextNumber(-2,2),0,rng:NextNumber(-2,2))*scale; local base=pos+Vector3.new(0,.2,0); local last=base
 for s=1,5 do local t=s/5; local nextP=base+Vector3.new(lean.X*t,height*t,lean.Z*t)+Vector3.new(math.noise(index,s)*.65,0,math.noise(s,index)*.65); local trunk=limb(m,last,nextP,(3.2-1.65*t)*scale,bark); if s==1 then m.PrimaryPart=trunk; local pr=Instance.new("ProximityPrompt"); pr.ActionText="Chop"; pr.ObjectText="Broadleaf Tree"; pr.HoldDuration=.35; pr.MaxActivationDistance=11; pr.RequiresLineOfSight=false; pr.Parent=trunk end; last=nextP end
 local forks={}
 for j=1,7 do
  local a=j*2.399+rng:NextNumber(-.3,.3); local start=base+Vector3.new(lean.X*.56,height*rng:NextNumber(.48,.7),lean.Z*.56); local reach=rng:NextNumber(7,13)*scale; local tip=start+Vector3.new(math.cos(a)*reach,rng:NextNumber(5,11)*scale,math.sin(a)*reach); limb(m,start,tip,rng:NextNumber(.55,.95)*scale,bark); forks[#forks+1]=tip
  for k=1,2 do local aa=a+rng:NextNumber(-.7,.7); local twig=tip+Vector3.new(math.cos(aa)*rng:NextNumber(3,6)*scale,rng:NextNumber(2,5)*scale,math.sin(aa)*rng:NextNumber(3,6)*scale); limb(m,tip,twig,.3*scale,bark); forks[#forks+1]=twig end
 end
 for _,tip in forks do
  for k=1,rng:NextInteger(2,4) do local a=rng:NextNumber(0,math.pi*2); local r=rng:NextNumber(1.2,4.4)*scale; local leaf=ball(m,"LeafCluster",Vector3.new(rng:NextNumber(6,10)*scale,rng:NextNumber(4,7)*scale,rng:NextNumber(6,10)*scale),CFrame.new(tip+Vector3.new(math.cos(a)*r,rng:NextNumber(-1,3)*scale,math.sin(a)*r))*CFrame.Angles(rng:NextNumber(-.18,.18),a,rng:NextNumber(-.12,.12)),leafPalette[rng:NextInteger(1,#leafPalette)],Enum.Material.Grass); leaf.CanQuery=false end
 end
 return m
end

for i=1,75 do local p=temperatePoint(1280); if p then broadleaf(i,p) end end

local function fern(index,pos,scale)
 local m=Instance.new("Model"); m.Name="Fern_"..index; m.Parent=detail
 for j=1,8 do local a=j*math.pi/4+rng:NextNumber(-.16,.16); local len=rng:NextNumber(3.5,6)*scale; local leaf=part(m,"Frond",Vector3.new(.16,.18,len),CFrame.new(pos+Vector3.new(math.cos(a)*len*.35,.55*scale,math.sin(a)*len*.35))*CFrame.Angles(math.rad(rng:NextNumber(-16,12)),-a,math.rad(rng:NextNumber(55,72))),Color3.fromRGB(rng:NextInteger(40,62),rng:NextInteger(102,139),rng:NextInteger(45,66)),Enum.Material.Grass,false); leaf.CanQuery=false end
end
for i=1,260 do local p=temperatePoint(1320); if p then fern(i,p,rng:NextNumber(.55,1.25)) end end

for i=1,150 do
 local p=temperatePoint(1300); if p then local m=Instance.new("Model"); m.Name="Wildflower_"..i; m.Parent=detail; local h=rng:NextNumber(.8,1.7); local stem=part(m,"Stem",Vector3.new(.08,h,.08),CFrame.new(p+Vector3.new(0,h/2,0)),Color3.fromRGB(55,112,48),Enum.Material.Grass,false); stem.CanQuery=false; local color=({Color3.fromRGB(240,235,205),Color3.fromRGB(225,207,91),Color3.fromRGB(202,180,224)})[rng:NextInteger(1,3)]; for j=1,5 do local a=j*math.pi*2/5; local petal=ball(m,"Petal",Vector3.new(.32,.12,.18),CFrame.new(p+Vector3.new(math.cos(a)*.2,h,math.sin(a)*.2))*CFrame.Angles(0,a,0),color,Enum.Material.SmoothPlastic); petal.CanQuery=false end end
end

for i=1,55 do
 local p=temperatePoint(1260); if p then local m=Instance.new("Model"); m.Name="Shrub_"..i; m.Parent=detail; for j=1,rng:NextInteger(4,7) do local a=rng:NextNumber(0,math.pi*2); local r=rng:NextNumber(.3,2.1); local leaf=ball(m,"Foliage",Vector3.new(rng:NextNumber(2.8,5),rng:NextNumber(2,4),rng:NextNumber(2.8,5)),CFrame.new(p+Vector3.new(math.cos(a)*r,rng:NextNumber(1,2.8),math.sin(a)*r)),leafPalette[rng:NextInteger(1,#leafPalette)],Enum.Material.Grass); leaf.CanQuery=false end end
end

for i=1,24 do
 local p=temperatePoint(1220); if p then local a=rng:NextNumber(0,math.pi*2); local len=rng:NextNumber(8,17); local log=part(detail,"FallenLog",Vector3.new(2.1,len,2.1),CFrame.new(p+Vector3.new(0,1,0))*CFrame.Angles(math.rad(90),0,a),Color3.fromRGB(75,59,43),Enum.Material.Wood,true); log.Shape=Enum.PartType.Cylinder end
end

local cc=Lighting:FindFirstChild("ForestColor") or Instance.new("ColorCorrectionEffect"); cc.Name="ForestColor"; cc.Brightness=.015; cc.Contrast=.06; cc.Saturation=.08; cc.TintColor=Color3.fromRGB(239,247,228); cc.Parent=Lighting
local rays=Lighting:FindFirstChild("ForestSunRays") or Instance.new("SunRaysEffect"); rays.Name="ForestSunRays"; rays.Intensity=.055; rays.Spread=.72; rays.Parent=Lighting
world:SetAttribute("TemperateForestDetail",true)
CHS:SetWaypoint("Added Temperate Forest Detail")
print("TEMPERATE_FOREST_COMPLETE",75,260,150,55,24)
