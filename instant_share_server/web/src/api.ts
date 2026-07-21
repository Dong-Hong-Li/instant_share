export interface ShareFile {
  id: string;
  name: string;
  size: number;
  size_text: string;
  download_url: string;
  owner_display_name?: string;
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
  articles: ShareArticle[];
}

export interface APIResponse<T> {
  ok: boolean;
  message?: string;
  data?: T;
}

function normalizeArticles(data: ShareStatus & { article?: ShareArticle | null }): ShareArticle[] {
  if (Array.isArray(data.articles)) {
    return data.articles;
  }
  if (data.article) {
    return [data.article];
  }
  return [];
}

export async function fetchShareStatus(): Promise<ShareStatus> {
  const response = await fetch("/api/v1/share/status");
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }

  const payload = (await response.json()) as APIResponse<
    ShareStatus & { article?: ShareArticle | null }
  >;
  if (!payload.ok || !payload.data) {
    throw new Error(payload.message ?? "加载分享状态失败");
  }

  return {
    active: payload.data.active,
    session_id: payload.data.session_id,
    files: payload.data.files ?? [],
    articles: normalizeArticles(payload.data),
  };
}
