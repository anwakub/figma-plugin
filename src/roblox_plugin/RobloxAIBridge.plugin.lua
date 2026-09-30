-- Roblox AI Bridge: paste this into a Studio Plugin Script, then save it as a local plugin.
-- Requires Game Settings > Security > Allow HTTP Requests while developing locally.
local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local toolbar = plugin:CreateToolbar("AI Bridge")
local connectButton = toolbar:CreateButton("Connect", "Connect the AI Bridge to the local relay", "rbxassetid://4458901886")
local widgetInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, true, false, 350, 260, 280, 200)
local widget = plugin:CreateDockWidgetPluginGui("RobloxAIBridge", widgetInfo)
widget.Title = "Roblox AI Bridge"

local ui = Instance.new("Frame")
ui.Size = UDim2.fromScale(1, 1); ui.BackgroundColor3 = Color3.fromRGB(30, 33, 40); ui.Parent = widget
local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 8); layout.Parent = ui
local padding = Instance.new("UIPadding"); padding.PaddingTop = UDim.new(0, 12); padding.PaddingLeft = UDim.new(0, 12); padding.PaddingRight = UDim.new(0, 12); padding.Parent = ui
local function label(text, height)
  local value = Instance.new("TextLabel"); value.Size = UDim2.new(1, 0, 0, height or 24); value.BackgroundTransparency = 1; value.TextColor3 = Color3.fromRGB(235, 235, 235); value.TextXAlignment = Enum.TextXAlignment.Left; value.TextWrapped = true; value.Font = Enum.Font.Gotham; value.TextSize = 13; value.Text = text; value.Parent = ui; return value
end
label("Local AI control for this Studio session", 25)
local channelBox = Instance.new("TextBox"); channelBox.Size = UDim2.new(1, 0, 0, 32); channelBox.BackgroundColor3 = Color3.fromRGB(54, 58, 70); channelBox.TextColor3 = Color3.new(1, 1, 1); channelBox.PlaceholderText = "Channel name, e.g. my-place"; channelBox.Text = plugin:GetSetting("channel") or "roblox-studio"; channelBox.ClearTextOnFocus = false; channelBox.Parent = ui
local status = label("Disconnected", 50); status.TextColor3 = Color3.fromRGB(255, 190, 80)
label("Start the relay, enter this channel in AI with join_channel, then click Connect.", 42)

local relay = plugin:GetSetting("relayUrl") or "http://127.0.0.1:3056"
local connected = false
local function encode(value) return HttpService:JSONEncode(value) end
local function request(method, path, data)
  local ok, response = pcall(function()
    return HttpService:RequestAsync({ Url = relay .. path, Method = method, Headers = { ["Content-Type"] = "application/json" }, Body = data and encode(data) or nil })
  end)
  if not ok then return nil, tostring(response) end
  if not response.Success then return nil, response.StatusMessage or ("HTTP " .. response.StatusCode) end
  local decodedOk, decoded = pcall(function() return HttpService:JSONDecode(response.Body) end)
  return decodedOk and decoded or nil, decodedOk and nil or "Invalid JSON from relay"
end
local function getPath(instance)
  local parts = {}; local current = instance
  while current and current ~= game do table.insert(parts, 1, current.Name); current = current.Parent end
  return table.concat(parts, "/")
end
local function fromPath(path)
  local current = game
  for part in string.gmatch(path, "[^/]+") do
    if part ~= "game" then current = current:FindFirstChild(part) end
    if not current then return nil end
  end
  return current
end
local function describe(instance)
  local value = { name = instance.Name, className = instance.ClassName, path = getPath(instance) }
  if instance:IsA("BasePart") then value.position = { instance.Position.X, instance.Position.Y, instance.Position.Z }; value.size = { instance.Size.X, instance.Size.Y, instance.Size.Z }; value.anchored = instance.Anchored end
  return value
end
local function execute(command, params)
  if command == "get_place_info" then
    local services = {}; for _, child in game:GetChildren() do table.insert(services, { name = child.Name, className = child.ClassName, children = #child:GetChildren() }) end
    return { placeName = game.Name, placeId = game.PlaceId, services = services }
  elseif command == "get_selection" then
    local selected = {}; for _, item in Selection:Get() do table.insert(selected, describe(item)) end; return { selection = selected }
  elseif command == "find_instances" then
    local found = {}; local limit = params.maxResults or 50
    for _, item in game:GetDescendants() do
      if (#found >= limit) then break end
      if (not params.name or string.lower(item.Name):find(string.lower(params.name), 1, true)) and (not params.className or item.ClassName == params.className) then table.insert(found, describe(item)) end
    end; return { instances = found, truncated = #found >= limit }
  elseif command == "create_part" then
    local parent = params.parentPath and fromPath(params.parentPath) or workspace; if not parent then error("Parent path was not found") end
    local item = Instance.new("Part"); item.Name = params.name; item.Anchored = params.anchored ~= false
    if params.position then item.Position = Vector3.new(params.position[1], params.position[2], params.position[3]) end
    if params.size then item.Size = Vector3.new(params.size[1], params.size[2], params.size[3]) end
    if params.color then item.Color = Color3.fromRGB(params.color[1], params.color[2], params.color[3]) end
    item.Parent = parent; ChangeHistoryService:SetWaypoint("AI Bridge: Create Part"); return describe(item)
  elseif command == "create_model" then
    local parent = params.parentPath and fromPath(params.parentPath) or workspace; if not parent then error("Parent path was not found") end
    local item = Instance.new("Model"); item.Name = params.name; item.Parent = parent; ChangeHistoryService:SetWaypoint("AI Bridge: Create Model"); return describe(item)
  elseif command == "set_instance_properties" then
    local item = fromPath(params.path); if not item then error("Instance path was not found") end
    if params.name then item.Name = params.name end
    if item:IsA("BasePart") then
      if params.anchored ~= nil then item.Anchored = params.anchored end; if params.canCollide ~= nil then item.CanCollide = params.canCollide end; if params.transparency ~= nil then item.Transparency = params.transparency end
      if params.position then item.Position = Vector3.new(params.position[1], params.position[2], params.position[3]) end; if params.size then item.Size = Vector3.new(params.size[1], params.size[2], params.size[3]) end; if params.color then item.Color = Color3.fromRGB(params.color[1], params.color[2], params.color[3]) end
    end; ChangeHistoryService:SetWaypoint("AI Bridge: Update Instance"); return describe(item)
  elseif command == "delete_instance" then
    local item = fromPath(params.path); if not item or item == game then error("Instance path was not found or is protected") end
    local old = getPath(item); item:Destroy(); ChangeHistoryService:SetWaypoint("AI Bridge: Delete Instance"); return { deleted = old }
  end
  error("Unsupported command: " .. tostring(command))
end
local function connect()
  plugin:SetSetting("channel", channelBox.Text); connected = true; widget.Enabled = true; status.Text = "Connecting to " .. relay .. "…"; status.TextColor3 = Color3.fromRGB(255, 190, 80)
  task.spawn(function()
    while connected do
      local joined, err = request("POST", "/roblox/join", { channel = channelBox.Text })
      if not joined then status.Text = "Relay unavailable: " .. tostring(err); status.TextColor3 = Color3.fromRGB(255, 105, 105); task.wait(2); continue end
      status.Text = "Connected — channel: " .. channelBox.Text; status.TextColor3 = Color3.fromRGB(110, 235, 150)
      local poll, pollErr = request("GET", "/roblox/poll?channel=" .. HttpService:UrlEncode(channelBox.Text))
      if poll and poll.command then
        local cmd = poll.command; local ok, output = pcall(execute, cmd.command, cmd.params or {})
        request("POST", "/roblox/respond", { channel = channelBox.Text, id = cmd.id, result = ok and output or nil, error = (not ok) and tostring(output) or nil })
      elseif not poll then status.Text = "Relay unavailable: " .. tostring(pollErr); status.TextColor3 = Color3.fromRGB(255, 105, 105); task.wait(1) else task.wait(0.15) end
    end
  end)
end
connectButton.Click:Connect(function() if connected then connected = false; status.Text = "Disconnected" else connect() end end)
widget:GetPropertyChangedSignal("Enabled"):Connect(function() if widget.Enabled and not connected then connect() end end)
