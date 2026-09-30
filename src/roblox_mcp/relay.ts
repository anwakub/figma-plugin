#!/usr/bin/env bun

/**
 * Local relay for the Roblox Studio AI Bridge.  Roblox plugins can make HTTP
 * requests but cannot create arbitrary WebSocket connections, so commands are
 * queued for the plugin to poll while MCP clients use a WebSocket.
 */
import { Server, ServerWebSocket } from "bun";

type Command = { id: string; command: string; params: Record<string, unknown> };
const channels = new Map<string, { clients: Set<ServerWebSocket<unknown>>; commands: Command[]; pluginSeenAt?: number }>();
const wsChannels = new WeakMap<ServerWebSocket<unknown>, string>();

function channel(name: string) {
  let value = channels.get(name);
  if (!value) {
    value = { clients: new Set(), commands: [] };
    channels.set(name, value);
  }
  return value;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } });
}

async function body(req: Request): Promise<Record<string, any> | null> {
  try { return await req.json() as Record<string, any>; } catch { return null; }
}

const port = Number(process.env.ROBLOX_RELAY_PORT ?? 3056);
const server = Bun.serve({
  port,
  fetch(req: Request, bunServer: Server) {
    const url = new URL(req.url);
    if (req.method === "OPTIONS") return new Response(null, { headers: { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Methods": "GET,POST,OPTIONS", "Access-Control-Allow-Headers": "Content-Type" } });
    if (url.pathname === "/ws" && bunServer.upgrade(req)) return;
    if (url.pathname === "/health") return json({ ok: true, service: "roblox-ai-bridge" });

    if (req.method === "GET" && url.pathname === "/roblox/poll") {
      const name = url.searchParams.get("channel");
      if (!name) return json({ error: "channel is required" }, 400);
      const state = channel(name);
      state.pluginSeenAt = Date.now();
      return json({ command: state.commands.shift() ?? null });
    }

    if (req.method === "POST" && url.pathname === "/roblox/join") {
      return body(req).then(data => {
        if (!data?.channel || typeof data.channel !== "string") return json({ error: "channel is required" }, 400);
        channel(data.channel).pluginSeenAt = Date.now();
        return json({ ok: true, channel: data.channel });
      });
    }

    if (req.method === "POST" && (url.pathname === "/roblox/respond" || url.pathname === "/roblox/event")) {
      return body(req).then(data => {
        if (!data?.channel || !data?.id) return json({ error: "channel and id are required" }, 400);
        const state = channel(data.channel);
        const payload = { type: "broadcast", message: { id: data.id, result: data.result, error: data.error } };
        for (const client of state.clients) if (client.readyState === WebSocket.OPEN) client.send(JSON.stringify(payload));
        return json({ ok: true });
      });
    }
    return new Response("Roblox AI Bridge relay is running", { headers: { "Access-Control-Allow-Origin": "*" } });
  },
  websocket: {
    open() {},
    message(ws, raw) {
      let data: any;
      try { data = JSON.parse(String(raw)); } catch { ws.send(JSON.stringify({ type: "error", message: "Invalid JSON" })); return; }
      if (data.type === "join") {
        if (!data.channel || typeof data.channel !== "string") { ws.send(JSON.stringify({ type: "error", message: "channel is required" })); return; }
        const state = channel(data.channel);
        state.clients.add(ws);
        wsChannels.set(ws, data.channel);
        ws.send(JSON.stringify({ type: "system", message: { id: data.id, result: `Joined channel: ${data.channel}` } }));
        return;
      }
      if (data.type === "message") {
        const name = wsChannels.get(ws);
        const command = data.message;
        if (!name) { ws.send(JSON.stringify({ type: "error", message: "Join a channel first" })); return; }
        if (!command?.id || !command?.command) { ws.send(JSON.stringify({ type: "error", message: "Invalid command" })); return; }
        channel(name).commands.push({ id: command.id, command: command.command, params: command.params ?? {} });
      }
    },
    close(ws) {
      const name = wsChannels.get(ws);
      if (name) channel(name).clients.delete(ws);
    }
  }
});

console.log(`Roblox AI Bridge relay listening on http://127.0.0.1:${server.port}`);
