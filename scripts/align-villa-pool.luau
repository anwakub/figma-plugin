local villa=assert(workspace:FindFirstChild("ModernLuxuryVilla"))
local floor=assert(villa.Pool:FindFirstChild("Pool_002_BasinFloor"))
local plinth=assert(villa.Structure:FindFirstChild("Structure_001_Plinth"))
local terrain=workspace.Terrain
local waterMin=Vector3.new(math.ceil((floor.Position.X-floor.Size.X/2+0.5)/4)*4,0,math.ceil((floor.Position.Z-floor.Size.Z/2+0.5)/4)*4)
local waterMax=Vector3.new(math.floor((floor.Position.X+floor.Size.X/2-0.5)/4)*4,4,math.floor((floor.Position.Z+floor.Size.Z/2-0.5)/4)*4)
assert(waterMax.X>waterMin.X and waterMax.Z>waterMin.Z,"Pool too small")
local priorMin=villa:GetAttribute("PoolTerrainMin") or Vector3.new(120,0,-48)
local priorMax=villa:GetAttribute("PoolTerrainMax") or Vector3.new(184,4,-36)
local oldRegion=Region3.new(priorMin,priorMax)
local oldMat,oldOcc=terrain:ReadVoxels(oldRegion,4)
for x=1,#oldOcc do for y=1,#oldOcc[x] do for z=1,#oldOcc[x][y] do
    assert(oldOcc[x][y][z]==0 or oldMat[x][y][z]==Enum.Material.Water,"Non-water terrain exists in the previous pool region")
end end end
-- Preserve a recoverable copy before relocating only the water made by this detail pass.
if not villa:FindFirstChild("PreviousPoolWaterBackup") then
    local copy=terrain:CopyRegion(Region3int16.new(Vector3int16.new(priorMin.X/4,priorMin.Y/4,priorMin.Z/4),Vector3int16.new(priorMax.X/4-1,priorMax.Y/4-1,priorMax.Z/4-1)))
    copy.Name="PreviousPoolWaterBackup"; copy.Parent=villa
end
terrain:FillBlock(oldRegion.CFrame,oldRegion.Size,Enum.Material.Air)
local newRegion=Region3.new(waterMin,waterMax)
terrain:FillBlock(newRegion.CFrame,newRegion.Size,Enum.Material.Water)
villa:SetAttribute("PoolTerrainMin",waterMin); villa:SetAttribute("PoolTerrainMax",waterMax)
local offset=plinth.Position-Vector3.new(145,1.25,3)
local rimY=4.15
local outerMinX=floor.Position.X-floor.Size.X/2
local outerMaxX=floor.Position.X+floor.Size.X/2
local outerMinZ=floor.Position.Z-floor.Size.Z/2
local outerMaxZ=floor.Position.Z+floor.Size.Z/2
local specs={
    {Vector3.new(floor.Position.X,rimY,(outerMinZ+waterMin.Z)/2),Vector3.new(floor.Size.X,1.1,waterMin.Z-outerMinZ)},
    {Vector3.new(floor.Position.X,rimY,(outerMaxZ+waterMax.Z)/2),Vector3.new(floor.Size.X,1.1,outerMaxZ-waterMax.Z)},
    {Vector3.new((outerMinX+waterMin.X)/2,rimY,(waterMin.Z+waterMax.Z)/2),Vector3.new(waterMin.X-outerMinX,1.1,waterMax.Z-waterMin.Z)},
    {Vector3.new((outerMaxX+waterMax.X)/2,rimY,(waterMin.Z+waterMax.Z)/2),Vector3.new(outerMaxX-waterMax.X,1.1,waterMax.Z-waterMin.Z)}
}
local index=0
for _,p in villa.PoolDetails:GetChildren() do
    if p.Name:find("LimestoneRim") then index+=1; p.Position=specs[index][1]; p.Size=specs[index][2]; p.Name="LimestoneRim_"..index
    elseif not villa:GetAttribute("PoolDetailOffsetApplied") and p:IsA("BasePart") then p.Position+=offset end
end
if not villa:GetAttribute("PoolDetailOffsetApplied") then
    for _,p in villa.Lights:GetChildren() do if p.Name:find("InteriorAmbient_") then p.Position+=offset end end
    villa:SetAttribute("PoolDetailOffsetApplied",true)
end
local mark=Instance.new("StringValue"); mark.Name="PoolWaterVerified"; mark.Value=tostring(waterMin).." to "..tostring(waterMax); mark.Parent=villa.PoolDetails
game:GetService("Selection"):Set({villa})
game:GetService("ChangeHistoryService"):SetWaypoint("Pool aligned to current villa position")
print("Pool water aligned",waterMin,waterMax)
