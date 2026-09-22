import 'app_language.dart';

/// Централизованное двуязычное хранилище строк (Русский + Кыргызча)
class AppStrings {
  static const Map<String, Map<AppLanguage, String>> _strings = {
    // Входная цитата и сплэш
    'entrance_quote': {
      AppLanguage.russian: 'Сон. Восстановление. Нагрузка.',
      AppLanguage.kyrgyz: 'Уйку. Калыбына келүү. Жүктөм.',
    },
    'entrance_quote_sub': {
      AppLanguage.russian: 'Три числа. Одно решение на день.',
      AppLanguage.kyrgyz: 'Үч сан. Күнгө бир чечим.',
    },
    'entrance_source': {
      AppLanguage.russian: 'КАЛКАН СПОРТ',
      AppLanguage.kyrgyz: 'КАЛКАН СПОРТ',
    },
    'entrance_tap_to_enter': {
      AppLanguage.russian: 'Нажмите, чтобы открыть',
      AppLanguage.kyrgyz: 'Ачуу үчүн басыңыз',
    },
    'entrance_initializing': {
      AppLanguage.russian: 'Инициализация сенсоров СААТ-1...',
      AppLanguage.kyrgyz: 'СААТ-1 сенсорлору иштетилүүдө...',
    },

    // Авторизация / Auth
    'auth_brand': {
      AppLanguage.russian: 'КАЛКАН СПОРТ · СААТ-1',
      AppLanguage.kyrgyz: 'КАЛКАН СПОРТ · СААТ-1',
    },
    'auth_login_title': {
      AppLanguage.russian: 'Вход',
      AppLanguage.kyrgyz: 'Кирүү',
    },
    'auth_signup_title': {
      AppLanguage.russian: 'Создание аккаунта',
      AppLanguage.kyrgyz: 'Аккаунт түзүү',
    },
    'auth_subtitle': {
      AppLanguage.russian: 'Подключите браслет и войдите в аккаунт',
      AppLanguage.kyrgyz: 'Билерикти туташтырып, аккаунтка кириңиз',
    },
    'auth_name_label': {
      AppLanguage.russian: 'Ваше имя',
      AppLanguage.kyrgyz: 'Сиздин атыңыз',
    },
    'auth_name_hint': {
      AppLanguage.russian: 'Батыр / Алихан',
      AppLanguage.kyrgyz: 'Батыр / Алихан',
    },
    'auth_email_label': {
      AppLanguage.russian: 'Email адрес',
      AppLanguage.kyrgyz: 'Email дареги',
    },
    'auth_password_label': {
      AppLanguage.russian: 'Пароль',
      AppLanguage.kyrgyz: 'Сырсөз',
    },
    'auth_button_login': {
      AppLanguage.russian: 'ВОЙТИ В СИСТЕМУ',
      AppLanguage.kyrgyz: 'СИСТЕМАГА КИРҮҮ',
    },
    'auth_button_signup': {
      AppLanguage.russian: 'ЗАРЕГИСТРИРОВАТЬСЯ',
      AppLanguage.kyrgyz: 'КАТТАЛУУ',
    },
    'auth_to_signup': {
      AppLanguage.russian: 'Нет аккаунта? Создать новый профиль',
      AppLanguage.kyrgyz: 'Аккаунтуңуз жокпу? Жаңы профиль түзүңүз',
    },
    'auth_to_login': {
      AppLanguage.russian: 'Уже есть аккаунт? Войти',
      AppLanguage.kyrgyz: 'Аккаунтуңуз барбы? Кирүү',
    },
    'auth_err_empty': {
      AppLanguage.russian: 'Заполните все обязательные поля',
      AppLanguage.kyrgyz: 'Бардык талап кылынган талааларды толтуруңуз',
    },
    'auth_err_email': {
      AppLanguage.russian: 'Введите корректный email адрес',
      AppLanguage.kyrgyz: 'Туура email дарегин киргизиңиз',
    },
    'auth_err_pass_length': {
      AppLanguage.russian: 'Пароль должен содержать минимум 6 символов',
      AppLanguage.kyrgyz: 'Сырсөз кеминде 6 белгиден турушу керек',
    },

    // Навигационная панель (Bottom Nav)
    'sport_history': {
      AppLanguage.russian: 'История тренировок',
      AppLanguage.kyrgyz: 'Машыгуулардын тарыхы',
    },
    'sport_pause': {
      AppLanguage.russian: 'Пауза',
      AppLanguage.kyrgyz: 'Пауза',
    },
    'sport_resume': {
      AppLanguage.russian: 'Продолжить',
      AppLanguage.kyrgyz: 'Улантуу',
    },
    'sport_finish': {
      AppLanguage.russian: 'Завершить',
      AppLanguage.kyrgyz: 'Аяктоо',
    },
    'sport_start': {
      AppLanguage.russian: 'Начать тренировку',
      AppLanguage.kyrgyz: 'Машыгууну баштоо',
    },
    'device_functions': {
      AppLanguage.russian: 'Функции часов',
      AppLanguage.kyrgyz: 'Сааттын функциялары',
    },
    'device_measure_hr': {
      AppLanguage.russian: 'Замер пульса',
      AppLanguage.kyrgyz: 'Пульсту өлчөө',
    },
    'device_sync_time': {
      AppLanguage.russian: 'Синхронизировать время',
      AppLanguage.kyrgyz: 'Убакытты шайкештирүү',
    },
    'firmware_title': {
      AppLanguage.russian: 'Прошивка',
      AppLanguage.kyrgyz: 'Прошивка',
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
    },
    'today_recovery': {
      AppLanguage.russian: 'ГОТОВНОСТЬ',
      AppLanguage.kyrgyz: 'КАЛЫБЫНА КЕЛҮҮ',
    },
    'today_streak_badge': {
      AppLanguage.russian: 'В ЗЕЛЁНОЙ ЗОНЕ 5 ДНЕЙ ПОДРЯД',
      AppLanguage.kyrgyz: 'ЖАШЫЛ ЗОНАДА КАТАРЫ МЕНЕН 5 КҮН',
    },
    'today_live_pulse': {
      AppLanguage.russian: 'ПУЛЬС В РЕАЛЬНОМ ВРЕМЕНИ',
      AppLanguage.kyrgyz: 'ЧЫНЫГЫ УБАКЫТТАГЫ ТАМЫР СОГУУ',
    },
    'today_trigger_pulse': {
      AppLanguage.russian: 'Запустить замер >',
      AppLanguage.kyrgyz: 'Ченөөнү баштоо >',
    },
    'today_pulse_measuring': {
      AppLanguage.russian: 'Инициация замера ЧСС через оптический сенсор СААТ-1...',
      AppLanguage.kyrgyz: 'СААТ-1 оптикалык сенсору аркылуу жүрөк согушун ченөө башталды...',
    },
    'today_5factors_title': {
      AppLanguage.russian: 'РАЗБОР 5 ФАКТОРОВ ВОССТАНОВЛЕНИЯ',
      AppLanguage.kyrgyz: 'КАЛЫБЫНА КЕЛҮҮНҮН 5 ФАКТОРУН ТАЛДОО',
    },
    'today_5factors_sub': {
      AppLanguage.russian: 'Почему сегодня 91%? Анализ ВСР, сна и температуры',
      AppLanguage.kyrgyz: 'Эмне үчүн бүгүн 91%? ЖЖВ, уйку жана температура талдоосу',
    },
    'today_hrv': {
      AppLanguage.russian: 'ВСР (HRV)',
      AppLanguage.kyrgyz: 'ЖЖВ (HRV)',
    },
    'today_rhr': {
      AppLanguage.russian: 'ЧСС ПОКОЯ',
      AppLanguage.kyrgyz: 'ТЫНЧ АБАЛДАГЫ ПУЛЬС',
    },
    'today_skin_temp': {
      AppLanguage.russian: 'ТЕМП. КОЖИ',
      AppLanguage.kyrgyz: 'ТЕРИ ТЕМП.',
    },
    'today_strain_budget': {
      AppLanguage.russian: 'НАГРУЗКА ДНЯ (STRAIN)',
      AppLanguage.kyrgyz: 'КҮНДҮК ООРЧУЛУК (STRAIN)',
    },
    'today_league_card_title': {
      AppLanguage.russian: 'КРУГ ДОВЕРИЯ · ПРИВАТНАЯ ЛИГА (4/5)',
      AppLanguage.kyrgyz: 'ИШЕНИМ ЧӨЙРӨСҮ · ЖЕКЕ ЛИГА (4/5)',
    },
    'today_league_card_sub': {
      AppLanguage.russian: 'Среднее восстановление близких: 82% · 1 слот свободен',
      AppLanguage.kyrgyz: 'Жакындардын орточо калыбына келүүсү: 82% · 1 орун бош',
    },

    // Маскот Барыс-Батыр
    'mascot_title': {
      AppLanguage.russian: 'Барыс',
      AppLanguage.kyrgyz: 'Барыс',
    },
    'mascot_level': {
      AppLanguage.russian: 'Уровень',
      AppLanguage.kyrgyz: 'Деңгээл',
    },
    'mascot_rank_cadet': {
      AppLanguage.russian: 'ИРБИС-КАДЕТ',
      AppLanguage.kyrgyz: 'ИЛБИРС-КАДЕТ',
    },
    'mascot_rank_sarbaz': {
      AppLanguage.russian: 'САРБАЗ',
      AppLanguage.kyrgyz: 'САРБАЗ',
    },
    'mascot_rank_batyr': {
      AppLanguage.russian: 'БАТЫР',
      AppLanguage.kyrgyz: 'БАТЫР',
    },
    'mascot_rank_aksakal': {
      AppLanguage.russian: 'АКСАКАЛ',
      AppLanguage.kyrgyz: 'АКСАКАЛ',
    },
    'mascot_evolution_link': {
      AppLanguage.russian: 'Все ступени эволюции >',
      AppLanguage.kyrgyz: 'Эволюциянын бардык баскычтары >',
    },
    'mascot_quests_title': {
      AppLanguage.russian: 'Задачи на день',
      AppLanguage.kyrgyz: 'Бүгүнкү милдеттер',
    },
    'mascot_quest_strain': {
      AppLanguage.russian: 'Закрыть дневной Strain',
      AppLanguage.kyrgyz: 'Күндүк Strain жүктөмүн жабуу',
    },
    'mascot_quest_journal': {
      AppLanguage.russian: 'Записать самочувствие',
      AppLanguage.kyrgyz: 'Абалды жазуу',
    },
    'mascot_quest_sleep': {
      AppLanguage.russian: 'Лечь до 22:30',
      AppLanguage.kyrgyz: '22:30га чейин уктоо',
    },

    // Спорт
    'sport_title': {
      AppLanguage.russian: 'СПОРТ И ТРЕНИРОВКИ',
      AppLanguage.kyrgyz: 'СПОРТ ЖАНА МАШЫГУУЛАР',
    },
    'sport_cat_all': {
      AppLanguage.russian: 'Все',
      AppLanguage.kyrgyz: 'Баары',
    },
    'sport_cat_strength': {
      AppLanguage.russian: 'Силовая',
      AppLanguage.kyrgyz: 'Күч машыгуусу',
    },
    'sport_cat_run': {
      AppLanguage.russian: 'Бег',
      AppLanguage.kyrgyz: 'Чуркоо',
    },
    'sport_cat_trail': {
      AppLanguage.russian: 'Горный трейл',
      AppLanguage.kyrgyz: 'Тоо трейли',
    },
    'sport_cat_cycling': {
      AppLanguage.russian: 'Велоспорт',
      AppLanguage.kyrgyz: 'Велоспорт',
    },
    'sport_cat_swim': {
      AppLanguage.russian: 'Плавание',
      AppLanguage.kyrgyz: 'Сууда сүзүү',
    },
    'sport_cat_flexibility': {
      AppLanguage.russian: 'Растяжка',
      AppLanguage.kyrgyz: 'Чоюлуу',
    },
    'sport_record_button': {
      AppLanguage.russian: 'Начать тренировку',
      AppLanguage.kyrgyz: 'Машыгууну баштоо',
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
    },
    // Анализ и стресс
    'analytics_title': {
      AppLanguage.russian: 'Анализ',
      AppLanguage.kyrgyz: 'Анализ',
      AppLanguage.english: 'Analysis',
    },
    'analytics_stress_timeline': {
      AppLanguage.russian: 'Стресс за день',
      AppLanguage.kyrgyz: 'Күндүк стресс',
    },
    'analytics_day_story': {
      AppLanguage.russian: 'День в событиях',
      AppLanguage.kyrgyz: 'Күндүн окуялары',
    },
    'analytics_healthspan': {
      AppLanguage.russian: 'Биологический возраст',
      AppLanguage.kyrgyz: 'Биологиялык курак',
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
    },
    'profile_language_section': {
      AppLanguage.russian: 'Язык',
      AppLanguage.kyrgyz: 'Тил',
    },
    'profile_language_sub': {
      AppLanguage.russian: 'Тилди тандоо · Выбор языка',
      AppLanguage.kyrgyz: 'Тилди тандоо · Выбор языка',
    },
    'profile_community_title': {
      AppLanguage.russian: 'СООБЩЕСТВО И ПРИВАТНЫЕ ЛИГИ',
      AppLanguage.kyrgyz: 'КООМДОШТУК ЖАНА ЖЕКЕ ЛИГАЛАР',
    },
    'profile_community_sub': {
      AppLanguage.russian: 'Круг доверия Данбара (3–5 человек)',
      AppLanguage.kyrgyz: 'Данбар ишеним чөйрөсү (3–5 адам)',
    },
    'profile_crisis_mode': {
      AppLanguage.russian: 'Режим «ГРОЗА» (Кризис и тревога)',
      AppLanguage.kyrgyz: '«ЧАГЫЛГАН» режими (Кризис жана кооптонуу)',
    },
    'profile_crisis_sub': {
      AppLanguage.russian: 'ЧСС 118, ВСР 22мс, стресс 89% (Red Zone)',
      AppLanguage.kyrgyz: 'Жүрөк 118, ЖЖВ 22мс, стресс 89% (Red Zone)',
    },
    'profile_logout': {
      AppLanguage.russian: 'ВЫЙТИ ИЗ СИСТЕМЫ',
      AppLanguage.kyrgyz: 'СИСТЕМАСЫНАН ЧЫГУУ',
    },
    'profile_logout_confirm_title': {
      AppLanguage.russian: 'Выйти из системы?',
      AppLanguage.kyrgyz: 'Системадан чыгасызбы?',
    },
    'profile_logout_confirm_desc': {
      AppLanguage.russian: 'Синхронизация биометрии будет приостановлена до повторного входа.',
      AppLanguage.kyrgyz: 'Биометрияны шайкештөө кайра киргенге чейин токтотулат.',
    },
    'common_cancel': {
      AppLanguage.russian: 'ОТМЕНА',
      AppLanguage.kyrgyz: 'ЖОККО ЧЫГАРУУ',
    },
    'common_confirm': {
      AppLanguage.russian: 'ПОДТВЕРДИТЬ',
      AppLanguage.kyrgyz: 'ЫРАС Walтоо',
    },
    'common_close': {
      AppLanguage.russian: 'ЗАКРЫТЬ',
      AppLanguage.kyrgyz: 'ЖАБУУ',
    },

    // Приватные лиги (Dunbar Circle)
    'league_appbar_sub': {
      AppLanguage.russian: 'Друзья',
      AppLanguage.kyrgyz: 'Достор',
    },
    'league_appbar_title': {
      AppLanguage.russian: 'Круг',
      AppLanguage.kyrgyz: 'Чөйрө',
    },
    'league_default_title': {
      AppLanguage.russian: 'Круг друзей',
      AppLanguage.kyrgyz: 'Достор чөйрөсү',
    },
    'league_slots_format': {
      AppLanguage.russian: '{current} / {max} мест',
      AppLanguage.kyrgyz: '{current} / {max} орун',
    },
    'league_avg_recovery': {
      AppLanguage.russian: 'Среднее восстановление',
      AppLanguage.kyrgyz: 'Орточо калыбына келүү',
    },
    'league_sync_badge': {
      AppLanguage.russian: 'Онлайн',
      AppLanguage.kyrgyz: 'Онлайн',
    },
    'league_invite_card_title': {
      AppLanguage.russian: 'Код для друзей',
      AppLanguage.kyrgyz: 'Достор үчүн код',
    },
    'league_copy_code': {
      AppLanguage.russian: 'Копировать',
      AppLanguage.kyrgyz: 'Көчүрүү',
    },
    'league_copied_snack': {
      AppLanguage.russian: 'Инвайт-код скопирован в буфер',
      AppLanguage.kyrgyz: 'Чакыруу коду алмашуу буферине көчүрүлдү',
    },
    'league_add_friend': {
      AppLanguage.russian: '+ ПРИГЛАСИТЬ ДРУГА ({count} СЛОТ СВОБОДЕН)',
      AppLanguage.kyrgyz: '+ ДОС ЧАКЫРУУ ({count} ОРУН БОШ)',
    },
    'league_full_badge': {
      AppLanguage.russian: 'КРУГ ДОВЕРИЯ ЗАПОЛНЕН (5/5)',
      AppLanguage.kyrgyz: 'ИШЕНИМ ЧӨЙРӨСҮ ТОЛДУ (5/5)',
    },
    'league_dialog_title': {
      AppLanguage.russian: 'ПРИГЛАШЕНИЕ В КРУГ ДОВЕРИЯ',
      AppLanguage.kyrgyz: 'ИШЕНИМ ЧӨЙРӨСҮНӨ ЧАКЫРУУ',
    },
    'league_friend_name_label': {
      AppLanguage.russian: 'Имя или позывной друга',
      AppLanguage.kyrgyz: 'Досуңуздун аты же каймана аты',
    },
    'league_friend_code_label': {
      AppLanguage.russian: 'Инвайт-код друга (опционально)',
      AppLanguage.kyrgyz: 'Досуңуздун чакыруу коду (милдеттүү эмес)',
    },
    'league_send_impulse': {
      AppLanguage.russian: 'ОТПРАВИТЬ ИМПУЛЬС СИЛЫ БАРЫСА ✦',
      AppLanguage.kyrgyz: 'БАРЫСТЫН КҮЧ ДЕМИН ЖӨНӨТҮҮ ✦',
    },
    'league_impulse_sent': {
      AppLanguage.russian: 'Импульс силы Барыса успешно отправлен атлету!',
      AppLanguage.kyrgyz: 'Барыстын күч деми атлетке ийгиликтүү жөнөтүлдү!',
    },
    'friend_detail_title': {
      AppLanguage.russian: 'БИОМЕТРИЧЕСКИЙ СНИМОК ДРУГА',
      AppLanguage.kyrgyz: 'ДОСУҢУЗДУН БИОМЕТРИКАЛЫК СҮРӨТҮ',
    },
    'friend_detail_recovery': {
      AppLanguage.russian: 'ВОССТАНОВЛЕНИЕ (RECOVERY)',
      AppLanguage.kyrgyz: 'КАЛЫБЫНА КЕЛҮҮ (RECOVERY)',
    },
    'friend_detail_strain': {
      AppLanguage.russian: 'НАГРУЗКА ДНЯ',
      AppLanguage.kyrgyz: 'КҮНДҮК ООРЧУЛУК',
    },
    'friend_detail_sleep': {
      AppLanguage.russian: 'СОН И КАЧЕСТВО',
      AppLanguage.kyrgyz: 'УЙКУ ЖАНА САПАТ',
    },
    'friend_detail_hrv': {
      AppLanguage.russian: 'ВСР (HRV)',
      AppLanguage.kyrgyz: 'ЖЖВ (HRV)',
    },
    'friend_detail_rhr': {
      AppLanguage.russian: 'ЧСС ПОКОЯ',
      AppLanguage.kyrgyz: 'ТЫНЧ АБАЛДАГЫ ПУЛЬС',
    },

    // Выбор пола (Gender Selection)
    'gender_label': {
      AppLanguage.russian: 'Ваш пол',
      AppLanguage.kyrgyz: 'Жынысыңыз',
    },
    'gender_male': {
      AppLanguage.russian: 'Мужской',
      AppLanguage.kyrgyz: 'Эркек',
    },
    'gender_female': {
      AppLanguage.russian: 'Женский',
      AppLanguage.kyrgyz: 'Аял',
    },

    // Мониторинг цикла (Menstrual Cycle & СААТ-1)
    'cycle_card_header': {
      AppLanguage.russian: 'ЖЕНСКИЙ БИОРИТМ · СААТ-1',
      AppLanguage.kyrgyz: 'АЯЛДАР БИОРИТМИ · СААТ-1',
    },
    'cycle_phase_menstrual': {
      AppLanguage.russian: 'Менструация',
      AppLanguage.kyrgyz: 'Этек кир',
    },
    'cycle_phase_follicular': {
      AppLanguage.russian: 'Фолликулярная',
      AppLanguage.kyrgyz: 'Фолликулярдык',
    },
    'cycle_phase_ovulatory': {
      AppLanguage.russian: 'Овуляция',
      AppLanguage.kyrgyz: 'Овуляция',
    },
    'cycle_phase_luteal': {
      AppLanguage.russian: 'Лютеиновая',
      AppLanguage.kyrgyz: 'Лютеиндик',
    },
    'cycle_day_counter': {
      AppLanguage.russian: 'День {day} из {total}',
      AppLanguage.kyrgyz: '{total} күндөн {day}-күн',
    },
    'cycle_screen_title': {
      AppLanguage.russian: 'Мониторинг цикла СААТ-1',
      AppLanguage.kyrgyz: 'СААТ-1 цикл мониторинги',
    },
    'cycle_screen_subtitle': {
      AppLanguage.russian: 'Ночная термометрия кожи и фазовый тренинг',
      AppLanguage.kyrgyz: 'Түнкү теринин термометриясы жана фазалык машыгуу',
    },
    'cycle_thermal_card': {
      AppLanguage.russian: 'ТЕРМОСЕНСОР КОЖИ СААТ-1',
      AppLanguage.kyrgyz: 'СААТ-1 ТЕРИ ТЕРМОСЕНСОРУ',
    },
    'cycle_thermal_desc': {
      AppLanguage.russian: 'Двухфазный ночной график температуры тела. Скачок подтверждает овуляцию.',
      AppLanguage.kyrgyz: 'Түнкү дене табынын эки фазалуу графиги. Секирик овуляцияны тастыктайт.',
    },
    'cycle_symptoms_title': {
      AppLanguage.russian: 'ЖУРНАЛ САМОЧУВСТВИЯ',
      AppLanguage.kyrgyz: 'ӨЗҮН СЕЗҮҮ КҮНДӨЛҮГҮ',
    },
    'cycle_symptom_energy': {
      AppLanguage.russian: 'Энергия',
      AppLanguage.kyrgyz: 'Кубаттуулук',
    },
    'cycle_symptom_cramps': {
      AppLanguage.russian: 'Спазмы',
      AppLanguage.kyrgyz: 'Сыздап ооруу',
    },
    'cycle_symptom_mood': {
      AppLanguage.russian: 'Настроение',
      AppLanguage.kyrgyz: 'Маанай',
    },
    'cycle_symptom_headache': {
      AppLanguage.russian: 'Головная боль',
      AppLanguage.kyrgyz: 'Баш оору',
    },
    'cycle_edit_settings': {
      AppLanguage.russian: 'Настройки цикла',
      AppLanguage.kyrgyz: 'Цикл жөндөөлөрү',
    },
    'cycle_settings_saved': {
      AppLanguage.russian: 'Параметры цикла сохранены в профиле',
      AppLanguage.kyrgyz: 'Цикл параметрлери профилде сакталды',
    },
    'cycle_directive_training': {
      AppLanguage.russian: 'Тренировки & Нагрузка',
      AppLanguage.kyrgyz: 'Машыгуу жана Оорчулук',
    },
    'cycle_directive_nutrition': {
      AppLanguage.russian: 'Питание & Гидратация',
      AppLanguage.kyrgyz: 'Тамактануу жана Гидратация',
    },
    'cycle_directive_sleep': {
      AppLanguage.russian: 'Сон & Терморегуляция',
      AppLanguage.kyrgyz: 'Уйку жана Терморегуляция',
    },
    'cycle_directive_barys': {
      AppLanguage.russian: 'Мудрость Барыса',
      AppLanguage.kyrgyz: 'Барыстын даанышмандыгы',
    },
  };

  /// Получить строку по ключу с учетом активного или переданного языка
  static String tr(String key, [AppLanguage? language]) {
    final lang = language ?? AppLocaleNotifier.current;
    final dict = _strings[key];
    if (dict == null) return key;
    return dict[lang] ?? dict[AppLanguage.russian] ?? key;
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
