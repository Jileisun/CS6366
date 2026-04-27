function ensureParameterPanelStyles() {
  if (document.getElementById("scene-parameter-panel-styles")) return;

  const style = document.createElement("style");
  style.id = "scene-parameter-panel-styles";
  style.textContent = `
    .scene-parameter-panel {
      position: fixed;
      top: 16px;
      right: 16px;
      z-index: 20;
      width: min(360px, calc(100vw - 32px));
      max-height: calc(100vh - 32px);
      overflow: auto;
      padding: 14px 16px 16px;
      border: 1px solid rgba(255, 244, 226, 0.14);
      border-radius: 14px;
      background: rgba(9, 14, 18, 0.74);
      box-shadow: 0 18px 50px rgba(0, 0, 0, 0.32);
      backdrop-filter: blur(18px);
      color: #f2eee5;
      font-family: "Avenir Next", "Segoe UI", sans-serif;
    }

    .scene-parameter-panel h2 {
      margin: 0;
      font-size: 18px;
      line-height: 1.2;
      font-weight: 600;
    }

    .scene-parameter-panel p {
      margin: 8px 0 0;
      font-size: 12px;
      line-height: 1.45;
      color: rgba(242, 238, 229, 0.78);
    }

    .scene-parameter-list {
      display: grid;
      gap: 12px;
      margin-top: 14px;
    }

    .scene-parameter-row {
      display: grid;
      gap: 6px;
    }

    .scene-parameter-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      font-size: 12px;
      color: rgba(242, 238, 229, 0.88);
    }

    .scene-parameter-value {
      color: rgba(174, 220, 191, 0.96);
      font-variant-numeric: tabular-nums;
    }

    .scene-parameter-slider,
    .scene-parameter-select {
      width: 100%;
      margin: 0;
      accent-color: #86b48f;
    }

    .scene-parameter-select {
      padding: 8px 10px;
      border: 1px solid rgba(242, 238, 229, 0.16);
      border-radius: 10px;
      background: rgba(255, 255, 255, 0.03);
      color: rgba(242, 238, 229, 0.88);
      font: inherit;
    }

    .scene-parameter-actions {
      display: flex;
      justify-content: flex-end;
      margin-top: 14px;
    }

    .scene-parameter-reset {
      padding: 8px 12px;
      border: 1px solid rgba(242, 238, 229, 0.16);
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.03);
      color: rgba(242, 238, 229, 0.88);
      font: inherit;
      cursor: pointer;
    }

    .scene-parameter-reset:hover {
      background: rgba(255, 255, 255, 0.08);
      border-color: rgba(242, 238, 229, 0.24);
    }
  `;
  document.head.appendChild(style);
}

function formatSpecValue(spec, value) {
  if (spec.format) return spec.format(value);
  if (spec.type === "select") {
    const option = spec.options.find((candidate) => candidate.value === value);
    return option ? option.label : String(value);
  }
  return String(value);
}

export function mountParameterPanel(config) {
  const {
    title,
    description,
    specs,
    initialValues,
    onUpdate,
    onReset,
    resetLabel = "Reset",
  } = config;

  ensureParameterPanelStyles();

  const existing = document.querySelector(".scene-parameter-panel");
  if (existing) existing.remove();

  const panel = document.createElement("section");
  panel.className = "scene-parameter-panel";
  panel.innerHTML = `
    <h2>${title}</h2>
    <p>${description}</p>
    <div class="scene-parameter-list"></div>
    <div class="scene-parameter-actions">
      <button type="button" class="scene-parameter-reset">${resetLabel}</button>
    </div>
  `;

  const list = panel.querySelector(".scene-parameter-list");
  const controlRefs = new Map();

  for (const spec of specs) {
    const row = document.createElement("label");
    row.className = "scene-parameter-row";

    const head = document.createElement("div");
    head.className = "scene-parameter-head";

    const titleNode = document.createElement("span");
    titleNode.textContent = spec.label;

    const valueNode = document.createElement("span");
    valueNode.className = "scene-parameter-value";
    valueNode.textContent = formatSpecValue(spec, initialValues[spec.key]);

    head.append(titleNode, valueNode);
    row.appendChild(head);

    if (spec.type === "select") {
      const select = document.createElement("select");
      select.className = "scene-parameter-select";

      for (const option of spec.options) {
        const optionNode = document.createElement("option");
        optionNode.value = String(option.value);
        optionNode.textContent = option.label;
        if (option.value === initialValues[spec.key]) optionNode.selected = true;
        select.appendChild(optionNode);
      }

      select.addEventListener("input", () => {
        const nextValue = Number(select.value);
        valueNode.textContent = formatSpecValue(spec, nextValue);
        onUpdate(spec.key, nextValue);
      });

      controlRefs.set(spec.key, { input: select, value: valueNode });
      row.appendChild(select);
    } else {
      const slider = document.createElement("input");
      slider.className = "scene-parameter-slider";
      slider.type = "range";
      slider.min = String(spec.min);
      slider.max = String(spec.max);
      slider.step = String(spec.step ?? 0.01);
      slider.value = String(initialValues[spec.key]);

      slider.addEventListener("input", () => {
        const nextValue = Number(slider.value);
        valueNode.textContent = formatSpecValue(spec, nextValue);
        onUpdate(spec.key, nextValue);
      });

      controlRefs.set(spec.key, { input: slider, value: valueNode });
      row.appendChild(slider);
    }

    list.appendChild(row);
  }

  panel.querySelector(".scene-parameter-reset").addEventListener("click", onReset);
  document.body.appendChild(panel);

  return {
    panel,
    setValues(nextValues) {
      for (const spec of specs) {
        const controls = controlRefs.get(spec.key);
        if (!controls) continue;

        controls.input.value = String(nextValues[spec.key]);
        controls.value.textContent = formatSpecValue(spec, nextValues[spec.key]);
      }
    },
  };
}
