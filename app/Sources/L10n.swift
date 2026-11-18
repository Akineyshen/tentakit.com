import Foundation

/// Название программы (из Info.plist) — подставляется вместо «MacTools» в текстах.
enum AppInfo {
    static let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Tentakit"
    static let bundleID = Bundle.main.bundleIdentifier ?? "app.tentakit"
}

/// Язык интерфейса: «auto» (как в системе), «en», «ru» или «pl».
enum Lang {
    static let key = "app.language"

    static var current: String {
        let v = UserDefaults.standard.string(forKey: key) ?? "auto"
        if v != "auto" { return v }
        let sys = Locale.preferredLanguages.first?.lowercased() ?? ""
        if sys.hasPrefix("pl") { return "pl" }
        if sys.hasPrefix("ru") || sys.hasPrefix("uk") || sys.hasPrefix("be") { return "ru" }
        return "en"
    }
}

/// Перевод строки интерфейса. Ключ — русский текст; %@ заменяются аргументами.
func L(_ ru: String, _ args: String...) -> String {
    var s: String
    switch Lang.current {
    case "pl": s = polish[ru] ?? ru
    case "en": s = english[ru] ?? ru
    default: s = ru
    }
    if AppInfo.name != "MacTools" { s = s.replacingOccurrences(of: "MacTools", with: AppInfo.name) }
    for a in args {
        guard let r = s.range(of: "%@") else { break }
        s.replaceSubrange(r, with: a)
    }
    return s
}

private let polish: [String: String] = [
    // Общее
    "Включить модуль": "Włącz moduł",
    "Открыть настройки": "Otwórz ustawienia",
    "Позже": "Później",
    "Отмена": "Anuluj",
    "Добавить": "Dodaj",
    "Выбрать": "Wybierz",
    "Изменить…": "Zmień…",
    "Модули": "Moduły",
    "Скоро": "Wkrótce",
    "скоро": "wkrótce",
    "всегда": "zawsze",

    // Меню в строке меню
    "⚠️ Дать доступ «Универсальный доступ»…": "⚠️ Nadaj uprawnienie „Dostępność”…",
    "Клик по Доку сворачивает окна": "Kliknięcie w Docku minimalizuje okna",
    "Окна прилипают к краям экрана": "Okna przyciągają się do krawędzi ekranu",
    "Плавная прокрутка мыши": "Płynne przewijanie myszy",
    "Автозакрытие по красной кнопке": "Automatyczne zamykanie czerwonym przyciskiem",
    "Мониторинг в строке меню": "Monitorowanie na pasku menu",
    "Открыть MacTools…": "Otwórz MacTools…",
    "Запускать при входе": "Uruchamiaj przy logowaniu",
    "Выйти из MacTools": "Zakończ MacTools",
    "Не удалось изменить автозапуск": "Nie udało się zmienić automatycznego uruchamiania",

    // Разделы
    "Обзор": "Przegląd",
    "Док": "Dock",
    "Раскладка окон": "Układ okien",
    "Мониторинг": "Monitorowanie",
    "Удаление приложений": "Usuwanie aplikacji",
    "Прокрутка мыши": "Przewijanie myszy",
    "Скриншоты": "Zrzuty ekranu",
    "Автозакрытие": "Automatyczne zamykanie",
    "Основные": "Ogólne",
    "Все модули MacTools": "Wszystkie moduły MacTools",
    "Клик по значку в Доке сворачивает окна, повторный клик разворачивает их обратно.": "Kliknięcie ikony w Docku minimalizuje okna, ponowne kliknięcie je przywraca.",
    "Перетащите окно к краю или в угол экрана, и оно встанет на половину или четверть.": "Przeciągnij okno do krawędzi lub rogu ekranu, a zajmie połowę lub ćwiartkę.",
    "Процессор, память, сеть и батарея в строке меню.": "Procesor, pamięć, sieć i bateria na pasku menu.",
    "Удаление приложений вместе с их остатками. Всё уходит в Корзину.": "Usuwanie aplikacji razem z pozostałościami. Wszystko trafia do Kosza.",
    "Плавная прокрутка и отдельное направление для мыши.": "Płynne przewijanie i osobny kierunek dla myszy.",
    "Как Lightshot: выделите область, рисуйте прямо на ней и копируйте одним нажатием.": "Jak Lightshot: zaznacz obszar, rysuj bezpośrednio na nim i kopiuj jednym kliknięciem.",
    "Красная кнопка на последнем окне завершает приложение. Можно добавить исключения.": "Czerwony przycisk na ostatnim oknie zamyka aplikację. Można dodać wyjątki.",
    "Автозапуск, доступ и информация о приложении.": "Automatyczne uruchamianie, uprawnienia i informacje o aplikacji.",
    "Все нужные утилиты в одном приложении": "Wszystkie potrzebne narzędzia w jednej aplikacji",
    "Этот модуль появится в следующих версиях.": "Ten moduł pojawi się w kolejnych wersjach.",

    // Доступ
    "Всё работает": "Wszystko działa",
    "Нужен доступ": "Potrzebne uprawnienie",
    "У MacTools есть «Универсальный доступ».": "MacTools ma uprawnienie „Dostępność”.",
    "Включите MacTools в «Конфиденциальность и безопасность → Универсальный доступ».": "Włącz MacTools w „Prywatność i ochrona → Dostępność”.",

    // Док
    "При первом клике": "Przy pierwszym kliknięciu",
    "Свернуть окна в Док": "Zminimalizuj okna do Docka",
    "Скрыть приложение (как ⌘H)": "Ukryj aplikację (jak ⌘H)",
    "Как это работает": "Jak to działa",
    "Нажмите на значок активного приложения в Доке: его окна свернутся.": "Kliknij ikonę aktywnej aplikacji w Docku: jej okna się zminimalizują.",
    "Нажмите ещё раз: все окна развернутся обратно.": "Kliknij ponownie: wszystkie okna wrócą.",
    "С зажатой ⌘, ⌥, ⌃ или ⇧ Док работает как обычно.": "Z wciśniętym ⌘, ⌥, ⌃ lub ⇧ Dock działa jak zwykle.",

    // Окна
    "Левая половина": "Lewa połowa",
    "Правая половина": "Prawa połowa",
    "Верхняя половина": "Górna połowa",
    "Нижняя половина": "Dolna połowa",
    "Левый верхний угол": "Lewy górny róg",
    "Правый верхний угол": "Prawy górny róg",
    "Левый нижний угол": "Lewy dolny róg",
    "Правый нижний угол": "Prawy dolny róg",
    "Левая треть": "Lewa jedna trzecia",
    "Средняя треть": "Środkowa jedna trzecia",
    "Правая треть": "Prawa jedna trzecia",
    "Левые две трети": "Lewe dwie trzecie",
    "Правые две трети": "Prawe dwie trzecie",
    "Развернуть на весь экран": "Na cały ekran",
    "По центру": "Na środku",
    "Вернуть как было": "Przywróć poprzedni rozmiar",
    "Половины": "Połowy",
    "Четверти": "Ćwiartki",
    "Трети": "Trzecie",
    "Другое": "Inne",
    "К левому краю": "Do lewej krawędzi",
    "К правому краю": "Do prawej krawędzi",
    "К верхнему краю": "Do górnej krawędzi",
    "К нижнему краю": "Do dolnej krawędzi",
    "В левый верхний угол": "Do lewego górnego rogu",
    "В правый верхний угол": "Do prawego górnego rogu",
    "В левый нижний угол": "Do lewego dolnego rogu",
    "В правый нижний угол": "Do prawego dolnego rogu",
    "Тащите окно за заголовок. Когда курсор коснётся края или угла, появится подсветка. Отпустите, и окно встанет на это место.": "Przeciągnij okno za pasek tytułu. Gdy kursor dotknie krawędzi lub rogu, pojawi się podświetlenie. Puść, a okno zajmie to miejsce.",
    "Зелёная кнопка разворачивает окно, не скрывая строку меню и Док": "Zielony przycisk powiększa okno, nie ukrywając paska menu i Docka",
    "Анимация, как в системе": "Animacja jak w systemie",
    "Зелёная кнопка": "Zielony przycisk",
    "Окно займёт весь экран, но строка меню сверху и Док останутся видны. Повторное нажатие вернёт прежний размер. С зажатой ⌥ кнопка работает как обычно.": "Okno zajmie cały ekran, ale pasek menu i Dock pozostaną widoczne. Ponowne kliknięcie przywróci poprzedni rozmiar. Z wciśniętym ⌥ przycisk działa jak zwykle.",
    "Куда тащить": "Gdzie przeciągnąć",
    "Горячие клавиши ⌃⌥ (дополнительно)": "Skróty klawiszowe ⌃⌥ (dodatkowo)",

    // Прокрутка
    "Работает только для колеса мыши. Трекпад не затрагивается.": "Działa tylko dla kółka myszy. Gładzik pozostaje bez zmian.",
    "Направление": "Kierunek",
    "Обратное направление для мыши": "Odwrócony kierunek dla myszy",
    "Переворачивать и масштаб (⌘ / ⌃ / ⌥ + колесо)": "Odwracaj też powiększanie (⌘ / ⌃ / ⌥ + kółko)",
    "Плавность": "Płynność",
    "Плавная прокрутка": "Płynne przewijanie",
    "Скорость": "Szybkość",
    "резко": "ostro",
    "мягко": "miękko",
    "Мыши Logitech через Logi Options+ тоже поддерживаются. Направление настраивайте здесь, а в Logi Options+ оставьте «Naturalne» и выключите «Płynne przewijanie», чтобы настройки не накладывались друг на друга.": "Myszy Logitech przez Logi Options+ też są obsługiwane. Kierunek ustawiaj tutaj, a w Logi Options+ zostaw „Naturalne” i wyłącz „Płynne przewijanie”, aby ustawienia się nie nakładały.",

    // Автозакрытие
    "Срабатывает, когда вы закрываете красной кнопкой последнее окно приложения. Если у приложения остались свёрнутые окна, оно не закроется.": "Działa, gdy zamykasz czerwonym przyciskiem ostatnie okno aplikacji. Jeśli aplikacja ma zminimalizowane okna, nie zostanie zamknięta.",
    "Исключения — эти приложения не закрываются": "Wyjątki — te aplikacje nie są zamykane",
    "Из запущенных": "Z uruchomionych",
    "Выбрать приложение…": "Wybierz aplikację…",
    "Убрать из исключений": "Usuń z wyjątków",

    // Удаление приложений
    "Поиск приложения": "Szukaj aplikacji",
    "Обновить список": "Odśwież listę",
    "без идентификатора": "bez identyfikatora",
    "Ищу остатки…": "Szukam pozostałości…",
    "Приложение": "Aplikacja",
    "Показать в Finder": "Pokaż w Finderze",
    "Найдено: %@ · выбрано %@": "Znaleziono: %@ · zaznaczono %@",
    "Удалить в Корзину": "Przenieś do Kosza",
    "Удалить «%@»?": "Usunąć „%@”?",
    "Переместить в Корзину": "Przenieś do Kosza",
    "Приложение будет закрыто, а выбранные объекты (%@ шт.) перемещены в Корзину. Пока Корзина не очищена, всё можно вернуть.": "Aplikacja zostanie zamknięta, a zaznaczone elementy (%@ szt.) przeniesione do Kosza. Dopóki Kosz nie zostanie opróżniony, wszystko można przywrócić.",
    "Выберите приложение слева. MacTools найдёт его настройки, кэши и другие остатки в ~/Library.": "Wybierz aplikację po lewej. MacTools znajdzie jej ustawienia, pamięć podręczną i inne pozostałości w ~/Library.",
    "Не удалось закрыть «%@». Закройте его вручную и попробуйте снова.": "Nie udało się zamknąć „%@”. Zamknij ją ręcznie i spróbuj ponownie.",
    "В Корзину перемещено: %@ (%@).": "Przeniesiono do Kosza: %@ (%@).",
    " Не удалось: %@.": " Nie udało się: %@.",

    // Мониторинг
    "Показывать в строке меню": "Pokazuj na pasku menu",
    "Нажмите на показатели в строке меню, чтобы открыть подробности.": "Kliknij wskaźniki na pasku menu, aby zobaczyć szczegóły.",
    "Что показывать в строке меню": "Co pokazywać na pasku menu",
    "Процессор": "Procesor",
    "Память": "Pamięć",
    "Сеть": "Sieć",
    "Сеть (скорость загрузки и отдачи)": "Sieć (prędkość pobierania i wysyłania)",
    "Батарея": "Bateria",
    "Диск": "Dysk",
    "Обновлять каждые": "Odświeżaj co",
    "1 секунду": "1 sekundę",
    "2 секунды": "2 sekundy",
    "5 секунд": "5 sekund",
    "Сейчас": "Teraz",
    "Включите модуль, чтобы видеть показатели.": "Włącz moduł, aby widzieć wskaźniki.",
    "Мониторинг активности": "Monitor aktywności",
    "Программы %@": "Aplikacje %@",
    "Система %@": "System %@",
    "%@ из %@": "%@ z %@",
    "Ядро %@": "Jądro %@",
    "Сжато %@": "Skompresowane %@",
    "свободно %@": "wolne %@",
    "Больше всего нагружают": "Najbardziej obciążają",
    "%.0f МБ": "%.0f MB",
    "/с": "/s",
    "Заряжается": "Ładowanie",
    "От сети": "Zasilacz",
    "От батареи": "Bateria",
    " · до полной %@ ч %@ мин": " · do pełna %@ godz. %@ min",
    " · осталось %@ ч %@ мин": " · zostało %@ godz. %@ min",

    // Скриншоты
    "Карандаш": "Ołówek",
    "Линия": "Linia",
    "Стрелка": "Strzałka",
    "Рамка": "Ramka",
    "Маркер": "Zakreślacz",
    "Текст": "Tekst",
    "Размытие": "Rozmycie",
    "Пробел": "Spacja",
    "Клавиша %@": "Klawisz %@",
    "Снимок области или окна": "Zrzut obszaru lub okna",
    "Снимок всего экрана": "Zrzut całego ekranu",
    "Нужен доступ к записи экрана": "Potrzebne uprawnienie do nagrywania ekranu",
    "Включите MacTools в «Конфиденциальность и безопасность → Запись экрана», затем перезапустите MacTools.": "Włącz MacTools w „Prywatność i ochrona → Nagrywanie ekranu”, a następnie uruchom MacTools ponownie.",
    "Нужна macOS 14 или новее": "Wymagany macOS 14 lub nowszy",
    "Экран не найден": "Nie znaleziono ekranu",
    "Скриншот %@.png": "Zrzut ekranu %@.png",
    "Выделите область или кликните по окну   ·   Esc — отмена": "Zaznacz obszar lub kliknij okno   ·   Esc — anuluj",
    "Отменить (⌘Z)": "Cofnij (⌘Z)",
    "Толщина": "Grubość",
    "Сохранить в папку и скопировать (⌘S)": "Zapisz w folderze i skopiuj (⌘S)",
    "Копировать": "Kopiuj",
    "Скопировать и закрыть (⌘C или ↩)": "Skopiuj i zamknij (⌘C lub ↩)",
    "Закрыть (Esc)": "Zamknij (Esc)",
    "Запись экрана разрешена": "Nagrywanie ekranu dozwolone",
    "Включите MacTools в «Запись экрана и звука», затем перезапустите MacTools.": "Włącz MacTools w „Nagrywanie ekranu i dźwięku”, a następnie uruchom MacTools ponownie.",
    "Горячие клавиши для снимков": "Skróty klawiszowe do zrzutów",
    "Снять": "Zrób zrzut",
    "Сочетания клавиш": "Skróty klawiszowe",
    "Нажмите на сочетание, чтобы задать своё. Нужна хотя бы одна из клавиш ⌘ ⌃ ⌥.": "Kliknij skrót, aby ustawić własny. Potrzebny jest co najmniej jeden z klawiszy ⌘ ⌃ ⌥.",
    "Как пользоваться": "Jak używać",
    "Выделите область мышью или просто кликните по окну.": "Zaznacz obszar myszą lub po prostu kliknij okno.",
    "Тяните за белые квадратики, чтобы изменить размер. Без выбранного инструмента область можно перетаскивать.": "Ciągnij za białe kwadraciki, aby zmienić rozmiar. Bez wybranego narzędzia obszar można przesuwać.",
    "Справа от области — инструменты: карандаш, линия, стрелка, рамка, маркер, текст, размытие.": "Po prawej stronie obszaru są narzędzia: ołówek, linia, strzałka, ramka, zakreślacz, tekst, rozmycie.",
    "⌘C или ↩ — скопировать. ⌘S — сохранить в папку. ⌘Z — отменить. Esc — закрыть.": "⌘C lub ↩ — kopiuj. ⌘S — zapisz w folderze. ⌘Z — cofnij. Esc — zamknij.",
    "Сохранение": "Zapisywanie",
    "Папка для ⌘S": "Folder dla ⌘S",
    "Нажмите сочетание…": "Naciśnij skrót…",
    "Вернуть %@": "Przywróć %@",

    // Основные
    "Запуск": "Uruchamianie",
    "Запускать MacTools при входе в систему": "Uruchamiaj MacTools przy logowaniu",
    "Доступ": "Uprawnienia",
    "О приложении": "O aplikacji",
    "Версия": "Wersja",
    "Модулей": "Moduły",
    "%@ готово, %@ скоро": "%@ gotowych, %@ wkrótce",
    "Поиск": "Szukaj",
    "Язык": "Język",
    "Как в системе": "Jak w systemie",
]
