import Foundation

struct AppLanguage: Identifiable, Equatable {
    let id: String
    let title: String
}

enum AppTextKey: String, CaseIterable {
    case tooltipGoUp
    case tooltipBack
    case tooltipForward
    case tooltipRefresh
    case tooltipCreateFolder
    case tooltipCreateFile
    case tooltipCut
    case tooltipCopy
    case tooltipPaste
    case tooltipSearch
    case tooltipThreePane
    case tooltipCopyPath
    case tooltipSort
    case tooltipView
    case sidebarHome
    case sidebarPictures
    case sidebarDesktop
    case sidebarDownloads
    case sidebarDocuments
    case sidebarMusic
    case sidebarMovies
    case sidebarNetwork
}

enum AppText {
    private enum Language: String {
        case zhHans = "zh-Hans"
        case zhHant = "zh-Hant"
        case en
        case ja
        case ko
        case fr
        case de
        case es
        case pt
        case ru
    }

    static let supportedLanguages: [AppLanguage] = [
        AppLanguage(id: "system", title: "跟随系统"),
        AppLanguage(id: "zh-Hans", title: "简体中文"),
        AppLanguage(id: "zh-Hant", title: "繁體中文"),
        AppLanguage(id: "en", title: "English"),
        AppLanguage(id: "ja", title: "日本語"),
        AppLanguage(id: "ko", title: "한국어"),
        AppLanguage(id: "fr", title: "Français"),
        AppLanguage(id: "de", title: "Deutsch"),
        AppLanguage(id: "es", title: "Español"),
        AppLanguage(id: "pt", title: "Português"),
        AppLanguage(id: "ru", title: "Русский")
    ]

    static func localized(_ key: AppTextKey, language: String) -> String {
        translations[resolvedLanguage(language)]?[key]
            ?? translations[.en]?[key]
            ?? translations[.zhHans]?[key]
            ?? key.rawValue
    }

    private static func resolvedLanguage(_ language: String) -> Language {
        if let explicit = Language(rawValue: language) {
            return explicit
        }

        let preferred = Locale.preferredLanguages.first ?? Locale.current.identifier
        let lowercased = preferred.lowercased()
        if lowercased.hasPrefix("zh-hant") || lowercased.hasPrefix("zh-tw") || lowercased.hasPrefix("zh-hk") {
            return .zhHant
        }
        if lowercased.hasPrefix("zh") {
            return .zhHans
        }
        if lowercased.hasPrefix("ja") { return .ja }
        if lowercased.hasPrefix("ko") { return .ko }
        if lowercased.hasPrefix("fr") { return .fr }
        if lowercased.hasPrefix("de") { return .de }
        if lowercased.hasPrefix("es") { return .es }
        if lowercased.hasPrefix("pt") { return .pt }
        if lowercased.hasPrefix("ru") { return .ru }
        return .en
    }

    private static let translations: [Language: [AppTextKey: String]] = [
        .zhHans: [
            .tooltipGoUp: "上一级",
            .tooltipBack: "后退",
            .tooltipForward: "前进",
            .tooltipRefresh: "刷新",
            .tooltipCreateFolder: "新建文件夹",
            .tooltipCreateFile: "新建文件",
            .tooltipCut: "剪切",
            .tooltipCopy: "复制",
            .tooltipPaste: "粘贴",
            .tooltipSearch: "搜索",
            .tooltipThreePane: "三窗口",
            .tooltipCopyPath: "双击复制路径",
            .tooltipSort: "排序",
            .tooltipView: "查看",
            .sidebarHome: "Home",
            .sidebarPictures: "图片",
            .sidebarDesktop: "桌面",
            .sidebarDownloads: "下载",
            .sidebarDocuments: "文档",
            .sidebarMusic: "音乐",
            .sidebarMovies: "视频",
            .sidebarNetwork: "内网计算机"
        ],
        .zhHant: [
            .tooltipGoUp: "上一層",
            .tooltipBack: "返回",
            .tooltipForward: "前進",
            .tooltipRefresh: "重新整理",
            .tooltipCreateFolder: "新增資料夾",
            .tooltipCreateFile: "新增檔案",
            .tooltipCut: "剪下",
            .tooltipCopy: "複製",
            .tooltipPaste: "貼上",
            .tooltipSearch: "搜尋",
            .tooltipThreePane: "三視窗",
            .tooltipCopyPath: "連按兩下複製路徑",
            .tooltipSort: "排序",
            .tooltipView: "檢視",
            .sidebarHome: "Home",
            .sidebarPictures: "圖片",
            .sidebarDesktop: "桌面",
            .sidebarDownloads: "下載",
            .sidebarDocuments: "文件",
            .sidebarMusic: "音樂",
            .sidebarMovies: "影片",
            .sidebarNetwork: "區域網路電腦"
        ],
        .en: [
            .tooltipGoUp: "Go Up",
            .tooltipBack: "Back",
            .tooltipForward: "Forward",
            .tooltipRefresh: "Refresh",
            .tooltipCreateFolder: "New Folder",
            .tooltipCreateFile: "New File",
            .tooltipCut: "Cut",
            .tooltipCopy: "Copy",
            .tooltipPaste: "Paste",
            .tooltipSearch: "Search",
            .tooltipThreePane: "Three Panes",
            .tooltipCopyPath: "Double-click to copy path",
            .tooltipSort: "Sort",
            .tooltipView: "View",
            .sidebarHome: "Home",
            .sidebarPictures: "Pictures",
            .sidebarDesktop: "Desktop",
            .sidebarDownloads: "Downloads",
            .sidebarDocuments: "Documents",
            .sidebarMusic: "Music",
            .sidebarMovies: "Movies",
            .sidebarNetwork: "Network"
        ],
        .ja: [
            .tooltipGoUp: "上へ",
            .tooltipBack: "戻る",
            .tooltipForward: "進む",
            .tooltipRefresh: "更新",
            .tooltipCreateFolder: "新規フォルダ",
            .tooltipCreateFile: "新規ファイル",
            .tooltipCut: "切り取り",
            .tooltipCopy: "コピー",
            .tooltipPaste: "貼り付け",
            .tooltipSearch: "検索",
            .tooltipThreePane: "3ペイン",
            .tooltipCopyPath: "ダブルクリックでパスをコピー",
            .tooltipSort: "並べ替え",
            .tooltipView: "表示",
            .sidebarHome: "ホーム",
            .sidebarPictures: "ピクチャ",
            .sidebarDesktop: "デスクトップ",
            .sidebarDownloads: "ダウンロード",
            .sidebarDocuments: "書類",
            .sidebarMusic: "ミュージック",
            .sidebarMovies: "ムービー",
            .sidebarNetwork: "ネットワーク"
        ],
        .ko: [
            .tooltipGoUp: "상위 폴더",
            .tooltipBack: "뒤로",
            .tooltipForward: "앞으로",
            .tooltipRefresh: "새로 고침",
            .tooltipCreateFolder: "새 폴더",
            .tooltipCreateFile: "새 파일",
            .tooltipCut: "잘라내기",
            .tooltipCopy: "복사",
            .tooltipPaste: "붙여넣기",
            .tooltipSearch: "검색",
            .tooltipThreePane: "세 창",
            .tooltipCopyPath: "두 번 클릭하여 경로 복사",
            .tooltipSort: "정렬",
            .tooltipView: "보기",
            .sidebarHome: "홈",
            .sidebarPictures: "사진",
            .sidebarDesktop: "데스크탑",
            .sidebarDownloads: "다운로드",
            .sidebarDocuments: "문서",
            .sidebarMusic: "음악",
            .sidebarMovies: "동영상",
            .sidebarNetwork: "네트워크"
        ],
        .fr: [
            .tooltipGoUp: "Dossier parent",
            .tooltipBack: "Retour",
            .tooltipForward: "Avancer",
            .tooltipRefresh: "Actualiser",
            .tooltipCreateFolder: "Nouveau dossier",
            .tooltipCreateFile: "Nouveau fichier",
            .tooltipCut: "Couper",
            .tooltipCopy: "Copier",
            .tooltipPaste: "Coller",
            .tooltipSearch: "Rechercher",
            .tooltipThreePane: "Trois panneaux",
            .tooltipCopyPath: "Double-cliquer pour copier le chemin",
            .tooltipSort: "Trier",
            .tooltipView: "Afficher",
            .sidebarHome: "Accueil",
            .sidebarPictures: "Images",
            .sidebarDesktop: "Bureau",
            .sidebarDownloads: "Téléchargements",
            .sidebarDocuments: "Documents",
            .sidebarMusic: "Musique",
            .sidebarMovies: "Vidéos",
            .sidebarNetwork: "Réseau"
        ],
        .de: [
            .tooltipGoUp: "Nach oben",
            .tooltipBack: "Zurück",
            .tooltipForward: "Vorwärts",
            .tooltipRefresh: "Aktualisieren",
            .tooltipCreateFolder: "Neuer Ordner",
            .tooltipCreateFile: "Neue Datei",
            .tooltipCut: "Ausschneiden",
            .tooltipCopy: "Kopieren",
            .tooltipPaste: "Einfügen",
            .tooltipSearch: "Suchen",
            .tooltipThreePane: "Drei Bereiche",
            .tooltipCopyPath: "Doppelklicken, um den Pfad zu kopieren",
            .tooltipSort: "Sortieren",
            .tooltipView: "Ansicht",
            .sidebarHome: "Home",
            .sidebarPictures: "Bilder",
            .sidebarDesktop: "Schreibtisch",
            .sidebarDownloads: "Downloads",
            .sidebarDocuments: "Dokumente",
            .sidebarMusic: "Musik",
            .sidebarMovies: "Filme",
            .sidebarNetwork: "Netzwerk"
        ],
        .es: [
            .tooltipGoUp: "Subir",
            .tooltipBack: "Atrás",
            .tooltipForward: "Adelante",
            .tooltipRefresh: "Actualizar",
            .tooltipCreateFolder: "Nueva carpeta",
            .tooltipCreateFile: "Nuevo archivo",
            .tooltipCut: "Cortar",
            .tooltipCopy: "Copiar",
            .tooltipPaste: "Pegar",
            .tooltipSearch: "Buscar",
            .tooltipThreePane: "Tres paneles",
            .tooltipCopyPath: "Doble clic para copiar la ruta",
            .tooltipSort: "Ordenar",
            .tooltipView: "Vista",
            .sidebarHome: "Inicio",
            .sidebarPictures: "Imágenes",
            .sidebarDesktop: "Escritorio",
            .sidebarDownloads: "Descargas",
            .sidebarDocuments: "Documentos",
            .sidebarMusic: "Música",
            .sidebarMovies: "Vídeos",
            .sidebarNetwork: "Red"
        ],
        .pt: [
            .tooltipGoUp: "Subir",
            .tooltipBack: "Voltar",
            .tooltipForward: "Avançar",
            .tooltipRefresh: "Atualizar",
            .tooltipCreateFolder: "Nova pasta",
            .tooltipCreateFile: "Novo arquivo",
            .tooltipCut: "Recortar",
            .tooltipCopy: "Copiar",
            .tooltipPaste: "Colar",
            .tooltipSearch: "Pesquisar",
            .tooltipThreePane: "Três painéis",
            .tooltipCopyPath: "Clique duas vezes para copiar o caminho",
            .tooltipSort: "Ordenar",
            .tooltipView: "Visualizar",
            .sidebarHome: "Início",
            .sidebarPictures: "Imagens",
            .sidebarDesktop: "Mesa",
            .sidebarDownloads: "Downloads",
            .sidebarDocuments: "Documentos",
            .sidebarMusic: "Música",
            .sidebarMovies: "Vídeos",
            .sidebarNetwork: "Rede"
        ],
        .ru: [
            .tooltipGoUp: "Вверх",
            .tooltipBack: "Назад",
            .tooltipForward: "Вперед",
            .tooltipRefresh: "Обновить",
            .tooltipCreateFolder: "Новая папка",
            .tooltipCreateFile: "Новый файл",
            .tooltipCut: "Вырезать",
            .tooltipCopy: "Копировать",
            .tooltipPaste: "Вставить",
            .tooltipSearch: "Поиск",
            .tooltipThreePane: "Три панели",
            .tooltipCopyPath: "Дважды щелкните, чтобы скопировать путь",
            .tooltipSort: "Сортировка",
            .tooltipView: "Вид",
            .sidebarHome: "Домой",
            .sidebarPictures: "Изображения",
            .sidebarDesktop: "Рабочий стол",
            .sidebarDownloads: "Загрузки",
            .sidebarDocuments: "Документы",
            .sidebarMusic: "Музыка",
            .sidebarMovies: "Видео",
            .sidebarNetwork: "Сеть"
        ]
    ]
}
