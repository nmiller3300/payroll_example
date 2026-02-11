const body = document.body;

const platformNameInput = document.getElementById("platformNameInput");
const platformName = document.getElementById("platform-name");
const platformLogo = document.getElementById("platform-logo");
const platformSubtitle = document.getElementById("platform-subtitle");
const businessName = document.getElementById("businessName");
const dashboardTitle = document.getElementById("dashboardTitle");
const dashboardHeadline = document.getElementById("dashboard-headline");
const dashboardSubtitle = document.getElementById("dashboard-subtitle");
const pendingApprovals = document.getElementById("pendingApprovals");
const payrollTotal = document.getElementById("payrollTotal");
const clockedIn = document.getElementById("clockedIn");
const payrollRows = document.getElementById("payrollRows");

const primaryColor = document.getElementById("primaryColor");
const accentColor = document.getElementById("accentColor");
const modeSelect = document.getElementById("modeSelect");
const backgroundSelect = document.getElementById("backgroundSelect");
const hexToggle = document.getElementById("hexToggle");
const hexOpacity = document.getElementById("hexOpacity");
const spacingSelect = document.getElementById("spacingSelect");

const closeButton = document.getElementById("closeButton");
const saveThemeButton = document.getElementById("saveThemeButton");
const runPayrollButton = document.getElementById("runPayrollButton");
const refreshDataButton = document.getElementById("refreshDataButton");

const resourceName = window.GetParentResourceName ? window.GetParentResourceName() : "mybusiness_payroll";

const postNui = async (endpoint, payload = {}) => {
  const response = await fetch(`https://${resourceName}/${endpoint}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(payload)
  });

  try {
    return await response.json();
  } catch (_error) {
    return null;
  }
};

const formatCurrency = (amount) => {
  const value = Number(amount) || 0;
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 0
  }).format(value);
};

const statusClass = (status) => {
  const value = (status || "").toLowerCase();
  if (value.includes("approved") || value.includes("paid")) return "success";
  if (value.includes("pending") || value.includes("review")) return "warning";
  if (value.includes("issue") || value.includes("error") || value.includes("hold")) return "error";
  return "neutral";
};

const renderRows = (rows = []) => {
  payrollRows.innerHTML = "";

  rows.forEach((row) => {
    const tr = document.createElement("tr");
    const rowStatusClass = statusClass(row.status);

    tr.innerHTML = `
      <td>${row.employee ?? "-"}</td>
      <td>${row.role ?? "-"}</td>
      <td>${row.hours ?? "0.0"}</td>
      <td><span class="pill ${rowStatusClass}">${row.status ?? "Unknown"}</span></td>
      <td>${formatCurrency(row.pay)}</td>
    `;

    payrollRows.appendChild(tr);
  });
};

const applyTheme = (theme = {}) => {
  if (theme.mode) {
    body.dataset.mode = theme.mode;
    modeSelect.value = theme.mode;
  }

  if (theme.spacing) {
    body.dataset.spacing = theme.spacing;
    spacingSelect.value = theme.spacing;
  }

  const hexEnabled = theme.hexEnabled !== false;
  body.dataset.hex = hexEnabled ? "on" : "off";
  hexToggle.value = hexEnabled ? "on" : "off";

  if (theme.hexOpacity) {
    const opacity = Number(theme.hexOpacity);
    hexOpacity.value = opacity;
    body.style.setProperty("--hex-opacity", (opacity / 100).toFixed(2));
  }

  if (theme.primaryColor) {
    primaryColor.value = theme.primaryColor;
    body.style.setProperty("--primary", theme.primaryColor);
  }

  if (theme.accentColor) {
    accentColor.value = theme.accentColor;
    body.style.setProperty("--accent", theme.accentColor);
  }

  if (theme.backgroundStyle) {
    backgroundSelect.value = theme.backgroundStyle;
    if (theme.backgroundStyle === "soft-gradient" && body.dataset.mode !== "light") {
      body.style.background = "linear-gradient(140deg, #101015 0%, #171921 52%, #222013 100%)";
    } else {
      body.style.background = "";
    }
  }
};

const getThemePayload = () => ({
  mode: modeSelect.value,
  spacing: spacingSelect.value,
  hexEnabled: hexToggle.value === "on",
  hexOpacity: Number(hexOpacity.value),
  primaryColor: primaryColor.value,
  accentColor: accentColor.value,
  backgroundStyle: backgroundSelect.value,
  platformName: platformNameInput.value
});

window.addEventListener("message", (event) => {
  const { action, payload } = event.data || {};

  if (action === "setVisible") {
    if (payload?.visible) {
      body.classList.remove("is-hidden");
    } else {
      body.classList.add("is-hidden");
    }
    return;
  }

  if (action !== "bootstrap") {
    return;
  }

  const platform = payload?.platform || {};
  const profile = payload?.profile || {};
  const summary = payload?.summary || {};

  platformName.textContent = platform.name || "MyBusiness Payroll";
  platformNameInput.value = platform.name || "MyBusiness Payroll";
  platformSubtitle.textContent = platform.subtitle || "Workforce Compensation & Time Management";
  platformLogo.textContent = platform.logoText || "MB";

  businessName.value = profile.businessName || "Business";
  dashboardTitle.value = profile.dashboardTitle || "Command Dashboard";
  dashboardHeadline.textContent = profile.dashboardTitle || "Command Dashboard";
  dashboardSubtitle.textContent = profile.dashboardSubtitle || "Agency-wide payroll status and time intelligence";

  pendingApprovals.textContent = summary.pendingApprovals ?? 0;
  payrollTotal.textContent = formatCurrency(summary.payrollTotal);
  clockedIn.textContent = summary.clockedIn ?? 0;

  renderRows(payload?.rows || []);
  applyTheme(payload?.theme || {});
  body.classList.remove("is-hidden");
});

platformNameInput.addEventListener("input", (event) => {
  platformName.textContent = event.target.value || "MyBusiness Payroll";
});

primaryColor.addEventListener("input", (event) => {
  body.style.setProperty("--primary", event.target.value);
});

accentColor.addEventListener("input", (event) => {
  body.style.setProperty("--accent", event.target.value);
});

modeSelect.addEventListener("change", (event) => {
  body.dataset.mode = event.target.value;
});

backgroundSelect.addEventListener("change", (event) => {
  if (event.target.value === "soft-gradient" && body.dataset.mode !== "light") {
    body.style.background = "linear-gradient(140deg, #101015 0%, #171921 52%, #222013 100%)";
    return;
  }

  body.style.background = "";
});

hexToggle.addEventListener("change", (event) => {
  body.dataset.hex = event.target.value;
});

hexOpacity.addEventListener("input", (event) => {
  const value = Number(event.target.value) / 100;
  body.style.setProperty("--hex-opacity", value.toFixed(2));
});

spacingSelect.addEventListener("change", (event) => {
  body.dataset.spacing = event.target.value;
});

closeButton.addEventListener("click", () => postNui("close"));
saveThemeButton.addEventListener("click", () => postNui("saveTheme", getThemePayload()));
const refreshDashboard = async () => {
  const response = await postNui("requestRefresh");
  if (!response || !response.ok) return;

  pendingApprovals.textContent = response.summary?.pendingApprovals ?? 0;
  payrollTotal.textContent = formatCurrency(response.summary?.payrollTotal);
  clockedIn.textContent = response.summary?.clockedIn ?? 0;
  renderRows(response.rows || []);
};

runPayrollButton.addEventListener("click", refreshDashboard);
refreshDataButton.addEventListener("click", refreshDashboard);

document.addEventListener("keyup", (event) => {
  if (event.key === "Escape") {
    postNui("close");
  }
});
