import QRCode from "qrcode";

let modalRoot: HTMLElement | null = null;

function ensureModal(): HTMLElement {
  if (modalRoot) {
    return modalRoot;
  }

  modalRoot = document.createElement("div");
  modalRoot.className = "modal";
  modalRoot.hidden = true;
  modalRoot.innerHTML = `
    <div class="modal-backdrop" data-close="true"></div>
    <div class="modal-panel" role="dialog" aria-modal="true" aria-labelledby="qr-title">
      <header class="modal-header">
        <div class="modal-header__text">
          <h2 id="qr-title" class="modal-title">移动端下载</h2>
          <p class="modal-subtitle">使用手机扫描二维码或复制链接下载</p>
        </div>
        <button type="button" class="modal-close-icon" aria-label="关闭" data-close="true">
          <span aria-hidden="true">×</span>
        </button>
      </header>
      <div class="modal-body">
        <div class="modal-file-card">
          <span class="modal-file-label">文件</span>
          <span class="modal-file-name"></span>
        </div>
        <div class="qr-section">
          <div class="qr-wrap">
            <canvas class="qr-canvas"></canvas>
          </div>
          <p class="qr-hint">扫码后将在手机浏览器中打开下载</p>
        </div>
        <div class="modal-link-field">
          <label class="modal-link-label" for="qr-download-url">下载链接</label>
          <div class="link-input-row">
            <input
              id="qr-download-url"
              class="modal-link-input"
              type="text"
              readonly
            />
            <button type="button" class="btn btn-secondary copy-link-btn">复制</button>
          </div>
        </div>
      </div>
      <footer class="modal-footer">
        <button type="button" class="btn btn-secondary modal-close-btn" data-close="true">关闭</button>
      </footer>
    </div>`;

  document.body.appendChild(modalRoot);

  modalRoot.addEventListener("click", (event) => {
    const target = event.target as HTMLElement;

    if (target.closest(".copy-link-btn")) {
      void copyDownloadLink();
      return;
    }

    if (target.closest("[data-close='true']")) {
      closeQrModal();
    }
  });

  window.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && modalRoot && !modalRoot.hidden) {
      closeQrModal();
    }
  });

  return modalRoot;
}

async function copyDownloadLink(): Promise<void> {
  const modal = modalRoot;
  if (!modal) {
    return;
  }

  const input = modal.querySelector<HTMLInputElement>(".modal-link-input");
  const button = modal.querySelector<HTMLButtonElement>(".copy-link-btn");
  if (!input || !button) {
    return;
  }

  const url = input.value;
  if (!url) {
    return;
  }

  try {
    await navigator.clipboard.writeText(url);
    button.textContent = "已复制";
    window.setTimeout(() => {
      button.textContent = "复制";
    }, 1600);
  } catch {
    input.select();
    document.execCommand("copy");
    button.textContent = "已复制";
    window.setTimeout(() => {
      button.textContent = "复制";
    }, 1600);
  }
}

export function closeQrModal(): void {
  if (!modalRoot || modalRoot.hidden) {
    return;
  }
  modalRoot.hidden = true;
  document.body.classList.remove("modal-open");
}

export async function openQrModal(fileName: string, url: string): Promise<void> {
  const modal = ensureModal();
  const nameEl = modal.querySelector<HTMLElement>(".modal-file-name");
  const urlInput = modal.querySelector<HTMLInputElement>(".modal-link-input");
  const canvas = modal.querySelector<HTMLCanvasElement>(".qr-canvas");
  const copyButton = modal.querySelector<HTMLButtonElement>(".copy-link-btn");

  if (!nameEl || !urlInput || !canvas || !copyButton) {
    return;
  }

  nameEl.textContent = fileName;
  nameEl.title = fileName;
  urlInput.value = url;
  urlInput.title = url;
  copyButton.textContent = "复制";

  await QRCode.toCanvas(canvas, url, {
    width: 168,
    margin: 0,
    color: {
      dark: "#101828",
      light: "#ffffff",
    },
  });

  modal.hidden = false;
  document.body.classList.add("modal-open");
}
