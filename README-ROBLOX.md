# Roblox Studio AI Bridge

This is a local MCP bridge that lets an AI agent inspect and edit the place open in Roblox Studio. It is intentionally restricted to inspection, creating Parts/Models, changing common Part properties, and deleting a specifically named instance. It does **not** run arbitrary Lua supplied by AI.

## Install and run

1. Run `bun install` once, then `bun run build`.
2. In a terminal, run `bun run roblox:relay` and leave it running.
3. In Roblox Studio, enable **Game Settings → Security → Allow HTTP Requests** for your development place.
4. Create a local Plugin Script, paste in [`RobloxAIBridge.plugin.lua`](src/roblox_plugin/RobloxAIBridge.plugin.lua), then save it as a local plugin. Run it from the **Plugins → AI Bridge** toolbar.
5. In your MCP client configuration, add:

```json
{
  "mcpServers": {
    "RobloxStudio": {
      "command": "bun",
      "args": ["run", "D:/cursor-talk-to-figma-mcp/dist/roblox-server.js"]
    }
  }
}
```

6. Use `join_channel` with the same channel shown in the Studio panel (default: `roblox-studio`), then call `get_place_info` or `get_selection` before changing anything.

The bridge binds to `127.0.0.1` only. Do not expose its port to a network: anyone who can reach the relay and knows its channel can control the connected Studio instance.
