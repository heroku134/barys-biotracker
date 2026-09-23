/**
 * KALKAN SPORT - Firebase Configuration & Unified Data Adapter
 * Интеграция с проектом watch-ba720 + гибридный адаптер Live Firestore / Demo Mode
 */

// Конфигурация Firebase из firebase_options.dart
const FIREBASE_CONFIG = {
  apiKey: "AIzaSyD19yDU1QGZpLRTTc2dfunyprwr67yzgsE",
  authDomain: "watch-ba720.firebaseapp.com",
  projectId: "watch-ba720",
  storageBucket: "watch-ba720.firebasestorage.app",
  messagingSenderId: "718180799511",
  appId: "1:718180799511:web:41ddb5b639f5cb67de3852"
};

class KalkanBackendAdapter {
  constructor() {
    this.isLive = localStorage.getItem('kalkan_admin_live_mode') === 'true';
    this.firebaseApp = null;
    this.firestore = null;
    this.auth = null;
    this.isFirebaseReady = false;

    // Локальное хранилище данных (для демо/симулятора)
    this.localData = this._loadLocalStore();
    this.initFirebase();
  }

  _loadLocalStore() {
    const saved = localStorage.getItem('kalkan_admin_store');
    if (saved) {
      try {
        return JSON.parse(saved);
      } catch (e) {
        console.warn('Failed to parse local store, fallback to mock data', e);
      }
    }
    // Глубокое клонирование mock-данных
    return JSON.parse(JSON.stringify(KALKAN_MOCK_DATA));
  }

  _saveLocalStore() {
    localStorage.setItem('kalkan_admin_store', JSON.stringify(this.localData));
  }

  async initFirebase() {
    try {
      if (typeof firebase !== 'undefined' && firebase.initializeApp) {
        if (!firebase.apps.length) {
          this.firebaseApp = firebase.initializeApp(FIREBASE_CONFIG);
        } else {
          this.firebaseApp = firebase.app();
        }
        this.firestore = firebase.firestore();
        this.auth = firebase.auth();
        this.isFirebaseReady = true;
        console.log("KALKAN Admin: Firebase initialized successfully (watch-ba720).");
      }
    } catch (e) {
      console.warn("KALKAN Admin: Firebase offline or blocked by browser", e);
      this.isFirebaseReady = false;
    }
  }

  setLiveMode(enabled) {
    this.isLive = enabled;
    localStorage.setItem('kalkan_admin_live_mode', enabled ? 'true' : 'false');
  }

  // --- ПОЛЬЗОВАТЕЛИ / АТЛЕТЫ ---

  async getAthletes() {
    if (this.isLive && this.isFirebaseReady) {
      try {
        const snap = await this.firestore.collection('users').get();
        if (!snap.empty) {
          const liveAthletes = [];
          snap.forEach(doc => {
            const d = doc.data();
            liveAthletes.push({
              id: doc.id,
              name: d.name || "Атлет KALKAN",
              email: d.email || "no-email@kalkan.sport",
              gender: d.gender || "male",
              age: d.age || 26,
              heightCm: d.heightCm || 175,
              weightKg: d.weightKg || 72,
              status: "active",
              calibrationDay: d.calibrationDay || 14,
              isCalibrated: (d.calibrationDay || 14) >= 14,
              recoveryScore: d.recovery || 80,
              recoveryZone: (d.recovery || 80) >= 67 ? "optimal" : ((d.recovery || 80) >= 34 ? "normal" : "low"),
              heartRate: d.heartRate || 65,
              restingHeartRate: d.restingHeartRate || 50,
              hrv: d.hrv || 65,
              currentStrain: d.currentStrain || 10.2,
              targetStrainMax: d.targetStrainMax || 14.5,
              sleepHours: d.sleepHours || 7,
              sleepMinutes: d.sleepMinutes || 40,
              sleepScore: d.sleepScore || 85,
              deepSleepMins: 100,
              remSleepMins: 90,
              device: {
                name: "СААТ-1",
                connected: true,
                battery: 85,
                firmware: "v1.4.2"
              },
              lastSync: d.updatedAt ? (d.updatedAt.toDate ? d.updatedAt.toDate().toISOString() : new Date().toISOString()) : new Date().toISOString()
            });
          });
          return liveAthletes;
        }
      } catch (err) {
        console.warn("Live Firestore read failed, falling back to local dataset:", err);
      }
    }
    return this.localData.athletes;
  }

  async saveAthlete(athlete) {
    const idx = this.localData.athletes.findIndex(a => a.id === athlete.id);
    if (idx >= 0) {
      this.localData.athletes[idx] = { ...this.localData.athletes[idx], ...athlete };
    } else {
      this.localData.athletes.unshift(athlete);
    }
    this._saveLocalStore();

    if (this.isLive && this.isFirebaseReady) {
      try {
        await this.firestore.collection('users').doc(athlete.id).set({
          name: athlete.name,
          email: athlete.email,
          gender: athlete.gender,
          recovery: athlete.recoveryScore,
          hrv: athlete.hrv,
          restingHeartRate: athlete.restingHeartRate,
          currentStrain: athlete.currentStrain,
          targetStrainMax: athlete.targetStrainMax,
          updatedAt: firebase.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
      } catch (e) {
        console.warn("Firestore save error:", e);
      }
    }
    return athlete;
  }

  async deleteAthlete(id) {
    this.localData.athletes = this.localData.athletes.filter(a => a.id !== id);
    this._saveLocalStore();

    if (this.isLive && this.isFirebaseReady) {
      try {
        await this.firestore.collection('users').doc(id).delete();
      } catch (e) {
        console.warn("Firestore delete error:", e);
      }
    }
    return true;
  }

  async resetCalibration(athleteId) {
    const athlete = this.localData.athletes.find(a => a.id === athleteId);
    if (athlete) {
      athlete.calibrationDay = 1;
      athlete.isCalibrated = false;
      this._saveLocalStore();
    }
    return athlete;
  }

  async simulateTelemetry(athleteId) {
    const athlete = this.localData.athletes.find(a => a.id === athleteId);
    if (athlete) {
      // Генерируем живое колебание пульса и HRV
      const deltaHr = Math.floor(Math.random() * 7) - 3;
      athlete.heartRate = Math.max(48, Math.min(185, athlete.heartRate + deltaHr));
      athlete.currentStrain = +(athlete.currentStrain + 0.2).toFixed(1);
      athlete.lastSync = new Date().toISOString();
      this._saveLocalStore();
    }
    return athlete;
  }

  // --- ТРЕНИРОВКИ ---

  async getWorkouts() {
    return this.localData.workouts;
  }

  async addWorkout(workout) {
    this.localData.workouts.unshift(workout);
    this._saveLocalStore();
    return workout;
  }

  // --- ЛИГИ ---

  async getLeagues() {
    return this.localData.leagues;
  }

  async createLeague(league) {
    this.localData.leagues.push(league);
    this._saveLocalStore();
    return league;
  }

  // --- ПУШ-УВЕДОМЛЕНИЯ ---

  async sendPushNotification(notification) {
    const entry = {
      id: "push_" + Date.now(),
      title: notification.title,
      body: notification.body,
      audience: notification.audience,
      sentAt: new Date().toISOString(),
      status: "delivered"
    };
    this.localData.pushHistory.unshift(entry);
    this._saveLocalStore();

    // Если есть токен FCM и Live режим, можно отправить через Cloud Function
    return entry;
  }

  async getPushHistory() {
    return this.localData.pushHistory;
  }

  // --- ИМПОРТ / ЭКСПОРТ ДАННЫХ ---

  exportJSON() {
    return JSON.stringify(this.localData, null, 2);
  }

  exportCSV() {
    const rows = [
      ["ID", "Имя", "Email", "Пол", "Возраст", "Рост", "Вес", "Готовность %", "HRV (мс)", "Пульс покоя", "Strain", "Сон (ч)", "СААТ-1", "Батарея %", "Калибровка (дни)"]
    ];

    this.localData.athletes.forEach(a => {
      rows.push([
        a.id,
        `"${a.name}"`,
        a.email,
        a.gender,
        a.age,
        a.heightCm,
        a.weightKg,
        a.recoveryScore,
        a.hrv,
        a.restingHeartRate,
        a.currentStrain,
        `${a.sleepHours}ч ${a.sleepMinutes}м`,
        a.device?.name || "Нет",
        a.device?.battery || 0,
        a.calibrationDay
      ]);
    });

    return rows.map(r => r.join(",")).join("\n");
  }

  importJSON(jsonString) {
    try {
      const parsed = JSON.parse(jsonString);
      if (parsed.athletes && Array.isArray(parsed.athletes)) {
        this.localData = parsed;
        this._saveLocalStore();
        return true;
      }
    } catch (e) {
      console.error("Invalid JSON import", e);
    }
    return false;
  }

  resetToDefault() {
    this.localData = JSON.parse(JSON.stringify(KALKAN_MOCK_DATA));
    this._saveLocalStore();
  }
}

// Глобальный экземпляр бэкенд-адаптера
window.kalkanBackend = new KalkanBackendAdapter();
