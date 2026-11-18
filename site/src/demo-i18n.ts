import type { Lang } from './i18n';

export interface DemoDict {
  eyebrow: string;
  title: string;
  lead: string;
  pause: string;
  play: string;
  app: string;
  remove: string;
  trash: string;
  caches: string;
  prefs: string;
  copied: string;
  mouse: string;
}

export const demoDict: Record<Lang, DemoDict> = {
  en: {
    eyebrow: 'Live demo',
    title: 'Watch every tentacle at work',
    lead: 'Eight small helpers, one menu bar icon. Pick one to see it, or just watch them play.',
    pause: 'Pause demo', play: 'Play demo',
    app: 'Notes', remove: 'Remove “Shop”?', trash: 'Move to Trash',
    caches: 'Caches', prefs: 'Preferences', copied: 'Copied to clipboard', mouse: 'Mouse wheel',
  },
  pl: {
    eyebrow: 'Na żywo',
    title: 'Zobacz każdą mackę w akcji',
    lead: 'Osiem małych pomocników, jedna ikona na pasku menu. Wybierz funkcję albo po prostu oglądaj.',
    pause: 'Wstrzymaj demo', play: 'Odtwórz demo',
    app: 'Notatki', remove: 'Usunąć „Shop”?', trash: 'Przenieś do Kosza',
    caches: 'Pamięć podręczna', prefs: 'Ustawienia', copied: 'Skopiowano do schowka', mouse: 'Kółko myszy',
  },
  ru: {
    eyebrow: 'Вживую',
    title: 'Каждое щупальце в деле',
    lead: 'Восемь маленьких помощников и один значок в строке меню. Выберите функцию или просто смотрите.',
    pause: 'Пауза', play: 'Воспроизвести',
    app: 'Заметки', remove: 'Удалить «Shop»?', trash: 'Переместить в Корзину',
    caches: 'Кэши', prefs: 'Настройки', copied: 'Скопировано в буфер', mouse: 'Колесо мыши',
  },
};
