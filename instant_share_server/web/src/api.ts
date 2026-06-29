export interface ShareFile {
  id: string;
  name: string;
  size: number;
  size_text: string;
  download_url: string;
}

export interface ShareArticle {
  id: string;
  title: string;
  content: string;
}

export interface ShareStatus {
  active: boolean;
  session_id?: string;
  files: ShareFile[];
  article?: ShareArticle | null;
}

export interface APIResponse<T> {
  ok: boolean;
  message?: string;
  data?: T;
}

export async function fetchShareStatus(): Promise<ShareStatus> {
  const response = await fetch("/api/v1/share/status");
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }

  const payload = (await response.json()) as APIResponse<ShareStatus>;
  if (!payload.ok || !payload.data) {
    throw new Error(payload.message ?? "加载分享状态失败");
  }

  return payload.data;
}
