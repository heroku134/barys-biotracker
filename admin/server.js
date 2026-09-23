/**
 * KALKAN SPORT - Admin Console Node.js / Express Server
 * Автономный сервер для локального запуска, API эндпоинтов и интеграции с Firebase Admin SDK
 */

const express = require('express');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());
app.use(express.static(__dirname));

// Инициализация Firebase Admin SDK (если есть файл service-account.json)
let admin = null;
let firestoreAdmin = null;

const serviceAccountPath = path.join(__dirname, 'service-account.json');
if (fs.existsSync(serviceAccountPath)) {
  try {
    admin = require('firebase-admin');
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: 'watch-ba720'
    });
    firestoreAdmin = admin.firestore();
    console.log('✅ Firebase Admin SDK успешно инициализирован с сервисным аккаунтом.');
  } catch (e) {
    console.warn('⚠️ Ошибка инициализации firebase-admin:', e.message);
  }
} else {
  console.log('ℹ️ Файл service-account.json не обнаружен. Сервер работает в режиме прямого хостинга.');
}

// REST API эндпоинты для автоматизации и сторонних интеграций

app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    platform: 'KALKAN SPORT Admin',
    firebaseAdminReady: !!firestoreAdmin,
    timestamp: new Date().toISOString()
  });
});

app.get('/api/stats', (req, res) => {
  const mockData = require('./mock-data.js');
  const athletes = mockData.athletes || [];
  res.json({
    totalAthletes: athletes.length,
    activeToday: athletes.filter(a => a.status === 'active').length,
    avgRecovery: Math.round(athletes.reduce((acc, a) => acc + (a.recoveryScore || 0), 0) / (athletes.length || 1)),
    avgStrain: (athletes.reduce((acc, a) => acc + (a.currentStrain || 0), 0) / (athletes.length || 1)).toFixed(1),
    connectedWatches: athletes.filter(a => a.device && a.device.connected).length
  });
});

// Отправка системного push-уведомления
app.post('/api/push', async (req, res) => {
  const { title, body, topic } = req.body;
  if (!title || !body) {
    return res.status(400).json({ error: 'title and body are required' });
  }

  if (admin && admin.messaging) {
    try {
      const message = {
        notification: { title, body },
        topic: topic || 'all_athletes'
      };
      const response = await admin.messaging().send(message);
      return res.json({ success: true, messageId: response });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  }

  // Симуляция отправки
  res.json({
    success: true,
    simulated: true,
    title,
    body,
    timestamp: new Date().toISOString()
  });
});

// Главный роут для SPA
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

app.listen(PORT, () => {
  console.log(`
=====================================================
🛡️  KALKAN SPORT ADMIN CONSOLE ЗАПУЩЕН
📡  URL: http://localhost:${PORT}
📁  Папка: ${__dirname}
=====================================================
`);
});
