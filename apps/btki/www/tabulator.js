// Declare tabulatorInstances at the top level of your script
const tabulatorInstances = {};

Shiny.addCustomMessageHandler("renderTabulator", function(msg) {
  const { container, data } = msg;

  // Use the data directly without parsing
  const tableData = data;

  // 临时表格 div 的 id
  const tmpId = `${container}_tmp`;

  // 移除旧的临时表格 div
  const oldTmp = document.getElementById(tmpId);
  if (oldTmp) {
    // 销毁旧的 Tabulator 实例
    if (tabulatorInstances[tmpId]) {
      tabulatorInstances[tmpId].destroy();
      delete tabulatorInstances[tmpId];
    }
    oldTmp.remove();
  }

  // 新建临时表格 div 并挂载到 container
  const containerEl = document.getElementById(container);
  if (!containerEl) {
    console.error(`[Tabulator] Container not found: ${container}`);
    return;
  }
  const tmpDiv = document.createElement("div");
  tmpDiv.id = tmpId;
  containerEl.appendChild(tmpDiv);

  // Check if data is empty

  // Derive columns dynamically from data keys
  const columns = Object.keys(tableData[0] || {}).map(key => ({
    title: key.replace(/\./g, ' ').replace(/(^|\s)\S/g, l => l.toUpperCase()), // Capitalize column titles
    field: key,
    headerTooltip: true,
    tooltip: true
  }));

  // Create a new Tabulator instance
  try {
    tabulatorInstances[tmpId] = new Tabulator(`#${tmpId}`, {
      data: tableData,
      columns: columns,
      layout: "fitData",
      height: "100%",
      virtualDom: true,
      virtualDomBuffer: 150,
      pagination: "local",
      paginationSize: 20,
      paginationSizeSelector: [10, 25, 50, 100],
      columnDefaults: {
        tooltip: true,
        headerTooltip: true,
        resizable: true // Allow columns to be resizable
      },
      locale: true,
      langs: {
        "zh-cn": {
          "pagination": {
            "first": "First",
            "last": "Last",
            "prev": "Previous",
            "next": "Next"
          }
        }
      }
    });
  } catch (e) {
    console.error("[Tabulator] Initialization error:", e);
    tmpDiv.innerHTML = `
      <div class="alert alert-danger">
        <h4>Table Initialization Error</h4>
        <p>${e.message}</p>
        <pre>${JSON.stringify(columns, null, 2)}</pre>
      </div>
    `;
  }
});
