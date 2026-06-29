import type { ShareStatus } from "./api";

export type ShareStatusListener = (status: ShareStatus) => void;

export interface ShareStatusConnection {
  onStatus: ShareStatusListener;
  onError?: (message: string) => void;
}

const RECONNECT_DELAY_MS = 3000;

let ws: WebSocket | null = null;
let connection: ShareStatusConnection | null = null;
let reconnectTimer: ReturnType<typeof setTimeout> | null = null;
let shouldConnect = false;
let hasReceivedStatus = false;

function viewerDeviceId(): string {
  const key = "instant_share_viewer_id";
  let id = sessionStorage.getItem(key);
  if (!id) {
    if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
      id = crypto.randomUUID();
    } else {
      id = `viewer-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
    }
    sessionStorage.setItem(key, id);
  }
  return id;
}

function wsUrl(): string {
  const protocol = location.protocol === "https:" ? "wss:" : "ws:";
  const params = new URLSearchParams({
    role: "viewer",
    device_id: viewerDeviceId(),
  });
  return `${protocol}//${location.host}/ws?${params.toString()}`;
}

function clearReconnectTimer(): void {
  if (reconnectTimer !== null) {
    clearTimeout(reconnectTimer);
    reconnectTimer = null;
  }
}

function scheduleReconnect(): void {
  if (!shouldConnect || reconnectTimer !== null) {
    return;
  }
  reconnectTimer = setTimeout(() => {
    reconnectTimer = null;
    connect();
  }, RECONNECT_DELAY_MS);
}

function handleMessage(event: MessageEvent<string>): void {
  let payload: {
    type?: string;
    code?: number;
    message?: string;
    data?: ShareStatus;
  };

  try {
    payload = JSON.parse(event.data) as typeof payload;
  } catch {
    return;
  }

  if (payload.type === "auth_ack") {
    if (payload.code !== 0) {
      connection?.onError?.(payload.message ?? "WebSocket 鉴权失败");
    }
    return;
  }

  if (payload.type === "share.status" && payload.code === 0 && payload.data) {
    hasReceivedStatus = true;
    connection?.onStatus(payload.data);
    return;
  }

  if (payload.type === "error" && payload.code !== 0) {
    connection?.onError?.(payload.message ?? "WebSocket 连接异常");
  }
}

function connect(): void {
  if (!shouldConnect) {
    return;
  }

  ws?.close();
  ws = new WebSocket(wsUrl());

  ws.addEventListener("message", handleMessage);
  ws.addEventListener("close", () => {
    if (shouldConnect && hasReceivedStatus) {
      connection?.onError?.("连接已断开，正在重连…");
    }
    scheduleReconnect();
  });
  ws.addEventListener("error", () => {
    ws?.close();
  });
}

export function connectShareStatus(options: ShareStatusConnection): () => void {
  connection = options;
  shouldConnect = true;
  hasReceivedStatus = false;
  connect();

  return () => {
    shouldConnect = false;
    connection = null;
    hasReceivedStatus = false;
    clearReconnectTimer();
    ws?.close();
    ws = null;
  };
}
