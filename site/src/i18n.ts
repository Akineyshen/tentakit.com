export const languages = { en: 'English', pl: 'Polski', ru: 'Русский' } as const;
export type Lang = keyof typeof languages;

export const INSTALL_CMD = 'curl -fsSL https://tentakit.com/install.sh | bash';
export const DOWNLOAD_URL = '/download/Tentakit.zip';
export const GITHUB_URL = ''; // появится, когда будет репозиторий

type Feature = { icon: string; title: string; text: string };
type QA = { q: string; a: string };

export interface Dict {
  meta: { title: string; description: string };
  nav: { features: string; install: string; faq: string; github: string };
  hero: { badge: string; title: string; titleAccent: string; lead: string; copy: string; copied: string; download: string; req: string };
  mock: { items: string[]; shot: string };
  features: { title: string; lead: string; items: Feature[] };
  why: { title: string; points: { title: string; text: string }[] };
  install: { title: string; lead: string; cmdTitle: string; cmdText: string; zipTitle: string; zipText: string; permsTitle: string; perms: string[] };
  faq: { title: string; items: QA[] };
  footer: { made: string; free: string };
}

const en: Dict = {
  meta: {
    title: 'Tentakit — eight Mac utilities in one free app',
    description: 'Tentakit replaces a pile of Mac utilities: Dock click to minimize, drag-to-snap windows, smooth mouse scrolling, auto-quit, app uninstaller, menu bar stats and Lightshot-style screenshots.',
  },
  nav: { features: 'Features', install: 'Install', faq: 'FAQ', github: 'GitHub' },
  hero: {
    badge: 'Free · macOS 13+',
    title: 'Eight Mac tools.',
    titleAccent: 'One tiny octopus.',
    lead: 'Tentakit does the job of a whole folder of utilities: Dock tricks, window snapping, smooth scrolling, auto-quit, an uninstaller, system stats and screenshots. One small app in your menu bar.',
    copy: 'Copy',
    copied: 'Copied!',
    download: 'Download .zip',
    req: 'Paste the command into Terminal. Works on Apple Silicon and Intel.',
  },
  mock: {
    items: ['Click Dock icon to minimize', 'Snap windows to screen edges', 'Smooth mouse scrolling', 'Quit apps with the red button', 'Stats in the menu bar'],
    shot: 'Capture area or window',
  },
  features: {
    title: 'Every tentacle does one job well',
    lead: 'Turn on only what you need. Everything else stays out of your way.',
    items: [
      { icon: 'dock', title: 'Dock click to minimize', text: 'Click an app in the Dock to tuck its windows away. Click again to bring them back.' },
      { icon: 'snap', title: 'Drag-to-snap windows', text: 'Drag a window to an edge or corner and it fills half or a quarter of the screen. No shortcuts to learn.' },
      { icon: 'max', title: 'A smarter green button', text: 'Maximize a window while the menu bar and Dock stay visible, with the native macOS animation.' },
      { icon: 'scroll', title: 'Smooth mouse scrolling', text: 'Silky scrolling and a separate direction for the mouse. Your trackpad stays untouched. Logitech mice included.' },
      { icon: 'quit', title: 'Auto-quit', text: 'Closing the last window with the red button quits the app. Keep a list of exceptions.' },
      { icon: 'trash', title: 'Clean uninstaller', text: 'Remove an app together with its caches and settings. Everything goes to the Trash, so nothing is lost by accident.' },
      { icon: 'stats', title: 'Menu bar stats', text: 'CPU, memory, network and battery at a glance, with details and the heaviest apps one click away.' },
      { icon: 'shot', title: 'Instant screenshots', text: 'Select an area, draw arrows, boxes, text or blur right on the screen, then copy with one key.' },
    ],
  },
  why: {
    title: 'Why one app instead of eight?',
    points: [
      { title: 'Less clutter', text: 'One icon in the menu bar instead of a row of them.' },
      { title: 'Light and native', text: 'Written in Swift. Tiny, fast and made only for macOS.' },
      { title: 'Private', text: 'No accounts, no tracking. Everything stays on your Mac.' },
    ],
  },
  install: {
    title: 'Install in 30 seconds',
    lead: 'Pick the way you like.',
    cmdTitle: 'One command (recommended)',
    cmdText: 'Open Terminal, paste the command and press Return. Tentakit is installed to Applications and starts right away.',
    zipTitle: 'Download manually',
    zipText: 'Unzip and move Tentakit to Applications. On first launch open System Settings → Privacy & Security and click “Open Anyway”.',
    permsTitle: 'macOS will ask for two permissions',
    perms: ['Accessibility — to manage windows, the Dock and scrolling.', 'Screen Recording — only for screenshots.'],
  },
  faq: {
    title: 'Questions',
    items: [
      { q: 'Is Tentakit free?', a: 'Yes. Tentakit is free to use. If you like it, you can support development later.' },
      { q: 'Why does macOS warn me when I open it?', a: 'Tentakit is not yet notarized by Apple, so the downloaded zip shows a warning once. The one-command install avoids it. Notarization is planned.' },
      { q: 'Which macOS do I need?', a: 'macOS 13 Ventura or newer. Screenshots need macOS 14 Sonoma or newer.' },
      { q: 'Does it collect any data?', a: 'No. Tentakit works fully offline and sends nothing anywhere.' },
      { q: 'Which languages does the app speak?', a: 'English, Polish and Russian. Tentakit picks your Mac’s language automatically, and you can switch it in Settings.' },
    ],
  },
  footer: { made: 'Made for Mac lovers.', free: 'Free forever for personal use.' },
};

const pl: Dict = {
  meta: {
    title: 'Tentakit — osiem narzędzi dla Maca w jednej darmowej aplikacji',
    description: 'Tentakit zastępuje kilka aplikacji na Maca: minimalizowanie kliknięciem w Docku, przyciąganie okien, płynne przewijanie myszy, automatyczne zamykanie, usuwanie aplikacji, statystyki na pasku menu i zrzuty ekranu jak w Lightshot.',
  },
  nav: { features: 'Funkcje', install: 'Instalacja', faq: 'Pytania', github: 'GitHub' },
  hero: {
    badge: 'Za darmo · macOS 13+',
    title: 'Osiem narzędzi dla Maca.',
    titleAccent: 'Jedna mała ośmiornica.',
    lead: 'Tentakit robi to, co cały folder aplikacji: sztuczki z Dockiem, przyciąganie okien, płynne przewijanie, automatyczne zamykanie, usuwanie aplikacji, statystyki systemu i zrzuty ekranu. Jedna mała aplikacja na pasku menu.',
    copy: 'Kopiuj',
    copied: 'Skopiowano!',
    download: 'Pobierz .zip',
    req: 'Wklej polecenie do Terminala. Działa na Apple Silicon i Intelu.',
  },
  mock: {
    items: ['Kliknięcie w Docku minimalizuje', 'Przyciąganie okien do krawędzi', 'Płynne przewijanie myszy', 'Zamykanie czerwonym przyciskiem', 'Statystyki na pasku menu'],
    shot: 'Zrzut obszaru lub okna',
  },
  features: {
    title: 'Każda macka robi jedną rzecz dobrze',
    lead: 'Włącz tylko to, czego potrzebujesz. Reszta nie przeszkadza.',
    items: [
      { icon: 'dock', title: 'Minimalizowanie kliknięciem w Docku', text: 'Kliknij aplikację w Docku, a jej okna się schowają. Kliknij ponownie, a wrócą.' },
      { icon: 'snap', title: 'Przyciąganie okien', text: 'Przeciągnij okno do krawędzi lub rogu, a zajmie połowę lub ćwiartkę ekranu. Bez skrótów do zapamiętania.' },
      { icon: 'max', title: 'Mądrzejszy zielony przycisk', text: 'Powiększa okno, a pasek menu i Dock zostają widoczne. Z natywną animacją macOS.' },
      { icon: 'scroll', title: 'Płynne przewijanie myszy', text: 'Gładkie przewijanie i osobny kierunek dla myszy. Gładzik bez zmian. Myszy Logitech też działają.' },
      { icon: 'quit', title: 'Automatyczne zamykanie', text: 'Zamknięcie ostatniego okna czerwonym przyciskiem zamyka aplikację. Możesz dodać wyjątki.' },
      { icon: 'trash', title: 'Dokładne usuwanie aplikacji', text: 'Usuwa aplikację razem z pamięcią podręczną i ustawieniami. Wszystko trafia do Kosza, więc nic nie zginie przypadkiem.' },
      { icon: 'stats', title: 'Statystyki na pasku menu', text: 'Procesor, pamięć, sieć i bateria w jednym spojrzeniu, a szczegóły i najcięższe aplikacje jedno kliknięcie dalej.' },
      { icon: 'shot', title: 'Błyskawiczne zrzuty ekranu', text: 'Zaznacz obszar, rysuj strzałki, ramki, tekst lub rozmycie bezpośrednio na ekranie i skopiuj jednym klawiszem.' },
    ],
  },
  why: {
    title: 'Dlaczego jedna aplikacja zamiast ośmiu?',
    points: [
      { title: 'Mniej bałaganu', text: 'Jedna ikona na pasku menu zamiast całego rzędu.' },
      { title: 'Lekka i natywna', text: 'Napisana w Swift. Mała, szybka i tylko dla macOS.' },
      { title: 'Prywatna', text: 'Bez kont i śledzenia. Wszystko zostaje na Twoim Macu.' },
    ],
  },
  install: {
    title: 'Instalacja w 30 sekund',
    lead: 'Wybierz sposób, który wolisz.',
    cmdTitle: 'Jedno polecenie (zalecane)',
    cmdText: 'Otwórz Terminal, wklej polecenie i naciśnij Return. Tentakit zainstaluje się w Aplikacjach i od razu się uruchomi.',
    zipTitle: 'Pobierz ręcznie',
    zipText: 'Rozpakuj i przenieś Tentakit do Aplikacji. Przy pierwszym uruchomieniu otwórz Ustawienia systemowe → Prywatność i ochrona i kliknij „Otwórz mimo to”.',
    permsTitle: 'macOS poprosi o dwa uprawnienia',
    perms: ['Dostępność — do zarządzania oknami, Dockiem i przewijaniem.', 'Nagrywanie ekranu — tylko do zrzutów ekranu.'],
  },
  faq: {
    title: 'Pytania',
    items: [
      { q: 'Czy Tentakit jest darmowy?', a: 'Tak. Tentakit jest darmowy. Jeśli Ci się spodoba, później będzie można wesprzeć rozwój.' },
      { q: 'Dlaczego macOS pokazuje ostrzeżenie?', a: 'Tentakit nie jest jeszcze notaryzowany przez Apple, więc pobrany plik zip raz pokaże ostrzeżenie. Instalacja jednym poleceniem go omija. Notaryzacja jest w planach.' },
      { q: 'Jakiego macOS potrzebuję?', a: 'macOS 13 Ventura lub nowszego. Zrzuty ekranu wymagają macOS 14 Sonoma lub nowszego.' },
      { q: 'Czy aplikacja zbiera dane?', a: 'Nie. Tentakit działa całkowicie offline i nigdzie niczego nie wysyła.' },
      { q: 'W jakich językach jest aplikacja?', a: 'Po angielsku, polsku i rosyjsku. Tentakit sam wybiera język Twojego Maca, a w ustawieniach możesz go zmienić.' },
    ],
  },
  footer: { made: 'Stworzone dla miłośników Maca.', free: 'Zawsze za darmo do użytku osobistego.' },
};

const ru: Dict = {
  meta: {
    title: 'Tentakit — восемь утилит для Mac в одной бесплатной программе',
    description: 'Tentakit заменяет сразу несколько утилит для Mac: сворачивание кликом по Доку, прилипание окон к краям, плавная прокрутка мыши, автозакрытие, удаление программ, мониторинг в строке меню и скриншоты как в Lightshot.',
  },
  nav: { features: 'Возможности', install: 'Установка', faq: 'Вопросы', github: 'GitHub' },
  hero: {
    badge: 'Бесплатно · macOS 13+',
    title: 'Восемь утилит для Mac.',
    titleAccent: 'Один маленький осьминог.',
    lead: 'Tentakit заменяет целую папку программ: фишки Дока, прилипание окон, плавную прокрутку, автозакрытие, удаление программ, мониторинг системы и скриншоты. Одна маленькая программа в строке меню.',
    copy: 'Копировать',
    copied: 'Скопировано!',
    download: 'Скачать .zip',
    req: 'Вставьте команду в Терминал. Работает на Apple Silicon и Intel.',
  },
  mock: {
    items: ['Клик по Доку сворачивает окна', 'Окна прилипают к краям', 'Плавная прокрутка мыши', 'Закрытие красной кнопкой', 'Мониторинг в строке меню'],
    shot: 'Снимок области или окна',
  },
  features: {
    title: 'Каждое щупальце отвечает за своё',
    lead: 'Включайте только то, что нужно. Остальное не мешает.',
    items: [
      { icon: 'dock', title: 'Сворачивание кликом по Доку', text: 'Нажмите на программу в Доке, и её окна свернутся. Нажмите ещё раз, и они вернутся.' },
      { icon: 'snap', title: 'Прилипание окон', text: 'Перетащите окно к краю или в угол, и оно займёт половину или четверть экрана. Никаких сочетаний клавиш.' },
      { icon: 'max', title: 'Умная зелёная кнопка', text: 'Разворачивает окно, оставляя видимыми строку меню и Док. С родной анимацией macOS.' },
      { icon: 'scroll', title: 'Плавная прокрутка мыши', text: 'Мягкая прокрутка и отдельное направление для мыши. Трекпад не затрагивается. Мыши Logitech тоже поддерживаются.' },
      { icon: 'quit', title: 'Автозакрытие', text: 'Закрыли последнее окно красной кнопкой, и программа завершается. Можно добавить исключения.' },
      { icon: 'trash', title: 'Чистое удаление программ', text: 'Удаляет программу вместе с кэшами и настройками. Всё уходит в Корзину, так что ничего не пропадёт случайно.' },
      { icon: 'stats', title: 'Мониторинг в строке меню', text: 'Процессор, память, сеть и батарея одним взглядом, а подробности и самые прожорливые программы в один клик.' },
      { icon: 'shot', title: 'Мгновенные скриншоты', text: 'Выделите область, рисуйте стрелки, рамки, текст или размытие прямо на экране и копируйте одной клавишей.' },
    ],
  },
  why: {
    title: 'Зачем одна программа вместо восьми?',
    points: [
      { title: 'Меньше хлама', text: 'Один значок в строке меню вместо целого ряда.' },
      { title: 'Лёгкая и родная', text: 'Написана на Swift. Маленькая, быстрая и только для macOS.' },
      { title: 'Приватная', text: 'Без аккаунтов и слежки. Всё остаётся на вашем Mac.' },
    ],
  },
  install: {
    title: 'Установка за 30 секунд',
    lead: 'Выберите удобный способ.',
    cmdTitle: 'Одна команда (рекомендуем)',
    cmdText: 'Откройте Терминал, вставьте команду и нажмите Return. Tentakit установится в «Программы» и сразу запустится.',
    zipTitle: 'Скачать вручную',
    zipText: 'Распакуйте и перенесите Tentakit в «Программы». При первом запуске откройте Системные настройки → Конфиденциальность и безопасность и нажмите «Всё равно открыть».',
    permsTitle: 'macOS попросит два разрешения',
    perms: ['Универсальный доступ — чтобы управлять окнами, Доком и прокруткой.', 'Запись экрана — только для скриншотов.'],
  },
  faq: {
    title: 'Вопросы',
    items: [
      { q: 'Tentakit бесплатный?', a: 'Да. Tentakit бесплатный. Если понравится, позже можно будет поддержать разработку.' },
      { q: 'Почему macOS показывает предупреждение?', a: 'Tentakit пока не прошёл нотаризацию Apple, поэтому скачанный zip один раз покажет предупреждение. Установка одной командой его обходит. Нотаризация в планах.' },
      { q: 'Какая нужна macOS?', a: 'macOS 13 Ventura или новее. Для скриншотов нужна macOS 14 Sonoma или новее.' },
      { q: 'Программа собирает данные?', a: 'Нет. Tentakit работает полностью офлайн и ничего никуда не отправляет.' },
      { q: 'На каких языках программа?', a: 'На английском, польском и русском. Tentakit сам выбирает язык вашего Mac, а в настройках его можно поменять.' },
    ],
  },
  footer: { made: 'Сделано для любителей Mac.', free: 'Бесплатно для личного использования.' },
};

export const dict: Record<Lang, Dict> = { en, pl, ru };
export const pathFor = (l: Lang) => (l === 'en' ? '/' : `/${l}/`);
