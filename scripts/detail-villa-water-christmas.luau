-- Add native animated water and six decorated evergreen trees to the existing villa.
local villa = assert(workspace:FindFirstChild("ModernLuxuryVilla"), "Villa is missing")
local history = game:GetService("ChangeHistoryService")
history:SetWaypoint("Before pool water and Christmas trees")
local terrain = workspace.Terrain
local region = Region3.new(Vector3.new(120,0,-48), Vector3.new(184,4,-36))
if not villa:GetAttribute("ChristmasWaterV1") then
    local materials, occupancy = terrain:ReadVoxels(region, 4)
    for x=1,#occupancy do for y=1,#occupancy[x] do for z=1,#occupancy[x][y] do
        assert(occupancy[x][y][z] == 0, "Existing terrain occupies the pool; stop before overwriting it")
    end end end
end
local function make(parent,name,position,size,color,material,shape)
    local p=Instance.new("Part")
    p.Name=name; p.Anchored=true; p.Size=size; p.Position=position
    p.Color=color; p.Material=material or Enum.Material.SmoothPlastic
    p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
    if shape then p.Shape=shape end
    p.Parent=parent
    return p
end
if not villa:GetAttribute("ChristmasWaterV1") then
    -- Retain the existing pool layout, raising the terrace to accommodate Roblox's 4-stud water grid.
    for _,p in villa.Pool:GetChildren() do
        if p:IsA("BasePart") then
            p.Position=p.Position+Vector3.new(0,2.4,0)
            if p.Name:find("Water") then p.Transparency=1; p.CanCollide=false end
        end
    end
    for _,p in villa.Timber:GetChildren() do
        if p.Name:find("DeckSeam") then p.Position=p.Position+Vector3.new(0,2.4,0) end
    end
    -- Widen the paving around the water into a clean, raised infinity-pool surround.
    local detail=Instance.new("Model"); detail.Name="PoolDetails"; detail.Parent=villa
    for _,entry in {{152,4.05,-49.35,67,1.3,2.7},{152,4.05,-34.65,67,1.3,2.7},{118.9,4.05,-42,2.2,1.3,12},{185.65,4.05,-42,3.3,1.3,12}} do
        make(detail,"LimestoneRim",Vector3.new(entry[1],entry[2],entry[3]),Vector3.new(entry[4],entry[5],entry[6]),Color3.fromRGB(204,198,179),Enum.Material.Concrete)
    end
    for i=1,3 do
        make(detail,"TerraceEntryStep",Vector3.new(145,3.05+i*0.48,-19.3-i*0.65),Vector3.new(22,0.48,1.3),Color3.fromRGB(213,207,191),Enum.Material.Concrete)
    end
    for _,x in {127,143,159,175} do
        local lamp=make(detail,"UnderwaterLamp",Vector3.new(x,3.45,-47.7),Vector3.new(0.7,0.45,0.12),Color3.fromRGB(149,218,238),Enum.Material.Neon)
        lamp.CanCollide=false
        local light=Instance.new("PointLight"); light.Color=Color3.fromRGB(147,219,236); light.Range=10; light.Brightness=0.7; light.Parent=lamp
    end
    terrain:FillBlock(CFrame.new(152,2,-42),Vector3.new(64,4,12),Enum.Material.Water)
    villa:SetAttribute("ChristmasWaterV1",true)
end
terrain.WaterColor=Color3.fromRGB(39,110,119)
terrain.WaterReflectance=0.28
terrain.WaterTransparency=0.38
terrain.WaterWaveSize=0.1
terrain.WaterWaveSpeed=7

if not villa:FindFirstChild("ChristmasTrees") then
    local forest=Instance.new("Model"); forest.Name="ChristmasTrees"; forest.Parent=villa
    local positions={}
    for _,old in villa.Trees:GetChildren() do
        if old:IsA("BasePart") then
            if old.Name:find("Trunk") then table.insert(positions,Vector3.new(old.Position.X,0.6,old.Position.Z)) end
            old.Transparency=1; old.CanCollide=false; old.CastShadow=false
        end
    end
    for index,base in positions do
        local tree=Instance.new("Model"); tree.Name="ChristmasPine_"..index; tree.Parent=forest
        local scale=index>4 and 0.76 or 1
        local function at(x,y,z) return base+Vector3.new(x,y,z)*scale end
        local trunk=make(tree,"CedarTrunk",at(0,7,0),Vector3.new(13,1.1,1.1)*scale,Color3.fromRGB(105,73,45),Enum.Material.Wood,Enum.PartType.Cylinder)
        trunk.CFrame=CFrame.new(at(0,7,0))*CFrame.Angles(0,0,math.pi/2)
        -- Radial wedges form tapered branches; staggered rings create an evergreen silhouette.
        for tier=1,7 do
            local radius=6.5-(tier-1)*0.78
            local bottom=2+(tier-1)*2.1
            local height=5.5-(tier-1)*0.28
            for segment=1,14 do
                local angle=segment*math.pi*2/14+tier*0.12
                local bough=Instance.new("WedgePart")
                bough.Name="FirBough"; bough.Anchored=true; bough.CanCollide=false
                bough.Size=Vector3.new(radius*0.47,height,radius)*scale
                bough.CFrame=CFrame.new(base)*CFrame.Angles(0,angle,0)*CFrame.new(0,(bottom+height/2)*scale,-radius*scale/2)
                bough.Color=Color3.fromRGB(24+tier*2+(segment%3)*3,65+tier*3+(segment%4)*3,44+tier*2)
                bough.Material=Enum.Material.Grass; bough.TopSurface=Enum.SurfaceType.Smooth; bough.BottomSurface=Enum.SurfaceType.Smooth; bough.Parent=tree
            end
            if tier<7 then
                for ornament=1,6 do
                    local angle=ornament*math.pi/3+tier*0.7
                    local r=radius*0.83
                    local ball=make(tree,"Bauble",at(math.sin(angle)*r,bottom+0.8,math.cos(angle)*r),Vector3.new(0.58,0.58,0.58)*scale,ornament%2==0 and Color3.fromRGB(180,26,37) or Color3.fromRGB(221,169,56),Enum.Material.Metal,Enum.PartType.Ball)
                    ball.CanCollide=false; ball.Reflectance=0.18
                end
            end
        end
        for i=0,63 do
            local t=i/63; local h=3+t*14; local r=6*(1-t)+0.4; local angle=t*math.pi*10
            local bulb=make(tree,"FairyLight",at(math.sin(angle)*r,h,math.cos(angle)*r),Vector3.new(0.16,0.16,0.16)*scale,Color3.fromRGB(255,215,137),Enum.Material.Neon,Enum.PartType.Ball)
            bulb.CanCollide=false; bulb.CastShadow=false
            if i%16==0 then local l=Instance.new("PointLight"); l.Color=Color3.fromRGB(255,206,123); l.Range=8*scale; l.Brightness=0.45; l.Parent=bulb end
        end
        -- Five pairs of rays give the topper a recognizable gold star silhouette.
        local starCenter=at(0,19.7,0)
        for ray=0,4 do
            local a=ray*2*math.pi/5
            local star=make(tree,"GoldenStar",starCenter,Vector3.new(0.42,2.25,0.25)*scale,Color3.fromRGB(255,209,101),Enum.Material.Neon)
            star.CFrame=CFrame.new(starCenter)*CFrame.Angles(0,0,a)*CFrame.new(0,0.7*scale,0)
            star.CanCollide=false
        end
        local pot=make(tree,"TreeBase",at(0,0.4,0),Vector3.new(0.8,5,5)*scale,Color3.fromRGB(105,106,97),Enum.Material.Concrete,Enum.PartType.Cylinder)
        pot.CFrame=CFrame.new(at(0,0.4,0))*CFrame.Angles(0,0,math.pi/2)
    end
end
local camera=workspace.CurrentCamera
camera.FieldOfView=52
camera.CFrame=CFrame.lookAt(Vector3.new(90,47,-119),Vector3.new(145,10,-20))
camera.Focus=CFrame.new(145,10,-20)
game:GetService("Selection"):Set({})
history:SetWaypoint("Animated pool and Christmas garden complete")
villa:SetAttribute("DetailPassComplete",true)
print("COMPLETE: native animated pool water; six decorated Christmas pines; villa materials and lights.")
