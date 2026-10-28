# Сборка APK для Android

Проект собирается **без Gradle** — из официального шаблона Godot. Нужны только
Godot, шаблоны экспорта, JDK и Android SDK Build-Tools (для подписи).

## Версии, на которых проверена сборка

| Компонент | Версия |
|---|---|
| Godot | **4.4.1-stable** (official, `49a5bc7b6`) |
| Шаблоны экспорта | 4.4.1-stable (`Godot_v4.4.1-stable_export_templates.tpz`) |
| JDK | OpenJDK 21 (подходит и 17) |
| Android SDK | cmdline-tools latest, `build-tools;34.0.0`, `platforms;android-34`, `platform-tools` |
| Результат | minSdk 21, targetSdk 34, ABI `arm64-v8a` + `armeabi-v7a`, портретная ориентация, без разрешений |

Игра рассчитана на Android 10+ (API 29+), но запустится и на более старых
(минимум API 21).

## 1. Установка инструментов (Linux)

```bash
# Godot 4.4.1
wget https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_linux.x86_64.zip
unzip Godot_v4.4.1-stable_linux.x86_64.zip && sudo mv Godot_v4.4.1-stable_linux.x86_64 /usr/local/bin/godot

# Шаблоны экспорта
wget https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_export_templates.tpz
mkdir -p ~/.local/share/godot/export_templates
unzip Godot_v4.4.1-stable_export_templates.tpz -d /tmp/tpl
mv /tmp/tpl/templates ~/.local/share/godot/export_templates/4.4.1.stable

# Android SDK (только build-tools нужны для подписи)
mkdir -p ~/android-sdk/cmdline-tools && cd ~/android-sdk/cmdline-tools
wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip commandlinetools-linux-*.zip && mv cmdline-tools latest
yes | latest/bin/sdkmanager --sdk_root=$HOME/android-sdk "platform-tools" "build-tools;34.0.0" "platforms;android-34"
```

На Windows/macOS: скачайте те же версии с godotengine.org и установите
шаблоны через редактор: *Editor → Manage Export Templates → Install from File*.

## 2. Пути в настройках редактора

Откройте проект в редакторе Godot 4.4.1 один раз (он импортирует ресурсы) и
укажите в *Editor → Editor Settings → Export → Android*:

* **Java SDK Path** — например `/usr/lib/jvm/java-21-openjdk-amd64`;
* **Android SDK Path** — например `~/android-sdk`.

Без редактора можно дописать в `~/.config/godot/editor_settings-4.4.tres`
(секция `[resource]`):

```
export/android/java_sdk_path = "/usr/lib/jvm/java-21-openjdk-amd64"
export/android/android_sdk_path = "/home/USER/android-sdk"
```

## 3. Ключ подписи

Для релизной сборки создайте собственный ключ (храните его в надёжном месте,
в репозиторий не добавляйте — `*.keystore` уже в `.gitignore`):

```bash
keytool -genkeypair -keystore solarfarm-release.keystore -alias solarfarm \
  -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Solar Farm, C=RU"
```

Godot берёт данные ключа из переменных окружения, поэтому пароли не попадают
в `export_presets.cfg`:

```bash
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$PWD/solarfarm-release.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=solarfarm
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=ваш_пароль
```

Для отладочной сборки достаточно debug-ключа, который Godot создаёт сам
(`~/.local/share/godot/keystores/debug.keystore`).

## 4. Сборка

```bash
cd SolarFarm
godot --headless --path . --import                       # первый импорт ресурсов
mkdir -p build
godot --headless --path . --export-release "Android" build/SolarFarm.apk
# или отладочная:
godot --headless --path . --export-debug "Android" build/SolarFarm-debug.apk
```

Пресет `Android` уже настроен в `export_presets.cfg`:
пакет `ru.solarfarm.game`, имя «Солнечная ферма», портрет, иммерсивный режим,
адаптивная иконка, все разрешения выключены (в том числе INTERNET), тесты,
инструменты и документация исключены из пакета.

## 5. Проверка APK

```bash
BT=~/android-sdk/build-tools/34.0.0
$BT/aapt dump badging build/SolarFarm.apk | grep -E "package|sdkVersion|permission|native-code"
$BT/apksigner verify --print-certs build/SolarFarm.apk
```

Ожидаемо: нет ни одной строки `uses-permission`, `native-code: 'arm64-v8a' 'armeabi-v7a'`.

## 6. Установка на устройство

```bash
adb install -r build/SolarFarm.apk
```

или скопируйте APK на телефон и откройте его (разрешите установку из
неизвестных источников). Интернет игре не нужен.

## Размер APK

≈ 62 МБ, из них ≈ 55 МБ — библиотеки движка для двух архитектур. Если
поддержка старых 32-битных устройств не нужна, отключите
`architectures/armeabi-v7a` в `export_presets.cfg` — APK уменьшится примерно
до 30 МБ. Для Google Play вместо APK используйте AAB
(`gradle_build/use_gradle_build=true`, `gradle_build/export_format=1`; потребуется
установленный Android Build Template).
