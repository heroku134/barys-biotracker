/**
 * KALKAN SPORT - Mock Database & Realistic Athletic Seed Data
 * Предустановленный набор реалистичных данных атлетов для автономной работы и тестирования
 */

const KALKAN_MOCK_DATA = {
  // Список атлетов платформы
  athletes: [
    {
      id: "ath_001",
      name: "Алихан Султанов",
      email: "alikhan@kalkan.sport",
      gender: "male",
      age: 27,
      heightCm: 182,
      weightKg: 78,
      status: "active",
      calibrationDay: 14,
      isCalibrated: true,
      recoveryScore: 88,
      recoveryZone: "optimal", // optimal, normal, low
      heartRate: 64,
      restingHeartRate: 49,
      hrv: 72,
      currentStrain: 12.4,
      targetStrainMax: 15.0,
      sleepHours: 7,
      sleepMinutes: 45,
      sleepScore: 91,
      deepSleepMins: 110,
      remSleepMins: 95,
      device: {
        name: "СААТ-1 Obsidian",
        mac: "D4:F5:13:88:2A:41",
        connected: true,
        battery: 84,
        firmware: "v1.4.2"
      },
      lastSync: "2026-09-23T15:45:00Z",
      createdAt: "2026-08-10T10:00:00Z"
    },
    {
      id: "ath_002",
      name: "Айсулуу Тыныбекова",
      email: "aysuluu@kalkan.sport",
      gender: "female",
      age: 26,
      heightCm: 168,
      weightKg: 62,
      status: "active",
      calibrationDay: 14,
      isCalibrated: true,
      recoveryScore: 94,
      recoveryZone: "optimal",
      heartRate: 58,
      restingHeartRate: 46,
      hrv: 86,
      currentStrain: 16.8,
      targetStrainMax: 17.5,
      sleepHours: 8,
      sleepMinutes: 15,
      sleepScore: 95,
      deepSleepMins: 135,
      remSleepMins: 110,
      cycle: {
        cycleDay: 12,
        phase: "follicular",
        partnerCode: "AYS-784",
        partnerName: "Алихан Султанов"
      },
      device: {
        name: "СААТ-1 Titanium",
        mac: "C8:2B:96:11:4E:90",
        connected: true,
        battery: 92,
        firmware: "v1.4.2"
      },
      lastSync: "2026-09-23T15:52:00Z",
      createdAt: "2026-08-01T08:30:00Z"
    },
    {
      id: "ath_003",
      name: "Искандер Бакиров",
      email: "iskander@kalkan.sport",
      gender: "male",
      age: 31,
      heightCm: 176,
      weightKg: 74,
      status: "active",
      calibrationDay: 14,
      isCalibrated: true,
      recoveryScore: 54,
      recoveryZone: "normal",
      heartRate: 72,
      restingHeartRate: 56,
      hrv: 52,
      currentStrain: 9.8,
      targetStrainMax: 12.5,
      sleepHours: 6,
      sleepMinutes: 20,
      sleepScore: 68,
      deepSleepMins: 70,
      remSleepMins: 60,
      device: {
        name: "СААТ-1 Obsidian",
        mac: "E1:44:6C:9A:12:0F",
        connected: true,
        battery: 45,
        firmware: "v1.4.2"
      },
      lastSync: "2026-09-23T14:10:00Z",
      createdAt: "2026-08-15T12:00:00Z"
    },
    {
      id: "ath_004",
      name: "Бегимай Сапарова",
      email: "begimay@kalkan.sport",
      gender: "female",
      age: 24,
      heightCm: 172,
      weightKg: 58,
      status: "active",
      calibrationDay: 7,
      isCalibrated: false,
      recoveryScore: 78,
      recoveryZone: "optimal",
      heartRate: 66,
      restingHeartRate: 51,
      hrv: 64,
      currentStrain: 11.2,
      targetStrainMax: 14.0,
      sleepHours: 7,
      sleepMinutes: 30,
      sleepScore: 82,
      deepSleepMins: 90,
      remSleepMins: 85,
      cycle: {
        cycleDay: 21,
        phase: "luteal",
        partnerCode: "BEG-910",
        partnerName: null
      },
      device: {
        name: "СААТ-1 Rose Gold",
        mac: "F2:18:7E:33:0A:77",
        connected: true,
        battery: 68,
        firmware: "v1.4.2"
      },
      lastSync: "2026-09-23T15:20:00Z",
      createdAt: "2026-09-16T14:00:00Z"
    },
    {
      id: "ath_005",
      name: "Чыңгыз Айтматов",
      email: "chyngyz@kalkan.sport",
      gender: "male",
      age: 35,
      heightCm: 185,
      weightKg: 85,
      status: "active",
      calibrationDay: 14,
      isCalibrated: true,
      recoveryScore: 29,
      recoveryZone: "low",
      heartRate: 82,
      restingHeartRate: 64,
      hrv: 34,
      currentStrain: 4.5,
      targetStrainMax: 8.5,
      sleepHours: 5,
      sleepMinutes: 10,
      sleepScore: 48,
      deepSleepMins: 40,
      remSleepMins: 45,
      device: {
        name: "СААТ-1 Obsidian",
        mac: "A9:31:44:88:FF:10",
        connected: false,
        battery: 18,
        firmware: "v1.4.1"
      },
      lastSync: "2026-09-23T09:15:00Z",
      createdAt: "2026-07-20T09:00:00Z"
    },
    {
      id: "ath_006",
      name: "Данияр Касымов",
      email: "daniyar@kalkan.sport",
      gender: "male",
      age: 29,
      heightCm: 179,
      weightKg: 81,
      status: "active",
      calibrationDay: 14,
      isCalibrated: true,
      recoveryScore: 82,
      recoveryZone: "optimal",
      heartRate: 61,
      restingHeartRate: 50,
      hrv: 70,
      currentStrain: 14.1,
      targetStrainMax: 15.5,
      sleepHours: 7,
      sleepMinutes: 50,
      sleepScore: 89,
      deepSleepMins: 115,
      remSleepMins: 90,
      device: {
        name: "СААТ-1 Stealth",
        mac: "BB:70:12:44:99:3C",
        connected: true,
        battery: 79,
        firmware: "v1.4.2"
      },
      lastSync: "2026-09-23T15:30:00Z",
      createdAt: "2026-08-05T11:00:00Z"
    },
    {
      id: "ath_007",
      name: "Салтанат Орозбекова",
      email: "saltanat@kalkan.sport",
      gender: "female",
      age: 28,
      heightCm: 165,
      weightKg: 55,
      status: "active",
      calibrationDay: 4,
      isCalibrated: false,
      recoveryScore: 65,
      recoveryZone: "normal",
      heartRate: 69,
      restingHeartRate: 54,
      hrv: 58,
      currentStrain: 8.4,
      targetStrainMax: 12.0,
      sleepHours: 7,
      sleepMinutes: 10,
      sleepScore: 78,
      deepSleepMins: 85,
      remSleepMins: 75,
      cycle: {
        cycleDay: 5,
        phase: "menstrual",
        partnerCode: "SLT-332",
        partnerName: "Данияр Касымов"
      },
      device: {
        name: "СААТ-1 Rose Gold",
        mac: "CC:88:51:20:AA:19",
        connected: true,
        battery: 95,
        firmware: "v1.4.2"
      },
      lastSync: "2026-09-23T15:40:00Z",
      createdAt: "2026-09-19T10:00:00Z"
    },
    {
      id: "ath_008",
      name: "Арсен Жумалиев",
      email: "arsen@kalkan.sport",
      gender: "male",
      age: 25,
      heightCm: 188,
      weightKg: 89,
      status: "active",
      calibrationDay: 14,
      isCalibrated: true,
      recoveryScore: 91,
      recoveryZone: "optimal",
      heartRate: 59,
      restingHeartRate: 47,
      hrv: 82,
      currentStrain: 17.5,
      targetStrainMax: 18.0,
      sleepHours: 8,
      sleepMinutes: 30,
      sleepScore: 96,
      deepSleepMins: 140,
      remSleepMins: 115,
      device: {
        name: "СААТ-1 Obsidian",
        mac: "EE:99:32:10:55:04",
        connected: true,
        battery: 62,
        firmware: "v1.4.2"
      },
      lastSync: "2026-09-23T15:50:00Z",
      createdAt: "2026-07-15T15:00:00Z"
    },
    {
      id: "ath_009",
      name: "Жылдыз Асылбекова",
      email: "zhyldyz@kalkan.sport",
      gender: "female",
      age: 30,
      heightCm: 170,
      weightKg: 64,
      status: "inactive",
      calibrationDay: 14,
      isCalibrated: true,
      recoveryScore: 42,
      recoveryZone: "normal",
      heartRate: 75,
      restingHeartRate: 59,
      hrv: 44,
      currentStrain: 3.1,
      targetStrainMax: 11.0,
      sleepHours: 6,
      sleepMinutes: 0,
      sleepScore: 61,
      deepSleepMins: 60,
      remSleepMins: 55,
      cycle: {
        cycleDay: 16,
        phase: "ovulatory",
        partnerCode: "ZHY-441",
        partnerName: null
      },
      device: {
        name: "СААТ-1 Titanium",
        mac: "AA:11:88:44:66:88",
        connected: false,
        battery: 22,
        firmware: "v1.4.0"
      },
      lastSync: "2026-09-22T19:00:00Z",
      createdAt: "2026-08-20T16:00:00Z"
    },
    {
      id: "ath_010",
      name: "Тимур Мамбетов",
      email: "timur@kalkan.sport",
      gender: "male",
      age: 33,
      heightCm: 180,
      weightKg: 77,
      status: "active",
      calibrationDay: 11,
      isCalibrated: false,
      recoveryScore: 76,
      recoveryZone: "optimal",
      heartRate: 65,
      restingHeartRate: 52,
      hrv: 66,
      currentStrain: 10.5,
      targetStrainMax: 13.5,
      sleepHours: 7,
      sleepMinutes: 15,
      sleepScore: 84,
      deepSleepMins: 95,
      remSleepMins: 80,
      device: {
        name: "СААТ-1 Obsidian",
        mac: "77:88:99:AA:BB:CC",
        connected: true,
        battery: 88,
        firmware: "v1.4.2"
      },
      lastSync: "2026-09-23T15:15:00Z",
      createdAt: "2026-09-12T13:00:00Z"
    }
  ],

  // Недавние тренировки
  workouts: [
    {
      id: "w_101",
      athleteId: "ath_002",
      athleteName: "Айсулуу Тыныбекова",
      sport: "runOutdoor",
      sportTitle: "Бег на улице",
      durationMins: 52,
      distanceKm: 10.4,
      calories: 640,
      avgHr: 158,
      maxHr: 178,
      strain: 14.8,
      date: "2026-09-23T10:30:00Z"
    },
    {
      id: "w_102",
      athleteId: "ath_008",
      athleteName: "Арсен Жумалиев",
      sport: "strength",
      sportTitle: "Силовая сессия",
      durationMins: 75,
      distanceKm: 0,
      calories: 520,
      avgHr: 138,
      maxHr: 168,
      strain: 13.2,
      date: "2026-09-23T12:00:00Z"
    },
    {
      id: "w_103",
      athleteId: "ath_001",
      athleteName: "Алихан Султанов",
      sport: "cycling",
      sportTitle: "Велоспорт",
      durationMins: 64,
      distanceKm: 24.5,
      calories: 580,
      avgHr: 142,
      maxHr: 165,
      strain: 11.8,
      date: "2026-09-23T08:15:00Z"
    },
    {
      id: "w_104",
      athleteId: "ath_006",
      athleteName: "Данияр Касымов",
      sport: "hiit",
      sportTitle: "Интервалы HIIT",
      durationMins: 38,
      distanceKm: 0,
      calories: 460,
      avgHr: 162,
      maxHr: 182,
      strain: 13.9,
      date: "2026-09-23T14:00:00Z"
    },
    {
      id: "w_105",
      athleteId: "ath_004",
      athleteName: "Бегимай Сапарова",
      sport: "swimming",
      sportTitle: "Плавание в бассейне",
      durationMins: 45,
      distanceKm: 1.8,
      calories: 390,
      avgHr: 134,
      maxHr: 154,
      strain: 10.4,
      date: "2026-09-23T09:00:00Z"
    },
    {
      id: "w_106",
      athleteId: "ath_003",
      athleteName: "Искандер Бакиров",
      sport: "runIndoor",
      sportTitle: "Беговая дорожка",
      durationMins: 40,
      distanceKm: 6.2,
      calories: 380,
      avgHr: 145,
      maxHr: 162,
      strain: 9.2,
      date: "2026-09-23T07:30:00Z"
    }
  ],

  // Приватные лиги
  leagues: [
    {
      id: "lg_01",
      name: "Бишкек Марафон Клуб",
      code: "BISH-RUN",
      membersCount: 28,
      leaderName: "Айсулуу Тыныбекова",
      avgStrain: 14.6,
      createdAt: "2026-08-01"
    },
    {
      id: "lg_02",
      name: "Калкан Спартанцы (HIIT)",
      code: "KLK-SPRT",
      membersCount: 16,
      leaderName: "Арсен Жумалиев",
      avgStrain: 15.2,
      createdAt: "2026-08-15"
    },
    {
      id: "lg_03",
      name: "Тянь-Шань Трейлраннинг",
      code: "TSH-TRAIL",
      membersCount: 42,
      leaderName: "Алихан Султанов",
      avgStrain: 13.8,
      createdAt: "2026-07-10"
    }
  ],

  // История пуш-уведомлений
  pushHistory: [
    {
      id: "push_01",
      title: "Готовность рассчитана",
      body: "Ваше ночное восстановление 88% (Оптимально). Цель нагрузки на сегодня: 15.0 Strain.",
      audience: "Все активные атлеты (9)",
      sentAt: "2026-09-23T07:00:00Z",
      status: "delivered"
    },
    {
      id: "push_02",
      title: "Низкое восстановление",
      body: "Ваш пульс покоя повышен на 8 уд/мин. Рекомендуем активное восстановление или растяжку.",
      audience: "Красная зона Recovery (1)",
      sentAt: "2026-09-23T07:15:00Z",
      status: "delivered"
    },
    {
      id: "push_03",
      title: "СААТ-1 готов к тренировке",
      body: "Датчик синхронизирован. Начните сессию в приложении для записи пульсовых зон.",
      audience: "Все атлеты с СААТ-1 (8)",
      sentAt: "2026-09-22T17:30:00Z",
      status: "delivered"
    }
  ],

  // Системные логи платформы
  systemLogs: [
    { timestamp: "16:05:12", level: "info", text: "Синхронизация Firestore: получены данные сна для ath_002 (8ч 15мин)." },
    { timestamp: "15:52:40", level: "info", text: "Атлет Айсулуу Тыныбекова завершила сессию 'Бег на улице' (Strain 14.8)." },
    { timestamp: "15:45:10", level: "success", text: "СААТ-1 (D4:F5:13:88:2A:41) передал пакет телеметрии: 64 bpm, HRV 72 ms." },
    { timestamp: "15:30:04", level: "warning", text: "Атлет Чыңгыз Айтматов: заряд СААТ-1 опустился до 18%." },
    { timestamp: "15:10:22", level: "info", text: "Атлет Бегимай Сапарова: день 7 калибровки baseline успешно зафиксирован." },
    { timestamp: "14:40:15", level: "error", text: "Атлет ath_009 не выходил на связь более 20 часов (BLE timeout)." }
  ]
};

// Экспорт для Node.js и браузера
if (typeof module !== 'undefined' && module.exports) {
  module.exports = KALKAN_MOCK_DATA;
}
