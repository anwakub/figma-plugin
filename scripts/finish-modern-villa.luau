-- Run in the Studio Command Bar after build-modern-villa.mjs.
-- Adds rendering properties not exposed by the initial bridge tool set.
local villa = workspace:FindFirstChild("ModernLuxuryVilla")
assert(villa, "Build ModernLuxuryVilla first")
local lighting = game:GetService("Lighting")
local history = game:GetService("ChangeHistoryService")
history:SetWaypoint("Before villa materials and lighting")
for _, item in villa:GetDescendants() do
    if item:IsA("BasePart") then
        item.TopSurface = Enum.SurfaceType.Smooth
        item.BottomSurface = Enum.SurfaceType.Smooth
        local category = item.Parent.Name
        if category == "Structure" then
            item.Material = Enum.Material.Concrete
            if item.Name:find("Slab") or item.Name:find("Portal") or item.Name:find("Roof") then
                item.Material = Enum.Material.SmoothPlastic
            end
        elseif category == "Timber" then
            item.Material = Enum.Material.Wood
        elseif category == "Frames" then
            item.Material = Enum.Material.Metal
        elseif category == "Glazing" then
            item.Material = Enum.Material.Glass
            item.Transparency = item.Name:find("Balustrade") and 0.65 or 0.72
            item.Reflectance = 0.12
            item.CastShadow = false
        elseif category == "Site" then
            item.Material = Enum.Material.Grass
        elseif category == "Garden" then
            item.Material = item.Name:find("Hedge") and Enum.Material.Grass or Enum.Material.Slate
        elseif category == "Trees" or category == "Plants" then
            if item.Name:find("Canopy") or item.Name:find("Foliage") or item.Name:find("Shrub") then
                item.Shape = Enum.PartType.Ball
                item.Material = Enum.Material.Grass
                item.CanCollide = false
            elseif item.Name:find("Trunk") then
                item.Material = Enum.Material.Wood
            else
                item.Material = Enum.Material.Concrete
            end
        elseif category == "Pool" then
            item.Material = Enum.Material.Concrete
            if item.Name:find("Water") then
                item.Material = Enum.Material.Glass
                item.Reflectance = 0.28
                item.Transparency = 0.3
                item.CastShadow = false
            elseif item.Name:find("Cushion") or item.Name:find("Back") then
                item.Material = Enum.Material.Fabric
            elseif item.Name:find("LeftDeck") then
                item.Material = Enum.Material.WoodPlanks
            end
        elseif category == "Interior" then
            item.Material = Enum.Material.Wood
            if item.Name:find("Cushion") or item.Name:find("Pillow") or item.Name:find("Mattress") or item.Name:find("Sofa") or item.Name:find("Rug") or item.Name:find("Throw") then
                item.Material = Enum.Material.Fabric
            end
        elseif category == "Lights" then
            if item.Name:find("Glow") or item.Name:find("Downlight") then
                item.Material = Enum.Material.Neon
                if not item:FindFirstChild("VillaLight") then
                    local down = item.Name:find("Downlight") ~= nil
                    local light = Instance.new(down and "SpotLight" or "PointLight")
                    light.Name = "VillaLight"
                    light.Color = Color3.fromRGB(255, 218, 169)
                    light.Brightness = down and 2 or 1.2
                    light.Range = down and 23 or 12
                    light.Shadows = true
                    if down then light.Face = Enum.NormalId.Bottom; light.Angle = 105 end
                    light.Parent = item
                end
            else item.Material = Enum.Material.Metal end
        end
    end
end
-- Soft interior glow makes the rooms readable through the facade at dusk.
for _, room in {{-23,12,7},{23,12,10},{-28,27,6},{20,26,8}} do
    local name = "InteriorAmbient_" .. tostring(room[1]) .. "_" .. tostring(room[2])
    if not villa.Lights:FindFirstChild(name) then
        local anchor = Instance.new("Part")
        anchor.Name = name; anchor.Size = Vector3.new(0.2,0.2,0.2)
        anchor.Position = Vector3.new(145+room[1],room[2],room[3])
        anchor.Anchored = true; anchor.CanCollide = false; anchor.Transparency = 1
        anchor.Parent = villa.Lights
        local light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(255,224,185); light.Brightness = 1.4; light.Range = 28
        light.Parent = anchor
    end
end
lighting.ClockTime = 17.4
lighting.Brightness = 2.5
lighting.Ambient = Color3.fromRGB(80,85,94)
lighting.OutdoorAmbient = Color3.fromRGB(113,118,126)
lighting.GlobalShadows = true
lighting.EnvironmentDiffuseScale = 0.7
lighting.EnvironmentSpecularScale = 1
local camera = workspace.CurrentCamera
camera.FieldOfView = 48
camera.CFrame = CFrame.lookAt(Vector3.new(50,60,-143),Vector3.new(145,12,-12))
camera.Focus = CFrame.new(145,12,-12)
game:GetService("Selection"):Set({})
history:SetWaypoint("Modern luxury villa completed")
print("ModernLuxuryVilla: materials, transparent glazing, pool, garden and lighting complete")
