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
  qs('.hex-overlay').style.display = theme.hexEnabled === false ? 'none' : 'block';
  if (theme.hexOpacity !== undefined) qs('.hex-overlay').style.opacity = Number(theme.hexOpacity) / 100;
}

function taxText(taxes = {}) {
  return `Tax: ${Number(taxes.taxRate || 0).toFixed(2)}% | SS: ${Number(taxes.ssRate || 0).toFixed(2)}% | Medicare: ${Number(taxes.medicareRate || 0).toFixed(2)}%`;
}

function renderSharedBranding(payload) {
  const logoUrl = payload?.settings?.businessLogoUrl || payload?.employee?.businessLogoUrl || '';
  const platformLogo = qs('#platformLogo');
  if (logoUrl) {
    platformLogo.src = logoUrl;
    platformLogo.classList.remove('hidden');
  } else {
    platformLogo.src = '';
    platformLogo.classList.add('hidden');
  }
}

function renderBoss(payload) {
  qs('#bossPanel').classList.remove('hidden');
  qs('#employeePanel').classList.add('hidden');

  qs('#bossTitle').textContent = payload.profile?.dashboardTitle || 'Command Dashboard';
  qs('#bossSub').textContent = payload.profile?.dashboardSubtitle || '';

  qs('#metricEmployees').textContent = payload.summary?.employees ?? 0;
  qs('#metricPayroll').textContent = money(payload.summary?.payrollTotal);
  qs('#metricTax').textContent = money(payload.summary?.taxTotal);
  qs('#taxPreview').textContent = taxText(payload.taxes || {});

  qs('#periodDays').value = payload.settings?.periodDays ?? 14;
  qs('#loginDomain').value = payload.settings?.loginDomain ?? 'business.org';
  qs('#businessName').value = payload.settings?.businessNameOverride ?? '';
  qs('#businessLogo').value = payload.settings?.businessLogoUrl ?? '';
  qs('#hourlyRate').value = payload.settings?.hourlyRate ?? 100;

  const rows = qs('#rows');
  rows.innerHTML = '';
  (payload.rows || []).forEach((row) => {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td>${row.employee}</td><td>${Number(row.hours || 0).toFixed(2)}</td><td>${money(row.hourlyRate)}</td><td>${money(row.bonus)}</td><td>${money(row.gross)}</td><td>${money(row.deductions)}</td><td>${money(row.net)}</td>`;
    rows.appendChild(tr);
  });

  const gradeList = qs('#jobGradeList');
  gradeList.innerHTML = '';
  (payload.jobGrades || []).forEach((grade) => {
    const li = document.createElement('li');
    li.textContent = `Grade ${grade.grade_level}: ${grade.grade_name || 'N/A'} ($${Number(grade.payment || 0).toFixed(2)})`;
    gradeList.appendChild(li);
  });

  const adjustmentList = qs('#adjustmentList');
  adjustmentList.innerHTML = '';
  if ((payload.pendingAdjustments || []).length === 0) {
    adjustmentList.innerHTML = '<li>No pending adjustment requests.</li>';
  } else {
    payload.pendingAdjustments.forEach((item) => {
      const li = document.createElement('li');
      li.innerHTML = `${item.employee_name} requested ${item.minutes_delta > 0 ? '+' : ''}${item.minutes_delta} mins — ${item.reason}
        <button class="btn primary tiny" data-approve="${item.id}">Approve</button>
        <button class="btn muted tiny" data-reject="${item.id}">Reject</button>`;
      adjustmentList.appendChild(li);
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
  qs('#employeeTaxPreview').textContent = taxText(payload.taxes || {});
  qs('#adjustMinutes').max = payload.settings?.maxAdjustmentMinutes || 180;
  qs('#adjustMinutes').min = -1 * (payload.settings?.maxAdjustmentMinutes || 180);

  const logo = qs('#employeeLogo');
  if (payload.employee?.businessLogoUrl) {
    logo.src = payload.employee.businessLogoUrl;
    logo.classList.remove('hidden');
  } else {
    logo.src = '';
    logo.classList.add('hidden');
  }

  const history = qs('#employeeAdjustmentHistory');
  history.innerHTML = '';
  (payload.adjustmentRequests || []).forEach((item) => {
    const li = document.createElement('li');
    li.textContent = `${item.minutes_delta > 0 ? '+' : ''}${item.minutes_delta} mins | ${item.status} | ${item.reason}`;
    history.appendChild(li);
  });
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
    renderSharedBranding(payload);

    if (currentMode === 'employee') renderEmployee(payload);
    else renderBoss(payload);
  }
});

document.addEventListener('click', (event) => {
  const approveId = event.target.getAttribute('data-approve');
  const rejectId = event.target.getAttribute('data-reject');
  if (approveId) {
    postNui('reviewAdjustment', { requestId: Number(approveId), decision: 'approved' }).then(() => postNui('requestRefresh', { mode: 'boss' }));
  }
  if (rejectId) {
    postNui('reviewAdjustment', { requestId: Number(rejectId), decision: 'rejected' }).then(() => postNui('requestRefresh', { mode: 'boss' }));
  }
});

qs('#closeBtn').addEventListener('click', () => postNui('close'));
qs('#refreshBtn').addEventListener('click', () => postNui('requestRefresh', { mode: currentMode }));
qs('#saveSettingsBtn').addEventListener('click', () => postNui('saveSettings', {
  periodDays: Number(qs('#periodDays').value || 14),
  loginDomain: qs('#loginDomain').value,
  businessNameOverride: qs('#businessName').value,
  businessLogoUrl: qs('#businessLogo').value,
  hourlyRate: Number(qs('#hourlyRate').value || 100)
}));
qs('#runPayrollBtn').addEventListener('click', () => postNui('runPayroll'));
qs('#setGradeRateBtn').addEventListener('click', () => postNui('setGradeRate', {
  gradeLevel: Number(qs('#gradeLevelInput').value || 0),
  hourlyRate: Number(qs('#gradeRateInput').value || 0)
}).then(() => postNui('requestRefresh', { mode: 'boss' })));
qs('#setEmployeeRateBtn').addEventListener('click', () => postNui('setEmployeeRate', {
  citizenid: qs('#employeeCidInput').value,
  hourlyRate: Number(qs('#employeeRateInput').value || 0)
}).then(() => postNui('requestRefresh', { mode: 'boss' })));
qs('#addBonusBtn').addEventListener('click', () => postNui('addEmployeeBonus', {
  citizenid: qs('#bonusCidInput').value,
  amount: Number(qs('#bonusAmountInput').value || 0),
  reason: qs('#bonusReasonInput').value
}).then(() => postNui('requestRefresh', { mode: 'boss' })));
qs('#clockInBtn').addEventListener('click', () => postNui('clockIn'));
qs('#clockOutBtn').addEventListener('click', () => postNui('clockOut'));
qs('#submitAdjustmentBtn').addEventListener('click', () => postNui('submitAdjustment', {
  minutesDelta: Number(qs('#adjustMinutes').value || 0),
  reason: qs('#adjustReason').value
}).then(() => postNui('requestRefresh', { mode: 'employee' })));

document.addEventListener('keydown', (event) => {
  const key = (event.key || '').toLowerCase();
  if (key === 'escape') {
    postNui('close');
  }
});
