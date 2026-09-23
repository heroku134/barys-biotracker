/**
 * KALKAN SPORT - Admin Panel Application Logic
 * Высокопроизводительное управление атлетами, телеметрией СААТ-1, тренировками и пушами
 */

class KalkanAdminApp {
  constructor() {
    this.currentTab = 'overview';
    this.athletes = [];
    this.workouts = [];
    this.leagues = [];
    this.pushHistory = [];
    
    // Фильтры атлетов
    this.searchQuery = '';
    this.genderFilter = 'all';
    this.recoveryFilter = 'all';

    // Ссылки на графики Chart.js
    this.charts = {};

    this.init();
  }

  async init() {
    this.setupNavigation();
    this.setupEventListeners();
    await this.loadAllData();
    this.renderCurrentTab();
    this.updateLiveIndicator();
  }

  async loadAllData() {
    this.athletes = await window.kalkanBackend.getAthletes();
    this.workouts = await window.kalkanBackend.getWorkouts();
    this.leagues = await window.kalkanBackend.getLeagues();
    this.pushHistory = await window.kalkanBackend.getPushHistory();
  }

  setupNavigation() {
    const navItems = document.querySelectorAll('.nav-item');
    navItems.forEach(item => {
      item.addEventListener('click', () => {
        const tab = item.getAttribute('data-tab');
        this.switchTab(tab);
      });
    });
  }

  switchTab(tabId) {
    this.currentTab = tabId;

    // Обновляем активность пунктов меню
    document.querySelectorAll('.nav-item').forEach(item => {
      item.classList.toggle('active', item.getAttribute('data-tab') === tabId);
    });

    // Переключаем контентные вкладки
    document.querySelectorAll('.tab-pane').forEach(pane => {
      pane.classList.toggle('active', pane.id === `tab-${tabId}`);
    });

    // Обновляем заголовок страницы
    const titles = {
      overview: 'Обзор платформы KALKAN',
      athletes: 'Управление атлетами и СААТ-1',
      telemetry: 'Телеметрия и суточные срезы',
      workouts: 'Тренировки и активности',
      leagues: 'Лиги Данбара и партнёры',
      push: 'Центр оповещений и пуш-рассылок',
      settings: 'Системные настройки и экспорт'
    };
    const headingEl = document.getElementById('pageHeading');
    if (headingEl) headingEl.textContent = titles[tabId] || 'Панель администратора';

    this.renderCurrentTab();
  }

  renderCurrentTab() {
    switch (this.currentTab) {
      case 'overview':
        this.renderOverview();
        break;
      case 'athletes':
        this.renderAthletes();
        break;
      case 'telemetry':
        this.renderTelemetry();
        break;
      case 'workouts':
        this.renderWorkouts();
        break;
      case 'leagues':
        this.renderLeagues();
        break;
      case 'push':
        this.renderPush();
        break;
      case 'settings':
        this.renderSettings();
        break;
    }
  }

  // ==========================================
  // 1. СВОДКА И АНАЛИТИКА (OVERVIEW)
  // ==========================================

  renderOverview() {
    const totalAthletes = this.athletes.length;
    const activeToday = this.athletes.filter(a => a.status === 'active').length;
    
    const avgRecovery = Math.round(
      this.athletes.reduce((acc, a) => acc + (a.recoveryScore || 0), 0) / (totalAthletes || 1)
    );

    const avgStrain = (
      this.athletes.reduce((acc, a) => acc + (a.currentStrain || 0), 0) / (totalAthletes || 1)
    ).toFixed(1);

    const connectedDevices = this.athletes.filter(a => a.device && a.device.connected).length;

    // Устанавливаем значения в KPI карточки
    document.getElementById('kpiTotalAthletes').textContent = totalAthletes;
    document.getElementById('kpiActiveToday').textContent = activeToday;
    document.getElementById('kpiAvgRecovery').textContent = `${avgRecovery}%`;
    document.getElementById('kpiAvgStrain').textContent = avgStrain;
    document.getElementById('kpiConnectedDevices').textContent = `${connectedDevices} / ${totalAthletes}`;

    // Рендерим графики
    this.renderOverviewCharts();
    this.renderLiveLogs();
  }

  renderOverviewCharts() {
    if (typeof Chart === 'undefined') return;

    // 1. График распределения готовности (Recovery Zones)
    const optimalCount = this.athletes.filter(a => a.recoveryZone === 'optimal').length;
    const normalCount = this.athletes.filter(a => a.recoveryZone === 'normal').length;
    const lowCount = this.athletes.filter(a => a.recoveryZone === 'low').length;

    const recoveryCtx = document.getElementById('chartRecoveryDist');
    if (recoveryCtx) {
      if (this.charts.recovery) this.charts.recovery.destroy();
      this.charts.recovery = new Chart(recoveryCtx, {
        type: 'doughnut',
        data: {
          labels: ['Оптимально (>66%)', 'В норме (34-66%)', 'Низкое (<34%)'],
          datasets: [{
            data: [optimalCount, normalCount, lowCount],
            backgroundColor: ['#7FA088', '#E5A93C', '#E05A47'],
            borderWidth: 0,
            hoverOffset: 6
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: { position: 'bottom', labels: { color: '#9BA2B0', boxWidth: 12, padding: 14 } }
          },
          cutout: '72%'
        }
      });
    }

    // 2. График недельной активности атлетов
    const activityCtx = document.getElementById('chartWeeklyActivity');
    if (activityCtx) {
      if (this.charts.activity) this.charts.activity.destroy();
      this.charts.activity = new Chart(activityCtx, {
        type: 'line',
        data: {
          labels: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
          datasets: [
            {
              label: 'Средний Strain',
              data: [11.2, 13.5, 12.8, 14.2, 15.6, 16.8, 10.4],
              borderColor: '#E5A93C',
              backgroundColor: 'rgba(229, 169, 60, 0.12)',
              fill: true,
              tension: 0.35,
              borderWidth: 2.5
            },
            {
              label: 'Средний Пульс (bpm)',
              data: [64, 66, 63, 68, 70, 72, 62],
              borderColor: '#38BDF8',
              borderDash: [4, 4],
              borderWidth: 1.8,
              tension: 0.2
            }
          ]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: { labels: { color: '#9BA2B0' } }
          },
          scales: {
            x: { grid: { color: '#1D212A' }, ticks: { color: '#596172' } },
            y: { grid: { color: '#1D212A' }, ticks: { color: '#596172' } }
          }
        }
      });
    }
  }

  renderLiveLogs() {
    const logsContainer = document.getElementById('liveLogFeed');
    if (!logsContainer) return;

    logsContainer.innerHTML = (KALKAN_MOCK_DATA.systemLogs || []).map(log => `
      <div class="log-item ${log.level}">
        <span class="log-time">[${log.timestamp}]</span>
        <span class="log-text">${log.text}</span>
      </div>
    `).join('');
  }

  // ==========================================
  // 2. УПРАВЛЕНИЕ АТЛЕТАМИ (ATHLETES)
  // ==========================================

  renderAthletes() {
    const tableBody = document.getElementById('athletesTableBody');
    if (!tableBody) return;

    // Применяем поиск и фильтры
    let filtered = this.athletes.filter(a => {
      const matchSearch = a.name.toLowerCase().includes(this.searchQuery.toLowerCase()) ||
                          a.email.toLowerCase().includes(this.searchQuery.toLowerCase());
      const matchGender = this.genderFilter === 'all' || a.gender === this.genderFilter;
      const matchRecovery = this.recoveryFilter === 'all' || a.recoveryZone === this.recoveryFilter;
      return matchSearch && matchGender && matchRecovery;
    });

    if (filtered.length === 0) {
      tableBody.innerHTML = `
        <tr>
          <td colspan="7" style="text-align: center; padding: 40px; color: var(--text-muted);">
            Атлеты по заданным критериям не найдены.
          </td>
        </tr>
      `;
      return;
    }

    tableBody.innerHTML = filtered.map(a => {
      const initials = a.name.split(' ').map(n => n[0]).join('').substring(0, 2);
      const zoneBadgeClass = a.recoveryZone === 'optimal' ? 'badge-optimal' : (a.recoveryZone === 'normal' ? 'badge-normal' : 'badge-low');
      const zoneLabel = a.recoveryZone === 'optimal' ? 'Оптимально' : (a.recoveryZone === 'normal' ? 'В норме' : 'Низкое');
      
      const calibBadge = a.isCalibrated 
        ? `<span class="badge" style="background: rgba(127,160,136,0.1); color: var(--accent-sage);">День 14/14</span>`
        : `<span class="badge badge-calib">Калибровка ${a.calibrationDay}/14</span>`;

      const deviceStatus = a.device?.connected
        ? `<span class="badge badge-connected">СААТ-1 (${a.device.battery}%)</span>`
        : `<span class="badge" style="background: #1C2028; color: var(--text-muted);">Отключен</span>`;

      return `
        <tr>
          <td>
            <div class="user-info-cell">
              <div class="user-avatar">${initials}</div>
              <div>
                <div class="user-name">${a.name}</div>
                <div class="user-email">${a.email}</div>
              </div>
            </div>
          </td>
          <td>
            <span class="badge ${zoneBadgeClass}">${a.recoveryScore}% · ${zoneLabel}</span>
          </td>
          <td>
            <div style="font-family: var(--font-mono); font-size: 13px;">
              <span>${a.currentStrain}</span> <span style="color: var(--text-muted);">/ ${a.targetStrainMax}</span>
            </div>
          </td>
          <td>
            <div style="font-family: var(--font-mono); font-size: 12px;">
              ❤️ ${a.heartRate} bpm · HRV ${a.hrv} ms
            </div>
          </td>
          <td>${deviceStatus}</td>
          <td>${calibBadge}</td>
          <td>
            <div style="display: flex; gap: 6px;">
              <button class="btn btn-outline btn-sm" onclick="adminApp.openEditModal('${a.id}')">Редактировать</button>
              <button class="btn btn-outline btn-sm" title="Сбросить 14-дневную калибровку" onclick="adminApp.resetCalibration('${a.id}')">Сброс 14д</button>
              <button class="btn btn-outline btn-sm" title="Симулировать телеметрию СААТ-1" onclick="adminApp.simulateTelemetry('${a.id}')">⚡ Тест</button>
              <button class="btn btn-danger btn-sm" title="Удалить атлета" onclick="adminApp.deleteAthlete('${a.id}')">✕</button>
            </div>
          </td>
        </tr>
      `;
    }).join('');
  }

  // ==========================================
  // 3. ТЕЛЕМЕТРИЯ (TELEMETRY)
  // ==========================================

  renderTelemetry() {
    const container = document.getElementById('telemetryGrid');
    if (!container) return;

    container.innerHTML = this.athletes.map(a => `
      <div class="kpi-card" style="gap: 12px;">
        <div style="display: flex; justify-content: space-between; align-items: center;">
          <strong style="font-size: 14px;">${a.name}</strong>
          <span style="font-size: 11px; color: var(--text-muted);">${a.device?.mac || 'СААТ-1'}</span>
        </div>
        <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; text-align: center; background: var(--bg-input); padding: 10px; border-radius: var(--radius-md);">
          <div>
            <div style="font-size: 10px; color: var(--text-muted);">ГОТОВНОСТЬ</div>
            <div style="font-size: 18px; font-weight: 800; color: ${a.recoveryScore >= 67 ? 'var(--accent-sage)' : (a.recoveryScore >= 34 ? 'var(--accent-amber)' : 'var(--accent-coral)')};">
              ${a.recoveryScore}%
            </div>
          </div>
          <div>
            <div style="font-size: 10px; color: var(--text-muted);">HRV ПУЛЬСА</div>
            <div style="font-size: 18px; font-weight: 800; color: var(--accent-cyan);">${a.hrv} ms</div>
          </div>
          <div>
            <div style="font-size: 10px; color: var(--text-muted);">ПУЛЬС ПОКОЯ</div>
            <div style="font-size: 18px; font-weight: 800; color: var(--text-main);">${a.restingHeartRate}</div>
          </div>
        </div>
        <div style="display: flex; justify-content: space-between; font-size: 12px; color: var(--text-secondary);">
          <span>Сон: <strong>${a.sleepHours}ч ${a.sleepMinutes}м</strong> (${a.sleepScore}%)</span>
          <span>Нагрузка: <strong>${a.currentStrain}</strong></span>
        </div>
        <div style="display: flex; gap: 8px; margin-top: 4px;">
          <button class="btn btn-outline btn-sm" style="flex: 1;" onclick="adminApp.simulateTelemetry('${a.id}')">Сгенерировать пакет</button>
        </div>
      </div>
    `).join('');
  }

  // ==========================================
  // 4. ТРЕНИРОВКИ (WORKOUTS)
  // ==========================================

  renderWorkouts() {
    const tableBody = document.getElementById('workoutsTableBody');
    if (!tableBody) return;

    tableBody.innerHTML = this.workouts.map(w => {
      return `
        <tr>
          <td>
            <strong>${w.athleteName}</strong>
          </td>
          <td>
            <span class="badge" style="background: rgba(229,169,60,0.15); color: var(--accent-amber);">
              ${w.sportTitle}
            </span>
          </td>
          <td style="font-family: var(--font-mono);">${w.durationMins} мин</td>
          <td style="font-family: var(--font-mono);">${w.distanceKm > 0 ? `${w.distanceKm} км` : '—'}</td>
          <td style="font-family: var(--font-mono);">${w.calories} ккал</td>
          <td style="font-family: var(--font-mono);">${w.avgHr} / ${w.maxHr} bpm</td>
          <td style="font-family: var(--font-mono); font-weight: 700; color: var(--accent-amber);">${w.strain}</td>
          <td style="color: var(--text-muted); font-size: 12px;">${new Date(w.date).toLocaleString('ru-RU')}</td>
        </tr>
      `;
    }).join('');
  }

  // ==========================================
  // 5. ЛИГИ И ПАРТНЁРЫ (LEAGUES)
  // ==========================================

  renderLeagues() {
    const container = document.getElementById('leaguesContainer');
    if (!container) return;

    container.innerHTML = this.leagues.map(l => `
      <div class="kpi-card" style="gap: 10px;">
        <div style="display: flex; justify-content: space-between; align-items: center;">
          <strong style="font-size: 16px;">${l.name}</strong>
          <span class="badge badge-normal" style="font-family: var(--font-mono);">${l.code}</span>
        </div>
        <div style="color: var(--text-secondary); font-size: 13px;">
          Лидер лиги: <strong style="color: var(--text-main);">${l.leaderName}</strong>
        </div>
        <div style="display: flex; justify-content: space-between; font-size: 12px; color: var(--text-muted); border-top: 1px solid var(--border-subtle); padding-top: 8px;">
          <span>Участников: <strong>${l.membersCount}</strong></span>
          <span>Средний Strain: <strong>${l.avgStrain}</strong></span>
        </div>
      </div>
    `).join('');
  }

  // ==========================================
  // 6. ПУШ-УВЕДОМЛЕНИЯ (PUSH NOTIFICATIONS)
  // ==========================================

  renderPush() {
    const historyBody = document.getElementById('pushHistoryBody');
    if (!historyBody) return;

    historyBody.innerHTML = this.pushHistory.map(p => `
      <tr>
        <td><strong>${p.title}</strong></td>
        <td style="color: var(--text-secondary); max-width: 320px;">${p.body}</td>
        <td><span class="badge badge-normal">${p.audience}</span></td>
        <td style="color: var(--text-muted); font-size: 12px;">${new Date(p.sentAt).toLocaleString('ru-RU')}</td>
        <td><span class="badge badge-optimal">Доставлено</span></td>
      </tr>
    `).join('');
  }

  // ==========================================
  // 7. НАСТРОЙКИ И ЭКСПОРТ (SETTINGS)
  // ==========================================

  renderSettings() {
    const liveToggle = document.getElementById('liveModeToggle');
    if (liveToggle) {
      liveToggle.checked = window.kalkanBackend.isLive;
    }
  }

  // ==========================================
  // ДЕЙСТВИЯ НАД ДАННЫМИ (ACTIONS)
  // ==========================================

  async openEditModal(athleteId) {
    const athlete = this.athletes.find(a => a.id === athleteId);
    if (!athlete) return;

    document.getElementById('editAthleteId').value = athlete.id;
    document.getElementById('editName').value = athlete.name;
    document.getElementById('editEmail').value = athlete.email;
    document.getElementById('editGender').value = athlete.gender;
    document.getElementById('editHeight').value = athlete.heightCm;
    document.getElementById('editWeight').value = athlete.weightKg;
    document.getElementById('editRecovery').value = athlete.recoveryScore;
    document.getElementById('editHrv').value = athlete.hrv;
    document.getElementById('editStrain').value = athlete.currentStrain;

    document.getElementById('modalEditAthlete').classList.add('active');
  }

  closeModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) modal.classList.remove('active');
  }

  async saveAthleteForm() {
    const id = document.getElementById('editAthleteId').value;
    const recoveryScore = parseInt(document.getElementById('editRecovery').value) || 75;
    const updatedData = {
      id,
      name: document.getElementById('editName').value,
      email: document.getElementById('editEmail').value,
      gender: document.getElementById('editGender').value,
      heightCm: parseFloat(document.getElementById('editHeight').value) || 175,
      weightKg: parseFloat(document.getElementById('editWeight').value) || 70,
      recoveryScore: recoveryScore,
      recoveryZone: recoveryScore >= 67 ? 'optimal' : (recoveryScore >= 34 ? 'normal' : 'low'),
      hrv: parseInt(document.getElementById('editHrv').value) || 60,
      currentStrain: parseFloat(document.getElementById('editStrain').value) || 10.0,
      lastSync: new Date().toISOString()
    };

    await window.kalkanBackend.saveAthlete(updatedData);
    await this.loadAllData();
    this.closeModal('modalEditAthlete');
    this.renderCurrentTab();
    this.showToast('Профиль атлета успешно сохранён!');
  }

  async resetCalibration(id) {
    if (confirm('Сбросить 14-дневную калибровку персонального baseline для этого атлета?')) {
      await window.kalkanBackend.resetCalibration(id);
      await this.loadAllData();
      this.renderCurrentTab();
      this.showToast('Калибровка сброшена на день 1.');
    }
  }

  async simulateTelemetry(id) {
    const athlete = await window.kalkanBackend.simulateTelemetry(id);
    await this.loadAllData();
    this.renderCurrentTab();
    this.showToast(`СААТ-1 передал пакет для ${athlete.name}: ${athlete.heartRate} bpm.`);
  }

  async deleteAthlete(id) {
    if (confirm('Вы уверены, что хотите удалить этого атлета из базы?')) {
      await window.kalkanBackend.deleteAthlete(id);
      await this.loadAllData();
      this.renderCurrentTab();
      this.showToast('Атлет удалён из системы.');
    }
  }

  openAddModal() {
    document.getElementById('modalAddAthlete').classList.add('active');
  }

  async createAthleteForm() {
    const newAthlete = {
      id: "ath_" + Date.now(),
      name: document.getElementById('addName').value || 'Новый Атлет',
      email: document.getElementById('addEmail').value || 'new@kalkan.sport',
      gender: document.getElementById('addGender').value || 'male',
      age: parseInt(document.getElementById('addAge').value) || 25,
      heightCm: parseFloat(document.getElementById('addHeight').value) || 175,
      weightKg: parseFloat(document.getElementById('addWeight').value) || 70,
      status: "active",
      calibrationDay: 1,
      isCalibrated: false,
      recoveryScore: 82,
      recoveryZone: "optimal",
      heartRate: 64,
      restingHeartRate: 50,
      hrv: 68,
      currentStrain: 0.0,
      targetStrainMax: 14.0,
      sleepHours: 7,
      sleepMinutes: 30,
      sleepScore: 85,
      deepSleepMins: 90,
      remSleepMins: 80,
      device: {
        name: "СААТ-1 Obsidian",
        mac: "D4:AA:BB:CC:11:22",
        connected: true,
        battery: 100,
        firmware: "v1.4.2"
      },
      lastSync: new Date().toISOString(),
      createdAt: new Date().toISOString()
    };

    await window.kalkanBackend.saveAthlete(newAthlete);
    await this.loadAllData();
    this.closeModal('modalAddAthlete');
    this.renderCurrentTab();
    this.showToast('Новый атлет успешно добавлен в KALKAN SPORT!');
  }

  async sendPushNotificationForm() {
    const title = document.getElementById('pushTitle').value;
    const body = document.getElementById('pushBody').value;
    const audience = document.getElementById('pushAudience').value;

    if (!title || !body) {
      alert('Пожалуйста, заполните заголовок и текст уведомления.');
      return;
    }

    await window.kalkanBackend.sendPushNotification({ title, body, audience });
    await this.loadAllData();
    this.renderPush();
    this.showToast('Пуш-уведомление успешно разослано!');
    document.getElementById('pushTitle').value = '';
    document.getElementById('pushBody').value = '';
  }

  setPushTemplate(title, body) {
    document.getElementById('pushTitle').value = title;
    document.getElementById('pushBody').value = body;
  }

  exportCSV() {
    const csvContent = "data:text/csv;charset=utf-8," + encodeURIComponent(window.kalkanBackend.exportCSV());
    const dlAnchor = document.createElement('a');
    dlAnchor.setAttribute("href", csvContent);
    dlAnchor.setAttribute("download", `kalkan_athletes_${new Date().toISOString().slice(0,10)}.csv`);
    document.body.appendChild(dlAnchor);
    dlAnchor.click();
    dlAnchor.remove();
    this.showToast('Экспорт CSV файла завершён.');
  }

  exportJSON() {
    const jsonContent = "data:text/json;charset=utf-8," + encodeURIComponent(window.kalkanBackend.exportJSON());
    const dlAnchor = document.createElement('a');
    dlAnchor.setAttribute("href", jsonContent);
    dlAnchor.setAttribute("download", `kalkan_database_${new Date().toISOString().slice(0,10)}.json`);
    document.body.appendChild(dlAnchor);
    dlAnchor.click();
    dlAnchor.remove();
    this.showToast('Экспорт JSON бэкапа завершён.');
  }

  importJSONFile(event) {
    const file = event.target.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = async (e) => {
      const success = window.kalkanBackend.importJSON(e.target.result);
      if (success) {
        await this.loadAllData();
        this.renderCurrentTab();
        this.showToast('База данных успешно импортирована!');
      } else {
        alert('Ошибка при импорте JSON: неверная структура данных.');
      }
    };
    reader.readAsText(file);
  }

  resetAllData() {
    if (confirm('Сбросить все данные админ-панели до исходного демонстрационного состояния?')) {
      window.kalkanBackend.resetToDefault();
      this.loadAllData().then(() => {
        this.renderCurrentTab();
        this.showToast('Данные восстановлены по умолчанию.');
      });
    }
  }

  updateLiveIndicator() {
    const dot = document.getElementById('statusPulseDot');
    const label = document.getElementById('statusModeLabel');
    if (window.kalkanBackend.isLive) {
      if (dot) dot.className = 'pulse-dot';
      if (label) label.textContent = 'Live Firestore (watch-ba720)';
    } else {
      if (dot) dot.className = 'pulse-dot amber';
      if (label) label.textContent = 'Демо / Симулятор СААТ-1';
    }
  }

  toggleLiveMode(enabled) {
    window.kalkanBackend.setLiveMode(enabled);
    this.updateLiveIndicator();
    this.loadAllData().then(() => {
      this.renderCurrentTab();
      this.showToast(enabled ? 'Включён режим Live Firestore.' : 'Включён автономный Демо-режим.');
    });
  }

  showToast(message) {
    const container = document.getElementById('toastContainer');
    if (!container) return;

    const toast = document.createElement('div');
    toast.className = 'toast';
    toast.innerHTML = `<span>⚡</span> <span>${message}</span>`;
    container.appendChild(toast);

    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transform = 'translateY(10px)';
      toast.style.transition = 'all 0.2s';
      setTimeout(() => toast.remove(), 200);
    }, 3000);
  }

  setupEventListeners() {
    // Поиск атлетов в шапке
    const searchInput = document.getElementById('globalSearchInput');
    if (searchInput) {
      searchInput.addEventListener('input', (e) => {
        this.searchQuery = e.target.value;
        if (this.currentTab === 'athletes') this.renderAthletes();
      });
    }

    // Чипы фильтров атлетов
    document.querySelectorAll('.chip[data-filter-group="gender"]').forEach(chip => {
      chip.addEventListener('click', () => {
        document.querySelectorAll('.chip[data-filter-group="gender"]').forEach(c => c.classList.remove('active'));
        chip.classList.add('active');
        this.genderFilter = chip.getAttribute('data-value');
        this.renderAthletes();
      });
    });

    document.querySelectorAll('.chip[data-filter-group="recovery"]').forEach(chip => {
      chip.addEventListener('click', () => {
        document.querySelectorAll('.chip[data-filter-group="recovery"]').forEach(c => c.classList.remove('active'));
        chip.classList.add('active');
        this.recoveryFilter = chip.getAttribute('data-value');
        this.renderAthletes();
      });
    });
  }
}

// Запуск приложения при загрузке документа
document.addEventListener('DOMContentLoaded', () => {
  window.adminApp = new KalkanAdminApp();
});
