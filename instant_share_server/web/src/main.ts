import type { ShareArticle, ShareFile, ShareStatus } from "./api";
import { openQrModal } from "./qr-modal";
import { absoluteUrl, fileKind, formatTotalSize } from "./utils";
import { connectShareStatus } from "./ws";
import "./style.css";

const selectedIds = new Set<string>();
let currentFiles: ShareFile[] = [];
let currentArticle: ShareArticle | null = null;
let shareActive = false;

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

function renderStatusMeta(status: ShareStatus): string {
  if (status.active) {
    const parts: string[] = [];
    if (status.article) {
      parts.push("1 篇文章");
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
        <div>
          <div class="article-panel__label">分享文章</div>
          <h2 class="article-panel__title">${escapeHtml(title)}</h2>
        </div>
        <button type="button" class="btn btn-ghost copy-article-btn">复制正文</button>
      </div>
      <div class="article-panel__body">${escapeHtml(content).replaceAll("\n", "<br />")}</div>
    </section>`;
}

function renderEmptySharePanel(): string {
  return `
    <div class="empty-state">
      <p class="empty-state__title">当前没有可接收内容</p>
      <p class="empty-state__desc">发起者已开启分享，但尚未发布文章或添加文件。</p>
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

function renderActivePanel(status: ShareStatus): string {
  const sections: string[] = [];

  if (status.article) {
    sections.push(renderArticlePanel(status.article));
  }

  if (status.files.length > 0) {
    sections.push(`
      <div class="panel-list">
        ${renderToolbar(status.files)}
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
              ${status.files.map(renderFileRow).join("")}
            </tbody>
          </table>
        </div>
      </div>`);
  }

  if (sections.length === 0) {
    return renderEmptySharePanel();
  }

  return sections.join("");
}

function renderInactivePanel(): string {
  return `
    <div class="empty-state">
      <p class="empty-state__title">暂无可用内容</p>
      <p class="empty-state__desc">请在发起者桌面端开启分享后，通过本页面接收文章或下载文件。</p>
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

function renderShell(statusBar: string, panelBody: string): string {
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
        <section class="panel">${panelBody}</section>
      </main>
      <footer class="app-footer">局域网分享 · 仅限内网访问</footer>
    </div>`;
}

function renderContent(status: ShareStatus): string {
  syncSelection(status.files);
  currentFiles = status.files;
  currentArticle = status.article ?? null;
  shareActive = status.active;
  const panelBody = status.active ? renderActivePanel(status) : renderInactivePanel();
  return renderShell(renderStatusMeta(status), panelBody);
}

function renderError(message: string): string {
  shareActive = false;
  currentFiles = [];
  currentArticle = null;
  return renderShell(
    `<span class="status-indicator status-indicator--error"><span class="status-dot" aria-hidden="true"></span>连接失败</span>`,
    renderErrorPanel(message),
  );
}

function renderConnecting(): string {
  shareActive = false;
  currentFiles = [];
  currentArticle = null;
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

async function copyArticleContent(): Promise<void> {
  if (!currentArticle?.content) {
    return;
  }

  try {
    await navigator.clipboard.writeText(currentArticle.content);
  } catch {
    const textarea = document.createElement("textarea");
    textarea.value = currentArticle.content;
    document.body.appendChild(textarea);
    textarea.select();
    document.execCommand("copy");
    textarea.remove();
  }
}

function bindAppEvents(root: HTMLElement): void {
  root.addEventListener("click", (event) => {
    const target = event.target as HTMLElement;

    if (target.closest(".copy-article-btn")) {
      void copyArticleContent();
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
    if (!batchButton || batchButton.disabled) {
      return;
    }

    const ids = currentFiles
      .filter((file) => selectedIds.has(file.id))
      .map((file) => file.id);
    triggerBatchDownload(ids);
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
      root.innerHTML = renderContent({ active: true, files: currentFiles, article: currentArticle });
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
      root.innerHTML = renderContent({ active: true, files: currentFiles, article: currentArticle });
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
