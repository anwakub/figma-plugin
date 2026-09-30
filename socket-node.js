import http from 'http';
import { WebSocketServer, WebSocket } from 'ws';

const PORT = process.env.PORT || 3055;

// Create HTTP server for health check and CORS preflight
const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('WebSocket server running');
});

// Create WebSocket server attached to HTTP server
const wss = new WebSocketServer({ server });

// Store clients by channel
const channels = new Map();

wss.on('connection', (ws) => {
  console.log('New client connected');

  // Send welcome message to the new client
  ws.send(JSON.stringify({
    type: 'system',
    message: 'Please join a channel to start chatting',
  }));

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message.toString());
      console.log(`\n=== Received message from client ===`);
      console.log(`Type: ${data.type}, Channel: ${data.channel || 'N/A'}`);
      if (data.message?.command) {
        console.log(`Command: ${data.message.command}, ID: ${data.id}`);
      } else if (data.message?.result) {
        console.log(`Response: ID: ${data.id}, Has Result: ${!!data.message.result}`);
      }

      if (data.type === 'join') {
        const channelName = data.channel;
        if (!channelName || typeof channelName !== 'string') {
          ws.send(JSON.stringify({
            type: 'error',
            message: 'Channel name is required',
          }));
          return;
        }

        if (!channels.has(channelName)) {
          channels.set(channelName, new Set());
        }

        const channelClients = channels.get(channelName);
        channelClients.add(ws);

        console.log(`\n✓ Client joined channel "${channelName}" (${channelClients.size} total clients)`);

        ws.send(JSON.stringify({
          type: 'system',
          message: `Joined channel: ${channelName}`,
          channel: channelName,
        }));

        ws.send(JSON.stringify({
          type: 'system',
          message: {
            id: data.id,
            result: 'Connected to channel: ' + channelName,
          },
          channel: channelName,
        }));

        channelClients.forEach((client) => {
          if (client !== ws && client.readyState === WebSocket.OPEN) {
            client.send(JSON.stringify({
              type: 'system',
              message: 'A new user has joined the channel',
              channel: channelName,
            }));
          }
        });
        return;
      }

      if (data.type === 'message') {
        const channelName = data.channel;
        if (!channelName || typeof channelName !== 'string') {
          ws.send(JSON.stringify({
            type: 'error',
            message: 'Channel name is required',
          }));
          return;
        }

        const channelClients = channels.get(channelName);
        if (!channelClients || !channelClients.has(ws)) {
          ws.send(JSON.stringify({
            type: 'error',
            message: 'You must join the channel first',
          }));
          return;
        }

        let broadcastCount = 0;
        channelClients.forEach((client) => {
          if (client !== ws && client.readyState === WebSocket.OPEN) {
            broadcastCount++;
            const broadcastMessage = {
              type: 'broadcast',
              message: data.message,
              sender: 'peer',
              channel: channelName,
            };
            client.send(JSON.stringify(broadcastMessage));
          }
        });

        if (broadcastCount === 0) {
          console.log(`⚠️  No other clients in channel "${channelName}" to receive message!`);
        } else {
          console.log(`✓ Broadcast to ${broadcastCount} peer(s) in channel "${channelName}"`);
        }
      }

      if (data.type === 'progress_update') {
        const channelName = data.channel;
        if (!channelName) return;

        const channelClients = channels.get(channelName);
        if (!channelClients || !channelClients.has(ws)) return;

        channelClients.forEach((client) => {
          if (client !== ws && client.readyState === WebSocket.OPEN) {
            client.send(JSON.stringify(data));
          }
        });
      }
    } catch (err) {
      console.error('Error handling message:', err);
    }
  });

  ws.on('close', () => {
    console.log('Client disconnected');
    channels.forEach((clients, channelName) => {
      if (clients.has(ws)) {
        clients.delete(ws);
        clients.forEach((client) => {
          if (client.readyState === WebSocket.OPEN) {
            client.send(JSON.stringify({
              type: 'system',
              message: 'A user has left the channel',
              channel: channelName,
            }));
          }
        });
      }
    });
  });
});

server.listen(PORT, () => {
  console.log(`WebSocket relay server running on port ${PORT} (Node.js)`);
});
