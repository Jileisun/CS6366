import { sceneLinks } from "./sceneRegistry.js";

let stylesMounted = false;

function ensureStyles() {
  if (stylesMounted) return;

  const style = document.createElement("style");
  style.textContent = `
    html,
    body {
      margin: 0;
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: #040608;
      color: #f2eee5;
    }

    body {
      font-family: "Avenir Next", "Segoe UI", sans-serif;
    }

    canvas {
      display: block;
      width: 100%;
      height: 100%;
    }

    .scene-chrome {
      position: fixed;
      top: 16px;
      left: 16px;
      z-index: 20;
      pointer-events: none;
    }

    .scene-panel {
      width: min(360px, calc(100vw - 32px));
      padding: 14px 16px 16px;
      border: 1px solid rgba(255, 244, 226, 0.14);
      border-radius: 14px;
      background: rgba(9, 14, 18, 0.74);
      box-shadow: 0 18px 50px rgba(0, 0, 0, 0.32);
      backdrop-filter: blur(18px);
      pointer-events: auto;
    }

    .scene-kicker {
      margin: 0 0 6px;
      font-size: 11px;
      letter-spacing: 0.14em;
      text-transform: uppercase;
      color: rgba(242, 238, 229, 0.62);
    }

    .scene-title {
      margin: 0;
      font-size: 24px;
      line-height: 1.1;
      font-weight: 600;
    }

    .scene-description,
    .scene-controls {
      margin: 10px 0 0;
      font-size: 13px;
      line-height: 1.45;
      color: rgba(242, 238, 229, 0.82);
    }

    .scene-nav {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin-top: 14px;
    }

    .scene-nav-link {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      padding: 7px 12px;
      border: 1px solid rgba(242, 238, 229, 0.16);
      border-radius: 999px;
      color: rgba(242, 238, 229, 0.78);
      background: rgba(255, 255, 255, 0.02);
      text-decoration: none;
      font-size: 12px;
      line-height: 1;
      transition: background-color 140ms ease, border-color 140ms ease, color 140ms ease;
    }

    .scene-nav-link:hover {
      background: rgba(255, 255, 255, 0.08);
      border-color: rgba(242, 238, 229, 0.26);
      color: #ffffff;
    }

    .scene-nav-link.is-current {
      border-color: rgba(174, 220, 191, 0.42);
      background: rgba(62, 109, 78, 0.52);
      color: #f6fff9;
    }

    .scene-error {
      position: fixed;
      inset: 16px;
      z-index: 30;
      margin: 0;
      padding: 16px;
      border: 1px solid rgba(255, 180, 180, 0.25);
      border-radius: 16px;
      background: rgba(28, 8, 10, 0.92);
      color: #ffcccc;
      overflow: auto;
      white-space: pre-wrap;
      box-shadow: 0 18px 50px rgba(0, 0, 0, 0.45);
    }
  `;
  document.head.appendChild(style);
  stylesMounted = true;
}

export function mountSceneChrome(sceneConfig) {
  ensureStyles();
  document.title = sceneConfig.title;

  const existing = document.querySelector(".scene-chrome");
  if (existing) existing.remove();

  const chrome = document.createElement("div");
  chrome.className = "scene-chrome";

  const navLinks = sceneLinks.map(({ key, label, href }) => {
    const currentClass = key === sceneConfig.key ? " is-current" : "";
    return `<a class="scene-nav-link${currentClass}" href="${href}">${label}</a>`;
  }).join("");

  chrome.innerHTML = `
    <div class="scene-panel">
      <p class="scene-kicker">CG Project Scenes</p>
      <h1 class="scene-title">${sceneConfig.title}</h1>
      <p class="scene-description">${sceneConfig.description}</p>
      <p class="scene-controls">${sceneConfig.controls}</p>
      <nav class="scene-nav" aria-label="Scene switcher">${navLinks}</nav>
    </div>
  `;

  document.body.appendChild(chrome);
}

export function showFatalError(error) {
  ensureStyles();
  console.error(error);

  const existing = document.querySelector(".scene-error");
  if (existing) existing.remove();

  const pre = document.createElement("pre");
  pre.className = "scene-error";
  pre.textContent = String(error);
  document.body.appendChild(pre);
}
