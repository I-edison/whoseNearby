import { WebSocketServer, WebSocket } from 'ws';
import type { Server } from 'http';
import jwt from 'jsonwebtoken';

type Client = {
  ws: WebSocket;
  userId: string;
  jobId: string | null;
};

const clients = new Set<Client>();

export function createWsServer(server: Server) {
  const wss = new WebSocketServer({ server, path: '/ws' });

  wss.on('connection', (ws, req) => {
    try {
      const url = new URL(req.url || '', 'http://localhost');
      const token = url.searchParams.get('token');
      if (!token) {
        ws.close(4001, 'Missing token');
        return;
      }
      const secret = process.env.JWT_SECRET || 'whosenearby-dev-secret';
      const payload = jwt.verify(token, secret) as { userId: string };
      const client: Client = { ws, userId: payload.userId, jobId: null };
      clients.add(client);

      ws.on('message', (raw) => {
        try {
          const msg = JSON.parse(raw.toString());
          if (msg.type === 'join' && typeof msg.jobId === 'string') {
            client.jobId = msg.jobId;
            ws.send(JSON.stringify({ type: 'joined', jobId: msg.jobId }));
          }
          if (msg.type === 'leave') {
            client.jobId = null;
          }
          if (msg.type === 'ping') {
            ws.send(JSON.stringify({ type: 'pong' }));
          }
        } catch {
          // ignore
        }
      });

      ws.on('close', () => clients.delete(client));
      ws.on('error', () => clients.delete(client));

      ws.send(JSON.stringify({ type: 'ready', userId: payload.userId }));
    } catch {
      ws.close(4003, 'Invalid token');
    }
  });

  return wss;
}

export function broadcastToJob(
  jobId: string,
  payload: Record<string, unknown>,
  exceptUserId?: string
) {
  const data = JSON.stringify(payload);
  for (const c of clients) {
    if (c.jobId !== jobId) continue;
    if (exceptUserId && c.userId === exceptUserId) continue;
    if (c.ws.readyState === WebSocket.OPEN) {
      c.ws.send(data);
    }
  }
}

export function notifyUser(userId: string, payload: Record<string, unknown>) {
  const data = JSON.stringify(payload);
  for (const c of clients) {
    if (c.userId !== userId) continue;
    if (c.ws.readyState === WebSocket.OPEN) {
      c.ws.send(data);
    }
  }
}
