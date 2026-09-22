import 'app_language.dart';

/// Централизованное многоязычное хранилище строк (Русский + Кыргызча + English)
class AppStrings {
  static const Map<String, Map<AppLanguage, String>> _strings = {
    // Входная цитата и сплэш
    'entrance_quote': {
      AppLanguage.russian: 'Сон. Восстановление. Нагрузка.',
      AppLanguage.kyrgyz: 'Уйку. Калыбына келүү. Жүктөм.',
      AppLanguage.english: 'Sleep. Recovery. Strain.',
    },
    'entrance_quote_sub': {
      AppLanguage.russian: 'Три числа. Одно решение на день.',
      AppLanguage.kyrgyz: 'Үч сан. Күнгө бир чечим.',
      AppLanguage.english: 'Three numbers. One decision for the day.',
    },
    'entrance_source': {
      AppLanguage.russian: 'КАЛКАН СПОРТ',
      AppLanguage.kyrgyz: 'КАЛКАН СПОРТ',
      AppLanguage.english: 'KALKAN SPORT',
    },
    'entrance_tap_to_enter': {
      AppLanguage.russian: 'Нажмите, чтобы открыть',
      AppLanguage.kyrgyz: 'Ачуу үчүн басыңыз',
      AppLanguage.english: 'Tap to enter',
    },
    'entrance_initializing': {
      AppLanguage.russian: 'Инициализация сенсоров СААТ-1...',
      AppLanguage.kyrgyz: 'СААТ-1 сенсорлору иштетилүүдө...',
      AppLanguage.english: 'Initializing СААТ-1 sensors...',
    },

    // Авторизация / Auth
    'auth_brand': {
      AppLanguage.russian: 'КАЛКАН СПОРТ · СААТ-1',
      AppLanguage.kyrgyz: 'КАЛКАН СПОРТ · СААТ-1',
      AppLanguage.english: 'KALKAN SPORT · СААТ-1',
    },
    'auth_login_title': {
      AppLanguage.russian: 'Вход',
      AppLanguage.kyrgyz: 'Кирүү',
      AppLanguage.english: 'Sign In',
    },
    'auth_signup_title': {
      AppLanguage.russian: 'Создание аккаунта',
      AppLanguage.kyrgyz: 'Аккаунт түзүү',
      AppLanguage.english: 'Create Account',
    },
    'auth_subtitle': {
      AppLanguage.russian: 'Подключите браслет и войдите в аккаунт',
      AppLanguage.kyrgyz: 'Билерикти туташтырып, аккаунтка кириңиз',
      AppLanguage.english: 'Connect your watch and sign in to your account',
    },
    'auth_name_label': {
      AppLanguage.russian: 'Ваше имя',
      AppLanguage.kyrgyz: 'Сиздин атыңыз',
      AppLanguage.english: 'Your name',
    },
    'auth_name_hint': {
      AppLanguage.russian: 'Батыр / Алихан',
      AppLanguage.kyrgyz: 'Батыр / Алихан',
      AppLanguage.english: 'Batyr / Alex',
    },
    'auth_email_label': {
      AppLanguage.russian: 'Email адрес',
      AppLanguage.kyrgyz: 'Email дареги',
      AppLanguage.english: 'Email address',
    },
    'auth_password_label': {
      AppLanguage.russian: 'Пароль',
      AppLanguage.kyrgyz: 'Сырсөз',
      AppLanguage.english: 'Password',
    },
    'auth_button_login': {
      AppLanguage.russian: 'ВОЙТИ В СИСТЕМУ',
      AppLanguage.kyrgyz: 'СИСТЕМАГА КИРҮҮ',
      AppLanguage.english: 'SIGN IN',
    },
    'auth_button_signup': {
      AppLanguage.russian: 'ЗАРЕГИСТРИРОВАТЬСЯ',
      AppLanguage.kyrgyz: 'КАТТАЛУУ',
      AppLanguage.english: 'REGISTER',
    },
    'auth_to_signup': {
      AppLanguage.russian: 'Нет аккаунта? Создать новый профиль',
      AppLanguage.kyrgyz: 'Аккаунтуңуз жокпу? Жаңы профиль түзүңүз',
      AppLanguage.english: 'No account? Create a new profile',
    },
    'auth_to_login': {
      AppLanguage.russian: 'Уже есть аккаунт? Войти',
      AppLanguage.kyrgyz: 'Аккаунтуңуз барбы? Кирүү',
      AppLanguage.english: 'Already have an account? Sign in',
    },
    'auth_err_empty': {
      AppLanguage.russian: 'Заполните все обязательные поля',
      AppLanguage.kyrgyz: 'Бардык талап кылынган талааларды толтуруңуз',
      AppLanguage.english: 'Please fill in all required fields',
    },
    'auth_err_email': {
      AppLanguage.russian: 'Введите корректный email адрес',
      AppLanguage.kyrgyz: 'Туура email дарегин киргизиңиз',
      AppLanguage.english: 'Enter a valid email address',
    },
    'auth_err_pass_length': {
      AppLanguage.russian: 'Пароль должен содержать минимум 6 символов',
      AppLanguage.kyrgyz: 'Сырсөз кеминде 6 белгиден турушу керек',
      AppLanguage.english: 'Password must contain at least 6 characters',
    },

    // Спорт и кнопки
    'sport_history': {
      AppLanguage.russian: 'История тренировок',
      AppLanguage.kyrgyz: 'Машыгуулардын тарыхы',
      AppLanguage.english: 'Workout History',
    },
    'sport_pause': {
      AppLanguage.russian: 'Пауза',
      AppLanguage.kyrgyz: 'Пауза',
      AppLanguage.english: 'Pause',
    },
    'sport_resume': {
      AppLanguage.russian: 'Продолжить',
      AppLanguage.kyrgyz: 'Улантуу',
      AppLanguage.english: 'Resume',
    },
    'sport_finish': {
      AppLanguage.russian: 'Завершить',
      AppLanguage.kyrgyz: 'Аяктоо',
      AppLanguage.english: 'Finish',
    },
    'sport_start': {
      AppLanguage.russian: 'Начать тренировку',
      AppLanguage.kyrgyz: 'Машыгууну баштоо',
      AppLanguage.english: 'Start Workout',
    },
    'device_functions': {
      AppLanguage.russian: 'Функции часов',
      AppLanguage.kyrgyz: 'Сааттын функциялары',
      AppLanguage.english: 'Watch Functions',
    },
    'device_measure_hr': {
      AppLanguage.russian: 'Замер пульса',
      AppLanguage.kyrgyz: 'Пульсту өлчөө',
      AppLanguage.english: 'Measure Heart Rate',
    },
    'device_sync_time': {
      AppLanguage.russian: 'Синхронизировать время',
      AppLanguage.kyrgyz: 'Убакытты шайкештирүү',
      AppLanguage.english: 'Sync Time',
    },
    'firmware_title': {
      AppLanguage.russian: 'Прошивка',
      AppLanguage.kyrgyz: 'Прошивка',
      AppLanguage.english: 'Firmware',
    },
    'nav_today': {
      AppLanguage.russian: 'Сегодня',
      AppLanguage.kyrgyz: 'Бүгүн',
      AppLanguage.english: 'Today',
    },
    'nav_analysis': {
      AppLanguage.russian: 'Анализ',
      AppLanguage.kyrgyz: 'Талдоо',
      AppLanguage.english: 'Analysis',
    },
    'nav_barys': {
      AppLanguage.russian: 'Барыс',
      AppLanguage.kyrgyz: 'Барыс',
      AppLanguage.english: 'Barys',
    },
    'nav_sport': {
      AppLanguage.russian: 'Спорт',
      AppLanguage.kyrgyz: 'Спорт',
      AppLanguage.english: 'Sport',
    },
    'nav_cycle': {
      AppLanguage.russian: 'Цикл',
      AppLanguage.kyrgyz: 'Цикл',
      AppLanguage.english: 'Cycle',
    },
    'nav_pregnancy': {
      AppLanguage.russian: 'Срок',
      AppLanguage.kyrgyz: 'Мөөнөт',
      AppLanguage.english: 'Term',
    },
    'nav_profile': {
      AppLanguage.russian: 'Профиль',
      AppLanguage.kyrgyz: 'Профиль',
      AppLanguage.english: 'Profile',
    },

    // Главный экран («Сегодня» / «Бүгүн»)
    'today_header': {
      AppLanguage.russian: 'СЕГОДНЯ',
      AppLanguage.kyrgyz: 'БҮГҮН',
      AppLanguage.english: 'TODAY',
    },
    'today_recovery': {
      AppLanguage.russian: 'ГОТОВНОСТЬ',
      AppLanguage.kyrgyz: 'КАЛЫБЫНА КЕЛҮҮ',
      AppLanguage.english: 'RECOVERY',
    },
    'today_streak_badge': {
      AppLanguage.russian: 'В ЗЕЛЁНОЙ ЗОНЕ 5 ДНЕЙ ПОДРЯД',
      AppLanguage.kyrgyz: 'ЖАШЫЛ ЗОНАДА КАТАРЫ МЕНЕН 5 КҮН',
      AppLanguage.english: 'IN GREEN ZONE 5 DAYS IN A ROW',
    },
    'today_live_pulse': {
      AppLanguage.russian: 'ПУЛЬС В РЕАЛЬНОМ ВРЕМЕНИ',
      AppLanguage.kyrgyz: 'ЧЫНЫГЫ УБАКЫТТАГЫ ТАМЫР СОГУУ',
      AppLanguage.english: 'REAL-TIME HEART RATE',
    },
    'today_trigger_pulse': {
      AppLanguage.russian: 'Запустить замер >',
      AppLanguage.kyrgyz: 'Ченөөнү баштоо >',
      AppLanguage.english: 'Start reading >',
    },
    'today_pulse_measuring': {
      AppLanguage.russian: 'Инициация замера ЧСС через оптический сенсор СААТ-1...',
      AppLanguage.kyrgyz: 'СААТ-1 оптикалык сенсору аркылуу жүрөк согушун ченөө башталды...',
      AppLanguage.english: 'Initiating HR reading via СААТ-1 optical sensor...',
    },
    'today_5factors_title': {
      AppLanguage.russian: 'РАЗБОР 5 ФАКТОРОВ ВОССТАНОВЛЕНИЯ',
      AppLanguage.kyrgyz: 'КАЛЫБЫНА КЕЛҮҮНҮН 5 ФАКТОРУН ТАЛДОО',
      AppLanguage.english: '5 RECOVERY FACTORS BREAKDOWN',
    },
    'today_5factors_sub': {
      AppLanguage.russian: 'Почему сегодня 91%? Анализ ВСР, сна и температуры',
      AppLanguage.kyrgyz: 'Эмне үчүн бүгүн 91%? ЖЖВ, уйку жана температура талдоосу',
      AppLanguage.english: 'Why 91% today? HRV, sleep and temperature analysis',
    },
    'today_hrv': {
      AppLanguage.russian: 'ВСР (HRV)',
      AppLanguage.kyrgyz: 'ЖЖВ (HRV)',
      AppLanguage.english: 'HRV',
    },
    'today_rhr': {
      AppLanguage.russian: 'ЧСС ПОКОЯ',
      AppLanguage.kyrgyz: 'ТЫНЧ АБАЛДАГЫ ПУЛЬС',
      AppLanguage.english: 'RESTING HR',
    },
    'today_skin_temp': {
      AppLanguage.russian: 'ТЕМП. КОЖИ',
      AppLanguage.kyrgyz: 'ТЕРИ ТЕМП.',
      AppLanguage.english: 'SKIN TEMP',
    },
    'today_strain_budget': {
      AppLanguage.russian: 'НАГРУЗКА ДНЯ (STRAIN)',
      AppLanguage.kyrgyz: 'КҮНДҮК ООРЧУЛУК (STRAIN)',
      AppLanguage.english: 'DAILY STRAIN',
    },
    'today_league_card_title': {
      AppLanguage.russian: 'КРУГ ДОВЕРИЯ · ПРИВАТНАЯ ЛИГА (4/5)',
      AppLanguage.kyrgyz: 'ИШЕНИМ ЧӨЙРӨСҮ · ЖЕКЕ ЛИГА (4/5)',
      AppLanguage.english: 'TRUST CIRCLE · PRIVATE LEAGUE (4/5)',
    },
    'today_league_card_sub': {
      AppLanguage.russian: 'Среднее восстановление близких: 82% · 1 слот свободен',
      AppLanguage.kyrgyz: 'Жакындардын орточо калыбына келүүсү: 82% · 1 орун бош',
      AppLanguage.english: 'Inner circle average recovery: 82% · 1 slot open',
    },

    // Маскот Барыс-Батыр
    'mascot_title': {
      AppLanguage.russian: 'Барыс',
      AppLanguage.kyrgyz: 'Барыс',
      AppLanguage.english: 'Barys',
    },
    'mascot_level': {
      AppLanguage.russian: 'Уровень',
      AppLanguage.kyrgyz: 'Деңгээл',
      AppLanguage.english: 'Level',
    },
    'mascot_rank_cadet': {
      AppLanguage.russian: 'ИРБИС-КАДЕТ',
      AppLanguage.kyrgyz: 'ИЛБИРС-КАДЕТ',
      AppLanguage.english: 'SNOW LEOPARD CADET',
    },
    'mascot_rank_sarbaz': {
      AppLanguage.russian: 'САРБАЗ',
      AppLanguage.kyrgyz: 'САРБАЗ',
      AppLanguage.english: 'SARBAZ',
    },
    'mascot_rank_batyr': {
      AppLanguage.russian: 'БАТЫР',
      AppLanguage.kyrgyz: 'БАТЫР',
      AppLanguage.english: 'BATYR',
    },
    'mascot_rank_aksakal': {
      AppLanguage.russian: 'АКСАКАЛ',
      AppLanguage.kyrgyz: 'АКСАКАЛ',
      AppLanguage.english: 'AKSAKAL',
    },
    'mascot_evolution_link': {
      AppLanguage.russian: 'Все ступени эволюции >',
      AppLanguage.kyrgyz: 'Эволюциянын бардык баскычтары >',
      AppLanguage.english: 'All evolution stages >',
    },
    'mascot_quests_title': {
      AppLanguage.russian: 'Задачи на день',
      AppLanguage.kyrgyz: 'Бүгүнкү милдеттер',
      AppLanguage.english: 'Daily Targets',
    },
    'mascot_quest_strain': {
      AppLanguage.russian: 'Закрыть дневной Strain',
      AppLanguage.kyrgyz: 'Күндүк Strain жүктөмүн жабуу',
      AppLanguage.english: 'Hit daily Strain target',
    },
    'mascot_quest_journal': {
      AppLanguage.russian: 'Записать самочувствие',
      AppLanguage.kyrgyz: 'Абалды жазуу',
      AppLanguage.english: 'Log wellness note',
    },
    'mascot_quest_sleep': {
      AppLanguage.russian: 'Лечь до 22:30',
      AppLanguage.kyrgyz: '22:30га чейин уктоо',
      AppLanguage.english: 'Sleep before 22:30',
    },

    // Спорт
    'sport_title': {
      AppLanguage.russian: 'СПОРТ И ТРЕНИРОВКИ',
      AppLanguage.kyrgyz: 'СПОРТ ЖАНА МАШЫГУУЛАР',
      AppLanguage.english: 'SPORT & WORKOUTS',
    },
    'sport_cat_all': {
      AppLanguage.russian: 'Все',
      AppLanguage.kyrgyz: 'Баары',
      AppLanguage.english: 'All',
    },
    'sport_cat_strength': {
      AppLanguage.russian: 'Силовая',
      AppLanguage.kyrgyz: 'Күч машыгуусу',
      AppLanguage.english: 'Strength',
    },
    'sport_cat_run': {
      AppLanguage.russian: 'Бег',
      AppLanguage.kyrgyz: 'Чуркоо',
      AppLanguage.english: 'Running',
    },
    'sport_cat_trail': {
      AppLanguage.russian: 'Горный трейл',
      AppLanguage.kyrgyz: 'Тоо трейли',
      AppLanguage.english: 'Trail Run',
    },
    'sport_cat_cycling': {
      AppLanguage.russian: 'Велоспорт',
      AppLanguage.kyrgyz: 'Велоспорт',
      AppLanguage.english: 'Cycling',
    },
    'sport_cat_swim': {
      AppLanguage.russian: 'Плавание',
      AppLanguage.kyrgyz: 'Сууда сүзүү',
      AppLanguage.english: 'Swimming',
    },
    'sport_cat_flexibility': {
      AppLanguage.russian: 'Растяжка',
      AppLanguage.kyrgyz: 'Чоюлуу',
      AppLanguage.english: 'Mobility',
    },
    'sport_record_button': {
      AppLanguage.russian: 'Начать тренировку',
      AppLanguage.kyrgyz: 'Машыгууну баштоо',
      AppLanguage.english: 'Start Workout',
    },
    'home_sleep': {
      AppLanguage.russian: 'Сон',
      AppLanguage.kyrgyz: 'Уйку',
      AppLanguage.english: 'Sleep',
    },
    'home_recovery': {
      AppLanguage.russian: 'Восстановление',
      AppLanguage.kyrgyz: 'Калыбына келүү',
      AppLanguage.english: 'Recovery',
    },
    'home_strain': {
      AppLanguage.russian: 'Нагрузка',
      AppLanguage.kyrgyz: 'Жүктөм',
      AppLanguage.english: 'Strain',
    },
    'home_synced': {
      AppLanguage.russian: 'Связь',
      AppLanguage.kyrgyz: 'Байланыш',
      AppLanguage.english: 'Synced',
    },
    'home_offline': {
      AppLanguage.russian: 'Офлайн',
      AppLanguage.kyrgyz: 'Офлайн',
      AppLanguage.english: 'Offline',
    },
    'home_guest': {
      AppLanguage.russian: 'Гость',
      AppLanguage.kyrgyz: 'Конок',
      AppLanguage.english: 'Guest',
    },

    // Анализ и стресс
    'analytics_title': {
      AppLanguage.russian: 'Анализ',
      AppLanguage.kyrgyz: 'Талдоо',
      AppLanguage.english: 'Analysis',
    },
    'analytics_stress_timeline': {
      AppLanguage.russian: 'Стресс за день',
      AppLanguage.kyrgyz: 'Күндүк стресс',
      AppLanguage.english: 'Daily Stress',
    },
    'analytics_day_story': {
      AppLanguage.russian: 'День в событиях',
      AppLanguage.kyrgyz: 'Күндүн окуялары',
      AppLanguage.english: 'Day Events Story',
    },
    'analytics_healthspan': {
      AppLanguage.russian: 'Биологический возраст',
      AppLanguage.kyrgyz: 'Биологиялык курак',
      AppLanguage.english: 'Biological Age',
    },

    // Профиль и настройки
    'profile_title': {
      AppLanguage.russian: 'Профиль',
      AppLanguage.kyrgyz: 'Профиль',
      AppLanguage.english: 'Profile',
    },
    'profile_passport': {
      AppLanguage.russian: 'Данные профиля',
      AppLanguage.kyrgyz: 'Профиль маалыматы',
      AppLanguage.english: 'Profile Data',
    },
    'profile_language_section': {
      AppLanguage.russian: 'Язык',
      AppLanguage.kyrgyz: 'Тил',
      AppLanguage.english: 'Language',
    },
    'profile_language_sub': {
      AppLanguage.russian: 'Тилди тандоо · Выбор языка',
      AppLanguage.kyrgyz: 'Тилди тандоо · Выбор языка',
      AppLanguage.english: 'Choose language / Тилди тандоо',
    },
    'profile_community_title': {
      AppLanguage.russian: 'СООБЩЕСТВО И ПРИВАТНЫЕ ЛИГИ',
      AppLanguage.kyrgyz: 'КООМДОШТУК ЖАНА ЖЕКЕ ЛИГАЛАР',
      AppLanguage.english: 'COMMUNITY & PRIVATE LEAGUES',
    },
    'profile_community_sub': {
      AppLanguage.russian: 'Круг доверия Данбара (3–5 человек)',
      AppLanguage.kyrgyz: 'Данбар ишеним чөйрөсү (3–5 адам)',
      AppLanguage.english: 'Dunbar Trust Circle (3–5 people)',
    },
    'profile_crisis_mode': {
      AppLanguage.russian: 'Режим «ГРОЗА» (Кризис и тревога)',
      AppLanguage.kyrgyz: '«ЧАГЫЛГАН» режими (Кризис жана кооптонуу)',
      AppLanguage.english: '"STORM" Mode (Crisis & Anxiety)',
    },
    'profile_crisis_sub': {
      AppLanguage.russian: 'ЧСС 118, ВСР 22мс, стресс 89% (Red Zone)',
      AppLanguage.kyrgyz: 'Жүрөк 118, ЖЖВ 22мс, стресс 89% (Red Zone)',
      AppLanguage.english: 'HR 118, HRV 22ms, Stress 89% (Red Zone)',
    },
    'profile_logout': {
      AppLanguage.russian: 'ВЫЙТИ ИЗ СИСТЕМЫ',
      AppLanguage.kyrgyz: 'СИСТЕМАСЫНАН ЧЫГУУ',
      AppLanguage.english: 'LOG OUT',
    },
    'profile_logout_confirm_title': {
      AppLanguage.russian: 'Выйти из системы?',
      AppLanguage.kyrgyz: 'Системадан чыгасызбы?',
      AppLanguage.english: 'Log out of account?',
    },
    'profile_logout_confirm_desc': {
      AppLanguage.russian: 'Синхронизация биометрии будет приостановлена до повторного входа.',
      AppLanguage.kyrgyz: 'Биометрияны шайкештөө кайра киргенге чейин токтотулат.',
      AppLanguage.english: 'Biometric syncing will be paused until next sign-in.',
    },
    'common_cancel': {
      AppLanguage.russian: 'ОТМЕНА',
      AppLanguage.kyrgyz: 'ЖОККО ЧЫГАРУУ',
      AppLanguage.english: 'CANCEL',
    },
    'common_confirm': {
      AppLanguage.russian: 'ПОДТВЕРДИТЬ',
      AppLanguage.kyrgyz: 'ЫРАСТОО',
      AppLanguage.english: 'CONFIRM',
    },
    'common_close': {
      AppLanguage.russian: 'ЗАКРЫТЬ',
      AppLanguage.kyrgyz: 'ЖАБУУ',
      AppLanguage.english: 'CLOSE',
    },

    // Приватные лиги (Dunbar Circle)
    'league_appbar_sub': {
      AppLanguage.russian: 'Друзья',
      AppLanguage.kyrgyz: 'Достор',
      AppLanguage.english: 'Friends',
    },
    'league_appbar_title': {
      AppLanguage.russian: 'Круг',
      AppLanguage.kyrgyz: 'Чөйрө',
      AppLanguage.english: 'Circle',
    },
    'league_default_title': {
      AppLanguage.russian: 'Круг друзей',
      AppLanguage.kyrgyz: 'Достор чөйрөсү',
      AppLanguage.english: 'Friends Circle',
    },
    'league_slots_format': {
      AppLanguage.russian: '{current} / {max} мест',
      AppLanguage.kyrgyz: '{current} / {max} орун',
      AppLanguage.english: '{current} / {max} slots',
    },
    'league_avg_recovery': {
      AppLanguage.russian: 'Среднее восстановление',
      AppLanguage.kyrgyz: 'Орточо калыбына келүү',
      AppLanguage.english: 'Average Recovery',
    },
    'league_sync_badge': {
      AppLanguage.russian: 'Онлайн',
      AppLanguage.kyrgyz: 'Онлайн',
      AppLanguage.english: 'Online',
    },
    'league_invite_card_title': {
      AppLanguage.russian: 'Код для друзей',
      AppLanguage.kyrgyz: 'Достор үчүн код',
      AppLanguage.english: 'Invite code for friends',
    },
    'league_copy_code': {
      AppLanguage.russian: 'Копировать',
      AppLanguage.kyrgyz: 'Көчүрүү',
      AppLanguage.english: 'Copy',
    },
    'league_copied_snack': {
      AppLanguage.russian: 'Инвайт-код скопирован в буфер',
      AppLanguage.kyrgyz: 'Чакыруу коду алмашуу буферине көчүрүлдү',
      AppLanguage.english: 'Invite code copied to clipboard',
    },
    'league_add_friend': {
      AppLanguage.russian: '+ ПРИГЛАСИТЬ ДРУГА ({count} СЛОТ СВОБОДЕН)',
      AppLanguage.kyrgyz: '+ ДОС ЧАКЫРУУ ({count} ОРУН БОШ)',
      AppLanguage.english: '+ INVITE FRIEND ({count} OPEN SLOT)',
    },
    'league_full_badge': {
      AppLanguage.russian: 'КРУГ ДОВЕРИЯ ЗАПОЛНЕН (5/5)',
      AppLanguage.kyrgyz: 'ИШЕНИМ ЧӨЙРӨСҮ ТОЛДУ (5/5)',
      AppLanguage.english: 'TRUST CIRCLE FULL (5/5)',
    },
    'league_dialog_title': {
      AppLanguage.russian: 'ПРИГЛАШЕНИЕ В КРУГ ДОВЕРИЯ',
      AppLanguage.kyrgyz: 'ИШЕНИМ ЧӨЙРӨСҮНӨ ЧАКЫРУУ',
      AppLanguage.english: 'INVITE TO TRUST CIRCLE',
    },
    'league_friend_name_label': {
      AppLanguage.russian: 'Имя или позывной друга',
      AppLanguage.kyrgyz: 'Досуңуздун аты же каймана аты',
      AppLanguage.english: "Friend's name or nickname",
    },
    'league_friend_code_label': {
      AppLanguage.russian: 'Инвайт-код друга (опционально)',
      AppLanguage.kyrgyz: 'Досуңуздун чакыруу коду (милдеттүү эмес)',
      AppLanguage.english: "Friend's invite code (optional)",
    },
    'league_send_impulse': {
      AppLanguage.russian: 'ОТПРАВИТЬ ИМПУЛЬС СИЛЫ БАРЫСА ✦',
      AppLanguage.kyrgyz: 'БАРЫСТЫН КҮЧ ДЕМИН ЖӨНӨТҮҮ ✦',
      AppLanguage.english: 'SEND BARYS POWER IMPULSE ✦',
    },
    'league_impulse_sent': {
      AppLanguage.russian: 'Импульс силы Барыса успешно отправлен атлету!',
      AppLanguage.kyrgyz: 'Барыстын күч деми атлетке ийгиликтүү жөнөтүлдү!',
      AppLanguage.english: 'Barys power impulse successfully sent to athlete!',
    },
    'friend_detail_title': {
      AppLanguage.russian: 'БИОМЕТРИЧЕСКИЙ СНИМОК ДРУГА',
      AppLanguage.kyrgyz: 'ДОСУҢУЗДУН БИОМЕТРИКАЛЫК СҮРӨТҮ',
      AppLanguage.english: 'FRIEND BIOMETRIC SNAPSHOT',
    },
    'friend_detail_recovery': {
      AppLanguage.russian: 'ВОССТАНОВЛЕНИЕ (RECOVERY)',
      AppLanguage.kyrgyz: 'КАЛЫБЫНА КЕЛҮҮ (RECOVERY)',
      AppLanguage.english: 'RECOVERY',
    },
    'friend_detail_strain': {
      AppLanguage.russian: 'НАГРУЗКА ДНЯ',
      AppLanguage.kyrgyz: 'КҮНДҮК ООРЧУЛУК',
      AppLanguage.english: 'DAILY STRAIN',
    },
    'friend_detail_sleep': {
      AppLanguage.russian: 'СОН И КАЧЕСТВО',
      AppLanguage.kyrgyz: 'УЙКУ ЖАНА САПАТ',
      AppLanguage.english: 'SLEEP & QUALITY',
    },
    'friend_detail_hrv': {
      AppLanguage.russian: 'ВСР (HRV)',
      AppLanguage.kyrgyz: 'ЖЖВ (HRV)',
      AppLanguage.english: 'HRV',
    },
    'friend_detail_rhr': {
      AppLanguage.russian: 'ЧСС ПОКОЯ',
      AppLanguage.kyrgyz: 'ТЫНЧ АБАЛДАГЫ ПУЛЬС',
      AppLanguage.english: 'RESTING HR',
    },

    // Выбор пола (Gender Selection)
    'gender_label': {
      AppLanguage.russian: 'Ваш пол',
      AppLanguage.kyrgyz: 'Жынысыңыз',
      AppLanguage.english: 'Gender',
    },
    'gender_male': {
      AppLanguage.russian: 'Мужской',
      AppLanguage.kyrgyz: 'Эркек',
      AppLanguage.english: 'Male',
    },
    'gender_female': {
      AppLanguage.russian: 'Женский',
      AppLanguage.kyrgyz: 'Аял',
      AppLanguage.english: 'Female',
    },

    // Мониторинг цикла (Menstrual Cycle & СААТ-1)
    'cycle_card_header': {
      AppLanguage.russian: 'ЖЕНСКИЙ БИОРИТМ · СААТ-1',
      AppLanguage.kyrgyz: 'АЯЛДАР БИОРИТМИ · СААТ-1',
      AppLanguage.english: 'FEMALE BIORHYTHM · СААТ-1',
    },
    'cycle_phase_menstrual': {
      AppLanguage.russian: 'Менструация',
      AppLanguage.kyrgyz: 'Этек кир',
      AppLanguage.english: 'Menstrual',
    },
    'cycle_phase_follicular': {
      AppLanguage.russian: 'Фолликулярная',
      AppLanguage.kyrgyz: 'Фолликулярдык',
      AppLanguage.english: 'Follicular',
    },
    'cycle_phase_ovulatory': {
      AppLanguage.russian: 'Овуляция',
      AppLanguage.kyrgyz: 'Овуляция',
      AppLanguage.english: 'Ovulatory',
    },
    'cycle_phase_luteal': {
      AppLanguage.russian: 'Лютеиновая',
      AppLanguage.kyrgyz: 'Лютеиндик',
      AppLanguage.english: 'Luteal',
    },
    'cycle_day_counter': {
      AppLanguage.russian: 'День {day} из {total}',
      AppLanguage.kyrgyz: '{total} күндөн {day}-күн',
      AppLanguage.english: 'Day {day} of {total}',
    },
    'cycle_screen_title': {
      AppLanguage.russian: 'Мониторинг цикла СААТ-1',
      AppLanguage.kyrgyz: 'СААТ-1 цикл мониторинги',
      AppLanguage.english: 'СААТ-1 Cycle Monitoring',
    },
    'cycle_screen_subtitle': {
      AppLanguage.russian: 'Ночная термометрия кожи и фазовый тренинг',
      AppLanguage.kyrgyz: 'Түнкү теринин термометриясы жана фазалык машыгуу',
      AppLanguage.english: 'Overnight skin thermometry & phase training',
    },
    'cycle_thermal_card': {
      AppLanguage.russian: 'ТЕРМОСЕНСОР КОЖИ СААТ-1',
      AppLanguage.kyrgyz: 'СААТ-1 ТЕРИ ТЕРМОСЕНСОРУ',
      AppLanguage.english: 'СААТ-1 SKIN THERMAL SENSOR',
    },
    'cycle_thermal_desc': {
      AppLanguage.russian: 'Двухфазный ночной график температуры тела. Скачок подтверждает овуляцию.',
      AppLanguage.kyrgyz: 'Түнкү дене табынын эки фазалуу графиги. Секирик овуляцияны тастыктайт.',
      AppLanguage.english: 'Biphasic night skin temp curve. A surge confirms ovulation.',
    },
    'cycle_symptoms_title': {
      AppLanguage.russian: 'ЖУРНАЛ САМОЧУВСТВИЯ',
      AppLanguage.kyrgyz: 'ӨЗҮН СЕЗҮҮ КҮНДӨЛҮГҮ',
      AppLanguage.english: 'WELLNESS LOG',
    },
    'cycle_symptom_energy': {
      AppLanguage.russian: 'Энергия',
      AppLanguage.kyrgyz: 'Кубаттуулук',
      AppLanguage.english: 'Energy',
    },
    'cycle_symptom_cramps': {
      AppLanguage.russian: 'Спазмы',
      AppLanguage.kyrgyz: 'Сыздап ооруу',
      AppLanguage.english: 'Cramps',
    },
    'cycle_symptom_mood': {
      AppLanguage.russian: 'Настроение',
      AppLanguage.kyrgyz: 'Маанай',
      AppLanguage.english: 'Mood',
    },
    'cycle_symptom_headache': {
      AppLanguage.russian: 'Головная боль',
      AppLanguage.kyrgyz: 'Баш оору',
      AppLanguage.english: 'Headache',
    },
    'cycle_edit_settings': {
      AppLanguage.russian: 'Настройки цикла',
      AppLanguage.kyrgyz: 'Цикл жөндөөлөрү',
      AppLanguage.english: 'Cycle Settings',
    },
    'cycle_settings_saved': {
      AppLanguage.russian: 'Параметры цикла сохранены в профиле',
      AppLanguage.kyrgyz: 'Цикл параметрлери профилде сакталды',
      AppLanguage.english: 'Cycle settings saved in profile',
    },
    'cycle_directive_training': {
      AppLanguage.russian: 'Тренировки & Нагрузка',
      AppLanguage.kyrgyz: 'Машыгуу жана Оорчулук',
      AppLanguage.english: 'Workouts & Strain',
    },
    'cycle_directive_nutrition': {
      AppLanguage.russian: 'Питание & Гидратация',
      AppLanguage.kyrgyz: 'Тамактануу жана Гидратация',
      AppLanguage.english: 'Nutrition & Hydration',
    },
    'cycle_directive_sleep': {
      AppLanguage.russian: 'Сон & Терморегуляция',
      AppLanguage.kyrgyz: 'Уйку жана Терморегуляция',
      AppLanguage.english: 'Sleep & Thermoregulation',
    },
    'cycle_directive_barys': {
      AppLanguage.russian: 'Мудрость Барыса',
      AppLanguage.kyrgyz: 'Барыстын даанышмандыгы',
      AppLanguage.english: 'Wisdom of Barys',
    },
  };

  /// Получить строку по ключу с учетом активного или переданного языка
  static String tr(String key, [AppLanguage? language]) {
    final lang = language ?? AppLocaleNotifier.current;
    final dict = _strings[key];
    if (dict == null) return key;
    return dict[lang] ?? dict[AppLanguage.english] ?? dict[AppLanguage.russian] ?? key;
  }

  /// Получить строку с подстановкой именованных параметров (напр. {count})
  static String trParams(String key, Map<String, dynamic> params, [AppLanguage? language]) {
    String text = tr(key, language);
    params.forEach((paramKey, value) {
      text = text.replaceAll('{$paramKey}', value.toString());
    });
    return text;
  }
}
