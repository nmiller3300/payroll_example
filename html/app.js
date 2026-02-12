const resourceName = window.GetParentResourceName ? GetParentResourceName() : 'mybusiness_payroll';
let currentMode = 'boss';

const qs = (sel) => document.querySelector(sel);

function postNui(endpoint, payload = {}) {
  return fetch(`https://${resourceName}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(payload)
  });
}

function money(value) {
  return `$${Number(value || 0).toFixed(2)}`;
}

function applyTheme(theme = {}) {
  const root = document.documentElement;
  if (theme.primaryColor) root.style.setProperty('--accent', theme.primaryColor);
  if (theme.hexEnabled === false) qs('.hex-overlay').style.display = 'none';
  else qs('.hex-overlay').style.display = 'block';
  if (theme.hexOpacity !== undefined) qs('.hex-overlay').style.opacity = Number(theme.hexOpacity) / 100;
}

function renderBoss(payload) {
  qs('#bossPanel').classList.remove('hidden');
  qs('#employeePanel').classList.add('hidden');

  qs('#bossTitle').textContent = payload.profile?.dashboardTitle || 'Command Dashboard';
  qs('#bossSub').textContent = payload.profile?.dashboardSubtitle || '';

  qs('#metricEmployees').textContent = payload.summary?.employees ?? 0;
  qs('#metricPayroll').textContent = money(payload.summary?.payrollTotal);
  qs('#metricAudit').textContent = payload.auditIssues?.length ?? 0;

  qs('#periodDays').value = payload.settings?.periodDays ?? 14;
  qs('#loginDomain').value = payload.settings?.loginDomain ?? 'business.org';
  qs('#businessName').value = payload.settings?.businessNameOverride ?? '';
  qs('#hourlyRate').value = payload.settings?.hourlyRate ?? 100;

  const rows = qs('#rows');
  rows.innerHTML = '';
  (payload.rows || []).forEach((row) => {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td>${row.employee}</td><td>${Number(row.hours || 0).toFixed(2)}</td><td>${money(row.pay)}</td><td>${row.status || 'Ready'}</td>`;
    rows.appendChild(tr);
  });

  const audit = qs('#auditList');
  audit.innerHTML = '';
  if (!payload.auditIssues || payload.auditIssues.length === 0) {
    const li = document.createElement('li');
    li.textContent = 'No active audit flags.';
    audit.appendChild(li);
  } else {
    payload.auditIssues.forEach((issue) => {
      const li = document.createElement('li');
      li.className = issue.severity || 'warning';
      li.textContent = `${issue.employee}: ${issue.type} - ${issue.detail}`;
      audit.appendChild(li);
    });
  }
}

function renderEmployee(payload) {
  qs('#bossPanel').classList.add('hidden');
  qs('#employeePanel').classList.remove('hidden');

  qs('#employeeBusiness').textContent = payload.employee?.businessName || 'Business';
  qs('#employeeIdentity').textContent = payload.employee?.loginIdentity || 'employee@business.org';
  qs('#employeeStatus').textContent = payload.employee?.isClockedIn ? 'Clocked In' : 'Clocked Out';
  qs('#employeeHours').textContent = Number(payload.summary?.totalHours || 0).toFixed(2);
  qs('#employeeProjected').textContent = money(payload.summary?.projectedPay);
}

window.addEventListener('message', (event) => {
  const { action, payload, mode } = event.data || {};
  if (action === 'close') {
    document.body.classList.add('hidden');
    return;
  }

  if (action === 'open') {
    currentMode = mode || payload?.mode || 'boss';
    document.body.classList.remove('hidden');

    qs('#platformName').textContent = payload.platform?.name || 'MyBusiness Payroll';
    qs('#platformSubtitle').textContent = payload.platform?.subtitle || '';
    applyTheme(payload.theme || {});

    if (currentMode === 'employee') renderEmployee(payload);
    else renderBoss(payload);
  }
});

qs('#closeBtn').addEventListener('click', () => postNui('close'));
qs('#refreshBtn').addEventListener('click', () => postNui('requestRefresh', { mode: currentMode }));
qs('#saveSettingsBtn').addEventListener('click', () => postNui('saveSettings', {
  periodDays: Number(qs('#periodDays').value || 14),
  loginDomain: qs('#loginDomain').value,
  businessNameOverride: qs('#businessName').value,
  hourlyRate: Number(qs('#hourlyRate').value || 100)
}));
qs('#runPayrollBtn').addEventListener('click', () => postNui('runPayroll'));
qs('#clockInBtn').addEventListener('click', () => postNui('clockIn'));
qs('#clockOutBtn').addEventListener('click', () => postNui('clockOut'));

document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') postNui('close');
});
