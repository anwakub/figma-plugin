import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const channel = process.env.FIGMA_CHANNEL || "ipypclkg";
const mode = process.argv[2] || "inspect";

const flows = [
  {
    name: "Customer journey",
    frames: [
      "9:1215", "9:1216", "9:1217", "9:1293", "9:1294", "9:1295",
      "9:1365", "9:1366", "9:1367", "9:1436", "9:1437", "9:1438",
      "9:1521", "9:1522",
    ],
  },
  {
    name: "Owner journey",
    frames: [
      "9:1523", "9:1585", "9:1586", "9:1587", "9:1672", "9:1673",
      "9:1674", "9:1739", "9:1740", "9:1741", "9:1825", "9:1826", "9:1827",
    ],
  },
];

const frameIds = flows.flatMap((flow) => flow.frames);
const captions = {
  "9:1215": "9:1290", "9:1216": "9:1291", "9:1217": "9:1292",
  "9:1293": "9:1363", "9:1294": "9:1364", "9:1295": "9:1362",
  "9:1365": "9:1434", "9:1366": "9:1418", "9:1367": "9:1435",
  "9:1436": "9:1512", "9:1437": "9:1520", "9:1438": "9:1519",
  "9:1521": "9:1584", "9:1522": "9:1574", "9:1523": "9:1583",
  "9:1585": "9:1671", "9:1586": "9:1670", "9:1587": "9:1652",
  "9:1672": "9:1738", "9:1673": "9:1737", "9:1674": "9:1728",
  "9:1739": "9:1824", "9:1740": "9:1823", "9:1741": "9:1822",
  "9:1825": "9:1908", "9:1826": "9:1909", "9:1827": "9:1892",
};
const transport = new StdioClientTransport({
  command: "node",
  args: ["dist/server.js"],
  cwd: process.cwd(),
  env: { ...process.env, FIGMA_MCP_QUIET: "1" },
});
const client = new Client({ name: "pdf-layout", version: "1.0.0" });

function toolText(result) {
  return result.content?.find((item) => item.type === "text")?.text || "";
}

function parseResult(result) {
  const text = toolText(result);
  const start = [text.indexOf("["), text.indexOf("{")].filter((i) => i >= 0).sort((a, b) => a - b)[0];
  return JSON.parse(text.slice(start));
}

await client.connect(transport);
try {
  let joined = false;
  for (let attempt = 0; attempt < 20 && !joined; attempt += 1) {
    const result = await client.callTool({ name: "join_channel", arguments: { channel } });
    joined = /joined channel/i.test(toolText(result)) && !/error/i.test(toolText(result));
    if (!joined) await new Promise((resolve) => setTimeout(resolve, 250));
  }
  if (!joined) throw new Error(`Could not join Figma channel ${channel}`);

  if (mode === "root") {
    console.log(toolText(await client.callTool({ name: "get_document_info", arguments: {} })));
    process.exit(0);
  }

  if (mode === "verify-labels") {
    const labelIds = [...Object.values(captions), "9:1910", "9:1911", "9:1912"];
    const labels = parseResult(await client.callTool({
      name: "get_nodes_info",
      arguments: { nodeIds: labelIds },
    }));
    for (const item of (Array.isArray(labels) ? labels : [labels])) {
      const node = item.document || item;
      const box = node.absoluteBoundingBox;
      console.log(`${node.id}\t${node.name}\t${box?.x},${box?.y}`);
    }
    process.exit(0);
  }

  const nodes = parseResult(await client.callTool({
    name: "get_nodes_info",
    arguments: { nodeIds: frameIds },
  }));
  const frames = (Array.isArray(nodes) ? nodes : [nodes]).map((item) => item.document || item);

  if (mode === "inspect") {
    for (const frame of frames) {
      const box = frame.absoluteBoundingBox;
      console.log(`${frame.id}\t${frame.name}\t${box?.x},${box?.y}\t${box?.width}x${box?.height}`);
    }
    process.exitCode = 0;
  } else if (mode === "apply") {
    const byId = new Map(frames.map((frame) => [frame.id, frame]));
    const maxWidth = Math.max(...frames.map((frame) => frame.absoluteBoundingBox?.width || 390));
    const maxHeight = Math.max(...frames.map((frame) => frame.absoluteBoundingBox?.height || 844));
    const startX = 0;
    const startY = 100;
    const columns = 4;
    const gapX = 120;
    const gapY = 160;
    let rowOffset = 0;
    const operations = [];

    for (const [flowIndex, flow] of flows.entries()) {
      const flowStartY = startY + rowOffset * (maxHeight + gapY);
      operations.push({
        nodeId: flowIndex === 0 ? "9:1910" : "9:1911",
        x: startX,
        y: flowStartY - 90 + (flowIndex === 1 ? 476 : 0),
      });
      if (flowIndex === 0) {
        operations.push({ nodeId: "9:1912", x: startX, y: flowStartY - 55 });
      }
      for (let index = 0; index < flow.frames.length; index += 1) {
        const nodeId = flow.frames[index];
        if (!byId.has(nodeId)) throw new Error(`Frame ${nodeId} was not returned by Figma`);
        const column = index % columns;
        const row = rowOffset + Math.floor(index / columns);
        const x = startX + column * (maxWidth + gapX);
        const y = startY + row * (maxHeight + gapY);
        operations.push({
          nodeId,
          x,
          y,
        });
        operations.push({ nodeId: captions[nodeId], x, y: y - 30 });
      }
      rowOffset += Math.ceil(flow.frames.length / columns) + 1;
    }

    for (const operation of operations) {
      const result = await client.callTool({ name: "move_node", arguments: operation });
      if (/error/i.test(toolText(result))) throw new Error(toolText(result));
    }
    console.log(`Laid out ${operations.length} frames in two ordered flows (${columns} columns, ${gapX}px × ${gapY}px spacing).`);
  } else {
    throw new Error(`Unknown mode: ${mode}`);
  }
} finally {
  await client.close();
}
