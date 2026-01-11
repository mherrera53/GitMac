import SwiftUI
import AppKit

// MARK: - Nodo de sistema de archivos
final class FileSystemNode: NSObject, @unchecked Sendable {
    let url: URL
    let isDirectory: Bool
    private(set) var children: [FileSystemNode]?
    private var didLoad = false

    init(url: URL) {
        self.url = url
        var isDir: ObjCBool = false
        _ = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        self.isDirectory = isDir.boolValue
        super.init()
    }

    func loadChildren() {
        guard isDirectory, !didLoad else { return }
        defer { didLoad = true }

        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .localizedNameKey], options: [.skipsHiddenFiles]) else {
            children = []
            return
        }

        var result: [FileSystemNode] = []
        result.reserveCapacity(items.count)

        for u in items {
            if u.lastPathComponent == ".git" { continue }
            result.append(FileSystemNode(url: u))
        }

        result.sort { a, b in
            if a.isDirectory && !b.isDirectory { return true }
            if !a.isDirectory && b.isDirectory { return false }
            return a.url.lastPathComponent.localizedCaseInsensitiveCompare(b.url.lastPathComponent) == .orderedAscending
        }

        children = result
    }
}

// MARK: - Icon cache
@MainActor
final class FileIconCache {
    static let shared = FileIconCache()
    private let cache = NSCache<NSString, NSImage>()

    func icon(for url: URL) -> NSImage {
        let key = url.path as NSString
        if let img = cache.object(forKey: key) { return img }
        let img = NSWorkspace.shared.icon(forFile: url.path)
        img.size = NSSize(width: 16, height: 16)
        cache.setObject(img, forKey: key)
        return img
    }
}

// MARK: - NSOutlineView bridge
struct OutlineFileBrowserView: NSViewRepresentable {
    let rootURL: URL
    var onOpen: ((URL) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onOpen: onOpen)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        let outline = NSOutlineView()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col"))
        column.title = "Files"
        outline.addTableColumn(column)
        outline.outlineTableColumn = column
        outline.headerView = nil
        outline.rowHeight = 22
        outline.delegate = context.coordinator
        outline.dataSource = context.coordinator
        outline.doubleAction = #selector(Coordinator.doubleClick(_:))
        outline.target = context.coordinator

        let clip = NSClipView()
        clip.documentView = outline
        scroll.contentView = clip
        scroll.hasVerticalScroller = true

        context.coordinator.outlineView = outline
        context.coordinator.root = FileSystemNode(url: rootURL)
        outline.reloadData()
        outline.expandItem(nil, expandChildren: true) // Expand raíz

        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // No-op por ahora
    }

    final class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
        var outlineView: NSOutlineView?
        var root: FileSystemNode?
        let onOpen: ((URL) -> Void)?

        init(onOpen: ((URL) -> Void)?) {
            self.onOpen = onOpen
        }

        // DataSource
        func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            let node = (item as? FileSystemNode) ?? root
            node?.loadChildren()
            return node?.children?.count ?? 0
        }

        func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            guard let node = item as? FileSystemNode else { return false }
            return node.isDirectory
        }

        func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            let node = (item as? FileSystemNode) ?? root
            return node?.children?[index] as Any
        }

        // Delegate
        func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
            guard let node = item as? FileSystemNode else { return nil }
            let id = NSUserInterfaceItemIdentifier("cell")
            let view = outlineView.makeView(withIdentifier: id, owner: self) as? NSTableCellView ?? {
                let v = NSTableCellView()
                v.identifier = id
                let img = NSImageView()
                let txt = NSTextField(labelWithString: "")
                txt.lineBreakMode = .byTruncatingMiddle
                txt.translatesAutoresizingMaskIntoConstraints = false
                img.translatesAutoresizingMaskIntoConstraints = false
                v.addSubview(img)
                v.addSubview(txt)
                v.imageView = img
                v.textField = txt
                NSLayoutConstraint.activate([
                    v.imageView!.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 4),
                    v.imageView!.centerYAnchor.constraint(equalTo: v.centerYAnchor),
                    v.imageView!.widthAnchor.constraint(equalToConstant: 16),
                    v.imageView!.heightAnchor.constraint(equalToConstant: 16),

                    v.textField!.leadingAnchor.constraint(equalTo: v.imageView!.trailingAnchor, constant: 6),
                    v.textField!.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -4),
                    v.textField!.centerYAnchor.constraint(equalTo: v.centerYAnchor)
                ])
                return v
            }()

            view.imageView?.image = FileIconCache.shared.icon(for: node.url)
            view.textField?.stringValue = node.url.lastPathComponent
            return view
        }

        @MainActor @objc func doubleClick(_ sender: Any?) {
            guard let outline = outlineView else { return }
            let row = outline.clickedRow
            guard row >= 0,
                  let node = outline.item(atRow: row) as? FileSystemNode else { return }

            if node.isDirectory {
                if outline.isItemExpanded(node) {
                    outline.collapseItem(node)
                } else {
                    outline.expandItem(node)
                }
            } else {
                if let onOpen { onOpen(node.url) }
                else { NSWorkspace.shared.open(node.url) }
            }
        }

        @MainActor func outlineView(_ outlineView: NSOutlineView, menuFor event: NSEvent) -> NSMenu? {
            let menu = NSMenu()
            let row = outlineView.row(at: outlineView.convert(event.locationInWindow, from: nil))
            guard row >= 0, let node = outlineView.item(atRow: row) as? FileSystemNode else { return nil }

            menu.addItem(withTitle: "Revelar en Finder", action: #selector(revealInFinder(_:)), keyEquivalent: "")
            menu.addItem(withTitle: "Abrir", action: #selector(open(_:)), keyEquivalent: "")
            menu.addItem(withTitle: "Copiar ruta", action: #selector(copyPath(_:)), keyEquivalent: "")

            menu.items.forEach { $0.representedObject = node }
            return menu
        }

        @objc private func revealInFinder(_ sender: NSMenuItem) {
            guard let node = sender.representedObject as? FileSystemNode else { return }
            NSWorkspace.shared.activateFileViewerSelecting([node.url])
        }

        @objc private func open(_ sender: NSMenuItem) {
            guard let node = sender.representedObject as? FileSystemNode else { return }
            if let onOpen { onOpen(node.url) } else { NSWorkspace.shared.open(node.url) }
        }

        @objc private func copyPath(_ sender: NSMenuItem) {
            guard let node = sender.representedObject as? FileSystemNode else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(node.url.path, forType: .string)
        }
    }
}

// MARK: - SwiftUI wrapper listo para usar
struct FileBrowserView: View {
    let repoPath: String
    var onOpen: ((URL) -> Void)? = nil

    var body: some View {
        OutlineFileBrowserView(rootURL: URL(fileURLWithPath: repoPath), onOpen: onOpen)
            .frame(minWidth: 240)
    }
}
