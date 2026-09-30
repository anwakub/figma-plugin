import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { writeFile } from "node:fs/promises";
import path from "node:path";
import os from "node:os";

const channel = process.env.FIGMA_CHANNEL || "i9hezibu";
const mode = process.argv[2] || "inspect";
const inspectOffset = Number(process.env.INSPECT_OFFSET || 0);
const inspectCount = Number(process.env.INSPECT_COUNT || 5);
const inspectIds = process.env.INSPECT_IDS?.split(",").map((id) => id.trim()).filter(Boolean);

const frameIds = [
  "9:1215", "9:1216", "9:1217", "9:1293", "9:1294", "9:1295",
  "9:1365", "9:1366", "9:1367", "9:1436", "9:1437", "9:1438",
  "9:1521", "9:1522", "9:1523", "9:1585", "9:1586", "9:1587",
  "9:1672", "9:1673", "9:1674", "9:1739", "9:1740", "9:1741",
  "9:1825", "9:1826", "9:1827",
];

const transport = new StdioClientTransport({
  command: "node",
  args: ["dist/server.js"],
  cwd: process.cwd(),
  env: { ...process.env, FIGMA_MCP_QUIET: "1" },
});
const client = new Client({ name: "prototype-flow", version: "1.0.0" });

function parseToolJson(result) {
  const text = result.content?.find((item) => item.type === "text")?.text || "";
  const firstBracket = Math.min(
    ...[text.indexOf("["), text.indexOf("{")].filter((index) => index >= 0),
  );
  return JSON.parse(text.slice(firstBracket));
}

function flatten(node, depth = 0, output = [], parentPath = "") {
  const path = parentPath ? `${parentPath} > ${node.name}` : node.name;
  output.push({
    id: node.id,
    name: node.name,
    type: node.type,
    depth,
    characters: node.characters,
    fills: node.fills,
    absoluteBoundingBox: node.absoluteBoundingBox,
    path,
  });
  for (const child of node.children || []) flatten(child, depth + 1, output, path);
  return output;
}

function normalizeFrames(value) {
  return (Array.isArray(value) ? value : [value]).map((frame) =>
    frame.document ? frame : { nodeId: frame.id, document: frame },
  );
}

function hexLuminance(hex) {
  if (!/^#[0-9a-f]{6}$/i.test(hex || "")) return 0;
  const channels = [1, 3, 5].map((offset) => parseInt(hex.slice(offset, offset + 2), 16) / 255);
  const linear = channels.map((value) => value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4);
  return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2];
}

await client.connect(transport);
try {
  let joined = false;
  for (let attempt = 0; attempt < 30 && !joined; attempt += 1) {
    const joinResult = await client.callTool({ name: "join_channel", arguments: { channel } });
    const joinText = joinResult.content?.find((item) => item.type === "text")?.text || "";
    joined = /joined channel/i.test(joinText) && !/error/i.test(joinText);
    if (!joined) await new Promise((resolve) => setTimeout(resolve, 250));
  }
  if (!joined) throw new Error(`Could not join Figma channel ${channel}`);

  if (mode === "inspect") {
    const result = await client.callTool({
      name: "get_nodes_info",
      arguments: { nodeIds: inspectIds || frameIds.slice(inspectOffset, inspectOffset + inspectCount) },
    });
    const parsedFrames = parseToolJson(result);
    const frames = normalizeFrames(parsedFrames);
    for (const frame of frames) {
      const rows = flatten(frame.document).filter((row) =>
        row.depth <= 2 ||
        row.type === "TEXT" ||
        /button|action|leading|upload|option|filter|photo|image|card|nav|close|confirm/i.test(row.name || ""),
      );
      console.log(`\n### ${frame.document.name} (${frame.nodeId})`);
      for (const row of rows) {
        const label = row.characters ? ` :: ${row.characters.replace(/\s+/g, " ").slice(0, 90)}` : "";
        console.log(`${"  ".repeat(row.depth)}${row.id} [${row.type}] ${row.name}${label}`);
      }
    }
  } else if (mode === "apply") {
    const byName = (sourceFrameId, nodeName, type, destinationId) => ({
      sourceFrameId,
      nodeName,
      action: { type, ...(destinationId ? { destinationId } : {}) },
    });
    const byText = (sourceFrameId, characters, targetAncestorDepth, type, destinationId) => ({
      sourceFrameId,
      characters,
      targetAncestorDepth,
      action: { type, ...(destinationId ? { destinationId } : {}) },
    });

    const items = [
      // Customer flow
      byName("9:1215", "New Repair Action", "NAVIGATE", "9:1216"),
      byName("9:1215", "Track Action", "NAVIGATE", "9:1436"),
      byName("9:1216", "Primary Button", "NAVIGATE", "9:1217"),
      byName("9:1216", "Secondary Button", "NAVIGATE", "9:1215"),
      byName("9:1217", "Primary Button", "NAVIGATE", "9:1293"),
      byName("9:1217", "Secondary Button", "BACK"),
      byName("9:1293", "Primary Button", "NAVIGATE", "9:1294"),
      byName("9:1293", "Secondary Button", "BACK"),
      byName("9:1294", "Primary Button", "NAVIGATE", "9:1365"),
      byName("9:1294", "Secondary Button", "BACK"),
      byText("9:1294", "+ เพิ่มรูปภาพ", 1, "OVERLAY", "9:1295"),
      byText("9:1295", "ถ่ายภาพ", 1, "CLOSE"),
      byText("9:1295", "เลือกจากคลังรูปภาพ", 1, "CLOSE"),
      byText("9:1295", "เลือกไฟล์", 1, "CLOSE"),
      byName("9:1365", "Primary Button", "OVERLAY", "9:1366"),
      byName("9:1365", "Secondary Button", "BACK"),
      byName("9:1366", "Primary Button", "NAVIGATE", "9:1367"),
      byName("9:1366", "Secondary Button", "CLOSE"),
      byName("9:1367", "Primary Button", "NAVIGATE", "9:1436"),
      byName("9:1367", "Secondary Button", "NAVIGATE", "9:1215"),
      byName("9:1436", "Primary Button", "NAVIGATE", "9:1437"),
      byName("9:1436", "Secondary Button", "NAVIGATE", "9:1215"),
      byName("9:1437", "Primary Button", "NAVIGATE", "9:1438"),
      byName("9:1437", "Secondary Button", "BACK"),
      byName("9:1438", "Primary Button", "NAVIGATE", "9:1521"),
      byName("9:1438", "Secondary Button", "BACK"),
      byName("9:1521", "Primary Button", "OVERLAY", "9:1522"),
      byName("9:1521", "Secondary Button", "BACK"),
      byName("9:1522", "Primary Button", "NAVIGATE", "9:1437"),
      byName("9:1522", "Secondary Button", "CLOSE"),

      // Owner flow
      byName("9:1523", "Primary Button", "NAVIGATE", "9:1585"),
      byText("9:1585", "ดูรายการทั้งหมด", 1, "NAVIGATE", "9:1586"),
      byText("9:1585", "รายการแจ้งซ่อม", 1, "NAVIGATE", "9:1586"),
      byText("9:1586", "ตัวกรอง", 1, "OVERLAY", "9:1587"),
      byText("9:1586", "RP-2026-00128", 1, "NAVIGATE", "9:1672"),
      byName("9:1587", "Primary Button", "CLOSE"),
      byName("9:1587", "Secondary Button", "CLOSE"),
      byText("9:1672", "ดูรูปภาพ", 1, "NAVIGATE", "9:1673"),
      byName("9:1672", "Primary Button", "NAVIGATE", "9:1739"),
      byName("9:1672", "Secondary Button", "BACK"),
      byText("9:1673", "รูป 1", 1, "OVERLAY", "9:1674"),
      byText("9:1673", "รูป 2", 1, "OVERLAY", "9:1674"),
      byText("9:1673", "รูป 3", 1, "OVERLAY", "9:1674"),
      byName("9:1673", "Secondary Button", "BACK"),
      byText("9:1674", "ปิด", 1, "CLOSE"),
      byName("9:1739", "Primary Button", "NAVIGATE", "9:1740"),
      byName("9:1739", "Secondary Button", "BACK"),
      byName("9:1740", "Primary Button", "NAVIGATE", "9:1741"),
      byName("9:1740", "Secondary Button", "BACK"),
      byName("9:1741", "Primary Button", "NAVIGATE", "9:1825"),
      byName("9:1741", "Secondary Button", "BACK"),
      byText("9:1825", "RP-2026-00124", 1, "NAVIGATE", "9:1826"),
      byName("9:1826", "Primary Button", "OVERLAY", "9:1827"),
      byName("9:1826", "Secondary Button", "BACK"),
      byText("9:1827", "รอรับงาน", 1, "CLOSE"),
      byText("9:1827", "กำลังซ่อม", 1, "CLOSE"),
      byText("9:1827", "ซ่อมเสร็จ", 1, "CLOSE"),

      // Header back controls
      ...["9:1216", "9:1217", "9:1293", "9:1294", "9:1365", "9:1436", "9:1437", "9:1438", "9:1521", "9:1586", "9:1672", "9:1673", "9:1739", "9:1740", "9:1741", "9:1825", "9:1826"].map((frameId) =>
        byName(frameId, "App Leading", "BACK"),
      ),
      ...["9:1295", "9:1366", "9:1522", "9:1587", "9:1674", "9:1827"].map((frameId) =>
        byName(frameId, "App Leading", "CLOSE"),
      ),
    ];

    const result = await client.callTool({
      name: "set_prototype_reactions",
      arguments: { items },
    });
    console.log(result.content?.find((item) => item.type === "text")?.text || JSON.stringify(result));

    const verification = await client.callTool({
      name: "get_reactions",
      arguments: { nodeIds: frameIds },
    });
    console.log(verification.content?.find((item) => item.type === "text")?.text || JSON.stringify(verification));
  } else if (mode === "repair") {
    const node = (nodeId, type, destinationId) => ({
      nodeId,
      action: { type, ...(destinationId ? { destinationId } : {}) },
    });
    const items = [
      // Remove two over-broad frame-level interactions and one overlay-wide close action.
      node("9:1586", "CLEAR"),
      node("9:1825", "CLEAR"),
      node("9:1827", "CLEAR"),

      // Customer upload and confirmation overlays.
      node("9:1331", "OVERLAY", "9:1295"),
      node("9:1338", "CLOSE"),
      node("9:1339", "CLOSE"),
      node("9:1340", "CLOSE"),
      node("9:1427", "OVERLAY", "9:1366"),
      node("9:1406", "NAVIGATE", "9:1367"),
      node("9:1407", "CLOSE"),
      node("9:1573", "OVERLAY", "9:1522"),
      node("9:1562", "NAVIGATE", "9:1437"),
      node("9:1563", "CLOSE"),

      // Owner dashboard, list, filters, photos, and status overlay.
      node("9:1620", "NAVIGATE", "9:1586"),
      node("27:265", "NAVIGATE", "9:1586"),
      node("9:1612", "OVERLAY", "9:1587"),
      node("9:1638", "NAVIGATE", "9:1672"),
      node("9:1632", "CLOSE"),
      node("9:1709", "NAVIGATE", "9:1673"),
      node("9:1698", "OVERLAY", "9:1674"),
      node("9:1699", "OVERLAY", "9:1674"),
      node("9:1710", "OVERLAY", "9:1674"),
      node("9:1713", "OVERLAY", "9:1674"),
      node("9:1727", "BACK"),
      node("9:1703", "CLOSE"),
      node("9:1717", "CLOSE"),
      node("9:1906", "OVERLAY", "9:1827"),
      node("9:1869", "CLOSE"),
      node("9:1870", "CLOSE"),
      node("9:1871", "CLOSE"),
      node("9:1872", "CLOSE"),
    ];

    const result = await client.callTool({
      name: "set_prototype_reactions",
      arguments: { items },
    });
    console.log(result.content?.find((item) => item.type === "text")?.text || JSON.stringify(result));
  } else if (mode === "focus") {
    const focusNodeId = process.env.FOCUS_NODE || "9:1215";
    const result = await client.callTool({
      name: "set_focus",
      arguments: { nodeId: focusNodeId },
    });
    console.log(result.content?.find((item) => item.type === "text")?.text || JSON.stringify(result));
  } else if (mode === "audit-theme") {
    const candidates = [];
    for (let offset = 0; offset < frameIds.length; offset += 4) {
      const result = await client.callTool({
        name: "get_nodes_info",
        arguments: { nodeIds: frameIds.slice(offset, offset + 4) },
      });
      const frames = normalizeFrames(parseToolJson(result));
      for (const frame of frames) {
        const rows = flatten(frame.document);
        for (const row of rows) {
          if (!["FRAME", "RECTANGLE", "ELLIPSE"].includes(row.type)) continue;
          if (/Home Indicator|Logo|App Icon/i.test(row.name || "")) continue;
          const area = (row.absoluteBoundingBox?.width || 0) * (row.absoluteBoundingBox?.height || 0);
          if (area < 400) continue;
          for (const fill of row.fills || []) {
            if (fill.type !== "SOLID" || fill.visible === false) continue;
            const luminance = hexLuminance(fill.color);
            if (luminance >= 0.5 && (fill.opacity ?? 1) >= 0.4) {
              const box = row.absoluteBoundingBox;
              const containedTexts = rows.filter((textRow) => {
                if (textRow.type !== "TEXT" || !textRow.absoluteBoundingBox || !box) return false;
                const textBox = textRow.absoluteBoundingBox;
                const centerX = textBox.x + textBox.width / 2;
                const centerY = textBox.y + textBox.height / 2;
                return centerX >= box.x && centerX <= box.x + box.width && centerY >= box.y && centerY <= box.y + box.height;
              }).map((textRow) => {
                const textFill = (textRow.fills || []).find((paint) => paint.type === "SOLID");
                return {
                  id: textRow.id,
                  name: textRow.name,
                  characters: textRow.characters,
                  color: textFill?.color,
                  opacity: textFill?.opacity ?? 1,
                  luminance: Number(hexLuminance(textFill?.color).toFixed(3)),
                };
              });
              candidates.push({
                frame: frame.document.name,
                id: row.id,
                name: row.name,
                type: row.type,
                color: fill.color,
                opacity: fill.opacity ?? 1,
                luminance: Number(luminance.toFixed(3)),
                area: Math.round(area),
                path: row.path,
                containedTexts,
              });
            }
          }
        }
      }
    }
    console.log(JSON.stringify(candidates, null, 2));
  } else if (mode === "fix-theme") {
    const surfaces = [
      { nodeId: "9:1397", fill: [23, 49, 38], stroke: [69, 212, 131] },
      { nodeId: "9:1607", fill: [32, 36, 55], stroke: [123, 36, 245] },
      { nodeId: "9:1619", fill: [23, 49, 38], stroke: [69, 212, 131] },
      { nodeId: "9:1694", fill: [32, 36, 55], stroke: [123, 36, 245] },
      { nodeId: "9:1699", fill: [32, 36, 55], stroke: [123, 36, 245] },
      { nodeId: "9:1761", fill: [32, 36, 55], stroke: [123, 36, 245] },
      { nodeId: "9:1766", fill: [32, 36, 55], stroke: [123, 36, 245] },
      { nodeId: "9:1771", fill: [23, 49, 38], stroke: [69, 212, 131] },
    ];
    const results = [];
    for (const surface of surfaces) {
      const [r, g, b] = surface.fill.map((value) => value / 255);
      const [sr, sg, sb] = surface.stroke.map((value) => value / 255);
      const fillResult = await client.callTool({
        name: "set_fill_color",
        arguments: { nodeId: surface.nodeId, r, g, b, a: 0.96 },
      });
      const strokeResult = await client.callTool({
        name: "set_stroke_color",
        arguments: { nodeId: surface.nodeId, r: sr, g: sg, b: sb, a: 0.7, weight: 1 },
      });
      results.push({
        nodeId: surface.nodeId,
        fill: fillResult.content?.find((item) => item.type === "text")?.text,
        stroke: strokeResult.content?.find((item) => item.type === "text")?.text,
      });
    }
    console.log(JSON.stringify({ updated: results.length, results }, null, 2));
  } else if (mode === "export-preview") {
    const result = await client.callTool({
      name: "export_node_as_image",
      arguments: { nodeId: "9:1741", format: "PNG", scale: 1 },
    });
    const image = result.content?.find((item) => item.type === "image");
    if (!image?.data) throw new Error("Figma did not return preview image data");
    const outputPath = path.join(os.tmpdir(), "figma-o08-dark-theme-preview.png");
    await writeFile(outputPath, Buffer.from(image.data, "base64"));
    console.log(outputPath);
  }
} finally {
  await client.close();
}
