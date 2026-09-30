#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import WebSocket from "ws";
import { v4 as uuidv4 } from "uuid";

const log = (level: string, message: string) => process.stderr.write(`[${level}] ${message}\n`);
const relayPort = Number(process.env.ROBLOX_RELAY_PORT ?? 3056);
const relayUrl = process.env.ROBLOX_RELAY_URL ?? `ws://127.0.0.1:${relayPort}/ws`;
let socket: WebSocket | null = null;
let currentChannel: string | null = null;
const pending = new Map<string, { resolve: (value: unknown) => void; reject: (reason: Error) => void; timeout: ReturnType<typeof setTimeout> }>();

function connect() {
  if (socket && (socket.readyState === WebSocket.OPEN || socket.readyState === WebSocket.CONNECTING)) return;
  socket = new WebSocket(relayUrl);
  socket.on("open", () => { currentChannel = null; log("INFO", `Connected to Roblox relay at ${relayUrl}`); });
  socket.on("message", raw => {
    try {
      const message = JSON.parse(String(raw)).message;
      if (!message?.id || !pending.has(message.id)) return;
      const request = pending.get(message.id)!;
      clearTimeout(request.timeout); pending.delete(message.id);
      if (message.error) request.reject(new Error(message.error)); else request.resolve(message.result);
    } catch (error) { log("ERROR", `Could not parse relay response: ${String(error)}`); }
  });
  socket.on("close", () => { socket = null; currentChannel = null; for (const [id, request] of pending) { clearTimeout(request.timeout); request.reject(new Error("Roblox relay connection closed")); pending.delete(id); } setTimeout(connect, 2000); });
  socket.on("error", error => log("ERROR", `Relay socket error: ${error.message}`));
}

function send(command: string, params: Record<string, unknown> = {}, timeoutMs = 30000): Promise<unknown> {
  return new Promise((resolve, reject) => {
    if (!socket || socket.readyState !== WebSocket.OPEN) { connect(); reject(new Error("Not connected to the Roblox relay yet. Ensure `bun run roblox:relay` is running, then retry.")); return; }
    if (!currentChannel) { reject(new Error("Call join_channel before issuing Roblox commands.")); return; }
    const id = uuidv4();
    const timeout = setTimeout(() => { if (pending.delete(id)) reject(new Error(`Roblox Studio did not respond to ${command} within ${timeoutMs / 1000}s. Check that the plugin is running and connected.`)); }, timeoutMs);
    pending.set(id, { resolve, reject, timeout });
    socket.send(JSON.stringify({ type: "message", message: { id, command, params } }));
  });
}

function result(value: unknown) { return { content: [{ type: "text" as const, text: JSON.stringify(value, null, 2) }] }; }
function failure(prefix: string, error: unknown) { return result({ error: `${prefix}: ${error instanceof Error ? error.message : String(error)}` }); }

const server = new McpServer({ name: "RobloxStudioMCP", version: "0.1.0" });
server.tool("join_channel", "Connect this AI session to the named Roblox Studio plugin channel.", { channel: z.string().min(1).describe("Channel shown in the Roblox AI Bridge toolbar") }, async ({ channel }) => {
  try {
    if (!socket || socket.readyState !== WebSocket.OPEN) { connect(); await new Promise<void>((resolve, reject) => { const timer = setTimeout(() => reject(new Error("Timed out connecting to relay")), 3000); socket!.once("open", () => { clearTimeout(timer); resolve(); }); socket!.once("error", reject); }); }
    const id = uuidv4();
    const joined = new Promise<unknown>((resolve, reject) => { const timeout = setTimeout(() => { pending.delete(id); reject(new Error("Relay did not confirm the channel")); }, 5000); pending.set(id, { resolve, reject, timeout }); });
    socket!.send(JSON.stringify({ type: "join", id, channel })); await joined; currentChannel = channel;
    return result({ ok: true, channel, next: "Call get_place_info or get_selection before making changes." });
  } catch (error) { return failure("Could not join channel", error); }
});
server.tool("get_place_info", "Read the current Roblox place structure and key service child counts.", {}, async () => { try { return result(await send("get_place_info")); } catch (e) { return failure("Could not read place", e); } });
server.tool("get_selection", "Read the currently selected instances in Roblox Studio, including their paths and editable properties.", {}, async () => { try { return result(await send("get_selection")); } catch (e) { return failure("Could not read selection", e); } });
server.tool("find_instances", "Find Roblox instances by name, class, or both. Always inspect results before modifying or deleting instances.", { name: z.string().optional(), className: z.string().optional(), maxResults: z.number().int().min(1).max(200).optional() }, async params => { try { return result(await send("find_instances", params)); } catch (e) { return failure("Could not find instances", e); } });
server.tool("create_part", "Create a safe basic Part in Workspace. Position and size use Roblox studs.", { name: z.string().min(1), position: z.tuple([z.number(), z.number(), z.number()]).optional(), size: z.tuple([z.number().positive(), z.number().positive(), z.number().positive()]).optional(), color: z.tuple([z.number().min(0).max(255), z.number().min(0).max(255), z.number().min(0).max(255)]).optional(), anchored: z.boolean().optional(), parentPath: z.string().optional() }, async params => { try { return result(await send("create_part", params)); } catch (e) { return failure("Could not create part", e); } });
server.tool("create_model", "Create an empty Model under Workspace or a specified existing parent path.", { name: z.string().min(1), parentPath: z.string().optional() }, async params => { try { return result(await send("create_model", params)); } catch (e) { return failure("Could not create model", e); } });
server.tool("set_instance_properties", "Set a small allow-listed group of editable Roblox instance properties. Do not use this for arbitrary Lua execution.", { path: z.string().min(1), name: z.string().optional(), anchored: z.boolean().optional(), canCollide: z.boolean().optional(), transparency: z.number().min(0).max(1).optional(), size: z.tuple([z.number().positive(), z.number().positive(), z.number().positive()]).optional(), position: z.tuple([z.number(), z.number(), z.number()]).optional(), color: z.tuple([z.number().min(0).max(255), z.number().min(0).max(255), z.number().min(0).max(255)]).optional() }, async params => { try { return result(await send("set_instance_properties", params)); } catch (e) { return failure("Could not update instance", e); } });
server.tool("delete_instance", "Delete one Roblox instance by its full path. Inspect it first with find_instances or get_selection.", { path: z.string().min(1) }, async params => { try { return result(await send("delete_instance", params)); } catch (e) { return failure("Could not delete instance", e); } });

async function main() { connect(); await server.connect(new StdioServerTransport()); log("INFO", "Roblox Studio MCP running on stdio"); }
main().catch(error => { log("ERROR", String(error)); process.exit(1); });
