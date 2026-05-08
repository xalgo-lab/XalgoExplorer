# Changelog

## v0.1.2-candidate - 2026-05-08

### 简体中文

- 将文件区切换为 macOS 原生 AppKit 控件：列表模式使用 `NSTableView`，文件/预览模式使用 `NSCollectionView`，外层 SwiftUI 结构保持不变。
- 保持 `ExplorerModel` 作为唯一业务状态源，AppKit 只负责文件显示、选择、拖拽、右键菜单和事件桥接。
- 改进列表列宽、表头排序、键盘选择、焦点切换和三窗口文件区交互稳定性。
- 修复键盘向下选择文件时选中项不会自动滚入可见区域的问题。
- 修复 AppKit 拖拽 pasteboard 写入，支持内部拖拽、多文件拖拽和 Finder 风格复制/移动规则。
- 增加 AppKit 文件区、拖拽 pasteboard、键盘滚动和选择行为的回归测试。

### 繁體中文

- 將檔案區切換為 macOS 原生 AppKit 控件：列表模式使用 `NSTableView`，檔案/預覽模式使用 `NSCollectionView`，外層 SwiftUI 結構保持不變。
- 保持 `ExplorerModel` 作為唯一業務狀態來源，AppKit 只負責檔案顯示、選取、拖放、右鍵選單和事件橋接。
- 改進列表欄寬、表頭排序、鍵盤選取、焦點切換和三視窗檔案區互動穩定性。
- 修復鍵盤向下選取檔案時選中項不會自動捲入可視區域的問題。
- 修復 AppKit 拖放 pasteboard 寫入，支援內部拖放、多檔案拖放和 Finder 風格複製/移動規則。
- 增加 AppKit 檔案區、拖放 pasteboard、鍵盤捲動和選取行為的回歸測試。

### English

- Migrated the file area to native macOS AppKit controls: `NSTableView` for list mode and `NSCollectionView` for file/preview modes, while keeping the outer SwiftUI shell unchanged.
- Kept `ExplorerModel` as the single source of business state; AppKit only handles file rendering, selection, drag and drop, context menus, and event bridging.
- Improved list column resizing, header sorting, keyboard selection, focus routing, and three-pane file-area stability.
- Fixed keyboard selection not scrolling the newly selected item into view.
- Fixed AppKit drag pasteboard writing for internal drags, multi-file drags, and Finder-style copy/move rules.
- Added regression coverage for the AppKit file area, drag pasteboard behavior, keyboard scrolling, and selection behavior.

### 日本語

- ファイル領域を macOS ネイティブの AppKit コントロールへ移行しました。リスト表示は `NSTableView`、ファイル/プレビュー表示は `NSCollectionView` を使用し、外側の SwiftUI 構造は維持しています。
- `ExplorerModel` を業務状態の唯一の情報源として維持し、AppKit はファイル表示、選択、ドラッグ&ドロップ、コンテキストメニュー、イベント橋渡しのみを担当します。
- リストの列幅調整、ヘッダー並び替え、キーボード選択、フォーカス切り替え、3 ペインのファイル領域の安定性を改善しました。
- キーボードで下方向に選択しても新しい選択項目が表示領域へ自動スクロールしない問題を修正しました。
- 内部ドラッグ、複数ファイルドラッグ、Finder 風のコピー/移動ルールに対応する AppKit drag pasteboard 書き込みを修正しました。
- AppKit ファイル領域、drag pasteboard、キーボードスクロール、選択動作の回帰テストを追加しました。

### 한국어

- 파일 영역을 macOS 네이티브 AppKit 컨트롤로 전환했습니다. 목록 모드는 `NSTableView`, 파일/미리보기 모드는 `NSCollectionView`를 사용하며 외부 SwiftUI 구조는 유지했습니다.
- `ExplorerModel`을 비즈니스 상태의 단일 소스로 유지하고, AppKit은 파일 표시, 선택, 드래그 앤 드롭, 컨텍스트 메뉴, 이벤트 브리지만 담당합니다.
- 목록 열 너비 조절, 헤더 정렬, 키보드 선택, 포커스 전환, 3개 창 파일 영역의 안정성을 개선했습니다.
- 키보드로 아래쪽 파일을 선택할 때 선택 항목이 자동으로 보이는 영역으로 스크롤되지 않던 문제를 수정했습니다.
- 내부 드래그, 다중 파일 드래그, Finder 스타일 복사/이동 규칙을 위한 AppKit drag pasteboard 쓰기를 수정했습니다.
- AppKit 파일 영역, drag pasteboard, 키보드 스크롤, 선택 동작에 대한 회귀 테스트를 추가했습니다.

### Français

- La zone de fichiers utilise désormais des contrôles AppKit natifs de macOS : `NSTableView` pour le mode liste et `NSCollectionView` pour les modes fichiers/aperçu, sans modifier l'enveloppe SwiftUI.
- `ExplorerModel` reste l'unique source d'état métier ; AppKit gère seulement l'affichage, la sélection, le glisser-déposer, les menus contextuels et le pont d'événements.
- Amélioration du redimensionnement des colonnes, du tri par en-tête, de la sélection au clavier, du routage du focus et de la stabilité de la zone de fichiers en trois panneaux.
- Correction du défilement automatique lors de la sélection de fichiers au clavier.
- Correction de l'écriture du pasteboard AppKit pour les glissements internes, les glissements multi-fichiers et les règles copier/déplacer de type Finder.
- Ajout de tests de régression pour la zone de fichiers AppKit, le pasteboard de glisser-déposer, le défilement clavier et la sélection.

### Deutsch

- Der Dateibereich verwendet jetzt native macOS-AppKit-Steuerelemente: `NSTableView` im Listenmodus und `NSCollectionView` im Datei-/Vorschaumodus, während die äußere SwiftUI-Struktur unverändert bleibt.
- `ExplorerModel` bleibt die einzige Quelle für Geschäftsstatus; AppKit übernimmt nur Darstellung, Auswahl, Drag-and-drop, Kontextmenüs und Event-Bridging.
- Verbesserte Stabilität für Spaltenbreiten, Kopfzeilensortierung, Tastaturauswahl, Fokuswechsel und den Dateibereich im Drei-Fenster-Modus.
- Behoben: Bei Tastaturauswahl nach unten wurde das neu ausgewählte Element nicht automatisch sichtbar gescrollt.
- Behoben: AppKit-drag-pasteboard-Schreiben für interne Drags, Mehrfachdatei-Drags und Finder-artige Kopieren-/Verschieben-Regeln.
- Regressionstests für AppKit-Dateibereich, Drag-pasteboard, Tastatur-Scrolling und Auswahlverhalten ergänzt.

### Español

- El área de archivos ahora usa controles AppKit nativos de macOS: `NSTableView` para el modo lista y `NSCollectionView` para los modos de archivos/vista previa, manteniendo intacta la estructura SwiftUI externa.
- `ExplorerModel` sigue siendo la única fuente de estado de negocio; AppKit solo gestiona renderizado, selección, arrastrar y soltar, menús contextuales y puente de eventos.
- Mejora de estabilidad para el ancho de columnas, ordenación por encabezado, selección con teclado, foco y el área de archivos de tres paneles.
- Corregido el problema por el que la selección con teclado hacia abajo no desplazaba el elemento seleccionado al área visible.
- Corregida la escritura del pasteboard de AppKit para arrastres internos, arrastres de varios archivos y reglas de copiar/mover estilo Finder.
- Añadidas pruebas de regresión para el área de archivos AppKit, drag pasteboard, desplazamiento con teclado y selección.

### Português

- A área de arquivos agora usa controles AppKit nativos do macOS: `NSTableView` no modo lista e `NSCollectionView` nos modos arquivos/pré-visualização, mantendo a estrutura SwiftUI externa.
- `ExplorerModel` continua sendo a única fonte de estado de negócio; AppKit cuida apenas de renderização, seleção, arrastar e soltar, menus de contexto e ponte de eventos.
- Melhorias em redimensionamento de colunas, ordenação por cabeçalho, seleção pelo teclado, foco e estabilidade da área de arquivos em três painéis.
- Corrigido o problema em que a seleção pelo teclado para baixo não rolava automaticamente o item selecionado para a área visível.
- Corrigida a gravação do pasteboard de drag do AppKit para drags internos, drags de vários arquivos e regras de copiar/mover no estilo Finder.
- Adicionados testes de regressão para a área de arquivos AppKit, drag pasteboard, rolagem pelo teclado e seleção.

### Русский

- Область файлов переведена на нативные элементы AppKit для macOS: `NSTableView` для режима списка и `NSCollectionView` для режимов файлов/предпросмотра, при этом внешняя структура SwiftUI сохранена.
- `ExplorerModel` остается единственным источником бизнес-состояния; AppKit отвечает только за отображение файлов, выбор, drag-and-drop, контекстные меню и мост событий.
- Улучшена стабильность изменения ширины колонок, сортировки по заголовкам, выбора с клавиатуры, переключения фокуса и файловой области в трехпанельном режиме.
- Исправлено: при выборе файлов клавиатурой вниз новый выбранный элемент не прокручивался в видимую область.
- Исправлена запись AppKit drag pasteboard для внутренних перетаскиваний, перетаскивания нескольких файлов и правил копирования/перемещения в стиле Finder.
- Добавлены регрессионные тесты для AppKit-файловой области, drag pasteboard, прокрутки с клавиатуры и поведения выбора.
