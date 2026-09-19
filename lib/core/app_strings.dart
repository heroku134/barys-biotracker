import 'app_language.dart';

/// Централизованное двуязычное хранилище строк (Русский + Кыргызча)
class AppStrings {
  static const Map<String, Map<AppLanguage, String>> _strings = {
    // Входная цитата и сплэш
    'entrance_quote': {
      AppLanguage.russian: '«Адамга өз чегин билбей өлгөн уят»',
      AppLanguage.kyrgyz: '«Адамга өз чегин билбей өлгөн уят»',
    },
    'entrance_quote_sub': {
      AppLanguage.russian: '«Стыдно человеку умереть, не познав предела своих сил»',
      AppLanguage.kyrgyz: '«Адам өз чегин, дараметин жана күчүн билбей өтүп кеткени уят»',
    },
    'entrance_source': {
      AppLanguage.russian: 'Кыргызская народная мудрость · Биометрическое ателье CIRCA',
      AppLanguage.kyrgyz: 'Кыргыз эл макалы · CIRCA биометрикалык ательеси',
    },
    'entrance_tap_to_enter': {
      AppLanguage.russian: 'ТАП ДЛЯ ВХОДА В БИОСИСТЕМУ',
      AppLanguage.kyrgyz: 'БИОСИСТЕМАГА КИРҮҮ ҮЧҮН БАСЫҢЫЗ',
    },
    'entrance_initializing': {
      AppLanguage.russian: 'Инициализация сенсоров CIRCA...',
      AppLanguage.kyrgyz: 'CIRCA сенсорлору иштетилүүдө...',
    },

    // Авторизация / Auth
    'auth_brand': {
      AppLanguage.russian: 'CIRCA ONE',
      AppLanguage.kyrgyz: 'CIRCA ONE',
    },
    'auth_login_title': {
      AppLanguage.russian: 'Вход в биосистему',
      AppLanguage.kyrgyz: 'Биосистемага кирүү',
    },
    'auth_signup_title': {
      AppLanguage.russian: 'Создание аккаунта',
      AppLanguage.kyrgyz: 'Аккаунт түзүү',
    },
    'auth_subtitle': {
      AppLanguage.russian: 'Синхронизация биометрии браслета с Барыс-Батыром',
      AppLanguage.kyrgyz: 'Билерик биометриясын Барыс-Батыр менен шайкештөө',
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
    'nav_today': {
      AppLanguage.russian: 'Сегодня',
      AppLanguage.kyrgyz: 'Бүгүн',
    },
    'nav_analysis': {
      AppLanguage.russian: 'Анализ',
      AppLanguage.kyrgyz: 'Талдоо',
    },
    'nav_barys': {
      AppLanguage.russian: '🐯 БАРЫС',
      AppLanguage.kyrgyz: '🐯 БАРЫС',
    },
    'nav_sport': {
      AppLanguage.russian: 'Спорт',
      AppLanguage.kyrgyz: 'Спорт',
    },
    'nav_profile': {
      AppLanguage.russian: 'Профиль',
      AppLanguage.kyrgyz: 'Профиль',
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
      AppLanguage.russian: 'Инициация замера ЧСС через оптический сенсор CIRCA...',
      AppLanguage.kyrgyz: 'CIRCA оптикалык сенсору аркылуу жүрөк согушун ченөө башталды...',
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
      AppLanguage.russian: 'ТЕМПЕРАТУРА КОЖИ',
      AppLanguage.kyrgyz: 'ТЕРИНИН ТЕМПЕРАТУРАСЫ',
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
      AppLanguage.russian: 'БИО-МАСКОТ БАРЫС',
      AppLanguage.kyrgyz: 'БАРЫС БИО-МАСКОТУ',
    },
    'mascot_level': {
      AppLanguage.russian: 'УРОВЕНЬ',
      AppLanguage.kyrgyz: 'ДЕҢГЭЭЛ',
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
      AppLanguage.russian: 'ЕЖЕДНЕВНЫЕ ЗАДАЧИ НАГРУЗКИ',
      AppLanguage.kyrgyz: 'КҮНДҮК ЖҮКТӨМ ТАПШЫРМАЛАРЫ',
    },
    'mascot_quest_strain': {
      AppLanguage.russian: 'Закрыть дневной Strain',
      AppLanguage.kyrgyz: 'Күндүк Strain жүктөмүн жабуу',
    },
    'mascot_quest_journal': {
      AppLanguage.russian: 'Залогировать био-журнал',
      AppLanguage.kyrgyz: 'Био-журналга белгилөө',
    },
    'mascot_quest_sleep': {
      AppLanguage.russian: 'Циркадный отбой до 22:30',
      AppLanguage.kyrgyz: 'Циркаддык уктоо (22:30 чейин)',
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
      AppLanguage.russian: 'НАЧАТЬ ТРЕНИРОВКУ',
      AppLanguage.kyrgyz: 'МАШЫГУУНУ БАШТОО',
    },

    // Анализ и стресс
    'analytics_title': {
      AppLanguage.russian: 'АНАЛИТИКА БИОСИСТЕМЫ',
      AppLanguage.kyrgyz: 'БИОСИСТЕМАНЫН АНАЛИТИКАСЫ',
    },
    'analytics_stress_timeline': {
      AppLanguage.russian: 'ХРОНОЛОГИЯ СТРЕССА',
      AppLanguage.kyrgyz: 'СТРЕССТИН ХРОНОЛОГИЯСЫ',
    },
    'analytics_day_story': {
      AppLanguage.russian: 'ДЕНЬ В 5 СОБЫТИЯХ',
      AppLanguage.kyrgyz: 'КҮН 5 ОКУЯДА',
    },
    'analytics_healthspan': {
      AppLanguage.russian: 'БИОЛОГИЧЕСКИЙ ВОЗРАСТ И HEALTHSPAN',
      AppLanguage.kyrgyz: 'БИОЛОГИЯЛЫК КУРАК ЖАНА HEALTHSPAN',
    },

    // Профиль и настройки
    'profile_title': {
      AppLanguage.russian: 'ПРОФИЛЬ АТЛЕТА',
      AppLanguage.kyrgyz: 'АТЛЕТТИН ПРОФИЛИ',
    },
    'profile_passport': {
      AppLanguage.russian: 'БИОМЕТРИЧЕСКИЙ ПАСПОРТ АТЛЕТА',
      AppLanguage.kyrgyz: 'АТЛЕТТИН БИОМЕТРИКАЛЫК ПАСПОРТУ',
    },
    'profile_language_section': {
      AppLanguage.russian: 'ЯЗЫК ИНТЕРФЕЙСА',
      AppLanguage.kyrgyz: 'ИНТЕРФЕЙС ТИЛИ',
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
      AppLanguage.russian: '⚡ Режим «ГРОЗА» (Кризис и тревога)',
      AppLanguage.kyrgyz: '⚡ «ЧАГЫЛГАН» режими (Кризис жана кооптонуу)',
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
      AppLanguage.russian: 'КРУГ ДОВЕРИЯ · ЛИГА',
      AppLanguage.kyrgyz: 'ИШЕНИМ ЧӨЙРӨСҮ · ЛИГА',
    },
    'league_appbar_title': {
      AppLanguage.russian: 'Приватная лига CIRCA',
      AppLanguage.kyrgyz: 'CIRCA жеке лигасы',
    },
    'league_default_title': {
      AppLanguage.russian: 'КРУГ БАТЫРОВ · ALMATY ATELIER',
      AppLanguage.kyrgyz: 'БАТЫРЛАР ЧӨЙРӨСҮ · ALMATY ATELIER',
    },
    'league_slots_format': {
      AppLanguage.russian: '{current} / {max} МЕСТ',
      AppLanguage.kyrgyz: '{current} / {max} ОРУН',
    },
    'league_avg_recovery': {
      AppLanguage.russian: 'СРЕДНЕЕ ВОССТАНОВЛЕНИЕ КРУГА',
      AppLanguage.kyrgyz: 'ЧӨЙРӨНҮН ОРТОЧО КАЛЫБЫНА КЕЛҮҮСҮ',
    },
    'league_sync_badge': {
      AppLanguage.russian: 'В СИНХРОНЕ',
      AppLanguage.kyrgyz: 'ШАЙКЕШТИКТЕ',
    },
    'league_invite_card_title': {
      AppLanguage.russian: 'ВАШ ИНВАЙТ-КОД ДЛЯ ДРУЗЕЙ',
      AppLanguage.kyrgyz: 'ДОСТОР ҮЧҮН ЧАКЫРУУ КОДУҢУЗ',
    },
    'league_copy_code': {
      AppLanguage.russian: 'СКОПИРОВАТЬ',
      AppLanguage.kyrgyz: 'КӨЧҮРҮҮ',
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
