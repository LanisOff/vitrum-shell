# shellcheck shell=bash disable=SC2034,SC2016
# The Russian side of every installer string, sourced by lib/i18n.sh.
#
# The key is the English template exactly as the code passes it to T, L, warn,
# err or die, %s and all; the value is the Russian text with the same number of
# %s in the same order. tests/sh/test_i18n.sh checks both. Commands, paths,
# package names and flags stay as they are. Keys with $ or ' in them are
# single-quoted ('\'' for a quote), so nothing is expanded here.
#
# Grouped by where the string is used; add a new group with a comment rather
# than mixing areas.

# ------------------------------------------------------- passed through -----

# A line that was already worded and translated where it was made (a replayed
# warning, a compiler's output); it goes out unchanged in either language.
I18N_RU['%s']='%s'

# ------------------------------------------------------ install.sh, die -----

I18N_RU['unknown option: %s (try --help)']='неизвестный параметр: %s (см. --help)'
I18N_RU['unknown stage: %s (stages: %s)']='неизвестный этап: %s (этапы: %s)'
I18N_RU['dry run — nothing will be modified']='пробный запуск — ничего не будет изменено'
I18N_RU['nothing done']='ничего не сделано'
I18N_RU['aborted']='прервано'
I18N_RU['Stage that failed:']='Этап с ошибкой:'
I18N_RU['Resume with:']='Продолжить:'
I18N_RU['Full log:']='Полный журнал:'

# ------------------------------------------------- files and commands -----

# lib/common.sh: run, sudo, backups and the install_* helpers.
I18N_RU['command failed: %s']='команда завершилась с ошибкой: %s'
I18N_RU['sudo is required']='нужен sudo'
I18N_RU['could not back up %s']='не удалось сделать резервную копию %s'
I18N_RU['missing source tree: %s']='нет исходного каталога: %s'
I18N_RU['missing source file: %s']='нет исходного файла: %s'
I18N_RU['rsync failed: %s -> %s']='ошибка rsync: %s -> %s'
I18N_RU['copy failed: %s -> %s']='не удалось скопировать: %s -> %s'
I18N_RU['could not install %s']='не удалось установить %s'
I18N_RU['could not write %s']='не удалось записать %s'
I18N_RU['could not copy %s']='не удалось скопировать %s'

# ------------------------------------------------------------- checks -----

# lib/stages/00-preflight.sh and lib/backend/detect.sh.
I18N_RU['vitrum runs on Linux']='vitrum работает только в Linux'
I18N_RU['run as your normal user, not root (sudo is used per command)']='запустите от обычного пользователя, не от root (sudo нужен только отдельным командам)'
I18N_RU['locale %s is not generated (this run borrows %s; perl and other programs keep warning about it) — uncomment it in /etc/locale.gen and run: sudo locale-gen']='локаль %s не сгенерирована (сейчас взята %s; perl и другие программы будут на это жаловаться) — раскомментируйте её в /etc/locale.gen и выполните: sudo locale-gen'
I18N_RU['Gentoo profile %s is not a desktop one — vitrum adds the USE a desktop needs (%s) for every package; a desktop profile does that and more: sudo eselect profile set default/linux/amd64/23.0/desktop']='профиль Gentoo %s не для рабочего стола — vitrum добавляет всем пакетам USE-флаги, нужные рабочему столу (%s); профиль для рабочего стола делает это и многое другое: sudo eselect profile set default/linux/amd64/23.0/desktop'
I18N_RU['only %sMB free in $HOME — the niri build alone wants about 5GB']='в $HOME свободно всего %s МБ — одной сборке niri нужно около 5 ГБ'
I18N_RU["NVIDIA GPU, but nvidia-drm modeset is '%s' — add nvidia-drm.modeset=1 to the kernel command line or the glass has no GBM path"]="видеокарта NVIDIA, но modeset у nvidia-drm равен '%s' — добавьте nvidia-drm.modeset=1 в параметры ядра, иначе эффекту стекла недоступен GBM"
I18N_RU['running inside a VM — the glass shader may be slow or unavailable']='работа в виртуальной машине — шейдер стекла может тормозить или не работать'
I18N_RU['unsupported system: packages=%s init=%s (supported: Gentoo with OpenRC or systemd, Arch with systemd, Fedora with systemd, Void with runit)']='система не поддерживается: packages=%s init=%s (поддерживаются Gentoo с OpenRC или systemd, Arch с systemd, Fedora с systemd и Void с runit)'

# ----------------------------------------------------------- packages -----

# lib/packages.sh, lib/prereqs.sh, lib/stages/10-packages.sh, lib/backend/pkg-*.sh.
I18N_RU["packages.sh: unknown PKG_BACKEND '%s'"]="packages.sh: неизвестный PKG_BACKEND '%s'"
I18N_RU['not available: %s — enable the overlays vitrum uses and sync them: sudo eselect repository enable guru gentoo-zh hyproverlay && for r in guru gentoo-zh hyproverlay; do sudo emaint sync -r $r; done']='недоступно: %s — включите оверлеи, которые использует vitrum, и синхронизируйте их: sudo eselect repository enable guru gentoo-zh hyproverlay && for r in guru gentoo-zh hyproverlay; do sudo emaint sync -r $r; done'
I18N_RU['not available in your repositories: %s — refresh the package databases and check your mirrors']='нет в ваших репозиториях: %s — обновите базы пакетов и проверьте зеркала'
I18N_RU['could not build paru — install paru or yay and re-run']='не удалось собрать paru — установите paru или yay и запустите снова'
I18N_RU['the batch did not finish — installing what is still missing one by one']='установка одним списком не удалась — недостающее ставится по одному'
I18N_RU['not installed: %s — see the emerge output above (a download failure means no network or a dead mirror)']='не установлено: %s — смотрите вывод emerge выше (ошибка загрузки значит, что нет сети или зеркало не отвечает)'
I18N_RU["could not rebuild %s with vitrum's USE flags — see the emerge output above"]='не удалось пересобрать %s с USE-флагами vitrum — смотрите вывод emerge выше'

# -------------------------------------------------------------- fonts -----

# lib/assets.sh: the fonts and other files fetched by checksum.
I18N_RU['unknown asset: %s']='неизвестный ресурс: %s'
I18N_RU['could not download %s from %s']='не удалось скачать %s с %s'
I18N_RU['%s: checksum mismatch (expected %s, got %s) — not installed']='%s: контрольная сумма не совпала (ожидалась %s, получена %s) — не установлено'
I18N_RU['asset %s: unknown kind %s']='ресурс %s: неизвестный тип %s'
I18N_RU['fc-cache failed']='fc-cache завершился с ошибкой'
I18N_RU['fc-cache failed: %s']='fc-cache завершился с ошибкой: %s'

# --------------------------------------------------------------- niri -----

I18N_RU['overlay file missing: %s (Niri-glass %s)']='нет файла оверлея: %s (Niri-glass %s)'
I18N_RU['niri did not build — full log: %s (the installed niri, if any, is untouched)']='niri не собрался — полный журнал: %s (уже установленный niri, если он есть, не тронут)'

# -------------------------------------------------------------- shell -----

I18N_RU['quickshell is not on PATH yet — installing the files anyway']='quickshell пока нет в PATH — файлы всё равно будут установлены'
I18N_RU['%s exists — Quickshell will ignore named configs while it is there; move it aside if you do not rely on it']='есть файл %s — пока он на месте, Quickshell не видит именованные конфигурации; уберите его, если он вам не нужен'
I18N_RU['the QML will not load — fix the above, or run with --skip shell to install the rest']='QML не загрузится — исправьте ошибки выше или запустите с --skip shell, чтобы установить остальное'
I18N_RU['vitrum-theme failed — the shell falls back to its built-in palette']='vitrum-theme завершился с ошибкой — оболочка возьмёт встроенную палитру'

# The shell stage: the Steam theme, through vitrum-steam-theme.
I18N_RU['%s is missing — the Steam theme is not installed']='нет %s — тема для Steam не установлена'
I18N_RU['the Steam theme could not be installed (the reason is above) — Steam keeps its own look; vitrum-steam-theme install tries again']='тему для Steam установить не удалось (причина выше) — у Steam остаётся своё оформление; vitrum-steam-theme install попробует снова'
# The Vesktop theme, through vitrum-vesktop-theme.
I18N_RU['%s is missing — the Vesktop theme is not installed']='нет %s — тема для Vesktop не установлена'
I18N_RU['the Vesktop theme could not be installed (the reason is above) — Vesktop keeps its own look; vitrum-vesktop-theme install tries again']='тему для Vesktop установить не удалось (причина выше) — у Vesktop остаётся своё оформление; vitrum-vesktop-theme install попробует снова'

# ----------------------------------------------------------- terminal -----

I18N_RU['vitrum-theme failed — run it again by hand to see why']='vitrum-theme завершился с ошибкой — запустите его вручную, чтобы увидеть причину'
I18N_RU['fastfetch is missing — ./install.sh --only packages installs it']='нет fastfetch — его установит ./install.sh --only packages'
I18N_RU['fish is missing — ./install.sh --only packages installs it']='нет fish — его установит ./install.sh --only packages'
I18N_RU['tmux is missing — ./install.sh --only packages installs it']='нет tmux — его установит ./install.sh --only packages'
I18N_RU['nvim is missing — ./install.sh --only packages installs it']='нет nvim — его установит ./install.sh --only packages'
I18N_RU['could not change the login shell']='не удалось сменить командную оболочку по умолчанию'
I18N_RU['could not update tpm']='не удалось обновить tpm'
I18N_RU['could not clone tpm (offline?) — tmux works without plugins; re-run --only terminal later']='не удалось клонировать tpm (нет сети?) — tmux работает и без плагинов; позже запустите снова с --only terminal'
I18N_RU['some tmux plugins did not install']='часть плагинов tmux не установилась'
I18N_RU['could not start a temporary tmux; press prefix + I inside tmux to install plugins']='не удалось запустить временный tmux; чтобы установить плагины, нажмите prefix + I внутри tmux'
I18N_RU["nvim --headless '+Lazy! sync' did not finish cleanly; run :Lazy sync in Neovim"]="nvim --headless '+Lazy! sync' завершился с ошибками; выполните :Lazy sync в Neovim"

# --------------------------------------------------------------- boot -----

# lib/stages/70-boot.sh and lib/dm.sh: the login screen and the splash.
I18N_RU['keeping %s as the login screen — pick the "vitrum" session there (or re-run with --replace-dm)']='экраном входа остаётся %s — выберите там сеанс «vitrum» (или запустите снова с --replace-dm)'
I18N_RU['/etc/sddm.conf sets %s under [Theme], which overrides the vitrum theme — remove that line (or set Current=vitrum)']='в /etc/sddm.conf в разделе [Theme] задано %s, и это перекрывает тему vitrum — удалите эту строку (или укажите Current=vitrum)'
I18N_RU['no rsvg-convert or ImageMagick — the splash shows only the spinner']='нет ни rsvg-convert, ни ImageMagick — на заставке будет только индикатор загрузки'
I18N_RU['dracut failed — the splash appears after your next successful initramfs rebuild']='dracut завершился с ошибкой — заставка появится после следующей удачной пересборки initramfs'
I18N_RU['mkinitcpio failed — the splash appears after your next successful rebuild']='mkinitcpio завершился с ошибкой — заставка появится после следующей удачной пересборки'
I18N_RU["add 'plymouth' after 'udev' (or 'systemd') to HOOKS in /etc/mkinitcpio.conf, then: sudo mkinitcpio -P"]="добавьте 'plymouth' после 'udev' (или 'systemd') в HOOKS в /etc/mkinitcpio.conf, затем выполните: sudo mkinitcpio -P"
I18N_RU['the initramfs is not built by dracut or mkinitcpio here — rebuild it with Plymouth in it the way you usually do']='initramfs здесь собирают не dracut и не mkinitcpio — пересоберите его с Plymouth так, как делаете обычно'

# ------------------------------------------------------------ session -----

# lib/stages/80-session.sh and the init backends.
I18N_RU['no KEYBINDS.md at %s']='нет KEYBINDS.md в %s'
I18N_RU['KEYBINDS.md could not be parsed']='не удалось разобрать KEYBINDS.md'
I18N_RU['vitrum-theme could not re-apply your keybinds']='vitrum-theme не смог заново применить ваши сочетания клавиш'
I18N_RU['niri not installed yet — config not validated']='niri ещё не установлен — конфигурация не проверена'
I18N_RU['niri rejected %s']='niri не принял %s'
I18N_RU['could not read %s — keyring not added there']='не удалось прочитать %s — связка ключей туда не добавлена'
I18N_RU['%s: unexpected result — keyring not added there']='%s: неожиданный результат — связка ключей туда не добавлена'
I18N_RU['could not migrate niri-tahoe settings']='не удалось перенести настройки niri-tahoe'
I18N_RU['could not add %s to the %s runlevel']='не удалось добавить %s в уровень запуска %s'
I18N_RU['could not add display-manager to the default runlevel']='не удалось добавить display-manager в уровень запуска default'
I18N_RU['could not add NetworkManager to the default runlevel']='не удалось добавить NetworkManager в уровень запуска default'
I18N_RU['could not enable %s']='не удалось включить %s'
I18N_RU['could not enable the PipeWire user units']='не удалось включить пользовательские юниты PipeWire'

# ------------------------------------------------------------- doctor -----

I18N_RU['%s problem(s), %s warning(s)']='проблем: %s, предупреждений: %s'

# ------------------------------------------------- the choice screen -----

# lib/screens/choose.sh: the rows, their hints and the keys.
I18N_RU['vitrum — what to install']='vitrum — что установить'
I18N_RU['Terminal']='Терминал'
I18N_RU['Shell']='Оболочка'
I18N_RU['fastfetch logo']='Логотип fastfetch'
I18N_RU['picture']='картинка'
I18N_RU['distribution logo']='логотип дистрибутива'
I18N_RU['Desktop']='Рабочий стол'
I18N_RU['Tools']='Инструменты'
I18N_RU["Extras — the author's own setup"]='Дополнительно — личная настройка автора'
I18N_RU['Login screen (SDDM)']='Экран входа (SDDM)'
I18N_RU['Boot splash (Plymouth)']='Заставка при загрузке (Plymouth)'
I18N_RU['Video wallpapers']='Видеообои'
I18N_RU['Phone (KDE Connect)']='Телефон (KDE Connect)'
I18N_RU['tmux, themed, with plugins']='tmux в оформлении vitrum, с плагинами'
I18N_RU['Game mode + HUD (gamemode, MangoHud)']='Игровой режим и HUD (gamemode, MangoHud)'
I18N_RU['Steam theme (Millennium)']='Тема для Steam (Millennium)'
I18N_RU['Vesktop theme (Discord)']='Тема Vesktop (Discord)'
I18N_RU['Mic noise filter, VPN, sensors, mixer, archives']='Шумоподавление микрофона, VPN, датчики, микшер, архивы'
I18N_RU['Command-line tools: eza, bat, fzf, zoxide, delta']='Консольные утилиты: eza, bat, fzf, zoxide, delta'
I18N_RU['File manager: Dolphin']='Файловый менеджер: Dolphin'
I18N_RU['Text from screenshots (OCR)']='Текст со снимков экрана (OCR)'
I18N_RU["Neovim with the author's config"]='Neovim с конфигурацией автора'
I18N_RU["tmux: the author's keys (Ctrl+a, | and - splits)"]='tmux: клавиши автора (Ctrl+a, разделение | и -)'
I18N_RU['Start tmux with every terminal']='Запускать tmux в каждом терминале'
I18N_RU['needs %s']='нужен %s'
I18N_RU['Needs %s ticked.']='Сначала отметьте «%s».'
I18N_RU['%s cannot show images']='%s не умеет показывать картинки'
I18N_RU['The terminal vitrum sets up and colours from your wallpaper.']='Терминал, который vitrum настраивает и раскрашивает под ваши обои.'
I18N_RU['The shell in that terminal, with the Starship prompt.']='Оболочка в этом терминале, с приглашением Starship.'
I18N_RU["What fastfetch shows beside the system facts: the vitrum picture or your distribution's logo."]='Что fastfetch показывает рядом со сведениями о системе: картинку vitrum или логотип дистрибутива.'
I18N_RU['The login screen in the same style as the lock screen; other sessions stay listed.']='Экран входа в том же стиле, что и экран блокировки; другие сеансы остаются в списке.'
I18N_RU['A boot splash. The initramfs is regenerated with dracut or mkinitcpio, whichever builds it here.']='Заставка при загрузке. initramfs пересобирается тем, чем он собирается здесь: dracut или mkinitcpio.'
I18N_RU['Live wallpapers through mpvpaper. Static ones work either way.']='Живые обои через mpvpaper. Обычные работают в любом случае.'
I18N_RU['Notifications from the phone, its battery, a shared clipboard and files. Pulls in part of KDE Frameworks.']='Уведомления с телефона, его заряд, общий буфер обмена и файлы. Тянет за собой часть KDE Frameworks.'
I18N_RU["tmux with a vitrum status bar and its plugins. Without the author's keys it keeps its own (Ctrl+b)."]='tmux со строкой состояния vitrum и плагинами. Без клавиш автора у него остаются свои (Ctrl+b).'
I18N_RU['Game mode with its HUD: gamemode and MangoHud.']='Игровой режим и его HUD: gamemode и MangoHud.'
I18N_RU["Steam theme: vitrum's look for Steam via Millennium, follows your colours."]='Тема для Steam: оформление vitrum в Steam через Millennium, следует за вашими цветами.'
I18N_RU["Vesktop theme: vitrum's glass for Discord (Vesktop), follows your colours."]='Тема Vesktop: стекло vitrum для Discord (Vesktop), следует вашим цветам.'
I18N_RU['The microphone noise filter, WireGuard and OpenVPN, hardware sensors, a sound mixer (pavucontrol), cava and Ark for archives.']='Шумоподавление микрофона, WireGuard и OpenVPN, датчики оборудования, микшер (pavucontrol), cava и Ark для архивов.'
I18N_RU['Better ls, cat, find and cd: eza, bat, fzf and zoxide, with delta for git diffs.']='Замена ls, cat, find и cd: eza, bat, fzf и zoxide, а для git diff — delta.'
I18N_RU['Dolphin, themed like the rest of the desktop.']='Dolphin в том же оформлении, что и весь рабочий стол.'
I18N_RU['Copy the text out of a screenshot, with tesseract. English always, Russian too on a Russian system.']='Текст со снимка экрана копируется через tesseract. Английский всегда, русский — если система на русском.'
I18N_RU["Neovim with the author's plugins and keymaps, and a colourscheme from the vitrum palette."]='Neovim с плагинами и сочетаниями клавиш автора и цветовой схемой из палитры vitrum.'
I18N_RU['Ctrl+a prefix, | and - split, H J K L resize, vi copy-mode. Unticked, tmux keeps its own keys (Ctrl+b).']='Префикс Ctrl+a, разделение | и -, H J K L меняют размер, копирование в стиле vi. Без отметки у tmux свои клавиши (Ctrl+b).'
I18N_RU['Opening a terminal drops you straight into a tmux session instead of a bare shell.']='Новый терминал сразу открывает сеанс tmux, а не просто оболочку.'
I18N_RU['move']='строки'
I18N_RU['choose']='вариант'
I18N_RU['space']='пробел'
I18N_RU['tick']='отметить'
I18N_RU['whole group']='вся группа'
I18N_RU['next']='далее'
I18N_RU['back']='назад'

# ---------------------------------------------- the confirmation screen -----

# lib/screens/confirm.sh: the summary, the questions the stages used to ask,
# the buttons.
I18N_RU['vitrum — ready to install']='vitrum — всё готово к установке'
I18N_RU['will install:']='установится:'
I18N_RU['not:']='без:'
I18N_RU['no longer managed: %s']='vitrum больше не управляет: %s'
I18N_RU['niri with liquid glass and the vitrum shell']='niri с жидким стеклом и оболочка vitrum'
I18N_RU['about %s min']='около %s мин'
I18N_RU['needs sudo']='нужен sudo'
I18N_RU['unknown']='неизвестно'
I18N_RU['Make fish my login shell (now %s)']='Сделать fish командной оболочкой по умолчанию (сейчас %s)'
I18N_RU['Replace %s with SDDM']='Заменить %s на SDDM'
I18N_RU['Only %sMB free, niri wants about 5GB: install anyway']='Свободно %s МБ, а niri нужно около 5 ГБ: всё равно установить'
I18N_RU['Logins and new terminals start fish. Unticked, %s stays the login shell and kitty still opens fish.']='Вход в систему и новые терминалы запускают fish. Без отметки по умолчанию остаётся %s, а kitty всё равно открывает fish.'
I18N_RU['SDDM with the vitrum theme becomes the login screen; uninstall.sh puts %s back. Unticked, pick the vitrum session in %s.']='Экраном входа станет SDDM с темой vitrum; uninstall.sh вернёт %s. Без отметки выберите сеанс vitrum в %s.'
I18N_RU['Building niri takes about 5GB in your home folder; with less it can fail halfway.']='Сборке niri нужно около 5 ГБ в домашней папке; если места меньше, она может прерваться на полпути.'
I18N_RU['The password for sudo is asked once, after Install.']='Пароль для sudo спросят один раз, после «Установить».'
I18N_RU['Tick the disk space row to install anyway, or free some space first.']='Отметьте строку про место на диске, чтобы всё равно установить, или сначала освободите место.'
I18N_RU['Install']='Установить'
I18N_RU['Change']='Изменить'
I18N_RU['Cancel']='Отмена'
I18N_RU['button']='кнопка'
I18N_RU['row']='строка'
I18N_RU['select']='выбрать'
I18N_RU['change']='изменить'
I18N_RU['Login screen']='Экран входа'
I18N_RU['Boot splash']='Заставка при загрузке'
I18N_RU['Phone']='Телефон'
I18N_RU['Game mode']='Игровой режим'
I18N_RU['Steam theme']='Тема для Steam'
I18N_RU['Vesktop theme']='Тема Vesktop'
I18N_RU['Mic filter, VPN, sensors']='Шумоподавление, VPN, датчики'
I18N_RU["the author's tmux keys"]='клавиши tmux от автора'
I18N_RU['tmux autostart']='автозапуск tmux'

# ------------------------------------------------------ the progress view -----

# lib/progress.sh: the stages' names, their states, the bar and the failure prompt.
I18N_RU['Checks']='Проверки'
I18N_RU['Packages']='Пакеты'
I18N_RU['Fonts']='Шрифты'
I18N_RU['niri']='niri'
I18N_RU['Apps']='Приложения'
I18N_RU['Theming']='Оформление'
I18N_RU['Boot']='Загрузка'
I18N_RU['Session']='Сеанс'
I18N_RU['Doctor']='Проверка установки'
I18N_RU['failed']='ошибка'
I18N_RU['skipped']='пропущен'
I18N_RU['skipped: needs %s']='пропущен: нужен этап %s'
I18N_RU['%s/%s · about %s min left']='%s/%s · осталось около %s мин'
I18N_RU['%s/%s · done']='%s/%s · готово'
I18N_RU['installing']='установка'
I18N_RU['updating']='обновление'
I18N_RU['Retry']='Повторить'
I18N_RU['Skip this stage']='Пропустить этап'
I18N_RU['Show log']='Показать журнал'
I18N_RU['Quit']='Выйти'
I18N_RU['Interrupted.']='Прервано.'
I18N_RU['Continue later: %s']='Продолжить позже: %s'
I18N_RU['Log: %s']='Журнал: %s'
I18N_RU['a command in this stage waited for input on the terminal (a sudo password?) and was stopped']='команда этого этапа ждала ввода в терминале (пароль sudo?) и была остановлена'
I18N_RU['A command asked for a password on the terminal. Do not type it here; run the installer again: sudo is asked first.']='Команда запросила пароль в терминале. Не вводите его здесь; запустите установщик снова: sudo спрашивается в самом начале.'
I18N_RU['Stopping safely: %s is given up to %s seconds to finish what it is doing.']='Безопасная остановка: этапу «%s» даётся до %s секунд, чтобы закончить начатое.'

# lib/components.sh: a components.json that cannot be read is not overwritten.
I18N_RU['could not read %s — it is left as it is, and this run uses the defaults']='не удалось прочитать %s — файл оставлен как есть, а этот запуск берёт значения по умолчанию'

# ------------------------------------------------------- the final screen -----

# lib/screens/finish.sh, and install.sh around the screens.
I18N_RU['vitrum %s is installed']='vitrum %s установлен'
I18N_RU['vitrum %s is updated']='vitrum %s обновлён'
I18N_RU['took %s']='заняло %s'
I18N_RU['Installed:']='Установлено:'
I18N_RU['Not installed:']='Не установлено:'
I18N_RU['%s (skipped)']='%s (этап пропущен)'
I18N_RU['%s (not in this run)']='%s (не в этом запуске)'
I18N_RU['Skipped: %s']='Пропущено: %s'
I18N_RU['not run without it: %s']='без него не запускались: %s'
I18N_RU['To run it later: %s']='Запустить позже: %s'
I18N_RU['What did not go cleanly']='Что прошло не гладко'
I18N_RU['First steps']='Первые шаги'
I18N_RU['Log out, then pick vitrum on the login screen.']='Выйдите из системы и выберите vitrum на экране входа.'
I18N_RU['every shortcut']='все сочетания клавиш'
I18N_RU['search apps and files']='поиск приложений и файлов'
I18N_RU['edit desktop widgets']='виджеты рабочего стола'
I18N_RU['when the bar says there is something new']='когда панель сообщит о новой версии'
I18N_RU['Nothing done.']='Ничего не сделано.'
I18N_RU['The update is not installed yet; to install it later: %s']='Обновление ещё не установлено; установить его позже: %s'
I18N_RU['Your choices are kept as they were; the update goes on.']='Ваш выбор оставлен как был; обновление продолжается.'

# ------------------------------------------------------ Fedora and Void -----

# lib/backend/pkg-dnf.sh, pkg-xbps.sh, init-runit.sh, and what they bring to
# lib/packages.sh, lib/assets.sh and the boot stage.
I18N_RU['%s is not Fedora: vitrum is tested on Fedora %s and newer, and its COPR repositories may have nothing for it']='%s — не Fedora: vitrum проверен на Fedora %s и новее, а в его репозиториях COPR для этой системы может ничего не оказаться'
I18N_RU['Fedora %s is too old for vitrum: it needs Fedora %s or newer (the COPR repositories it uses build for no older release, and the shell wants Qt 6.11)']='Fedora %s слишком старая для vitrum: нужна Fedora %s или новее (репозитории COPR, которые он использует, не собирают пакеты для более старых выпусков, а оболочке нужен Qt 6.11)'
I18N_RU['Void on musl (%s) is not supported: vitrum needs the glibc flavour (the NVIDIA driver and several of its packages are glibc-only)']='Void на musl (%s) не поддерживается: vitrum нужен вариант с glibc (драйвер NVIDIA и часть его пакетов есть только для glibc)'
I18N_RU['not installed: %s — see the xbps-install output above (it stopped with status %s)']='не установлено: %s — смотрите вывод xbps-install выше (он завершился с кодом %s)'
I18N_RU['not available in your repositories: %s — refresh them (sudo dnf makecache) and check that the COPR and RPM Fusion repositories vitrum enabled are reachable']='нет в ваших репозиториях: %s — обновите их (sudo dnf makecache) и проверьте, что репозитории COPR и RPM Fusion, включённые vitrum, доступны'
I18N_RU['not available in your repositories: %s — sync them (sudo xbps-install -S) and check your mirror']='нет в ваших репозиториях: %s — синхронизируйте их (sudo xbps-install -S) и проверьте зеркало'
I18N_RU['runit did not start %s — see: sudo sv status %s']='runit не запустил %s — смотрите: sudo sv status %s'
I18N_RU['no runit service %s — the login screen is not enabled']='нет службы runit %s — экран входа не включён'
I18N_RU['could not unpack %s into %s']='не удалось распаковать %s в %s'
I18N_RU["grubby could not add 'quiet splash' to the boot entries"]="grubby не смог добавить 'quiet splash' в пункты загрузки"
I18N_RU['grub-mkconfig failed — run it yourself: sudo grub-mkconfig -o %s']='grub-mkconfig завершился с ошибкой — запустите его сами: sudo grub-mkconfig -o %s'
I18N_RU['could not turn off %s — run: sudo systemctl disable --now %s']='не удалось выключить %s — выполните: sudo systemctl disable --now %s'
I18N_RU['Wi-Fi: from the next boot NetworkManager runs it, and the networks wpa_supplicant knew are not carried over — join them again in the network panel or with nmtui']='Wi-Fi: со следующей загрузки им управляет NetworkManager, а сети, известные wpa_supplicant, не переносятся — подключитесь к ним заново в панели сети или через nmtui'
I18N_RU['Wi-Fi: wpa_supplicant keeps its own service — without its D-Bus service file (%s) NetworkManager would be left with no Wi-Fi backend']='Wi-Fi: служба wpa_supplicant остаётся — без её файла службы D-Bus (%s) у NetworkManager не осталось бы бэкенда Wi-Fi'
I18N_RU['COPR %s: could not ask dnf what its packages need — its package list stays as it is (%s)']='COPR %s: не удалось узнать у dnf, что нужно его пакетам — список пакетов из него остаётся как есть (%s)'
I18N_RU['could not create %s, where /etc/rc.local points — nothing is changed at the next boot']='не удалось создать %s, куда указывает /etc/rc.local — при следующей загрузке ничего не изменится'
