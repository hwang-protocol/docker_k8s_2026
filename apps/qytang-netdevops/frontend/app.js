const deviceApiBase = window.localStorage.getItem("qytang-device-api") || "/api/device";
const auditApiBase = window.localStorage.getItem("qytang-audit-api") || "/api/audit";
const resourceApiBase = window.localStorage.getItem("qytang-resource-api") || "/api/resource";

const state = {
  currentView: "dashboard",
  summary: null,
  devices: [],
  filteredDevices: [],
  selectedDeviceId: null,
  selectedDevice: null,
  audits: [],
  editMode: false,
};

const viewTitles = {
  dashboard: {
    title: "Dashboard",
    subtitle: "设备资产、接口状态与最近变更的实时视图",
  },
  devices: {
    title: "Devices",
    subtitle: "设备列表、筛选、详情查看与增删改操作",
  },
  audits: {
    title: "Audit Center",
    subtitle: "聚合展示新增、修改、删除动作的审计时间线",
  },
};

async function requestJson(url, options = {}) {
  const response = await fetch(url, {
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    ...options,
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(text || `${response.status} ${response.statusText}`);
  }
  return response.status === 204 ? null : response.json();
}

function setView(viewName) {
  state.currentView = viewName;
  document.querySelectorAll(".view").forEach((item) => item.classList.remove("active"));
  document.querySelector(`#view-${viewName}`).classList.add("active");
  document.querySelectorAll(".nav-item").forEach((item) => {
    item.classList.toggle("active", item.dataset.view === viewName);
  });
  document.getElementById("page-title").textContent = viewTitles[viewName].title;
  document.getElementById("page-subtitle").textContent = viewTitles[viewName].subtitle;
}

function formatDate(value) {
  return new Date(value).toLocaleString("zh-CN", {
    hour12: false,
  });
}

function renderDistribution(containerId, items) {
  const container = document.getElementById(containerId);
  container.innerHTML = "";
  const maxValue = Math.max(...items.map((item) => item.value), 1);
  items.forEach((item) => {
    const node = document.createElement("div");
    node.className = "distribution-item";
    node.innerHTML = `
      <div class="detail-meta">
        <strong>${item.label}</strong>
        <small>${item.value}</small>
      </div>
      <div class="distribution-bar"><span style="width:${(item.value / maxValue) * 100}%"></span></div>
    `;
    container.appendChild(node);
  });
}

function renderTimeline(containerId, items) {
  const container = document.getElementById(containerId);
  container.innerHTML = "";
  items.forEach((item) => {
    const node = document.createElement("div");
    node.className = "timeline-item";
    node.innerHTML = `
      <strong>${item.action.toUpperCase()} · ${item.operator}</strong>
      <div>${item.detail}</div>
      <div class="timeline-meta">${formatDate(item.created_at)}</div>
    `;
    container.appendChild(node);
  });
}

function renderDashboard() {
  if (!state.summary) {
    return;
  }

  document.getElementById("hero-pills").innerHTML = `
    <span class="pill">在线率 ${Math.round((state.summary.online_devices / Math.max(state.summary.total_devices, 1)) * 100)}%</span>
    <span class="pill">最高速率 ${state.summary.top_interface_speed_mbps} Mbps</span>
    <span class="pill">风险设备 ${state.summary.risky_device_count}</span>
  `;

  document.getElementById("service-matrix").innerHTML = state.summary.service_matrix
    .map(
      (item) => `
        <div class="service-item">
          <div>${item.name}</div>
          <strong>${item.status}</strong>
          <p>${item.url}</p>
        </div>
      `
    )
    .join("");

  document.getElementById("kpi-grid").innerHTML = `
    <article class="panel-card kpi-card">
      <div>设备总数</div>
      <span class="kpi-value">${state.summary.total_devices}</span>
      <p>总资产对象</p>
    </article>
    <article class="panel-card kpi-card">
      <div>在线设备</div>
      <span class="kpi-value">${state.summary.online_devices}</span>
      <p>当前在线状态</p>
    </article>
    <article class="panel-card kpi-card">
      <div>接口 Up</div>
      <span class="kpi-value">${state.summary.interface_up_count}</span>
      <p>运行正常接口</p>
    </article>
    <article class="panel-card kpi-card">
      <div>最近变更</div>
      <span class="kpi-value">${state.summary.recent_change_count}</span>
      <p>最近审计事件</p>
    </article>
  `;

  renderDistribution("vendor-distribution", state.summary.vendor_distribution);
  renderDistribution("site-distribution", state.summary.site_distribution);
  renderDistribution("status-distribution", state.summary.status_distribution);
  renderTimeline("recent-changes", state.summary.recent_changes);
}

function renderDeviceTable() {
  const tbody = document.getElementById("device-table-body");
  tbody.innerHTML = "";

  state.filteredDevices.forEach((item) => {
    const row = document.createElement("tr");
    row.className = item.id === state.selectedDeviceId ? "active" : "";
    row.innerHTML = `
      <td>${item.hostname}</td>
      <td>${item.mgmt_ip}</td>
      <td>${item.vendor}</td>
      <td>${item.site}</td>
      <td><span class="badge ${item.status}">${item.status}</span></td>
    `;
    row.addEventListener("click", () => selectDevice(item.id));
    tbody.appendChild(row);
  });
}

function renderDeviceDetail() {
  const container = document.getElementById("device-detail");
  if (!state.selectedDevice) {
    container.className = "detail-block empty-state";
    container.textContent = "请选择左侧设备。";
    return;
  }

  const interfaces = state.selectedDevice.interfaces
    .map(
      (item) =>
        `<span class="list-chip">${item.name} · ${item.oper_status} · ${item.speed_mbps} Mbps${item.ip_address ? ` · ${item.ip_address}` : ""}</span>`
    )
    .join("");

  const audits = state.selectedDevice.audits
    .map(
      (item) => `
        <div class="timeline-item">
          <strong>${item.action.toUpperCase()} · ${item.operator}</strong>
          <div>${item.detail}</div>
          <div class="timeline-meta">${formatDate(item.created_at)}</div>
        </div>
      `
    )
    .join("");

  container.className = "detail-block";
  container.innerHTML = `
    <div class="detail-grid">
      <div class="detail-kv"><span>Hostname</span><strong>${state.selectedDevice.hostname}</strong></div>
      <div class="detail-kv"><span>Mgmt IP</span><strong>${state.selectedDevice.mgmt_ip}</strong></div>
      <div class="detail-kv"><span>Vendor / Model</span><strong>${state.selectedDevice.vendor} ${state.selectedDevice.model}</strong></div>
      <div class="detail-kv"><span>Site / Role</span><strong>${state.selectedDevice.site} / ${state.selectedDevice.role}</strong></div>
      <div class="detail-kv"><span>Version</span><strong>${state.selectedDevice.version}</strong></div>
      <div class="detail-kv"><span>Status</span><strong><span class="badge ${state.selectedDevice.status}">${state.selectedDevice.status}</span></strong></div>
    </div>
    <div>
      <h4>接口列表</h4>
      <div>${interfaces || "<span class='empty-state'>暂无接口</span>"}</div>
    </div>
    <div>
      <h4>最近审计</h4>
      <div class="timeline-list">${audits || "<span class='empty-state'>暂无审计</span>"}</div>
    </div>
  `;
}

function applyDeviceFilters() {
  const keyword = document.getElementById("device-search").value.trim().toLowerCase();
  const status = document.getElementById("device-status-filter").value;
  const vendor = document.getElementById("device-vendor-filter").value;
  const site = document.getElementById("device-site-filter").value;

  state.filteredDevices = state.devices.filter((item) => {
    const keywordMatched =
      !keyword ||
      [item.hostname, item.mgmt_ip, item.site, item.role].some((value) => value.toLowerCase().includes(keyword));
    const statusMatched = !status || item.status === status;
    const vendorMatched = !vendor || item.vendor === vendor;
    const siteMatched = !site || item.site === site;
    return keywordMatched && statusMatched && vendorMatched && siteMatched;
  });

  renderDeviceTable();
}

function populateFilterOptions() {
  const vendorSelect = document.getElementById("device-vendor-filter");
  const siteSelect = document.getElementById("device-site-filter");
  const vendors = [...new Set(state.devices.map((item) => item.vendor))].sort();
  const sites = [...new Set(state.devices.map((item) => item.site))].sort();

  vendorSelect.innerHTML = `<option value="">全部厂商</option>${vendors.map((item) => `<option value="${item}">${item}</option>`).join("")}`;
  siteSelect.innerHTML = `<option value="">全部站点</option>${sites.map((item) => `<option value="${item}">${item}</option>`).join("")}`;
}

async function loadDevices() {
  state.devices = await requestJson(`${deviceApiBase}/api/v1/devices`);
  populateFilterOptions();
  applyDeviceFilters();
  if (!state.selectedDeviceId && state.devices.length > 0) {
    await selectDevice(state.devices[0].id);
  }
}

async function loadSummary() {
  state.summary = await requestJson(`${deviceApiBase}/api/v1/dashboard/summary`);
  renderDashboard();
}

async function loadAudits() {
  state.audits = await requestJson(`${auditApiBase}/api/v1/audits?limit=20`);
  renderTimeline("audit-timeline", state.audits);
}

async function selectDevice(deviceId) {
  state.selectedDeviceId = deviceId;
  renderDeviceTable();
  state.selectedDevice = await requestJson(`${deviceApiBase}/api/v1/devices/${deviceId}`);
  renderDeviceDetail();
}

function openDeviceDialog(editMode = false) {
  state.editMode = editMode;
  const dialog = document.getElementById("device-dialog");
  const form = document.getElementById("device-form");
  document.getElementById("device-dialog-title").textContent = editMode ? "编辑设备" : "新增设备";

  if (editMode && state.selectedDevice) {
    Object.entries({
      hostname: state.selectedDevice.hostname,
      mgmt_ip: state.selectedDevice.mgmt_ip,
      vendor: state.selectedDevice.vendor,
      model: state.selectedDevice.model,
      version: state.selectedDevice.version,
      site: state.selectedDevice.site,
      role: state.selectedDevice.role,
      status: state.selectedDevice.status,
    }).forEach(([key, value]) => {
      form.elements[key].value = value;
    });
  } else {
    form.reset();
    form.elements.status.value = "online";
  }
  dialog.showModal();
}

async function submitDeviceForm(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const payload = {
    hostname: form.elements.hostname.value,
    mgmt_ip: form.elements.mgmt_ip.value,
    vendor: form.elements.vendor.value,
    model: form.elements.model.value,
    version: form.elements.version.value,
    site: form.elements.site.value,
    role: form.elements.role.value,
    status: form.elements.status.value,
  };

  if (state.editMode && state.selectedDeviceId) {
    await requestJson(`${deviceApiBase}/api/v1/devices/${state.selectedDeviceId}`, {
      method: "PUT",
      body: JSON.stringify(payload),
    });
  } else {
    await requestJson(`${deviceApiBase}/api/v1/devices`, {
      method: "POST",
      body: JSON.stringify(payload),
    });
  }

  document.getElementById("device-dialog").close();
  await refreshAll();
}

async function deleteSelectedDevice() {
  if (!state.selectedDeviceId || !window.confirm("确认删除当前设备吗？")) {
    return;
  }

  await requestJson(`${deviceApiBase}/api/v1/devices/${state.selectedDeviceId}`, {
    method: "DELETE",
  });
  state.selectedDeviceId = null;
  state.selectedDevice = null;
  await refreshAll();
}

async function refreshAll() {
  try {
    await Promise.all([loadSummary(), loadDevices(), loadAudits()]);
    document.getElementById("sidebar-health").textContent = "Healthy";
  } catch (error) {
    console.error(error);
    document.getElementById("sidebar-health").textContent = "Degraded";
    alert(`数据刷新失败: ${error.message}`);
  }
}

function bindEvents() {
  document.querySelectorAll(".nav-item").forEach((item) => {
    item.addEventListener("click", () => setView(item.dataset.view));
  });
  document.getElementById("refresh-button").addEventListener("click", refreshAll);
  document.getElementById("open-device-modal").addEventListener("click", () => openDeviceDialog(false));
  document.getElementById("edit-device-button").addEventListener("click", () => openDeviceDialog(true));
  document.getElementById("delete-device-button").addEventListener("click", deleteSelectedDevice);
  document.getElementById("cancel-device-dialog").addEventListener("click", () => {
    document.getElementById("device-dialog").close();
  });
  document.getElementById("device-form").addEventListener("submit", submitDeviceForm);

  ["device-search", "device-status-filter", "device-vendor-filter", "device-site-filter"].forEach((id) => {
    document.getElementById(id).addEventListener("input", applyDeviceFilters);
    document.getElementById(id).addEventListener("change", applyDeviceFilters);
  });
}

bindEvents();
refreshAll();
