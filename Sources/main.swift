import Cocoa
import ApplicationServices
import ServiceManagement
import CoreGraphics
import Carbon.HIToolbox
import UniformTypeIdentifiers

// MARK: - Localization (v1.3)
//
// Six languages. Each row of "strings" lists the text in this fixed order:
//   [ja, en, zh-Hans, ko, it, es]
// Placeholders are positional (%1$@, %2$@) so word order can differ per language.
// A missing language falls back to English, then to the key itself.

enum Lang: String, CaseIterable {
    case ja, en
    case zhHans = "zh-Hans"
    case ko, it, es

    var index: Int {
        switch self {
        case .ja: return 0
        case .en: return 1
        case .zhHans: return 2
        case .ko: return 3
        case .it: return 4
        case .es: return 5
        }
    }

    var nativeName: String {
        switch self {
        case .ja: return "日本語"
        case .en: return "English"
        case .zhHans: return "简体中文"
        case .ko: return "한국어"
        case .it: return "Italiano"
        case .es: return "Español"
        }
    }
}

enum L10n {
    /// The language chosen in the menu, or nil to follow the system.
    static var override: Lang? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "appLanguage") else { return nil }
            return Lang(rawValue: raw)
        }
        set {
            if let v = newValue {
                UserDefaults.standard.set(v.rawValue, forKey: "appLanguage")
            } else {
                UserDefaults.standard.removeObject(forKey: "appLanguage")
            }
        }
    }

    static func systemLang() -> Lang {
        for p in Locale.preferredLanguages {
            let l = p.lowercased()
            if l.hasPrefix("ja") { return .ja }
            if l.hasPrefix("zh") { return .zhHans }
            if l.hasPrefix("ko") { return .ko }
            if l.hasPrefix("it") { return .it }
            if l.hasPrefix("es") { return .es }
            if l.hasPrefix("en") { return .en }
        }
        return .en
    }

    static var current: Lang { override ?? systemLang() }
}

/// Look up a localized string. Arguments are always Strings (use "\(n)" for numbers).
func tr(_ key: String, _ args: String...) -> String {
    guard let row = strings[key] else { return key }
    let idx = L10n.current.index
    var text = idx < row.count ? row[idx] : row[1]
    if text.isEmpty { text = row[1] }
    if args.isEmpty { return text }
    return String(format: text, arguments: args.map { $0 as CVarArg })
}

private let strings: [String: [String]] = [
    // --- Common ---
    "ok": ["OK", "OK", "好", "확인", "OK", "Aceptar"],
    "cancel": ["キャンセル", "Cancel", "取消", "취소", "Annulla", "Cancelar"],
    "close": ["閉じる", "Close", "关闭", "닫기", "Chiudi", "Cerrar"],
    "save": ["保存", "Save", "保存", "저장", "Salva", "Guardar"],
    "rename": ["変更", "Rename", "重命名", "변경", "Rinomina", "Renombrar"],
    "delete": ["削除", "Delete", "删除", "삭제", "Elimina", "Eliminar"],
    "overwriteBtn": ["上書き", "Overwrite", "覆盖", "덮어쓰기", "Sovrascrivi", "Sobrescribir"],
    "open": ["開く", "Open", "打开", "열기", "Apri", "Abrir"],
    "later": ["後で", "Later", "稍后", "나중에", "Più tardi", "Más tarde"],
    "start": ["はじめる", "Get Started", "开始使用", "시작하기", "Inizia", "Empezar"],
    "next": ["次へ", "Next", "下一步", "다음", "Avanti", "Siguiente"],
    "back": ["戻る", "Back", "上一步", "이전", "Indietro", "Atrás"],
    "done": ["完了", "Done", "完成", "완료", "Fine", "Listo"],
    "openSettings": ["システム設定を開く", "Open System Settings", "打开系统设置", "시스템 설정 열기", "Apri Impostazioni di Sistema", "Abrir Ajustes del Sistema"],
    "copyReport": ["診断結果をコピー", "Copy Report", "复制诊断结果", "진단 결과 복사", "Copia report", "Copiar informe"],
    "yes": ["はい", "Yes", "是", "예", "Sì", "Sí"],
    "no": ["いいえ", "No", "否", "아니요", "No", "No"],

    // --- Menu ---
    "menu.header": ["Window Memory — ウィンドウメモリ", "Window Memory", "Window Memory — 窗口记忆", "Window Memory — 윈도우 메모리", "Window Memory", "Window Memory"],
    "menu.needAccess": ["⚠︎ アクセシビリティ権限が必要です", "⚠︎ Accessibility permission required", "⚠︎ 需要辅助功能权限", "⚠︎ 손쉬운 사용 권한이 필요합니다", "⚠︎ Serve l'autorizzazione Accessibilità", "⚠︎ Se necesita el permiso de Accesibilidad"],
    "menu.grant": ["システム設定で許可する…", "Allow in System Settings…", "在系统设置中允许…", "시스템 설정에서 허용…", "Consenti in Impostazioni di Sistema…", "Permitir en Ajustes del Sistema…"],
    "menu.save": ["現在の配置を保存…", "Save Current Layout…", "保存当前布局…", "현재 배치 저장…", "Salva disposizione attuale…", "Guardar disposición actual…"],
    "menu.restore": ["配置を復元", "Restore Layout", "恢复布局", "배치 복원", "Ripristina disposizione", "Restaurar disposición"],
    "menu.restoreNone": ["このディスプレイ構成の配置はありません", "No layouts for this display setup", "当前显示器组合没有已保存的布局", "이 디스플레이 구성의 배치가 없습니다", "Nessuna disposizione per questa configurazione", "No hay disposiciones para esta configuración de pantallas"],
    "menu.undo": ["直前の復元を元に戻す", "Undo Last Restore", "撤销上次恢复", "마지막 복원 되돌리기", "Annulla ultimo ripristino", "Deshacer última restauración"],
    "menu.manage": ["配置を管理", "Manage Layouts", "管理布局", "배치 관리", "Gestisci disposizioni", "Gestionar disposiciones"],
    "menu.manageNone": ["保存された配置はありません", "No saved layouts", "没有已保存的布局", "저장된 배치가 없습니다", "Nessuna disposizione salvata", "No hay disposiciones guardadas"],
    "menu.windowsCount": ["%1$@（%2$@ウィンドウ）", "%1$@ (%2$@ windows)", "%1$@（%2$@ 个窗口）", "%1$@ (창 %2$@개)", "%1$@ (%2$@ finestre)", "%1$@ (%2$@ ventanas)"],
    "menu.rename": ["名前を変更…", "Rename…", "重命名…", "이름 변경…", "Rinomina…", "Renombrar…"],
    "menu.overwrite": ["現在のウィンドウで上書き", "Overwrite with Current Windows", "用当前窗口覆盖", "현재 창으로 덮어쓰기", "Sovrascrivi con le finestre attuali", "Sobrescribir con las ventanas actuales"],
    "menu.setDefault": ["自動復元・ショートカットの既定にする", "Use for Auto-Restore & Shortcuts", "设为自动恢复和快捷键的默认布局", "자동 복원·단축키의 기본 배치로 설정", "Usa per ripristino automatico e scorciatoie", "Usar para restauración automática y atajos"],
    "menu.clearDefault": ["既定を解除", "Clear Default", "取消默认", "기본값 해제", "Rimuovi predefinita", "Quitar predeterminada"],
    "menu.delete": ["「%1$@」を削除", "Delete “%1$@”", "删除“%1$@”", "“%1$@” 삭제", "Elimina “%1$@”", "Eliminar “%1$@”"],
    "menu.autoRestore": ["ディスプレイ変更時に自動復元", "Auto-Restore on Display Change", "显示器变化时自动恢复", "디스플레이 변경 시 자동 복원", "Ripristino automatico al cambio schermi", "Restaurar automáticamente al cambiar pantallas"],
    "menu.settings": ["設定", "Settings", "设置", "설정", "Impostazioni", "Ajustes"],
    "menu.autoSave": ["配置を自動バックアップ（10分ごと）", "Auto-Backup Layout (every 10 min)", "自动备份布局（每 10 分钟）", "배치 자동 백업(10분마다)", "Backup automatico (ogni 10 min)", "Copia automática (cada 10 min)"],
    "menu.login": ["ログイン時に起動", "Launch at Login", "登录时启动", "로그인 시 실행", "Apri al login", "Abrir al iniciar sesión"],
    "menu.keepTitles": ["ウィンドウタイトルを保存する", "Save Window Titles", "保存窗口标题", "창 제목 저장", "Salva i titoli delle finestre", "Guardar títulos de ventana"],
    "menu.shortcuts": ["グローバルショートカット", "Global Shortcuts", "全局快捷键", "전역 단축키", "Scorciatoie globali", "Atajos globales"],
    "menu.shortcutSettings": ["ショートカットを設定…", "Shortcut Settings…", "设置快捷键…", "단축키 설정…", "Impostazioni scorciatoie…", "Configurar atajos…"],
    "menu.exclusions": ["復元から除外するアプリ", "Excluded Apps", "排除的应用", "제외할 앱", "App escluse", "Apps excluidas"],
    "menu.exclusionsHint": ["チェックしたアプリは保存・復元の対象外", "Checked apps are skipped when saving and restoring", "勾选的应用在保存和恢复时将被跳过", "선택한 앱은 저장·복원에서 제외됩니다", "Le app selezionate vengono ignorate", "Las apps marcadas se omiten al guardar y restaurar"],
    "menu.export": ["配置を書き出す…", "Export Layouts…", "导出布局…", "배치 내보내기…", "Esporta disposizioni…", "Exportar disposiciones…"],
    "menu.import": ["配置を読み込む…", "Import Layouts…", "导入布局…", "배치 가져오기…", "Importa disposizioni…", "Importar disposiciones…"],
    "menu.language": ["言語 / Language", "Language", "语言 / Language", "언어 / Language", "Lingua / Language", "Idioma / Language"],
    "menu.langAuto": ["システムの言語に合わせる", "Match System Language", "跟随系统语言", "시스템 언어 따르기", "Segui la lingua di sistema", "Usar el idioma del sistema"],
    "menu.guide": ["使い方ガイド…", "Getting Started Guide…", "使用指南…", "시작 가이드…", "Guida introduttiva…", "Guía de inicio…"],
    "menu.diagnose": ["アクセシビリティを診断…", "Diagnose Accessibility…", "诊断辅助功能…", "손쉬운 사용 진단…", "Diagnostica Accessibilità…", "Diagnosticar Accesibilidad…"],
    "menu.update": ["アップデートを確認…", "Check for Updates…", "检查更新…", "업데이트 확인…", "Verifica aggiornamenti…", "Buscar actualizaciones…"],
    "menu.about": ["Window Memory について", "About Window Memory", "关于 Window Memory", "Window Memory 정보", "Informazioni su Window Memory", "Acerca de Window Memory"],
    "menu.quit": ["終了", "Quit", "退出", "종료", "Esci", "Salir"],

    // --- Names ---
    "display.desc": ["ディスプレイ%1$@台（%2$@）", "%1$@ display(s) (%2$@)", "%1$@ 台显示器（%2$@）", "디스플레이 %1$@대(%2$@)", "%1$@ schermi (%2$@)", "%1$@ pantalla(s) (%2$@)"],
    "name.default": ["配置 %1$@", "Layout %1$@", "布局 %1$@", "배치 %1$@", "Disposizione %1$@", "Disposición %1$@"],
    "name.auto": ["自動バックアップ", "Auto Backup", "自动备份", "자동 백업", "Backup automatico", "Copia automática"],
    "name.quick": ["クイック保存", "Quick Save", "快速保存", "빠른 저장", "Salvataggio rapido", "Guardado rápido"],

    // --- Accessibility required ---
    "ax.required.title": ["アクセシビリティ権限が必要です", "Accessibility permission required", "需要辅助功能权限", "손쉬운 사용 권한이 필요합니다", "Serve l'autorizzazione Accessibilità", "Se necesita el permiso de Accesibilidad"],
    "ax.required.body": ["ウィンドウを操作するには許可が必要です。\n\nシステム設定 →「プライバシーとセキュリティ」→「アクセシビリティ」で\nWindow Memory をオンにしてください。\n\n● すでにオンなのに動作しない場合\nリストで Window Memory を選んで「−」で削除し、「＋」から\n/Applications/Window Memory.app をもう一度追加してオンにしてください。\n（アプリを更新すると、以前の許可が無効になることがあります）", "Permission is required to control windows.\n\nOpen System Settings → Privacy & Security → Accessibility and turn on Window Memory.\n\n● If it is already on but nothing works\nSelect Window Memory in the list, remove it with “−”, then add /Applications/Window Memory.app again with “+” and turn it on.\n(Updating the app can invalidate a previous permission.)", "控制窗口需要获得许可。\n\n请打开 系统设置 →“隐私与安全性”→“辅助功能”，开启 Window Memory。\n\n● 如果已开启但仍无法使用\n在列表中选中 Window Memory，用“−”删除，再用“＋”重新添加 /Applications/Window Memory.app 并开启。\n（更新应用后，之前的授权可能会失效。）", "창을 제어하려면 권한이 필요합니다.\n\n시스템 설정 → '개인정보 보호 및 보안' → '손쉬운 사용'에서 Window Memory를 켜 주세요.\n\n● 이미 켜져 있는데도 동작하지 않는 경우\n목록에서 Window Memory를 선택해 '−'로 삭제한 뒤, '＋'로 /Applications/Window Memory.app을 다시 추가하고 켜 주세요.\n(앱을 업데이트하면 이전 권한이 무효가 될 수 있습니다.)", "Per controllare le finestre serve un'autorizzazione.\n\nApri Impostazioni di Sistema → Privacy e sicurezza → Accessibilità e attiva Window Memory.\n\n● Se è già attivo ma non funziona\nSeleziona Window Memory nell'elenco, rimuovilo con “−”, poi aggiungi di nuovo /Applications/Window Memory.app con “+” e attivalo.\n(Aggiornando l'app, l'autorizzazione precedente può diventare non valida.)", "Se necesita un permiso para controlar las ventanas.\n\nAbre Ajustes del Sistema → Privacidad y seguridad → Accesibilidad y activa Window Memory.\n\n● Si ya está activado pero no funciona\nSelecciona Window Memory en la lista, quítalo con “−”, vuelve a añadir /Applications/Window Memory.app con “+” y actívalo.\n(Al actualizar la app, el permiso anterior puede dejar de ser válido.)"],

    // --- Guide (first launch / menu) ---
    "guide.title": ["Window Memory へようこそ", "Welcome to Window Memory", "欢迎使用 Window Memory", "Window Memory에 오신 것을 환영합니다", "Benvenuto in Window Memory", "Te damos la bienvenida a Window Memory"],
    "guide.step": ["ステップ %1$@ / %2$@", "Step %1$@ of %2$@", "第 %1$@ 步，共 %2$@ 步", "%1$@ / %2$@ 단계", "Passo %1$@ di %2$@", "Paso %1$@ de %2$@"],
    "guide.s1.title": ["ウィンドウ配置を記憶します", "Remember your window layout", "记住窗口布局", "창 배치를 기억합니다", "Ricorda la disposizione delle finestre", "Recuerda la disposición de tus ventanas"],
    "guide.s1.body": ["外部モニターの抜き差しで崩れたウィンドウの位置とサイズを、1クリックで元通りに戻すメニューバーアプリです。\n\n配置データはお使いの Mac の中にだけ保存され、外部には送信されません。", "Window Memory lives in your menu bar and puts your windows back where they were after you plug or unplug an external display — in one click.\n\nLayouts are stored only on your Mac and are never sent anywhere.", "Window Memory 常驻菜单栏，在您插拔外接显示器后，一键让窗口回到原来的位置和大小。\n\n布局数据仅保存在您的 Mac 上，不会发送到任何地方。", "Window Memory는 메뉴 막대에 상주하며, 외부 모니터를 연결하거나 분리해 흐트러진 창의 위치와 크기를 한 번의 클릭으로 되돌려 줍니다.\n\n배치 데이터는 사용 중인 Mac에만 저장되며 외부로 전송되지 않습니다.", "Window Memory vive nella barra dei menu e, dopo aver collegato o scollegato un monitor esterno, rimette le finestre al loro posto con un clic.\n\nLe disposizioni restano solo sul tuo Mac e non vengono inviate da nessuna parte.", "Window Memory vive en la barra de menús y, tras conectar o desconectar una pantalla externa, devuelve tus ventanas a su sitio con un clic.\n\nLas disposiciones se guardan solo en tu Mac y no se envían a ningún sitio."],
    "guide.s2.title": ["ウィンドウ操作を許可します", "Allow window control", "允许控制窗口", "창 제어를 허용합니다", "Consenti il controllo delle finestre", "Permite el control de ventanas"],
    "guide.s2.body": ["システム設定 →「プライバシーとセキュリティ」→「アクセシビリティ」で Window Memory を【オン】にしてください。下のボタンから開けます。\n\nオンにすると、下の状態が自動で ✅ に変わります。", "Open System Settings → Privacy & Security → Accessibility and turn Window Memory ON. The button below takes you there.\n\nThe status below turns to ✅ automatically once it is on.", "请打开 系统设置 →“隐私与安全性”→“辅助功能”，将 Window Memory 【开启】。可点击下方按钮直接前往。\n\n开启后，下方状态会自动变为 ✅。", "시스템 설정 → '개인정보 보호 및 보안' → '손쉬운 사용'에서 Window Memory를 【켜】 주세요. 아래 버튼으로 바로 열 수 있습니다.\n\n켜면 아래 상태가 자동으로 ✅로 바뀝니다.", "Apri Impostazioni di Sistema → Privacy e sicurezza → Accessibilità e attiva Window Memory. Il pulsante qui sotto ti ci porta.\n\nQuando è attivo, lo stato qui sotto diventa ✅ automaticamente.", "Abre Ajustes del Sistema → Privacidad y seguridad → Accesibilidad y activa Window Memory. El botón de abajo te lleva allí.\n\nCuando esté activado, el estado de abajo cambiará a ✅ automáticamente."],
    "guide.s2.ok": ["✅ 許可されています", "✅ Permission granted", "✅ 已获得许可", "✅ 허용되었습니다", "✅ Autorizzazione concessa", "✅ Permiso concedido"],
    "guide.s2.ng": ["❌ まだ許可されていません（確認中…）", "❌ Not allowed yet (checking…)", "❌ 尚未许可（检查中…）", "❌ 아직 허용되지 않았습니다(확인 중…)", "❌ Non ancora autorizzato (controllo in corso…)", "❌ Aún sin permiso (comprobando…)"],
    "guide.s2.stale": ["すでにオンなのに動作しないときは、リストで Window Memory を「−」で削除し、「＋」から /Applications/Window Memory.app を追加し直してください。", "If it is already on but nothing works, remove Window Memory with “−” in the list and add /Applications/Window Memory.app again with “+”.", "如果已开启但仍无法使用，请在列表中用“−”删除 Window Memory，再用“＋”重新添加 /Applications/Window Memory.app。", "이미 켜져 있는데도 동작하지 않으면 목록에서 Window Memory를 '−'로 삭제하고 '＋'로 /Applications/Window Memory.app을 다시 추가하세요.", "Se è già attivo ma non funziona, rimuovi Window Memory con “−” nell'elenco e aggiungi di nuovo /Applications/Window Memory.app con “+”.", "Si ya está activado pero no funciona, quita Window Memory con “−” de la lista y vuelve a añadir /Applications/Window Memory.app con “+”."],
    "guide.s3.title": ["使い方", "How to use it", "使用方法", "사용 방법", "Come si usa", "Cómo se usa"],
    "guide.s3.body": ["1. ウィンドウを好きな配置に並べます\n2. メニューバーの ⊞ アイコン →「現在の配置を保存…」\n3. モニターの抜き差しで崩れたら →「配置を復元」\n\n便利な設定（メニューの「設定」）：\n・ディスプレイ変更時の自動復元\n・グローバルショートカット\n・復元しないアプリの除外\n・10分ごとの自動バックアップ\n\nうまく動かないときは「アクセシビリティを診断…」で原因を確認できます。", "1. Arrange your windows the way you like\n2. Menu bar ⊞ icon → “Save Current Layout…”\n3. When a display change scrambles them → “Restore Layout”\n\nHandy options (Settings in the menu):\n• Auto-restore on display change\n• Global shortcuts\n• Excluding apps from restore\n• Auto-backup every 10 minutes\n\nIf something doesn't work, “Diagnose Accessibility…” shows what's wrong.", "1. 按喜欢的方式排列窗口\n2. 菜单栏 ⊞ 图标 →“保存当前布局…”\n3. 显示器变化导致窗口错乱时 →“恢复布局”\n\n实用设置（菜单中的“设置”）：\n• 显示器变化时自动恢复\n• 全局快捷键\n• 将应用排除在恢复之外\n• 每 10 分钟自动备份\n\n如果无法正常工作，可通过“诊断辅助功能…”查看原因。", "1. 창을 원하는 대로 배치합니다\n2. 메뉴 막대의 ⊞ 아이콘 → '현재 배치 저장…'\n3. 디스플레이 변경으로 배치가 흐트러지면 → '배치 복원'\n\n편리한 설정(메뉴의 '설정'):\n• 디스플레이 변경 시 자동 복원\n• 전역 단축키\n• 복원에서 제외할 앱\n• 10분마다 자동 백업\n\n잘 동작하지 않으면 '손쉬운 사용 진단…'으로 원인을 확인할 수 있습니다.", "1. Disponi le finestre come preferisci\n2. Icona ⊞ nella barra dei menu → “Salva disposizione attuale…”\n3. Quando un cambio di schermi le scompone → “Ripristina disposizione”\n\nOpzioni utili (Impostazioni nel menu):\n• Ripristino automatico al cambio schermi\n• Scorciatoie globali\n• Esclusione di app dal ripristino\n• Backup automatico ogni 10 minuti\n\nSe qualcosa non funziona, “Diagnostica Accessibilità…” mostra la causa.", "1. Coloca tus ventanas como prefieras\n2. Icono ⊞ de la barra de menús → “Guardar disposición actual…”\n3. Cuando un cambio de pantallas las desordene → “Restaurar disposición”\n\nOpciones útiles (Ajustes en el menú):\n• Restauración automática al cambiar pantallas\n• Atajos globales\n• Excluir apps de la restauración\n• Copia automática cada 10 minutos\n\nSi algo no funciona, “Diagnosticar Accesibilidad…” muestra la causa."],

    // --- Save ---
    "save.title": ["配置を保存", "Save Layout", "保存布局", "배치 저장", "Salva disposizione", "Guardar disposición"],
    "save.body": ["%1$@ で %2$@ 個のウィンドウを取得しました。\nこの配置に名前を付けてください:", "Captured %2$@ windows on %1$@.\nName this layout:", "在 %1$@ 下获取了 %2$@ 个窗口。\n请为此布局命名：", "%1$@에서 창 %2$@개를 가져왔습니다.\n이 배치의 이름을 입력하세요:", "Rilevate %2$@ finestre con %1$@.\nDai un nome a questa disposizione:", "Se capturaron %2$@ ventanas con %1$@.\nPon un nombre a esta disposición:"],
    "save.exists.title": ["「%1$@」は既に存在します", "“%1$@” already exists", "“%1$@”已存在", "“%1$@” 이름이 이미 있습니다", "“%1$@” esiste già", "“%1$@” ya existe"],
    "save.exists.body": ["上書きしますか？別名で保存したい場合はキャンセルして、もう一度名前を入力してください。", "Overwrite it? To keep both, cancel and enter a different name.", "要覆盖吗？如需另存，请取消后重新输入名称。", "덮어쓰시겠습니까? 따로 저장하려면 취소하고 다른 이름을 입력하세요.", "Vuoi sovrascriverla? Per tenerle entrambe, annulla e inserisci un altro nome.", "¿Sobrescribirla? Para conservar ambas, cancela e introduce otro nombre."],
    "save.overwritten.title": ["配置を上書きしました", "Layout overwritten", "已覆盖布局", "배치를 덮어썼습니다", "Disposizione sovrascritta", "Disposición sobrescrita"],
    "save.saved.title": ["配置を保存しました", "Layout saved", "已保存布局", "배치를 저장했습니다", "Disposizione salvata", "Disposición guardada"],
    "save.result.body": ["「%1$@」— %2$@ 個のウィンドウ", "“%1$@” — %2$@ windows", "“%1$@”— %2$@ 个窗口", "“%1$@” — 창 %2$@개", "“%1$@” — %2$@ finestre", "“%1$@” — %2$@ ventanas"],
    "save.nothing.title": ["保存できるものがありません", "Nothing to save", "没有可保存的内容", "저장할 항목이 없습니다", "Niente da salvare", "Nada que guardar"],
    "save.nothing.body": ["他のアプリのウィンドウが開かれていません。ウィンドウを開いてからお試しください。", "No windows from other apps are open. Open some windows and try again.", "没有打开其他应用的窗口。请先打开窗口再试。", "다른 앱의 창이 열려 있지 않습니다. 창을 연 다음 다시 시도하세요.", "Non ci sono finestre di altre app aperte. Aprine qualcuna e riprova.", "No hay ventanas de otras apps abiertas. Abre alguna e inténtalo de nuevo."],
    "save.fail.title": ["ウィンドウを取得できませんでした", "Couldn't read any windows", "无法获取窗口", "창을 가져오지 못했습니다", "Impossibile leggere le finestre", "No se pudieron leer las ventanas"],
    "save.fail.body": ["アクセシビリティの許可が有効になっていない可能性があります。\n設定上は「オン」でも、アプリを更新・再インストールすると\n以前の許可が無効になることがあります。\n\n次の手順で解決できます：\n\n1. システム設定 →「プライバシーとセキュリティ」\n   →「アクセシビリティ」を開く\n2. リストの「Window Memory」を選び、「−」ボタンで削除\n3. 「＋」ボタンを押し、\n   /Applications/Window Memory.app を追加\n4. 追加された「Window Memory」を【オン】にする\n5. このアプリを終了して、もう一度起動する\n\n※ 上記でも解決しない場合は、ターミナルで次を実行してください：\n  tccutil reset Accessibility %1$@", "Accessibility permission may not be effective. Even if it shows as on, updating or reinstalling the app can invalidate the earlier permission.\n\nTo fix it:\n\n1. Open System Settings → Privacy & Security → Accessibility\n2. Select Window Memory in the list and remove it with “−”\n3. Click “+” and add /Applications/Window Memory.app\n4. Turn Window Memory ON\n5. Quit this app and launch it again\n\nIf that still doesn't help, run this in Terminal:\n  tccutil reset Accessibility %1$@", "辅助功能权限可能未生效。即使显示为开启，更新或重新安装应用后，之前的授权也可能失效。\n\n解决步骤：\n\n1. 打开 系统设置 →“隐私与安全性”→“辅助功能”\n2. 在列表中选中 Window Memory，用“−”删除\n3. 点击“＋”，添加 /Applications/Window Memory.app\n4. 将 Window Memory 【开启】\n5. 退出本应用并重新启动\n\n如果仍无法解决，请在终端中运行：\n  tccutil reset Accessibility %1$@", "손쉬운 사용 권한이 유효하지 않을 수 있습니다. 설정에서 '켜짐'으로 보여도 앱을 업데이트하거나 다시 설치하면 이전 권한이 무효가 될 수 있습니다.\n\n해결 방법:\n\n1. 시스템 설정 → '개인정보 보호 및 보안' → '손쉬운 사용' 열기\n2. 목록에서 Window Memory를 선택하고 '−'로 삭제\n3. '＋'를 눌러 /Applications/Window Memory.app 추가\n4. Window Memory를 【켜기】\n5. 이 앱을 종료한 뒤 다시 실행\n\n그래도 해결되지 않으면 터미널에서 다음을 실행하세요:\n  tccutil reset Accessibility %1$@", "L'autorizzazione Accessibilità potrebbe non essere valida. Anche se risulta attiva, aggiornare o reinstallare l'app può invalidare l'autorizzazione precedente.\n\nPer risolvere:\n\n1. Apri Impostazioni di Sistema → Privacy e sicurezza → Accessibilità\n2. Seleziona Window Memory nell'elenco e rimuovilo con “−”\n3. Premi “+” e aggiungi /Applications/Window Memory.app\n4. Attiva Window Memory\n5. Chiudi l'app e riavviala\n\nSe non basta, esegui nel Terminale:\n  tccutil reset Accessibility %1$@", "Es posible que el permiso de Accesibilidad no sea válido. Aunque aparezca activado, actualizar o reinstalar la app puede invalidar el permiso anterior.\n\nPara solucionarlo:\n\n1. Abre Ajustes del Sistema → Privacidad y seguridad → Accesibilidad\n2. Selecciona Window Memory en la lista y quítalo con “−”\n3. Pulsa “+” y añade /Applications/Window Memory.app\n4. Activa Window Memory\n5. Cierra la app y vuelve a abrirla\n\nSi no basta, ejecuta en Terminal:\n  tccutil reset Accessibility %1$@"],

    // --- Restore / undo ---
    "restore.fail.title": ["復元できませんでした", "Couldn't restore", "无法恢复", "복원하지 못했습니다", "Impossibile ripristinare", "No se pudo restaurar"],
    "restore.fail.body": ["保存時のアプリが起動していないか、アクセシビリティの許可が\n無効になっている可能性があります。\n\nメニューの「アクセシビリティを診断…」で状態を確認できます。", "The apps from the saved layout may not be running, or Accessibility permission may be invalid.\n\nUse “Diagnose Accessibility…” in the menu to check.", "保存布局时的应用可能未运行，或辅助功能权限已失效。\n\n可通过菜单中的“诊断辅助功能…”检查状态。", "저장 당시의 앱이 실행 중이 아니거나 손쉬운 사용 권한이 무효일 수 있습니다.\n\n메뉴의 '손쉬운 사용 진단…'으로 상태를 확인할 수 있습니다.", "Le app della disposizione salvata potrebbero non essere in esecuzione, oppure l'autorizzazione Accessibilità non è valida.\n\nUsa “Diagnostica Accessibilità…” nel menu per verificare.", "Puede que las apps de la disposición guardada no estén abiertas o que el permiso de Accesibilidad no sea válido.\n\nUsa “Diagnosticar Accesibilidad…” en el menú para comprobarlo."],
    "restore.ok.title": ["「%1$@」を復元しました", "Restored “%1$@”", "已恢复“%1$@”", "“%1$@”을(를) 복원했습니다", "Ripristinata “%1$@”", "Restaurada “%1$@”"],
    "restore.ok.body": ["%1$@/%2$@ 個のウィンドウを配置しました。", "Placed %1$@ of %2$@ windows.", "已放置 %1$@/%2$@ 个窗口。", "창 %2$@개 중 %1$@개를 배치했습니다.", "Posizionate %1$@ finestre su %2$@.", "Se colocaron %1$@ de %2$@ ventanas."],
    "restore.skip.notrunning": ["未起動のアプリ: %1$@", "Apps not running: %1$@", "未运行的应用：%1$@", "실행 중이 아닌 앱: %1$@", "App non in esecuzione: %1$@", "Apps no abiertas: %1$@"],
    "restore.skip.excluded": ["除外設定により %1$@ 個をスキップ", "%1$@ skipped (excluded apps)", "因排除设置跳过 %1$@ 个", "제외 설정으로 %1$@개 건너뜀", "%1$@ saltate (app escluse)", "%1$@ omitidas (apps excluidas)"],
    "restore.skip.missing": ["見つからないウィンドウ: %1$@ 個（別のスペースにある可能性があります）", "Windows not found: %1$@ (they may be on another Space)", "未找到的窗口：%1$@ 个（可能在其他桌面空间）", "찾지 못한 창: %1$@개(다른 스페이스에 있을 수 있음)", "Finestre non trovate: %1$@ (potrebbero essere su un altro Space)", "Ventanas no encontradas: %1$@ (pueden estar en otro Space)"],
    "restore.none": ["復元できる保存済みの配置がありません。", "There is no saved layout to restore.", "没有可恢复的已保存布局。", "복원할 저장된 배치가 없습니다.", "Non c'è nessuna disposizione salvata da ripristinare.", "No hay ninguna disposición guardada para restaurar."],
    "undo.done": ["直前の復元を元に戻しました", "Last restore undone", "已撤销上次恢复", "마지막 복원을 되돌렸습니다", "Ultimo ripristino annullato", "Se deshizo la última restauración"],
    "undo.none": ["元に戻せる復元がありません", "Nothing to undo", "没有可撤销的恢复", "되돌릴 복원이 없습니다", "Niente da annullare", "No hay nada que deshacer"],
    "hud.autoRestored": ["ディスプレイ構成の変更を検知して自動復元しました", "Display change detected — layout restored automatically", "检测到显示器变化，已自动恢复布局", "디스플레이 변경을 감지해 자동으로 복원했습니다", "Cambio schermi rilevato: disposizione ripristinata automaticamente", "Cambio de pantallas detectado: disposición restaurada automáticamente"],

    // --- Manage ---
    "rename.title": ["名前を変更", "Rename", "重命名", "이름 변경", "Rinomina", "Renombrar"],
    "rename.body": ["「%1$@」の新しい名前を入力してください:", "Enter a new name for “%1$@”:", "请输入“%1$@”的新名称：", "“%1$@”의 새 이름을 입력하세요:", "Inserisci il nuovo nome per “%1$@”:", "Introduce un nuevo nombre para “%1$@”:"],
    "rename.fail.title": ["名前を変更できませんでした", "Couldn't rename", "无法重命名", "이름을 변경할 수 없습니다", "Impossibile rinominare", "No se pudo renombrar"],
    "rename.fail.body": ["「%1$@」は既に使われています。別の名前を指定してください。", "“%1$@” is already in use. Please choose another name.", "“%1$@”已被使用，请换一个名称。", "“%1$@” 이름은 이미 사용 중입니다. 다른 이름을 지정하세요.", "“%1$@” è già in uso. Scegli un altro nome.", "“%1$@” ya está en uso. Elige otro nombre."],
    "overwrite.done.title": ["配置を更新しました", "Layout updated", "已更新布局", "배치를 업데이트했습니다", "Disposizione aggiornata", "Disposición actualizada"],
    "overwrite.done.body": ["「%1$@」は %2$@ 個のウィンドウになりました。", "“%1$@” now has %2$@ windows.", "“%1$@”现在包含 %2$@ 个窗口。", "“%1$@”은(는) 이제 창 %2$@개입니다.", "“%1$@” ora contiene %2$@ finestre.", "“%1$@” ahora tiene %2$@ ventanas."],
    "delete.title": ["「%1$@」を削除しますか？", "Delete “%1$@”?", "要删除“%1$@”吗？", "“%1$@”을(를) 삭제할까요?", "Eliminare “%1$@”?", "¿Eliminar “%1$@”?"],
    "delete.body": ["この配置は完全に削除されます。", "This layout will be permanently deleted.", "此布局将被永久删除。", "이 배치는 영구적으로 삭제됩니다.", "Questa disposizione verrà eliminata definitivamente.", "Esta disposición se eliminará de forma permanente."],
    "login.error": ["自動起動の設定エラー", "Couldn't change launch-at-login", "登录时启动设置出错", "자동 실행 설정 오류", "Errore nell'impostazione di apertura al login", "Error al configurar el inicio automático"],

    // --- Update ---
    "update.fail.title": ["アップデートを確認できませんでした", "Couldn't check for updates", "无法检查更新", "업데이트를 확인할 수 없습니다", "Impossibile verificare gli aggiornamenti", "No se pudo buscar actualizaciones"],
    "update.fail.body": ["ネットワーク接続を確認して、もう一度お試しください。", "Check your network connection and try again.", "请检查网络连接后重试。", "네트워크 연결을 확인하고 다시 시도하세요.", "Controlla la connessione di rete e riprova.", "Comprueba tu conexión de red e inténtalo de nuevo."],
    "update.latest.title": ["最新バージョンです", "You're up to date", "已是最新版本", "최신 버전입니다", "Sei aggiornato", "Estás al día"],
    "update.latest.body": ["Window Memory %1$@ は最新です。", "Window Memory %1$@ is the latest version.", "Window Memory %1$@ 已是最新版本。", "Window Memory %1$@은(는) 최신 버전입니다.", "Window Memory %1$@ è l'ultima versione.", "Window Memory %1$@ es la última versión."],
    "update.new.title": ["新しいバージョンがあります", "A new version is available", "有新版本可用", "새 버전이 있습니다", "È disponibile una nuova versione", "Hay una nueva versión disponible"],
    "update.new.body": ["Window Memory %1$@ が公開されています。ダウンロードページを開きますか？", "Window Memory %1$@ is available. Open the download page?", "Window Memory %1$@ 已发布。要打开下载页面吗？", "Window Memory %1$@이(가) 공개되었습니다. 다운로드 페이지를 열까요?", "Window Memory %1$@ è disponibile. Aprire la pagina di download?", "Window Memory %1$@ está disponible. ¿Abrir la página de descarga?"],

    // --- Shortcuts ---
    "sc.title": ["ショートカットの設定", "Shortcut Settings", "快捷键设置", "단축키 설정", "Impostazioni scorciatoie", "Configuración de atajos"],
    "sc.body": ["修飾キーと、保存・復元・元に戻すに使う文字キーを選びます。他のアプリと重なる場合は変更してください。", "Choose the modifier keys and the letter keys for save, restore and undo. Change them if they clash with another app.", "选择修饰键，以及用于保存、恢复和撤销的字母键。若与其他应用冲突，请更改。", "수정자 키와 저장·복원·되돌리기에 사용할 문자 키를 선택하세요. 다른 앱과 겹치면 변경하세요.", "Scegli i tasti modificatori e le lettere per salvare, ripristinare e annullare. Cambiali se entrano in conflitto con un'altra app.", "Elige las teclas modificadoras y las letras para guardar, restaurar y deshacer. Cámbialas si chocan con otra app."],
    "sc.modifiers": ["修飾キー", "Modifiers", "修饰键", "수정자 키", "Modificatori", "Modificadores"],
    "sc.restore": ["復元", "Restore", "恢复", "복원", "Ripristina", "Restaurar"],
    "sc.undo": ["元に戻す", "Undo", "撤销", "되돌리기", "Annulla", "Deshacer"],
    "sc.failed": ["登録できなかったショートカットがあります（他のアプリが使用中の可能性）: %1$@", "Some shortcuts couldn't be registered (another app may use them): %1$@", "部分快捷键无法注册（可能已被其他应用占用）：%1$@", "등록하지 못한 단축키가 있습니다(다른 앱이 사용 중일 수 있음): %1$@", "Alcune scorciatoie non sono state registrate (forse usate da un'altra app): %1$@", "Algunos atajos no se pudieron registrar (puede que los use otra app): %1$@"],

    // --- Export / import ---
    "export.title": ["配置を書き出す", "Export Layouts", "导出布局", "배치 내보내기", "Esporta disposizioni", "Exportar disposiciones"],
    "export.done": ["%1$@ 件の配置を書き出しました。", "Exported %1$@ layouts.", "已导出 %1$@ 个布局。", "배치 %1$@개를 내보냈습니다.", "Esportate %1$@ disposizioni.", "Se exportaron %1$@ disposiciones."],
    "export.empty": ["書き出せる配置がありません。", "There are no layouts to export.", "没有可导出的布局。", "내보낼 배치가 없습니다.", "Non ci sono disposizioni da esportare.", "No hay disposiciones para exportar."],
    "export.fail": ["書き出しに失敗しました: %1$@", "Export failed: %1$@", "导出失败：%1$@", "내보내기 실패: %1$@", "Esportazione non riuscita: %1$@", "Error al exportar: %1$@"],
    "import.title": ["配置を読み込む", "Import Layouts", "导入布局", "배치 가져오기", "Importa disposizioni", "Importar disposiciones"],
    "import.done": ["%1$@ 件を追加、%2$@ 件を更新しました。", "Added %1$@, updated %2$@.", "新增 %1$@ 个，更新 %2$@ 个。", "%1$@개 추가, %2$@개 업데이트했습니다.", "Aggiunte %1$@, aggiornate %2$@.", "Añadidas %1$@, actualizadas %2$@."],
    "import.fail": ["読み込みに失敗しました。Window Memory が書き出したファイルを選んでください。", "Import failed. Please choose a file exported by Window Memory.", "导入失败。请选择由 Window Memory 导出的文件。", "가져오기에 실패했습니다. Window Memory에서 내보낸 파일을 선택하세요.", "Importazione non riuscita. Scegli un file esportato da Window Memory.", "Error al importar. Elige un archivo exportado por Window Memory."],

    // --- Diagnostics ---
    "diag.title": ["アクセシビリティ診断", "Accessibility Diagnostics", "辅助功能诊断", "손쉬운 사용 진단", "Diagnostica Accessibilità", "Diagnóstico de Accesibilidad"],
    "diag.api": ["許可の状態（API）: %1$@", "Permission (API): %1$@", "权限状态（API）：%1$@", "권한 상태(API): %1$@", "Autorizzazione (API): %1$@", "Permiso (API): %1$@"],
    "diag.on": ["有効", "Granted", "已授权", "허용됨", "Concessa", "Concedido"],
    "diag.off": ["無効", "Not granted", "未授权", "허용 안 됨", "Non concessa", "No concedido"],
    "diag.capture": ["実際のウィンドウ取得: %1$@ 個（画面上の他アプリのウィンドウ: %2$@ 個）", "Windows actually read: %1$@ (other apps' windows on screen: %2$@)", "实际获取的窗口：%1$@ 个（屏幕上其他应用的窗口：%2$@ 个）", "실제로 가져온 창: %1$@개(화면의 다른 앱 창: %2$@개)", "Finestre effettivamente lette: %1$@ (finestre di altre app a schermo: %2$@)", "Ventanas leídas realmente: %1$@ (ventanas de otras apps en pantalla: %2$@)"],
    "diag.version": ["バージョン: %1$@（%2$@）", "Version: %1$@ (%2$@)", "版本：%1$@（%2$@）", "버전: %1$@(%2$@)", "Versione: %1$@ (%2$@)", "Versión: %1$@ (%2$@)"],
    "diag.location": ["アプリの場所: %1$@", "App location: %1$@", "应用位置：%1$@", "앱 위치: %1$@", "Posizione app: %1$@", "Ubicación de la app: %1$@"],
    "diag.location.warn": ["⚠️ /Applications に置かれていません。/Applications に移動してから起動してください。", "⚠️ The app isn't in /Applications. Move it there and launch it again.", "⚠️ 应用不在 /Applications 中。请移动到 /Applications 后再启动。", "⚠️ 앱이 /Applications에 없습니다. /Applications로 옮긴 뒤 실행하세요.", "⚠️ L'app non è in /Applications. Spostala lì e riavviala.", "⚠️ La app no está en /Applications. Muévela allí y ábrela de nuevo."],
    "diag.login": ["ログイン時に起動: %1$@", "Launch at login: %1$@", "登录时启动：%1$@", "로그인 시 실행: %1$@", "Apri al login: %1$@", "Abrir al iniciar sesión: %1$@"],
    "diag.shortcuts": ["グローバルショートカット: %1$@", "Global shortcuts: %1$@", "全局快捷键：%1$@", "전역 단축키: %1$@", "Scorciatoie globali: %1$@", "Atajos globales: %1$@"],
    "diag.store": ["保存先: %1$@（%2$@ 件）", "Storage: %1$@ (%2$@ layouts)", "保存位置：%1$@（%2$@ 个布局）", "저장 위치: %1$@(배치 %2$@개)", "Archivio: %1$@ (%2$@ disposizioni)", "Almacenamiento: %1$@ (%2$@ disposiciones)"],
    "diag.spaces": ["※ 他のスペース（デスクトップ）や最小化・フルスクリーンのウィンドウは、macOS の制約により対象外です。", "Note: windows on other Spaces, minimized windows and full-screen windows are not handled, due to macOS limitations.", "注：由于 macOS 的限制，其他桌面空间、已最小化和全屏的窗口不在处理范围内。", "참고: macOS 제약으로 다른 스페이스, 최소화된 창, 전체 화면 창은 대상에서 제외됩니다.", "Nota: per limiti di macOS, le finestre su altri Space, minimizzate o a schermo intero non vengono gestite.", "Nota: por limitaciones de macOS, no se gestionan las ventanas de otros Spaces, minimizadas o a pantalla completa."],
    "diag.v.ok": ["✅ 正常に動作します。\n「現在の配置を保存…」で配置を保存できます。", "✅ Everything works.\nYou can save a layout with “Save Current Layout…”.", "✅ 运行正常。\n可通过“保存当前布局…”保存布局。", "✅ 정상 동작합니다.\n'현재 배치 저장…'으로 배치를 저장할 수 있습니다.", "✅ Tutto funziona.\nPuoi salvare una disposizione con “Salva disposizione attuale…”.", "✅ Todo funciona.\nPuedes guardar una disposición con “Guardar disposición actual…”."],
    "diag.v.empty": ["ℹ️ 現在、他のアプリのウィンドウが開かれていません。\nウィンドウを開いてから保存をお試しください（許可自体は正常です）。", "ℹ️ No windows from other apps are open right now.\nOpen some windows and try saving (the permission itself is fine).", "ℹ️ 目前没有打开其他应用的窗口。\n请先打开窗口再试着保存（权限本身正常）。", "ℹ️ 현재 다른 앱의 창이 열려 있지 않습니다.\n창을 연 다음 저장해 보세요(권한 자체는 정상입니다).", "ℹ️ Al momento non ci sono finestre di altre app aperte.\nApri qualche finestra e riprova a salvare (l'autorizzazione è a posto).", "ℹ️ Ahora no hay ventanas de otras apps abiertas.\nAbre algunas e intenta guardar (el permiso en sí está bien)."],
    "diag.v.stale": ["⚠️ 許可は「オン」ですが、実際にはウィンドウを取得できていません。\nアプリを更新・再インストールしたため、以前の許可が無効になった状態です。\n\n解決手順：\n1. システム設定 →「プライバシーとセキュリティ」→「アクセシビリティ」\n2. 「Window Memory」を「−」で削除\n3. 「＋」で /Applications/Window Memory.app を追加\n4. 【オン】にしてから、このアプリを再起動", "⚠️ Permission shows as ON, but no windows can actually be read.\nThe app was updated or reinstalled, so the earlier permission is no longer valid.\n\nTo fix it:\n1. System Settings → Privacy & Security → Accessibility\n2. Remove Window Memory with “−”\n3. Add /Applications/Window Memory.app with “+”\n4. Turn it ON, then restart this app", "⚠️ 权限显示为“开启”，但实际上无法获取窗口。\n应用经过更新或重新安装，之前的授权已失效。\n\n解决步骤：\n1. 系统设置 →“隐私与安全性”→“辅助功能”\n2. 用“−”删除 Window Memory\n3. 用“＋”添加 /Applications/Window Memory.app\n4. 【开启】后重新启动本应用", "⚠️ 권한은 '켜짐'이지만 실제로는 창을 가져오지 못하고 있습니다.\n앱을 업데이트하거나 다시 설치해 이전 권한이 무효가 된 상태입니다.\n\n해결 방법:\n1. 시스템 설정 → '개인정보 보호 및 보안' → '손쉬운 사용'\n2. Window Memory를 '−'로 삭제\n3. '＋'로 /Applications/Window Memory.app 추가\n4. 【켜기】 후 이 앱을 다시 실행", "⚠️ L'autorizzazione risulta attiva, ma in realtà non è possibile leggere le finestre.\nL'app è stata aggiornata o reinstallata, quindi l'autorizzazione precedente non è più valida.\n\nPer risolvere:\n1. Impostazioni di Sistema → Privacy e sicurezza → Accessibilità\n2. Rimuovi Window Memory con “−”\n3. Aggiungi /Applications/Window Memory.app con “+”\n4. Attivalo, poi riavvia l'app", "⚠️ El permiso aparece activado, pero en realidad no se pueden leer las ventanas.\nLa app se actualizó o reinstaló, así que el permiso anterior ya no es válido.\n\nPara solucionarlo:\n1. Ajustes del Sistema → Privacidad y seguridad → Accesibilidad\n2. Quita Window Memory con “−”\n3. Añade /Applications/Window Memory.app con “+”\n4. Actívalo y reinicia la app"],
    "diag.v.off": ["❌ 許可が有効になっていません。\nシステム設定 →「プライバシーとセキュリティ」→「アクセシビリティ」で Window Memory をオンにしてください。", "❌ Permission is not granted.\nTurn on Window Memory in System Settings → Privacy & Security → Accessibility.", "❌ 尚未获得许可。\n请在 系统设置 →“隐私与安全性”→“辅助功能”中开启 Window Memory。", "❌ 권한이 허용되지 않았습니다.\n시스템 설정 → '개인정보 보호 및 보안' → '손쉬운 사용'에서 Window Memory를 켜 주세요.", "❌ Autorizzazione non concessa.\nAttiva Window Memory in Impostazioni di Sistema → Privacy e sicurezza → Accessibilità.", "❌ Permiso no concedido.\nActiva Window Memory en Ajustes del Sistema → Privacidad y seguridad → Accesibilidad."],

    // --- About ---
    "about.title": ["Window Memory（ウィンドウメモリ）  バージョン %1$@", "Window Memory  Version %1$@", "Window Memory  版本 %1$@", "Window Memory  버전 %1$@", "Window Memory  Versione %1$@", "Window Memory  Versión %1$@"],
    "about.body": ["外部モニターの抜き差しで崩れたウィンドウ配置を、1クリックで元通りに復元するメニューバー常駐アプリです。\n\n■ 主な機能\n・配置の保存 … 起動中のアプリのウィンドウ位置・サイズを記録\n・1クリック復元 … メニューから選ぶだけ（⌘1〜⌘9）\n・ディスプレイごとの配置 … モニター構成ごとに自動で分類\n・自動復元 … モニターの抜き差しを検知して配置を戻す\n・グローバルショートカット … どのアプリからでも保存・復元・元に戻す\n・自動バックアップ … 10分ごとに現在の配置を控える\n・除外アプリ、書き出し／読み込み、元に戻す\n・日本語・English・简体中文・한국어・Italiano・Español\n\n■ しくみ\nmacOS のアクセシビリティ API でウィンドウの位置・サイズを読み書きします。配置データは Mac の中にだけ保存され、外部には送信されません。\n\n────────────────────────\n開発: LYNOX LLC\n© 2026 LYNOX LLC. All rights reserved.", "A menu bar app that puts your windows back where they were after you plug or unplug an external display — in one click.\n\n■ Features\n• Save layouts — records window positions and sizes of running apps\n• One-click restore — pick from the menu (⌘1–⌘9)\n• Per-display layouts — grouped automatically by monitor setup\n• Auto-restore — detects display changes and restores the layout\n• Global shortcuts — save, restore and undo from any app\n• Auto-backup — keeps the current layout every 10 minutes\n• Excluded apps, export/import, undo\n• 日本語 · English · 简体中文 · 한국어 · Italiano · Español\n\n■ How it works\nWindow Memory reads and sets window positions and sizes through the macOS Accessibility API. Layouts are stored only on your Mac and never sent anywhere.\n\n────────────────────────\nDeveloped by LYNOX LLC\n© 2026 LYNOX LLC. All rights reserved.", "常驻菜单栏的应用，在您插拔外接显示器后，一键让窗口回到原来的位置。\n\n■ 主要功能\n• 保存布局 … 记录运行中应用的窗口位置和大小\n• 一键恢复 … 从菜单中选择即可（⌘1–⌘9）\n• 按显示器分组 … 按显示器组合自动分类\n• 自动恢复 … 检测到显示器变化后自动恢复布局\n• 全局快捷键 … 在任何应用中保存、恢复、撤销\n• 自动备份 … 每 10 分钟保存一次当前布局\n• 排除应用、导出/导入、撤销\n• 日本語 · English · 简体中文 · 한국어 · Italiano · Español\n\n■ 工作原理\n通过 macOS 辅助功能 API 读取和设置窗口的位置和大小。布局数据仅保存在您的 Mac 上，不会发送到任何地方。\n\n────────────────────────\n开发：LYNOX LLC\n© 2026 LYNOX LLC. All rights reserved.", "외부 모니터를 연결하거나 분리해 흐트러진 창 배치를 한 번의 클릭으로 되돌려 주는 메뉴 막대 앱입니다.\n\n■ 주요 기능\n• 배치 저장 … 실행 중인 앱의 창 위치와 크기를 기록\n• 한 번에 복원 … 메뉴에서 선택만 하면 됩니다(⌘1–⌘9)\n• 디스플레이별 배치 … 모니터 구성별로 자동 분류\n• 자동 복원 … 디스플레이 변경을 감지해 배치를 되돌림\n• 전역 단축키 … 어떤 앱에서든 저장·복원·되돌리기\n• 자동 백업 … 10분마다 현재 배치를 보관\n• 제외할 앱, 내보내기/가져오기, 되돌리기\n• 日本語 · English · 简体中文 · 한국어 · Italiano · Español\n\n■ 동작 원리\nmacOS 손쉬운 사용 API로 창의 위치와 크기를 읽고 설정합니다. 배치 데이터는 사용 중인 Mac에만 저장되며 외부로 전송되지 않습니다.\n\n────────────────────────\n개발: LYNOX LLC\n© 2026 LYNOX LLC. All rights reserved.", "Un'app nella barra dei menu che, dopo aver collegato o scollegato un monitor esterno, rimette le finestre al loro posto con un clic.\n\n■ Funzioni\n• Salva disposizioni — registra posizione e dimensioni delle finestre delle app aperte\n• Ripristino con un clic — scegli dal menu (⌘1–⌘9)\n• Disposizioni per schermo — raggruppate automaticamente per configurazione\n• Ripristino automatico — rileva i cambi di schermo e ripristina\n• Scorciatoie globali — salva, ripristina e annulla da qualsiasi app\n• Backup automatico — conserva la disposizione ogni 10 minuti\n• App escluse, esporta/importa, annulla\n• 日本語 · English · 简体中文 · 한국어 · Italiano · Español\n\n■ Come funziona\nWindow Memory legge e imposta posizione e dimensioni delle finestre tramite l'API Accessibilità di macOS. Le disposizioni restano solo sul tuo Mac e non vengono inviate da nessuna parte.\n\n────────────────────────\nSviluppato da LYNOX LLC\n© 2026 LYNOX LLC. All rights reserved.", "Una app de la barra de menús que, tras conectar o desconectar una pantalla externa, devuelve tus ventanas a su sitio con un clic.\n\n■ Funciones\n• Guardar disposiciones — registra la posición y el tamaño de las ventanas de las apps abiertas\n• Restauración con un clic — elige en el menú (⌘1–⌘9)\n• Disposiciones por pantalla — agrupadas automáticamente por configuración\n• Restauración automática — detecta cambios de pantalla y restaura\n• Atajos globales — guarda, restaura y deshaz desde cualquier app\n• Copia automática — conserva la disposición cada 10 minutos\n• Apps excluidas, exportar/importar, deshacer\n• 日本語 · English · 简体中文 · 한국어 · Italiano · Español\n\n■ Cómo funciona\nWindow Memory lee y establece la posición y el tamaño de las ventanas mediante la API de Accesibilidad de macOS. Las disposiciones se guardan solo en tu Mac y no se envían a ningún sitio.\n\n────────────────────────\nDesarrollado por LYNOX LLC\n© 2026 LYNOX LLC. All rights reserved."],
]

// MARK: - Preferences

enum Prefs {
    private static let d = UserDefaults.standard

    static var autoRestore: Bool {
        get { d.bool(forKey: "autoRestoreOnDisplayChange") }
        set { d.set(newValue, forKey: "autoRestoreOnDisplayChange") }
    }
    static var autoSave: Bool {
        get { d.bool(forKey: "autoSaveEnabled") }
        set { d.set(newValue, forKey: "autoSaveEnabled") }
    }
    /// Window titles help match windows on restore, but can contain private text.
    static var keepTitles: Bool {
        get { (d.object(forKey: "keepTitles") as? Bool) ?? true }
        set { d.set(newValue, forKey: "keepTitles") }
    }
    static var shortcutsEnabled: Bool {
        get { d.bool(forKey: "shortcutsEnabled") }
        set { d.set(newValue, forKey: "shortcutsEnabled") }
    }
    static var hkModifier: Int {
        get { (d.object(forKey: "hkModifier") as? Int) ?? 0 }
        set { d.set(newValue, forKey: "hkModifier") }
    }
    static var hkSave: String {
        get { d.string(forKey: "hkSave") ?? "S" }
        set { d.set(newValue, forKey: "hkSave") }
    }
    static var hkRestore: String {
        get { d.string(forKey: "hkRestore") ?? "R" }
        set { d.set(newValue, forKey: "hkRestore") }
    }
    static var hkUndo: String {
        get { d.string(forKey: "hkUndo") ?? "Z" }
        set { d.set(newValue, forKey: "hkUndo") }
    }
    static var excluded: [String] {
        get { d.stringArray(forKey: "excludedBundleIds") ?? [] }
        set { d.set(newValue, forKey: "excludedBundleIds") }
    }
    static var didShowGuide: Bool {
        get { d.bool(forKey: "didShowGuide_v13") }
        set { d.set(newValue, forKey: "didShowGuide_v13") }
    }
    /// v1.0–v1.2 flag, kept so existing users aren't shown the first-run guide again.
    static var didShowLegacyWelcome: Bool { d.bool(forKey: "didShowWelcome") }
}

// MARK: - Models

/// One captured window's placement.
struct WindowSnapshot: Codable {
    var bundleId: String
    var appName: String
    var windowIndex: Int
    var title: String
    var x: Double
    var y: Double
    var w: Double
    var h: Double
}

/// A named layout profile bound to the display arrangement it was captured under.
/// isDefault and isAuto are optional so files written by v1.0–v1.2 still load.
struct Profile: Codable {
    var id: String
    var name: String
    var displaySignature: String
    var displayDescription: String
    var windows: [WindowSnapshot]
    var createdAt: Date
    var updatedAt: Date
    var isDefault: Bool?
    var isAuto: Bool?

    /// Shown in menus. The automatic backup has a localized name.
    var shownName: String { isAuto == true ? tr("name.auto") : name }
}

// MARK: - Display configuration

enum Displays {
    /// A stable signature for the current monitor arrangement, so a layout saved
    /// on one setup is only auto-suggested when that same setup returns.
    static func signature() -> String {
        let parts = NSScreen.screens.map { screen -> String in
            let f = screen.frame
            return "\(Int(f.origin.x)),\(Int(f.origin.y)),\(Int(f.width)),\(Int(f.height))"
        }.sorted()
        return parts.joined(separator: "|")
    }

    /// Human-readable text derived from a signature, so it follows the UI language.
    static func describe(signature: String) -> String {
        let parts = signature.split(separator: "|").map { String($0) }
        let sizes = parts.map { part -> String in
            let c = part.split(separator: ",").map { String($0) }
            return c.count == 4 ? "\(c[2])×\(c[3])" : part
        }.joined(separator: " + ")
        return tr("display.desc", "\(parts.count)", sizes)
    }

    static func description() -> String { describe(signature: signature()) }

    /// Screen rectangles in Accessibility coordinates (origin top-left of the primary screen).
    static func axRects() -> [CGRect] {
        guard let primary = NSScreen.screens.first else { return [] }
        let ph = primary.frame.height
        return NSScreen.screens.map { s in
            CGRect(x: s.frame.minX, y: ph - s.frame.maxY, width: s.frame.width, height: s.frame.height)
        }
    }
}

// MARK: - Accessibility / window engine

/// What a restore pass did, so the UI can report it honestly.
struct RestoreOutcome {
    var restored = 0
    var total = 0
    var excludedSkipped = 0
    var notRunning: [String] = []
    var missing = 0
    /// Where the moved windows were before the restore, for Undo.
    var previous: [WindowSnapshot] = []
}

enum WindowEngine {

    static func isTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Counts real on-screen windows system-wide via CGWindowList — this needs no
    /// special permission, unlike AXUIElement. Used to tell "there's genuinely
    /// nothing to capture" apart from "accessibility is broken and returning
    /// nothing despite windows being open".
    static func systemWindowCountHint() -> Int {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return 0 }
        let myPID = ProcessInfo.processInfo.processIdentifier
        return list.filter { info in
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { return false }
            guard let pid = info[kCGWindowOwnerPID as String] as? Int32, pid != myPID else { return false }
            return true
        }.count
    }

    private static func copyAttr(_ element: AXUIElement, _ attr: String) -> CFTypeRef? {
        var ref: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attr as CFString, &ref)
        return err == .success ? ref : nil
    }

    private static func boolAttr(_ element: AXUIElement, _ attr: String) -> Bool {
        if let n = copyAttr(element, attr) as? NSNumber { return n.boolValue }
        return false
    }

    /// Windows we should move: not minimized, not full screen, and a normal window
    /// (not a palette or popover). Index is the position in the app's own window
    /// list, so it stays comparable between capture and restore.
    private static func eligibleWindows(of app: NSRunningApplication) -> [(el: AXUIElement, index: Int)] {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        guard let windowsRef = copyAttr(axApp, kAXWindowsAttribute as String),
              let windows = windowsRef as? [AXUIElement] else { return [] }
        var result: [(el: AXUIElement, index: Int)] = []
        for (i, w) in windows.enumerated() {
            if boolAttr(w, kAXMinimizedAttribute as String) { continue }
            if boolAttr(w, "AXFullScreen") { continue }
            if let sub = copyAttr(w, kAXSubroleAttribute as String) as? String {
                let ok = (sub == "AXStandardWindow" || sub == "AXDialog" || sub == "AXSystemDialog")
                if !ok { continue }
            }
            result.append((w, i))
        }
        return result
    }

    /// Number of windows Accessibility can see at all (no filtering). Zero while windows
    /// are visibly open means the permission is stale.
    static func rawWindowCount() -> Int {
        var n = 0
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            if app.bundleIdentifier == Bundle.main.bundleIdentifier { continue }
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            if let ref = copyAttr(axApp, kAXWindowsAttribute as String),
               let ws = ref as? [AXUIElement] { n += ws.count }
        }
        return n
    }

    static func capture(excluded: Set<String>, keepTitles: Bool) -> [WindowSnapshot] {
        var snapshots: [WindowSnapshot] = []
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }

        for app in apps {
            guard let bundleId = app.bundleIdentifier,
                  bundleId != Bundle.main.bundleIdentifier,
                  !excluded.contains(bundleId) else { continue }

            for entry in eligibleWindows(of: app) {
                guard let (pos, size) = frame(of: entry.el) else { continue }
                if size.width < 1 || size.height < 1 { continue }
                let title = keepTitles ? (copyAttr(entry.el, kAXTitleAttribute as String) as? String ?? "") : ""
                snapshots.append(WindowSnapshot(
                    bundleId: bundleId,
                    appName: app.localizedName ?? bundleId,
                    windowIndex: entry.index,
                    title: title,
                    x: Double(pos.x), y: Double(pos.y),
                    w: Double(size.width), h: Double(size.height)
                ))
            }
        }
        return snapshots
    }

    private static func frame(of window: AXUIElement) -> (CGPoint, CGSize)? {
        guard let posRef = copyAttr(window, kAXPositionAttribute as String),
              let sizeRef = copyAttr(window, kAXSizeAttribute as String) else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        return (position, size)
    }

    private static func setFrame(of window: AXUIElement, position: CGPoint, size: CGSize) {
        var pos = position
        var sz = size
        // Set size first, then position, then size again — some apps clamp
        // position against the old size, so a second pass lands it correctly.
        if let szVal = AXValueCreate(.cgSize, &sz) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, szVal)
        }
        if let posVal = AXValueCreate(.cgPoint, &pos) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posVal)
        }
        if let szVal2 = AXValueCreate(.cgSize, &sz) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, szVal2)
        }
    }

    /// If a saved frame lies off every connected screen (a monitor is gone), pull it
    /// onto the primary screen instead of leaving the window unreachable.
    private static func clamped(position: CGPoint, size: CGSize) -> (CGPoint, CGSize) {
        let screens = Displays.axRects()
        guard !screens.isEmpty else { return (position, size) }
        let rect = CGRect(origin: position, size: size)
        for s in screens {
            let inter = s.intersection(rect)
            if !inter.isNull && inter.width >= min(120, size.width) && inter.height >= min(60, size.height) {
                return (position, size)
            }
        }
        let s = screens[0]
        let w = min(size.width, s.width)
        let h = min(size.height, max(100, s.height - 80))
        return (CGPoint(x: s.minX + 40, y: s.minY + 60), CGSize(width: w, height: h))
    }

    /// Restore a saved layout and report what happened.
    static func restore(_ snapshots: [WindowSnapshot], excluded: Set<String>) -> RestoreOutcome {
        var out = RestoreOutcome()
        let wantedAll = snapshots.filter { !excluded.contains($0.bundleId) }
        out.excludedSkipped = snapshots.count - wantedAll.count
        out.total = wantedAll.count

        let byBundle = Dictionary(grouping: wantedAll, by: { $0.bundleId })
        let regularApps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        var notRunning = Set<String>()

        for (bundleId, wanted) in byBundle {
            guard let app = regularApps.first(where: { $0.bundleIdentifier == bundleId }) else {
                notRunning.insert(wanted.first?.appName ?? bundleId)
                continue
            }

            var live: [(el: AXUIElement, title: String, index: Int)] = []
            for entry in eligibleWindows(of: app) {
                let title = copyAttr(entry.el, kAXTitleAttribute as String) as? String ?? ""
                live.append((entry.el, title, entry.index))
            }
            var used = Set<Int>()

            for snap in wanted {
                // Prefer an exact title match, then the same window index, then any free window.
                var pick: Int? = live.first(where: {
                    !used.contains($0.index) && !snap.title.isEmpty && $0.title == snap.title
                })?.index
                if pick == nil {
                    pick = live.first(where: { !used.contains($0.index) && $0.index == snap.windowIndex })?.index
                }
                if pick == nil {
                    pick = live.first(where: { !used.contains($0.index) })?.index
                }
                guard let idx = pick, let target = live.first(where: { $0.index == idx }) else {
                    out.missing += 1
                    continue
                }
                used.insert(idx)

                if let (p, s) = frame(of: target.el) {
                    out.previous.append(WindowSnapshot(
                        bundleId: bundleId, appName: snap.appName, windowIndex: idx,
                        title: target.title,
                        x: Double(p.x), y: Double(p.y), w: Double(s.width), h: Double(s.height)))
                }
                let (pos, size) = clamped(position: CGPoint(x: snap.x, y: snap.y),
                                          size: CGSize(width: snap.w, height: snap.h))
                setFrame(of: target.el, position: pos, size: size)
                out.restored += 1
            }
        }
        out.notRunning = notRunning.sorted()
        return out
    }
}

// MARK: - Persistence

final class Store {
    static let shared = Store()
    private(set) var profiles: [Profile] = []

    var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WindowMemory", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    var fileURL: URL { directoryURL.appendingPathComponent("profiles.json") }

    init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        profiles = (try? JSONDecoder.iso.decode([Profile].self, from: data)) ?? []
    }

    func save() {
        guard let data = try? JSONEncoder.iso.encode(profiles) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func upsert(_ profile: Profile) {
        if let i = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[i] = profile
        } else {
            profiles.append(profile)
        }
        save()
    }

    func delete(id: String) {
        profiles.removeAll { $0.id == id }
        save()
    }

    /// Mark one profile as the default for its display setup (clears the others).
    func setDefault(id: String, on: Bool) {
        guard let target = profiles.first(where: { $0.id == id }) else { return }
        for i in profiles.indices where profiles[i].displaySignature == target.displaySignature {
            profiles[i].isDefault = (profiles[i].id == id && on) ? true : nil
        }
        save()
    }

    /// Keeps a single automatic backup per display setup.
    func upsertAuto(windows: [WindowSnapshot], signature: String) {
        let now = Date()
        if let i = profiles.firstIndex(where: { $0.isAuto == true && $0.displaySignature == signature }) {
            profiles[i].windows = windows
            profiles[i].updatedAt = now
        } else {
            profiles.append(Profile(
                id: UUID().uuidString, name: "Auto Backup",
                displaySignature: signature, displayDescription: Displays.describe(signature: signature),
                windows: windows, createdAt: now, updatedAt: now, isDefault: nil, isAuto: true))
        }
        save()
    }

    /// Profiles for the current display setup: default first, then newest manual
    /// layouts, then the automatic backup.
    func profilesForCurrentDisplays() -> [Profile] {
        let sig = Displays.signature()
        let same = profiles.filter { $0.displaySignature == sig }
        let manual = same.filter { $0.isAuto != true }
            .sorted { a, b in
                if (a.isDefault == true) != (b.isDefault == true) { return a.isDefault == true }
                return a.updatedAt > b.updatedAt
            }
        return manual + same.filter { $0.isAuto == true }
    }

    /// What auto-restore and the restore shortcut should use.
    func preferredProfile(signature: String) -> Profile? {
        let same = profiles.filter { $0.displaySignature == signature }
        let manual = same.filter { $0.isAuto != true }
        if let d = manual.first(where: { $0.isDefault == true }) { return d }
        if let newest = manual.max(by: { $0.updatedAt < $1.updatedAt }) { return newest }
        return same.first(where: { $0.isAuto == true })
    }

    /// Merge imported profiles. Same id: keep the newer one. Returns (added, updated).
    func merge(_ incoming: [Profile]) -> (Int, Int) {
        var added = 0, updated = 0
        for p in incoming {
            if let i = profiles.firstIndex(where: { $0.id == p.id }) {
                if p.updatedAt > profiles[i].updatedAt { profiles[i] = p; updated += 1 }
            } else {
                profiles.append(p); added += 1
            }
        }
        if added + updated > 0 { save() }
        return (added, updated)
    }
}

extension JSONEncoder {
    static var iso: JSONEncoder {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.prettyPrinted]; return e
    }
}
extension JSONDecoder {
    static var iso: JSONDecoder {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }
}

// MARK: - HUD (non-modal result toast)

/// A small floating panel that fades out by itself. Used for restore results so a
/// background (automatic) restore never steals focus the way a modal alert would.
enum HUD {
    private static var panel: NSPanel?
    private static var hideWork: DispatchWorkItem?

    static func show(_ title: String, _ body: String = "") {
        DispatchQueue.main.async { present(title, body) }
    }

    private static func present(_ title: String, _ body: String) {
        hideWork?.cancel()
        panel?.orderOut(nil)

        let titleLabel = NSTextField(wrappingLabelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.preferredMaxLayoutWidth = 380

        var views: [NSView] = [titleLabel]
        if !body.isEmpty {
            let bodyLabel = NSTextField(wrappingLabelWithString: body)
            bodyLabel.font = NSFont.systemFont(ofSize: 12)
            bodyLabel.textColor = NSColor.secondaryLabelColor
            bodyLabel.preferredMaxLayoutWidth = 380
            views.append(bodyLabel)
        }

        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 18, bottom: 14, right: 18)
        let size = stack.fittingSize
        stack.frame = NSRect(origin: .zero, size: size)

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 14
        effect.layer?.masksToBounds = true
        effect.addSubview(stack)

        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.contentView = effect
        p.isOpaque = false
        p.backgroundColor = NSColor.clear
        p.hasShadow = true
        p.level = .statusBar
        p.ignoresMouseEvents = true
        p.isReleasedWhenClosed = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let vf = screen.visibleFrame
            p.setFrameOrigin(NSPoint(x: vf.midX - size.width / 2, y: vf.maxY - size.height - 24))
        }
        p.alphaValue = 0
        p.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            p.animator().alphaValue = 1
        }
        panel = p

        let lines = body.split(separator: "\n").count
        let seconds = min(9.0, 3.5 + Double(lines) * 1.2)
        let work = DispatchWorkItem {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.4
                p.animator().alphaValue = 0
            }, completionHandler: {
                p.orderOut(nil)
            })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
}

// MARK: - Global shortcuts (Carbon hot keys: no extra permission needed)

private func hotKeyCallback(_ next: EventHandlerCallRef?, _ event: EventRef?,
                            _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    var hkID = EventHotKeyID()
    let err = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                EventParamType(typeEventHotKeyID), nil,
                                MemoryLayout<EventHotKeyID>.size, nil, &hkID)
    if err == noErr {
        let id = hkID.id
        DispatchQueue.main.async { HotKeyCenter.shared.fire(id) }
    }
    return noErr
}

final class HotKeyCenter {
    static let shared = HotKeyCenter()

    /// Modifier presets offered in the settings dialog.
    static let modifierPresets: [(label: String, mask: UInt32)] = [
        ("⌃⌥⌘", UInt32(controlKey | optionKey | cmdKey)),
        ("⌃⌥", UInt32(controlKey | optionKey)),
        ("⌃⌘", UInt32(controlKey | cmdKey)),
        ("⌥⇧⌘", UInt32(optionKey | shiftKey | cmdKey)),
    ]

    /// ANSI virtual key codes for the letters A–Z.
    static let letterKeyCodes: [String: UInt32] = [
        "A": 0, "S": 1, "D": 2, "F": 3, "H": 4, "G": 5, "Z": 6, "X": 7, "C": 8, "V": 9,
        "B": 11, "Q": 12, "W": 13, "E": 14, "R": 15, "Y": 16, "T": 17, "O": 31, "U": 32,
        "I": 34, "P": 35, "L": 37, "J": 38, "K": 40, "N": 45, "M": 46,
    ]
    static var letters: [String] { letterKeyCodes.keys.sorted() }

    private var refs: [EventHotKeyRef] = []
    private var actions: [UInt32: () -> Void] = [:]
    private var handlerInstalled = false
    private(set) var failed: [String] = []
    private(set) var registered = 0

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), hotKeyCallback, 1, &spec, nil, nil)
        handlerInstalled = true
    }

    func unregisterAll() {
        for r in refs { UnregisterEventHotKey(r) }
        refs.removeAll()
        actions.removeAll()
        failed.removeAll()
        registered = 0
    }

    func register(id: UInt32, letter: String, modifiers: UInt32, label: String,
                  action: @escaping () -> Void) {
        installHandlerIfNeeded()
        guard let code = HotKeyCenter.letterKeyCodes[letter] else { failed.append(label); return }
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: OSType(0x574D454D), id: id)
        let status = RegisterEventHotKey(code, modifiers, hkID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let r = ref {
            refs.append(r)
            actions[id] = action
            registered += 1
        } else {
            failed.append(label)
        }
    }

    func fire(_ id: UInt32) { actions[id]?() }
}

// MARK: - Getting-started guide window

/// Three steps: what the app does, allow Accessibility (with a live status), how to use it.
/// Opened automatically on first launch and from the menu at any time.
final class GuideWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var step = 0
    private let lastStep = 2
    private var timer: Timer?
    private var statusLabel: NSTextField?
    var onOpenSettings: (() -> Void)?

    var isVisible: Bool { window?.isVisible ?? false }

    func show() {
        step = 0
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                             styleMask: [.titled, .closable],
                             backing: .buffered, defer: false)
            w.isReleasedWhenClosed = false
            w.delegate = self
            window = w
        }
        render()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshStatus()
        }
    }

    func close() { window?.close() }

    func windowWillClose(_ notification: Notification) {
        timer?.invalidate()
        timer = nil
        Prefs.didShowGuide = true
        NSApp.setActivationPolicy(.accessory)
    }

    private func refreshStatus() {
        guard step == 1, let label = statusLabel else { return }
        label.stringValue = WindowEngine.isTrusted(prompt: false) ? tr("guide.s2.ok") : tr("guide.s2.ng")
    }

    private func makeButton(_ title: String, _ action: Selector, primary: Bool = false) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        if primary { b.keyEquivalent = "\r" }
        return b
    }

    private func render() {
        guard let window = window else { return }
        statusLabel = nil
        window.title = "Window Memory"

        var views: [NSView] = []

        if let path = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let icon = NSImage(contentsOfFile: path) {
            let iv = NSImageView(image: icon)
            iv.imageScaling = .scaleProportionallyUpOrDown
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.widthAnchor.constraint(equalToConstant: 64).isActive = true
            iv.heightAnchor.constraint(equalToConstant: 64).isActive = true
            views.append(iv)
        }

        let stepLabel = NSTextField(labelWithString: tr("guide.step", "\(step + 1)", "\(lastStep + 1)"))
        stepLabel.font = NSFont.systemFont(ofSize: 11)
        stepLabel.textColor = NSColor.secondaryLabelColor
        views.append(stepLabel)

        let titleKey = ["guide.s1.title", "guide.s2.title", "guide.s3.title"][step]
        let bodyKey = ["guide.s1.body", "guide.s2.body", "guide.s3.body"][step]
        let title = NSTextField(wrappingLabelWithString: step == 0 ? tr("guide.title") : tr(titleKey))
        title.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        title.preferredMaxLayoutWidth = 440
        views.append(title)

        if step == 0 {
            let sub = NSTextField(wrappingLabelWithString: tr(titleKey))
            sub.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
            sub.preferredMaxLayoutWidth = 440
            views.append(sub)
        }

        let body = NSTextField(wrappingLabelWithString: tr(bodyKey))
        body.font = NSFont.systemFont(ofSize: 13)
        body.preferredMaxLayoutWidth = 440
        views.append(body)

        if step == 1 {
            let status = NSTextField(labelWithString:
                WindowEngine.isTrusted(prompt: false) ? tr("guide.s2.ok") : tr("guide.s2.ng"))
            status.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
            statusLabel = status
            views.append(status)
            views.append(makeButton(tr("openSettings"), #selector(openSettingsTapped)))
            let stale = NSTextField(wrappingLabelWithString: tr("guide.s2.stale"))
            stale.font = NSFont.systemFont(ofSize: 11)
            stale.textColor = NSColor.secondaryLabelColor
            stale.preferredMaxLayoutWidth = 440
            views.append(stale)
        }

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        var rowViews: [NSView] = []
        if step > 0 { rowViews.append(makeButton(tr("back"), #selector(backTapped))) }
        rowViews.append(spacer)
        rowViews.append(makeButton(step == lastStep ? tr("done") : tr("next"),
                                   #selector(nextTapped), primary: true))
        let row = NSStackView(views: rowViews)
        row.orientation = .horizontal
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: 440).isActive = true
        views.append(row)

        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 28, left: 30, bottom: 24, right: 30)
        let size = stack.fittingSize
        stack.frame = NSRect(origin: .zero, size: size)
        window.contentView = stack
        window.setContentSize(size)
    }

    @objc private func openSettingsTapped() { onOpenSettings?() }
    @objc private func backTapped() { if step > 0 { step -= 1; render() } }
    @objc private func nextTapped() {
        if step >= lastStep { window?.close() } else { step += 1; render() }
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let guide = GuideWindowController()

    private var pendingAutoRestore: DispatchWorkItem?
    private var pendingSecondPass: DispatchWorkItem?
    private var firstPassNeedsRetry = false
    private var lastScreenChange = Date.distantPast
    private var lastUndo: [WindowSnapshot] = []
    private var autoSaveTimer: Timer?

    // MARK: Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "macwindow.on.rectangle",
                                   accessibilityDescription: "Window Memory")
        }
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu
        populate(menu)

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        guide.onOpenSettings = { [weak self] in self?.openAccessibilitySettings() }
        applyHotKeys(userInitiated: false)
        startAutoSaveTimer()

        // First launch (or first launch of v1.3): walk the user through setup.
        // People who already completed the old welcome and have access are not interrupted.
        let trusted = WindowEngine.isTrusted(prompt: false)
        if !Prefs.didShowGuide && !(Prefs.didShowLegacyWelcome && trusted) {
            guide.show()
        }

        checkForUpdates()
    }

    // The menu is rebuilt each time it opens, so permission state, the running-app
    // list for exclusions and profile lists are always current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === statusItem.menu { populate(menu) }
    }

    private func rebuildMenu() {
        if let m = statusItem.menu { populate(m) }
    }

    // MARK: Display change handling

    @objc private func screensChanged() {
        lastScreenChange = Date()
        rebuildMenu()
        pendingAutoRestore?.cancel()
        pendingSecondPass?.cancel()
        firstPassNeedsRetry = false
        guard Prefs.autoRestore, WindowEngine.isTrusted(prompt: false) else { return }

        let first = DispatchWorkItem { [weak self] in self?.autoRestorePass(first: true) }
        let second = DispatchWorkItem { [weak self] in self?.autoRestorePass(first: false) }
        pendingAutoRestore = first
        pendingSecondPass = second
        // Wait for macOS to finish its own window shuffling, then try once more later
        // for apps that were slow to reappear.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: first)
        DispatchQueue.main.asyncAfter(deadline: .now() + 9, execute: second)
    }

    private func autoRestorePass(first: Bool) {
        if !first && !firstPassNeedsRetry { return }
        guard let profile = Store.shared.preferredProfile(signature: Displays.signature()) else { return }
        let r = WindowEngine.restore(profile.windows, excluded: Set(Prefs.excluded))
        if first {
            firstPassNeedsRetry = (r.missing > 0 || !r.notRunning.isEmpty)
            if r.restored > 0 {
                lastUndo = r.previous
                HUD.show(tr("hud.autoRestored"), okBody(r))
            }
        }
    }

    // MARK: Auto backup

    private func startAutoSaveTimer() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            self?.autoSaveTick()
        }
    }

    /// Keeps one automatic backup per display setup. It skips the first 30 seconds after a
    /// display change so a layout scrambled by macOS is never saved over a good one.
    private func autoSaveTick() {
        guard Prefs.autoSave, WindowEngine.isTrusted(prompt: false) else { return }
        guard Date().timeIntervalSince(lastScreenChange) > 30 else { return }
        let windows = captureNow()
        guard !windows.isEmpty else { return }
        Store.shared.upsertAuto(windows: windows, signature: Displays.signature())
    }

    // MARK: Global shortcuts

    private func applyHotKeys(userInitiated: Bool) {
        let hk = HotKeyCenter.shared
        hk.unregisterAll()
        guard Prefs.shortcutsEnabled else { return }
        let presets = HotKeyCenter.modifierPresets
        let preset = presets[min(max(Prefs.hkModifier, 0), presets.count - 1)]
        hk.register(id: 1, letter: Prefs.hkSave, modifiers: preset.mask,
                    label: preset.label + Prefs.hkSave) { [weak self] in self?.quickSave() }
        hk.register(id: 2, letter: Prefs.hkRestore, modifiers: preset.mask,
                    label: preset.label + Prefs.hkRestore) { [weak self] in self?.quickRestore() }
        hk.register(id: 3, letter: Prefs.hkUndo, modifiers: preset.mask,
                    label: preset.label + Prefs.hkUndo) { [weak self] in self?.undoLastRestore() }
        if userInitiated && !hk.failed.isEmpty {
            notify(tr("sc.title"), tr("sc.failed", hk.failed.joined(separator: ", ")))
        }
    }

    /// Shortcut: overwrite this display setup's default layout, or create one.
    private func quickSave() {
        guard WindowEngine.isTrusted(prompt: false) else {
            HUD.show(tr("ax.required.title"))
            return
        }
        let windows = captureNow()
        if windows.isEmpty {
            HUD.show(tr("save.nothing.title"), tr("save.nothing.body"))
            return
        }
        let sig = Displays.signature()
        let now = Date()
        if var existing = Store.shared.profiles.first(where: {
            $0.displaySignature == sig && $0.isDefault == true && $0.isAuto != true
        }) {
            existing.windows = windows
            existing.updatedAt = now
            Store.shared.upsert(existing)
            HUD.show(tr("save.overwritten.title"), tr("save.result.body", existing.name, "\(windows.count)"))
        } else {
            var name = tr("name.quick")
            if Store.shared.profiles.contains(where: { $0.name == name }) {
                name += " " + shortStamp()
            }
            let p = Profile(id: UUID().uuidString, name: name,
                            displaySignature: sig, displayDescription: Displays.describe(signature: sig),
                            windows: windows, createdAt: now, updatedAt: now, isDefault: nil, isAuto: nil)
            Store.shared.upsert(p)
            Store.shared.setDefault(id: p.id, on: true)
            HUD.show(tr("save.saved.title"), tr("save.result.body", name, "\(windows.count)"))
        }
        rebuildMenu()
    }

    private func quickRestore() {
        guard WindowEngine.isTrusted(prompt: false) else {
            HUD.show(tr("ax.required.title"))
            return
        }
        guard let p = Store.shared.preferredProfile(signature: Displays.signature()) else {
            HUD.show(tr("restore.none"))
            return
        }
        runRestore(p)
    }

    // MARK: Updates

    /// Lightweight, non-blocking check against GitHub Releases. The launch-time check is
    /// silent on any network failure; a check started from the menu always reports.
    private func checkForUpdates(userInitiated: Bool = false) {
        guard let url = URL(string: "https://api.github.com/repos/lynox-llc/Window-Memory/releases") else { return }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
            guard let data,
                  let releases = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let latest = releases.first,
                  let tag = latest["tag_name"] as? String,
                  let htmlURLString = latest["html_url"] as? String else {
                if userInitiated {
                    DispatchQueue.main.async {
                        self?.notify(tr("update.fail.title"), tr("update.fail.body"))
                    }
                }
                return
            }
            DispatchQueue.main.async {
                guard let self else { return }
                if Self.isNewerVersion(tag, than: current) {
                    self.showUpdateAvailable(tag: tag, urlString: htmlURLString, force: userInitiated)
                } else if userInitiated {
                    self.notify(tr("update.latest.title"), tr("update.latest.body", current))
                }
            }
        }.resume()
    }

    /// Compares dotted version numbers component-by-component, ignoring a leading "v".
    private static func isNewerVersion(_ remoteTag: String, than currentVersion: String) -> Bool {
        func parts(_ s: String) -> [Int] {
            s.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                .split(separator: ".")
                .map { Int($0.filter(\.isNumber)) ?? 0 }
        }
        let remote = parts(remoteTag), current = parts(currentVersion)
        for i in 0..<max(remote.count, current.count) {
            let r = i < remote.count ? remote[i] : 0
            let c = i < current.count ? current[i] : 0
            if r != c { return r > c }
        }
        return false
    }

    private func showUpdateAvailable(tag: String, urlString: String, force: Bool = false) {
        let dismissKey = "dismissedUpdate_\(tag)"
        guard force || !UserDefaults.standard.bool(forKey: dismissKey) else { return }
        let alert = NSAlert()
        applyIcon(alert)
        alert.messageText = tr("update.new.title")
        alert.informativeText = tr("update.new.body", tag)
        alert.addButton(withTitle: tr("open"))
        alert.addButton(withTitle: tr("later"))
        if presentFrontmost(alert) == .alertFirstButtonReturn {
            if let u = URL(string: urlString) { NSWorkspace.shared.open(u) }
        } else {
            UserDefaults.standard.set(true, forKey: dismissKey)
        }
    }

    // MARK: Menu

    @discardableResult
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector?, key: String = "",
                     enabled: Bool = true, state: NSControl.StateValue = .off,
                     object: Any? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        if action != nil { item.target = self }
        item.isEnabled = enabled
        item.state = state
        item.representedObject = object
        menu.addItem(item)
        return item
    }

    private func populate(_ menu: NSMenu) {
        menu.removeAllItems()
        let trusted = WindowEngine.isTrusted(prompt: false)

        add(menu, tr("menu.header"), nil, enabled: false)
        menu.addItem(.separator())

        if !trusted {
            add(menu, tr("menu.needAccess"), nil, enabled: false)
            add(menu, tr("menu.grant"), #selector(openAccessibilitySettings))
            menu.addItem(.separator())
        }

        add(menu, tr("menu.save"), #selector(saveLayout), key: "s", enabled: trusted)

        // Restore submenu: layouts for the display setup that is connected right now.
        let current = Store.shared.profilesForCurrentDisplays()
        let restoreItem = NSMenuItem(title: tr("menu.restore"), action: nil, keyEquivalent: "")
        let restoreMenu = NSMenu()
        restoreMenu.autoenablesItems = false
        if current.isEmpty {
            add(restoreMenu, tr("menu.restoreNone"), nil, enabled: false)
        } else {
            for (i, p) in current.enumerated() {
                let title = (p.isDefault == true ? "★ " : "") + p.shownName
                add(restoreMenu, title, #selector(restoreFromMenu(_:)),
                    key: i < 9 ? "\(i + 1)" : "", enabled: trusted, object: p.id)
            }
        }
        restoreItem.submenu = restoreMenu
        restoreItem.isEnabled = trusted && !current.isEmpty
        menu.addItem(restoreItem)

        add(menu, tr("menu.undo"), #selector(undoLastRestore), enabled: trusted && !lastUndo.isEmpty)

        menu.addItem(.separator())
        addManageMenu(to: menu, trusted: trusted)
        menu.addItem(.separator())

        add(menu, tr("menu.autoRestore"), #selector(toggleAutoRestore),
            state: Prefs.autoRestore ? .on : .off)

        // Settings submenu.
        let settingsItem = NSMenuItem(title: tr("menu.settings"), action: nil, keyEquivalent: "")
        let sm = NSMenu()
        sm.autoenablesItems = false
        add(sm, tr("menu.autoSave"), #selector(toggleAutoSave), state: Prefs.autoSave ? .on : .off)
        add(sm, tr("menu.login"), #selector(toggleLoginItem),
            state: SMAppService.mainApp.status == .enabled ? .on : .off)
        add(sm, tr("menu.keepTitles"), #selector(toggleKeepTitles), state: Prefs.keepTitles ? .on : .off)
        sm.addItem(.separator())
        add(sm, tr("menu.shortcuts"), #selector(toggleShortcuts), state: Prefs.shortcutsEnabled ? .on : .off)
        add(sm, tr("menu.shortcutSettings"), #selector(openShortcutSettings))
        sm.addItem(.separator())
        addExclusionsMenu(to: sm)
        sm.addItem(.separator())
        add(sm, tr("menu.export"), #selector(exportLayouts))
        add(sm, tr("menu.import"), #selector(importLayouts))
        sm.addItem(.separator())
        addLanguageMenu(to: sm)
        settingsItem.submenu = sm
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        add(menu, tr("menu.guide"), #selector(showGuide))
        add(menu, tr("menu.diagnose"), #selector(runDiagnostics))
        add(menu, tr("menu.update"), #selector(checkForUpdatesManually))
        add(menu, tr("menu.about"), #selector(showAbout))
        let quit = NSMenuItem(title: tr("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func addManageMenu(to menu: NSMenu, trusted: Bool) {
        let manageItem = NSMenuItem(title: tr("menu.manage"), action: nil, keyEquivalent: "")
        let manageMenu = NSMenu()
        manageMenu.autoenablesItems = false
        if Store.shared.profiles.isEmpty {
            add(manageMenu, tr("menu.manageNone"), nil, enabled: false)
        } else {
            let grouped = Dictionary(grouping: Store.shared.profiles, by: { $0.displaySignature })
            let ordered = grouped.keys.sorted { Displays.describe(signature: $0) < Displays.describe(signature: $1) }
            for sig in ordered {
                add(manageMenu, Displays.describe(signature: sig), nil, enabled: false)
                let profs = (grouped[sig] ?? []).sorted { a, b in
                    if (a.isAuto == true) != (b.isAuto == true) { return b.isAuto == true }
                    return a.updatedAt > b.updatedAt
                }
                for p in profs {
                    let star = p.isDefault == true ? "★ " : ""
                    let title = "   " + star + tr("menu.windowsCount", p.shownName, "\(p.windows.count)")
                    let sub = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                    let subMenu = NSMenu()
                    subMenu.autoenablesItems = false
                    if p.isAuto != true {
                        add(subMenu, tr("menu.rename"), #selector(renameProfile(_:)), object: p.id)
                        add(subMenu, tr("menu.overwrite"), #selector(overwriteProfile(_:)), enabled: trusted, object: p.id)
                        if p.isDefault == true {
                            add(subMenu, tr("menu.clearDefault"), #selector(clearDefaultProfile(_:)), object: p.id)
                        } else {
                            add(subMenu, tr("menu.setDefault"), #selector(setDefaultProfile(_:)), object: p.id)
                        }
                    }
                    add(subMenu, tr("menu.delete", p.shownName), #selector(deleteProfile(_:)), object: p.id)
                    sub.submenu = subMenu
                    manageMenu.addItem(sub)
                }
                manageMenu.addItem(.separator())
            }
        }
        manageItem.submenu = manageMenu
        menu.addItem(manageItem)
    }

    private func addExclusionsMenu(to menu: NSMenu) {
        let item = NSMenuItem(title: tr("menu.exclusions"), action: nil, keyEquivalent: "")
        let sub = NSMenu()
        sub.autoenablesItems = false
        add(sub, tr("menu.exclusionsHint"), nil, enabled: false)
        sub.addItem(.separator())

        let excluded = Set(Prefs.excluded)
        var entries: [(id: String, name: String)] = []
        var seen = Set<String>()
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            guard let id = app.bundleIdentifier, id != Bundle.main.bundleIdentifier, !seen.contains(id) else { continue }
            seen.insert(id)
            entries.append((id, app.localizedName ?? id))
        }
        for id in excluded where !seen.contains(id) {
            seen.insert(id)
            entries.append((id, id))
        }
        entries.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        for e in entries {
            add(sub, e.name, #selector(toggleExclusion(_:)),
                state: excluded.contains(e.id) ? .on : .off, object: e.id)
        }
        item.submenu = sub
        menu.addItem(item)
    }

    private func addLanguageMenu(to menu: NSMenu) {
        let item = NSMenuItem(title: tr("menu.language"), action: nil, keyEquivalent: "")
        let sub = NSMenu()
        sub.autoenablesItems = false
        add(sub, tr("menu.langAuto"), #selector(selectLanguage(_:)),
            state: L10n.override == nil ? .on : .off, object: "auto")
        sub.addItem(.separator())
        for lang in Lang.allCases {
            add(sub, lang.nativeName, #selector(selectLanguage(_:)),
                state: L10n.override == lang ? .on : .off, object: lang.rawValue)
        }
        item.submenu = sub
        menu.addItem(item)
    }

    // MARK: Actions — settings

    @objc private func openAccessibilitySettings() {
        _ = WindowEngine.isTrusted(prompt: true)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func toggleAutoRestore() {
        Prefs.autoRestore.toggle()
        rebuildMenu()
    }

    @objc private func toggleAutoSave() {
        Prefs.autoSave.toggle()
        if Prefs.autoSave { autoSaveTick() }
        rebuildMenu()
    }

    @objc private func toggleKeepTitles() {
        Prefs.keepTitles.toggle()
        rebuildMenu()
    }

    @objc private func toggleShortcuts() {
        Prefs.shortcutsEnabled.toggle()
        applyHotKeys(userInitiated: true)
        rebuildMenu()
    }

    @objc private func toggleExclusion(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        var list = Prefs.excluded
        if let i = list.firstIndex(of: id) { list.remove(at: i) } else { list.append(id) }
        Prefs.excluded = list
        rebuildMenu()
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        let raw = sender.representedObject as? String ?? "auto"
        L10n.override = Lang(rawValue: raw)   // "auto" is not a Lang, so it clears the override
        if guide.isVisible { guide.close() }
        rebuildMenu()
    }

    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            notify(tr("login.error"), error.localizedDescription)
        }
        rebuildMenu()
    }

    @objc private func openShortcutSettings() {
        let alert = NSAlert()
        applyIcon(alert)
        alert.messageText = tr("sc.title")
        alert.informativeText = tr("sc.body")

        let presets = HotKeyCenter.modifierPresets
        let modPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        modPopup.addItems(withTitles: presets.map { $0.label })
        modPopup.selectItem(at: min(max(Prefs.hkModifier, 0), presets.count - 1))

        func letterPopup(_ selected: String) -> NSPopUpButton {
            let p = NSPopUpButton(frame: .zero, pullsDown: false)
            p.addItems(withTitles: HotKeyCenter.letters)
            p.selectItem(withTitle: selected)
            return p
        }
        let savePop = letterPopup(Prefs.hkSave)
        let restorePop = letterPopup(Prefs.hkRestore)
        let undoPop = letterPopup(Prefs.hkUndo)

        func row(_ label: String, _ control: NSView) -> NSStackView {
            let l = NSTextField(labelWithString: label)
            l.alignment = .right
            l.translatesAutoresizingMaskIntoConstraints = false
            l.widthAnchor.constraint(equalToConstant: 110).isActive = true
            let s = NSStackView(views: [l, control])
            s.orientation = .horizontal
            s.spacing = 8
            return s
        }
        let stack = NSStackView(views: [
            row(tr("sc.modifiers"), modPopup),
            row(tr("save"), savePop),
            row(tr("sc.restore"), restorePop),
            row(tr("sc.undo"), undoPop),
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.frame = NSRect(origin: .zero, size: stack.fittingSize)
        alert.accessoryView = stack

        alert.addButton(withTitle: tr("save"))
        alert.addButton(withTitle: tr("cancel"))
        guard presentFrontmost(alert) == .alertFirstButtonReturn else { return }

        Prefs.hkModifier = modPopup.indexOfSelectedItem
        Prefs.hkSave = savePop.titleOfSelectedItem ?? "S"
        Prefs.hkRestore = restorePop.titleOfSelectedItem ?? "R"
        Prefs.hkUndo = undoPop.titleOfSelectedItem ?? "Z"
        Prefs.shortcutsEnabled = true
        applyHotKeys(userInitiated: true)
        rebuildMenu()
    }

    // MARK: Actions — export / import

    @objc private func exportLayouts() {
        let profiles = Store.shared.profiles
        guard !profiles.isEmpty else {
            notify(tr("export.title"), tr("export.empty"))
            return
        }
        let panel = NSSavePanel()
        panel.title = tr("export.title")
        panel.allowedContentTypes = [UTType.json]
        panel.nameFieldStringValue = "WindowMemory-layouts.json"
        let response = withFrontmost { () -> NSApplication.ModalResponse in panel.runModal() }
        guard response == .OK, let url = panel.url else { return }
        do {
            let data = try JSONEncoder.iso.encode(profiles)
            try data.write(to: url, options: .atomic)
            notify(tr("export.title"), tr("export.done", "\(profiles.count)"))
        } catch {
            notify(tr("export.title"), tr("export.fail", error.localizedDescription))
        }
    }

    @objc private func importLayouts() {
        let panel = NSOpenPanel()
        panel.title = tr("import.title")
        panel.allowedContentTypes = [UTType.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        let response = withFrontmost { () -> NSApplication.ModalResponse in panel.runModal() }
        guard response == .OK, let url = panel.url else { return }
        guard let data = try? Data(contentsOf: url),
              let incoming = try? JSONDecoder.iso.decode([Profile].self, from: data) else {
            notify(tr("import.title"), tr("import.fail"))
            return
        }
        let (added, updated) = Store.shared.merge(incoming)
        rebuildMenu()
        notify(tr("import.title"), tr("import.done", "\(added)", "\(updated)"))
    }

    // MARK: Actions — save / restore

    private func captureNow() -> [WindowSnapshot] {
        WindowEngine.capture(excluded: Set(Prefs.excluded), keepTitles: Prefs.keepTitles)
    }

    private func profile(from sender: NSMenuItem) -> Profile? {
        guard let id = sender.representedObject as? String else { return nil }
        return Store.shared.profiles.first(where: { $0.id == id })
    }

    /// Verify accessibility access before any window operation.
    @discardableResult
    private func ensureTrusted() -> Bool {
        if WindowEngine.isTrusted(prompt: false) { return true }
        let alert = NSAlert()
        applyIcon(alert)
        alert.messageText = tr("ax.required.title")
        alert.informativeText = tr("ax.required.body")
        alert.addButton(withTitle: tr("openSettings"))
        alert.addButton(withTitle: tr("cancel"))
        if presentFrontmost(alert) == .alertFirstButtonReturn { openAccessibilitySettings() }
        return false
    }

    @objc private func saveLayout() {
        guard ensureTrusted() else { return }
        let windows = captureNow()
        if windows.isEmpty {
            // Empty is ambiguous: nothing open, everything excluded/minimized, or a stale
            // permission. Accessibility seeing windows at all, or the system seeing none,
            // means the permission is fine.
            if WindowEngine.rawWindowCount() > 0 || WindowEngine.systemWindowCountHint() == 0 {
                notify(tr("save.nothing.title"), tr("save.nothing.body"))
                return
            }
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = tr("save.fail.title")
            alert.informativeText = tr("save.fail.body", Bundle.main.bundleIdentifier ?? "com.windowmemory.app")
            alert.addButton(withTitle: tr("openSettings"))
            alert.addButton(withTitle: tr("close"))
            if presentFrontmost(alert) == .alertFirstButtonReturn { openAccessibilitySettings() }
            return
        }

        let alert = NSAlert()
        applyIcon(alert)
        alert.messageText = tr("save.title")
        alert.informativeText = tr("save.body", Displays.description(), "\(windows.count)")
        alert.addButton(withTitle: tr("save"))
        alert.addButton(withTitle: tr("cancel"))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = defaultProfileName()
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard presentFrontmost(alert) == .alertFirstButtonReturn else { return }
        let typed = field.stringValue.trimmingCharacters(in: .whitespaces)
        let finalName = typed.isEmpty ? defaultProfileName() : typed
        let now = Date()

        if let existing = Store.shared.profiles.first(where: { $0.name == finalName && $0.isAuto != true }) {
            let ask = NSAlert()
            ask.alertStyle = .warning
            ask.messageText = tr("save.exists.title", finalName)
            ask.informativeText = tr("save.exists.body")
            ask.addButton(withTitle: tr("overwriteBtn"))
            ask.addButton(withTitle: tr("cancel"))
            guard presentFrontmost(ask) == .alertFirstButtonReturn else { return }
            var profile = existing
            profile.windows = windows
            profile.displaySignature = Displays.signature()
            profile.displayDescription = Displays.description()
            profile.updatedAt = now
            Store.shared.upsert(profile)
            rebuildMenu()
            HUD.show(tr("save.overwritten.title"), tr("save.result.body", profile.name, "\(windows.count)"))
            return
        }

        let profile = Profile(id: UUID().uuidString, name: finalName,
                              displaySignature: Displays.signature(),
                              displayDescription: Displays.description(),
                              windows: windows, createdAt: now, updatedAt: now,
                              isDefault: nil, isAuto: nil)
        Store.shared.upsert(profile)
        rebuildMenu()
        HUD.show(tr("save.saved.title"), tr("save.result.body", profile.name, "\(windows.count)"))
    }

    @objc private func restoreFromMenu(_ sender: NSMenuItem) {
        guard let p = profile(from: sender) else { return }
        guard ensureTrusted() else { return }
        runRestore(p)
    }

    /// Restore a profile, remember where windows were (for Undo) and report the result.
    private func runRestore(_ p: Profile) {
        let r = WindowEngine.restore(p.windows, excluded: Set(Prefs.excluded))
        if r.restored > 0 {
            lastUndo = r.previous
            rebuildMenu()
        }
        if r.restored == 0 {
            var body = tr("restore.fail.body")
            let extra = skipLines(r)
            if !extra.isEmpty { body += "\n\n" + extra.joined(separator: "\n") }
            notify(tr("restore.fail.title"), body)
        } else {
            HUD.show(tr("restore.ok.title", p.shownName), okBody(r))
        }
    }

    private func skipLines(_ r: RestoreOutcome) -> [String] {
        var lines: [String] = []
        if !r.notRunning.isEmpty {
            let shown = r.notRunning.prefix(5).joined(separator: ", ")
            lines.append(tr("restore.skip.notrunning", r.notRunning.count > 5 ? shown + "…" : shown))
        }
        if r.excludedSkipped > 0 { lines.append(tr("restore.skip.excluded", "\(r.excludedSkipped)")) }
        if r.missing > 0 { lines.append(tr("restore.skip.missing", "\(r.missing)")) }
        return lines
    }

    private func okBody(_ r: RestoreOutcome) -> String {
        ([tr("restore.ok.body", "\(r.restored)", "\(r.total)")] + skipLines(r)).joined(separator: "\n")
    }

    @objc private func undoLastRestore() {
        guard WindowEngine.isTrusted(prompt: false) else {
            HUD.show(tr("ax.required.title"))
            return
        }
        if lastUndo.isEmpty {
            HUD.show(tr("undo.none"))
            return
        }
        let r = WindowEngine.restore(lastUndo, excluded: [])
        lastUndo = []
        rebuildMenu()
        HUD.show(tr("undo.done"), tr("restore.ok.body", "\(r.restored)", "\(r.total)"))
    }

    @objc private func renameProfile(_ sender: NSMenuItem) {
        guard var profile = profile(from: sender) else { return }
        let alert = NSAlert()
        applyIcon(alert)
        alert.messageText = tr("rename.title")
        alert.informativeText = tr("rename.body", profile.name)
        alert.addButton(withTitle: tr("rename"))
        alert.addButton(withTitle: tr("cancel"))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = profile.name
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard presentFrontmost(alert) == .alertFirstButtonReturn else { return }
        let newName = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !newName.isEmpty, newName != profile.name else { return }
        if Store.shared.profiles.contains(where: { $0.name == newName && $0.id != profile.id }) {
            notify(tr("rename.fail.title"), tr("rename.fail.body", newName))
            return
        }
        profile.name = newName
        profile.updatedAt = Date()
        Store.shared.upsert(profile)
        rebuildMenu()
    }

    @objc private func overwriteProfile(_ sender: NSMenuItem) {
        guard var profile = profile(from: sender) else { return }
        guard ensureTrusted() else { return }
        profile.windows = captureNow()
        profile.displaySignature = Displays.signature()
        profile.displayDescription = Displays.description()
        profile.updatedAt = Date()
        Store.shared.upsert(profile)
        rebuildMenu()
        HUD.show(tr("overwrite.done.title"), tr("overwrite.done.body", profile.name, "\(profile.windows.count)"))
    }

    @objc private func setDefaultProfile(_ sender: NSMenuItem) {
        guard let p = profile(from: sender) else { return }
        Store.shared.setDefault(id: p.id, on: true)
        rebuildMenu()
    }

    @objc private func clearDefaultProfile(_ sender: NSMenuItem) {
        guard let p = profile(from: sender) else { return }
        Store.shared.setDefault(id: p.id, on: false)
        rebuildMenu()
    }

    @objc private func deleteProfile(_ sender: NSMenuItem) {
        guard let p = profile(from: sender) else { return }
        let alert = NSAlert()
        applyIcon(alert)
        alert.messageText = tr("delete.title", p.shownName)
        alert.informativeText = tr("delete.body")
        alert.addButton(withTitle: tr("delete"))
        alert.addButton(withTitle: tr("cancel"))
        guard presentFrontmost(alert) == .alertFirstButtonReturn else { return }
        Store.shared.delete(id: p.id)
        rebuildMenu()
    }

    // MARK: Actions — help

    @objc private func showGuide() { guide.show() }

    @objc private func checkForUpdatesManually() { checkForUpdates(userInitiated: true) }

    /// Full health check. Reports the API's answer and a real window read separately: the
    /// permission can read as granted while every call still fails (stale grant after an update).
    @objc private func runDiagnostics() {
        let trusted = WindowEngine.isTrusted(prompt: false)
        let reachable = WindowEngine.rawWindowCount()
        let systemHint = WindowEngine.systemWindowCountHint()
        let nothingOpen = systemHint == 0
        let working = reachable > 0 || nothingOpen

        let verdict: String
        if reachable > 0 {
            verdict = tr("diag.v.ok")
        } else if nothingOpen {
            verdict = tr("diag.v.empty")
        } else if trusted {
            verdict = tr("diag.v.stale")
        } else {
            verdict = tr("diag.v.off")
        }

        var lines: [String] = []
        lines.append(tr("diag.api", trusted ? tr("diag.on") : tr("diag.off")))
        lines.append(tr("diag.capture", "\(reachable)", "\(systemHint)"))
        lines.append(tr("diag.version", appVersion, architecture))
        lines.append("macOS: " + ProcessInfo.processInfo.operatingSystemVersionString)
        lines.append("Bundle ID: " + (Bundle.main.bundleIdentifier ?? "-"))
        lines.append(tr("diag.location", Bundle.main.bundlePath))
        if !Bundle.main.bundlePath.hasPrefix("/Applications/") { lines.append(tr("diag.location.warn")) }
        lines.append(tr("diag.login", SMAppService.mainApp.status == .enabled ? tr("yes") : tr("no")))
        var sc = tr("no")
        if Prefs.shortcutsEnabled {
            sc = "\(HotKeyCenter.shared.registered)/3"
            if !HotKeyCenter.shared.failed.isEmpty { sc += " ✗ " + HotKeyCenter.shared.failed.joined(separator: ", ") }
        }
        lines.append(tr("diag.shortcuts", sc))
        lines.append(tr("diag.store", Store.shared.fileURL.path, "\(Store.shared.profiles.count)"))
        let report = lines.joined(separator: "\n")

        let alert = NSAlert()
        alert.alertStyle = working ? .informational : .warning
        alert.messageText = tr("diag.title")
        alert.informativeText = report + "\n\n" + tr("diag.spaces") + "\n\n" + verdict
        alert.addButton(withTitle: tr("ok"))
        alert.addButton(withTitle: tr("openSettings"))
        alert.addButton(withTitle: tr("copyReport"))
        let response = presentFrontmost(alert)
        if response == .alertSecondButtonReturn {
            openAccessibilitySettings()
        } else if response == .alertThirdButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(report + "\n\n" + verdict, forType: .string)
        }
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        applyIcon(alert)
        alert.messageText = tr("about.title", appVersion)
        alert.informativeText = tr("about.body")
        alert.addButton(withTitle: tr("ok"))
        presentFrontmost(alert)
    }

    // MARK: Helpers

    /// Single source of truth for the displayed version — read from the bundle.
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var architecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    private func shortStamp() -> String {
        let df = DateFormatter()
        df.dateFormat = "MM/dd HH:mm"
        return df.string(from: Date())
    }

    private func defaultProfileName() -> String {
        tr("name.default", shortStamp())
    }

    private func applyIcon(_ alert: NSAlert) {
        if let path = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let icon = NSImage(contentsOfFile: path) { alert.icon = icon }
    }

    /// Show feedback the user is guaranteed to see (a modal alert always appears,
    /// unlike Notification Center for an unsigned menu-bar app).
    private func notify(_ title: String, _ body: String) {
        let alert = NSAlert()
        applyIcon(alert)
        alert.messageText = title
        alert.informativeText = body
        alert.addButton(withTitle: tr("ok"))
        presentFrontmost(alert)
    }

    /// Run something that needs focus (a modal or an open/save panel) from an
    /// accessory app, which otherwise may open behind other windows.
    private func withFrontmost<T>(_ body: () -> T) -> T {
        let previous = NSApp.activationPolicy()
        if previous != .regular { NSApp.setActivationPolicy(.regular) }
        NSApp.activate(ignoringOtherApps: true)
        let result = body()
        if previous != .regular { NSApp.setActivationPolicy(previous) }
        return result
    }

    @discardableResult
    private func presentFrontmost(_ alert: NSAlert) -> NSApplication.ModalResponse {
        withFrontmost { () -> NSApplication.ModalResponse in
            alert.window.level = .modalPanel
            alert.window.makeKeyAndOrderFront(nil)
            return alert.runModal()
        }
    }
}

// MARK: - Entry point

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
