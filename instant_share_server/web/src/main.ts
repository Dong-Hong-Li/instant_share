import type { ShareArticle, ShareFile, ShareStatus } from "./api";
import { openQrModal } from "./qr-modal";
import { absoluteUrl, fileKind, formatTotalSize } from "./utils";
import { connectShareStatus } from "./ws";
import "./style.css";

type ViewMode = "article" | "file";

const selectedIds = new Set<string>();
let currentFiles: ShareFile[] = [];
let currentArticles: ShareArticle[] = [];
let shareActive = false;
let viewMode: ViewMode = "article";

function normalizeArticles(
  status: ShareStatus & { article?: ShareArticle | null },
): ShareArticle[] {
  if (status.articles.length > 0) {
    return status.articles;
  }
  if (status.article) {
    return [status.article];
  }
  return [];
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function syncSelection(files: ShareFile[]): void {
  const validIds = new Set(files.map((file) => file.id));
  for (const id of selectedIds) {
    if (!validIds.has(id)) {
      selectedIds.delete(id);
    }
  }
}

function renderModeTabs(): string {
  const fileSelected = viewMode === "file";

  return `
    <div
      class="share-mode-tabs ${shareActive ? "share-mode-tabs--sharing" : ""} ${fileSelected ? "share-mode-tabs--file" : "share-mode-tabs--article"}"
      role="tablist"
      aria-label="分享类型"
    >
      <div class="share-mode-tabs__track">
        <div class="share-mode-tabs__slider" aria-hidden="true"></div>
        <button
          type="button"
          class="share-mode-tab ${fileSelected ? "" : "is-active"}"
          data-mode="article"
          role="tab"
          aria-selected="${fileSelected ? "false" : "true"}"
        >
          <span class="share-mode-tab__icon" aria-hidden="true">${renderSparkleIcon()}</span>
          <span>分享文章</span>
        </button>
        <button
          type="button"
          class="share-mode-tab ${fileSelected ? "is-active" : ""}"
          data-mode="file"
          role="tab"
          aria-selected="${fileSelected ? "true" : "false"}"
        >
          <span class="share-mode-tab__icon" aria-hidden="true">${renderFileIcon()}</span>
          <span>分享文件</span>
        </button>
      </div>
    </div>`;
}

function renderSparkleIcon(): string {
  return `
    <svg viewBox="0 0 16 16" width="15" height="15" fill="currentColor">
      <path d="M8 1.2 9.1 5.9 13.8 7 9.1 8.1 8 12.8 6.9 8.1 2.2 7 6.9 5.9 8 1.2Zm4.8 1.5.6 2.1 2.1.6-2.1.6-.6 2.1-.6-2.1-2.1-.6 2.1-.6.6-2.1ZM3.2 10.8l.4 1.4 1.4.4-1.4.4-.4 1.4-.4-1.4-1.4-.4 1.4-.4.4-1.4Z" />
    </svg>`;
}

function renderFileIcon(): string {
  return `
    <svg viewBox="0 0 16 16" width="15" height="15" fill="currentColor">
      <path d="M4 1.5h5.2L12 4.3V13.5A1.5 1.5 0 0 1 10.5 15h-6A1.5 1.5 0 0 1 3 13.5v-11A1.5 1.5 0 0 1 4.5 1H4Zm5 0V5h3.5L9 1.5ZM5 7.25h6v1H5v-1Zm0 2.75h4.5v1H5v-1Z" />
    </svg>`;
}
function renderStatusMeta(status: ShareStatus): string {
  if (status.active) {
    const parts: string[] = [];
    if (status.articles.length > 0) {
      parts.push(`${status.articles.length} 篇文章`);
    }
    if (status.files.length > 0) {
      parts.push(`${status.files.length} 个文件 · ${formatTotalSize(status.files)}`);
    }
    const meta = parts.length > 0 ? parts.join(" · ") : "分享进行中";

    return `
      <span class="status-indicator status-indicator--active">
        <span class="status-dot" aria-hidden="true"></span>
        分享进行中
      </span>
      <span class="status-meta">${meta}</span>`;
  }

  return `
    <span class="status-indicator status-indicator--idle">
      <span class="status-dot" aria-hidden="true"></span>
      等待分享
    </span>
    <span class="status-meta">发起者尚未开启分享</span>`;
}

function renderArticlePanel(article: ShareArticle): string {
  const title = article.title.trim() || "无标题";
  const content = article.content.trim();

  return `
    <section class="article-panel">
      <div class="article-panel__header">
        <h2 class="article-panel__title">${escapeHtml(title)}</h2>
        <button
          type="button"
          class="btn btn-ghost copy-article-btn"
          data-article-id="${escapeHtml(article.id)}"
        >复制正文</button>
      </div>
      <div class="article-panel__body">${escapeHtml(content).replaceAll("\n", "<br />")}</div>
    </section>`;
}

function renderArticlesPanel(articles: ShareArticle[]): string {
  return `
    <div class="articles-panel">
      ${articles.map(renderArticlePanel).join("")}
    </div>`;
}

function renderArticleEmptyPanel(): string {
  return `
    <div class="empty-state">
      <p class="empty-state__title">暂无文章</p>
      <p class="empty-state__desc">发起者尚未发布文章，或当前没有标记为已分享的文章。</p>
    </div>`;
}

function renderFileEmptyPanel(): string {
  return `
    <div class="empty-state">
      <p class="empty-state__title">暂无文件</p>
      <p class="empty-state__desc">发起者尚未添加可下载的文件。</p>
    </div>`;
}

function renderToolbar(files: ShareFile[]): string {
  if (files.length === 0) {
    return "";
  }

  const selectedCount = files.filter((file) => selectedIds.has(file.id)).length;
  const allSelected = files.length > 0 && selectedCount === files.length;

  return `
    <div class="panel-toolbar">
      <label class="toolbar-select">
        <input
          type="checkbox"
          class="file-checkbox select-all-checkbox"
          ${allSelected ? "checked" : ""}
          aria-label="全选文件"
        />
        <span>全选</span>
      </label>
      <span class="toolbar-divider" aria-hidden="true"></span>
      <span class="toolbar-summary">已选 ${selectedCount} / ${files.length}</span>
      <div class="toolbar-actions">
        <button
          type="button"
          class="btn btn-primary batch-download-btn"
          ${selectedCount === 0 ? "disabled" : ""}
        >下载选中</button>
      </div>
    </div>`;
}

function renderFileRow(file: ShareFile): string {
  const downloadUrl = absoluteUrl(file.download_url);
  const kind = fileKind(file.name);
  const checked = selectedIds.has(file.id) ? "checked" : "";

  return `
    <tr class="file-row">
      <td class="col-check">
        <input
          type="checkbox"
          class="file-checkbox row-checkbox"
          data-file-id="${escapeHtml(file.id)}"
          ${checked}
          aria-label="选择 ${escapeHtml(file.name)}"
        />
      </td>
      <td class="col-name">
        <div class="file-cell">
          <span class="file-type file-type-${kind}" aria-hidden="true">${kind.toUpperCase()}</span>
          <div class="file-meta">
            <div class="file-name" title="${escapeHtml(file.name)}">${escapeHtml(file.name)}</div>
          </div>
        </div>
      </td>
      <td class="col-size">${escapeHtml(file.size_text)}</td>
      <td class="col-actions">
        <button
          type="button"
          class="btn btn-ghost qr-btn"
          data-qr-name="${escapeHtml(file.name)}"
          data-qr-url="${escapeHtml(downloadUrl)}"
        >二维码</button>
        <a class="btn btn-ghost" href="${escapeHtml(file.download_url)}" download="${escapeHtml(file.name)}">下载</a>
      </td>
    </tr>`;
}

function renderFilePanel(files: ShareFile[]): string {
  return `
    <div class="panel-list">
      ${renderToolbar(files)}
      <div class="table-wrap">
        <table class="file-table">
          <thead>
            <tr>
              <th class="col-check" scope="col"></th>
              <th class="col-name" scope="col">文件名</th>
              <th class="col-size" scope="col">大小</th>
              <th class="col-actions" scope="col">操作</th>
            </tr>
          </thead>
          <tbody>
            ${files.map(renderFileRow).join("")}
          </tbody>
        </table>
      </div>
    </div>`;
}

function renderActivePanel(status: ShareStatus): string {
  if (viewMode === "article") {
    if (status.articles.length > 0) {
      return renderArticlesPanel(status.articles);
    }
    return renderArticleEmptyPanel();
  }

  if (status.files.length > 0) {
    return renderFilePanel(status.files);
  }
  return renderFileEmptyPanel();
}

function renderInactivePanel(): string {
  if (viewMode === "article") {
    return `
      <div class="empty-state">
        <p class="empty-state__title">暂无可用文章</p>
        <p class="empty-state__desc">请在发起者桌面端开启分享后，通过本页面接收文章。</p>
      </div>`;
  }

  return `
    <div class="empty-state">
      <p class="empty-state__title">暂无可用文件</p>
      <p class="empty-state__desc">请在发起者桌面端开启分享后，通过本页面下载文件。</p>
    </div>`;
}

function renderErrorPanel(message: string): string {
  return `
    <div class="empty-state empty-state--error">
      <p class="empty-state__title">连接异常</p>
      <p class="empty-state__desc">${escapeHtml(message)}</p>
      <p class="empty-state__hint">系统将自动重试连接，请确认与发起者处于同一局域网。</p>
    </div>`;
}

function renderConnectingPanel(): string {
  return `
    <div class="empty-state">
      <p class="empty-state__title">正在连接服务</p>
      <p class="empty-state__desc">正在建立 WebSocket 连接并同步分享状态…</p>
    </div>`;
}

function renderShell(statusBar: string, panelBody: string, options?: { showTabs?: boolean }): string {
  const showTabs = options?.showTabs ?? true;

  return `
    <div class="app-shell">
      <header class="app-header">
        <div class="app-brand">
          <div class="app-brand__mark" aria-hidden="true">IS</div>
          <div>
            <div class="app-brand__title">Instant Share</div>
            <div class="app-brand__subtitle">文件与文章接收控制台</div>
          </div>
        </div>
        <div class="app-header__status">${statusBar}</div>
      </header>
      <main class="app-main">
        <section class="panel">
          ${showTabs ? renderModeTabs() : ""}
          <div class="panel-body">${panelBody}</div>
        </section>
      </main>
      <footer class="app-footer">局域网分享 · 仅限内网访问</footer>
    </div>`;
}

function renderContent(status: ShareStatus & { article?: ShareArticle | null }): string {
  syncSelection(status.files);
  currentFiles = status.files;
  currentArticles = normalizeArticles(status);
  shareActive = status.active;
  const normalizedStatus: ShareStatus = {
    active: status.active,
    session_id: status.session_id,
    files: status.files,
    articles: currentArticles,
  };
  const panelBody = status.active
    ? renderActivePanel(normalizedStatus)
    : renderInactivePanel();
  return renderShell(renderStatusMeta(normalizedStatus), panelBody);
}

function renderError(message: string): string {
  shareActive = false;
  currentFiles = [];
  currentArticles = [];
  return renderShell(
    `<span class="status-indicator status-indicator--error"><span class="status-dot" aria-hidden="true"></span>连接失败</span>`,
    renderErrorPanel(message),
  );
}

function renderConnecting(): string {
  shareActive = false;
  currentFiles = [];
  currentArticles = [];
  return renderShell(
    `<span class="status-indicator status-indicator--idle"><span class="status-dot" aria-hidden="true"></span>连接中</span>`,
    renderConnectingPanel(),
  );
}

function batchDownloadUrl(ids: string[]): string {
  const params = new URLSearchParams({ ids: ids.join(",") });
  return `/api/v1/share/files/batch/download?${params.toString()}`;
}

function triggerBatchDownload(ids: string[]): void {
  if (ids.length === 0) {
    return;
  }
  const link = document.createElement("a");
  link.href = batchDownloadUrl(ids);
  link.rel = "noopener";
  document.body.appendChild(link);
  link.click();
  link.remove();
}

async function copyArticleContent(
  articleId: string,
  button?: HTMLButtonElement,
): Promise<boolean> {
  const article = currentArticles.find((item) => item.id === articleId);
  if (!article?.content) {
    showToast("暂无可复制的正文");
    return false;
  }

  try {
    await navigator.clipboard.writeText(article.content);
  } catch {
    try {
      const textarea = document.createElement("textarea");
      textarea.value = article.content;
      document.body.appendChild(textarea);
      textarea.select();
      document.execCommand("copy");
      textarea.remove();
    } catch {
      showToast("复制失败，请手动选择正文复制");
      return false;
    }
  }

  showToast("正文已复制");
  if (button) {
    const original = button.textContent ?? "复制正文";
    button.textContent = "已复制";
    window.setTimeout(() => {
      button.textContent = original;
    }, 1600);
  }
  return true;
}

let toastTimer: number | null = null;

function showToast(message: string): void {
  let toast = document.querySelector<HTMLElement>(".app-toast");
  if (!toast) {
    toast = document.createElement("div");
    toast.className = "app-toast";
    toast.setAttribute("role", "status");
    toast.setAttribute("aria-live", "polite");
    document.body.appendChild(toast);
  }

  toast.textContent = message;
  toast.classList.add("is-visible");

  if (toastTimer !== null) {
    window.clearTimeout(toastTimer);
  }
  toastTimer = window.setTimeout(() => {
    toast?.classList.remove("is-visible");
    toastTimer = null;
  }, 2000);
}

function currentShareStatus(): ShareStatus {
  return {
    active: shareActive,
    files: currentFiles,
    articles: currentArticles,
  };
}

function bindAppEvents(root: HTMLElement): void {
  root.addEventListener("click", (event) => {
    const target = event.target as HTMLElement;

    const modeTab = target.closest<HTMLButtonElement>(".share-mode-tab");
    if (modeTab?.dataset.mode) {
      const nextMode = modeTab.dataset.mode as ViewMode;
      if (nextMode !== viewMode) {
        viewMode = nextMode;
        root.innerHTML = renderContent(currentShareStatus());
      }
      return;
    }

    const copyButton = target.closest<HTMLButtonElement>(".copy-article-btn");
    if (copyButton?.dataset.articleId) {
      void copyArticleContent(copyButton.dataset.articleId, copyButton);
      return;
    }

    const qrButton = target.closest<HTMLButtonElement>(".qr-btn");
    if (qrButton) {
      const fileName = qrButton.dataset.qrName;
      const url = qrButton.dataset.qrUrl;
      if (fileName && url) {
        void openQrModal(fileName, url);
      }
      return;
    }

    const batchButton = target.closest<HTMLButtonElement>(".batch-download-btn");
    if (batchButton && !batchButton.disabled) {
      const ids = currentFiles
        .filter((file) => selectedIds.has(file.id))
        .map((file) => file.id);
      triggerBatchDownload(ids);
    }
  });

  root.addEventListener("change", (event) => {
    if (!shareActive) {
      return;
    }

    const target = event.target as HTMLElement;

    if (target.classList.contains("select-all-checkbox")) {
      const checkbox = target as HTMLInputElement;
      selectedIds.clear();
      if (checkbox.checked) {
        for (const file of currentFiles) {
          selectedIds.add(file.id);
        }
      }
      root.innerHTML = renderContent({ ...currentShareStatus(), active: true });
      return;
    }

    if (target.classList.contains("row-checkbox")) {
      const checkbox = target as HTMLInputElement;
      const fileId = checkbox.dataset.fileId;
      if (!fileId) {
        return;
      }
      if (checkbox.checked) {
        selectedIds.add(fileId);
      } else {
        selectedIds.delete(fileId);
      }
      root.innerHTML = renderContent({ ...currentShareStatus(), active: true });
    }
  });
}

function mount(root: HTMLElement): void {
  bindAppEvents(root);
  root.innerHTML = renderConnecting();

  const disconnectWs = connectShareStatus({
    onStatus: (status) => {
      root.innerHTML = renderContent(status);
    },
    onError: (message) => {
      root.innerHTML = renderError(message);
    },
  });

  window.addEventListener("beforeunload", () => {
    disconnectWs();
  });
}

const app = document.querySelector<HTMLElement>("#app");
if (app) {
  mount(app);
}
