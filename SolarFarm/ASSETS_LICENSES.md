# Ассеты и лицензии

Все ресурсы, включённые в игру, разрешены для коммерческого использования.
Ниже — что используется, откуда взято и под какой лицензией.

## 1. Графика — оригинальная, создана для проекта

Вся игровая графика (плитки Match-3, усилители, сорняки, четыре помощника,
постройки фермы на всех уровнях улучшения, животные, растения, иконки
интерфейса, монета, звёзды, фоны, текстуры травы и дорожек, частицы, иконка
приложения) нарисована специально для «Солнечной фермы» в виде векторных
SVG-описаний и растрирована в PNG с прозрачным фоном.

* Исходники: `tools/art/gen_art.py`, `tools/art/farm_art.py` (SVG-генератор),
  `tools/art/render.js` (растеризация через Chromium с поддержкой мягких теней
  и градиентов).
* Разрешение: плитки 256×256, помощники 512×512, постройки 440–660 px,
  фоны 1080×1920 — рисуются сразу в нужном размере, без растягивания мелких
  спрайтов.
* Лицензия: принадлежит проекту; может свободно использоваться в нём, в том
  числе коммерчески.

Почему не взяты готовые наборы графики. Были изучены:

| Набор | Лицензия | Решение |
|---|---|---|
| Kenney — Isometric Miniature Farm (opengameart.org/content/isometric-miniature-farm) | CC0 | Не используется: мелкие (≈100 px) приглушённые коричневые изометрические спрайты не подходят под яркий HD-стиль с видом сверху. |
| Kenney — UI Pack (opengameart.org/content/ui-pack) | CC0 | Не используется: плоские синие кнопки выбиваются из стиля; интерфейс нарисован средствами Godot (StyleBoxFlat) в общей палитре. |
| Kenney — Starter Kit Match-3 (github.com/KenneyNL/Starter-Kit-Match-3) | MIT (код), CC0 (спрайты) | Спрайты не используются (другие фигуры, не фрукты); используются три звука — см. ниже. |
| kenney.nl/assets | CC0 | Прямое скачивание с сайта требует прохождения браузерной страницы загрузки; те же наборы взяты с зеркал OpenGameArt. |

Ни скриншоты чужих игр, ни изображения из поисковой выдачи, ни эмодзи в игре
не используются. Персонажи, интерфейс, уровни и названия не копируют
Royal Match.

## 2. Шрифт

| Файл | Источник | Лицензия |
|---|---|---|
| `assets/fonts/Nunito-ExtraBold.ttf`, `Nunito-Black.ttf` | Google Fonts, Nunito (The Nunito Project Authors) | SIL Open Font License 1.1 — текст в `assets/fonts/OFL.txt` |

Шрифт поддерживает кириллицу и знак ₽.

## 3. Звуковые эффекты

| Файл в игре | Источник | Автор | Лицензия |
|---|---|---|---|
| `audio/sfx/swap.ogg`, `match.ogg`, `land.ogg` | Starter Kit Match-3 (`sounds/tile-swap.ogg`, `tile-match.ogg`, `tile-land.ogg`), github.com/KenneyNL/Starter-Kit-Match-3 | Kenney | MIT — текст в `docs/licenses/Kenney_Starter_Kit_Match3_MIT.txt` |
| `audio/sfx/click.ogg` (click_002), `back.ogg` (back_002), `invalid.ogg` (error_004), `purchase.ogg` (confirmation_002), `special_create.ogg` (maximize_006), `select.ogg` (select_003), `build_knock.ogg` (drop_002), `star.ogg` (glass_002), `lose.ogg` (minimize_008), `weed.ogg` (pluck_001) | Kenney — Interface Sounds, opengameart.org/content/interface-sounds | Kenney (kenney.nl) | CC0 1.0 |
| `audio/sfx/win.ogg` | «Win sound effect», opengameart.org/content/win-sound-effect | Listener | CC0 1.0 |
| `audio/sfx/rocket.ogg`, `boom.ogg`, `rainbow.ogg`, `coin.ogg`, `build.ogg`, `combo.ogg`, `helper_rooster.ogg`, `helper_squirrel.ogg`, `helper_hedgehog.ogg`, `helper_bee.ogg` | Синтезированы для проекта (ffmpeg, генераторы шума и тона) | проект | принадлежат проекту |

## 4. Музыка

| Файл в игре | Источник | Автор | Лицензия |
|---|---|---|---|
| `audio/music/farm_theme.ogg` | «Apple Cider», opengameart.org/content/apple-cider | Zane Little Music | CC0 1.0 |
| `audio/music/puzzle_theme.ogg` | «Fields of Cabbage», opengameart.org/content/fields-of-cabbage | ARoachIFoundOnMyPillow | CC0 1.0 |
| `audio/music/menu_theme.ogg` | «Happy Adventure (Loop)», opengameart.org/content/happy-adventure-loop | TinyWorlds | CC0 1.0 |

Музыка перекодирована в Ogg Vorbis (качество 2) для уменьшения размера APK.

## 5. Движок

Godot Engine 4.4.1-stable — MIT License (godotengine.org/license). Шаблоны
экспорта Android — официальные, той же версии.

Лицензии всех наборов проверены 28.10.2026 на страницах источников. Атрибуция
для CC0 не обязательна, но приведена выше и в разделе «Об игре» в настройках.
