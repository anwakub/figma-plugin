import WebSocket from 'ws';

export async function bridge(channel = 'roblox-studio') {
  const socket = new WebSocket('ws://127.0.0.1:3056/ws');
  const pending = new Map();
  socket.on('message', raw => {
    const response = JSON.parse(String(raw)).message;
    const request = pending.get(response?.id);
    if (!request) return;
    clearTimeout(request.timer);
    pending.delete(response.id);
    // Compatibility with the first installed plugin: successful table results
    // were accompanied by a spurious "table: 0x..." error.
    const legacyError = response.result !== undefined && /^table: 0x[0-9a-f]+$/i.test(response.error ?? '');
    if (response.error && !legacyError) request.reject(new Error(response.error));
    else request.resolve(response.result);
  });
  await new Promise((resolve, reject) => { socket.once('open', resolve); socket.once('error', reject); });
  function request(payload) {
    return new Promise((resolve, reject) => {
      const id = crypto.randomUUID();
      const timer = setTimeout(() => { pending.delete(id); reject(new Error('Studio response timed out')); }, 15000);
      pending.set(id, { resolve, reject, timer });
      socket.send(JSON.stringify(payload(id)));
    });
  }
  await request(id => ({ type: 'join', id, channel }));
  return {
    send: (command, params = {}) => request(id => ({ type: 'message', message: { id, command, params } })),
    close: () => socket.close(),
  };
}

if (process.argv[1]?.endsWith('roblox-bridge-client.mjs')) {
  const client = await bridge();
  try {
    const info = await client.send('get_place_info');
    console.log(JSON.stringify({ name: info.placeName, workspace: info.services.find(s => s.name === 'Workspace'), selection: await client.send('get_selection'), models: await client.send('find_instances', { className: 'Model', maxResults: 30 }) }));
  } finally { client.close(); }
}
