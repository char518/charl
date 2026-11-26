import AppKit
import CharlCore
import SwiftUI

final class ClipboardPreviewController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    var onClose: (() -> Void)?

    func show(item: ClipboardItem, image: NSImage?) {
        close()
        let view = ClipboardPreviewView(item: item, image: image) { [weak self] in self?.close() }
        let hosting = NSHostingView(rootView: view)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 460),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = loc("剪贴板预览", "Clipboard Preview")
        panel.contentView = hosting
        panel.level = .floating
        panel.center()
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.makeKeyAndOrderFront(nil)
        DisplayScaling.apply(to: panel)
        self.panel = panel
    }

    func close() {
        guard let value = panel else { return }
        panel = nil
        value.delegate = nil
        value.close()
        onClose?()
    }

    func windowWillClose(_ notification: Notification) { close() }
    func windowDidResignKey(_ notification: Notification) { close() }
}

private struct ClipboardPreviewView: View {
    let item: ClipboardItem
    let image: NSImage?
    let onClose: () -> Void

    private var kindTitle: String {
        if item.kind == .image { return loc("图片", "Image") }
        return item.isLink ? loc("链接", "Link") : loc("文本", "Text")
    }

    private var metadata: String {
        if item.kind == .image {
            return "\(item.imageWidth ?? 0) × \(item.imageHeight ?? 0) px"
        }
        return loc("\(item.characterCount) 字符", item.characterCount == 1 ? "1 char" : "\(item.characterCount) chars")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                AppIconView(bundleID: item.sourceBundleID, name: item.sourceApp ?? loc("剪贴板", "Clipboard"), size: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.sourceApp ?? loc("剪贴板", "Clipboard"))
                        .font(.system(size: 13, weight: .semibold))
                    Text(loc("仅预览，不会修改系统剪贴板", "Preview only — the system clipboard is unchanged"))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.tertiary)
                }
                Spacer()
                Chip(text: kindTitle, tint: Theme.secondary)
            }
            .padding(16)
            Hairline()

            if let image {
                ZStack {
                    Checkerboard()
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(18)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(item.text ?? item.preview)
                        .font(.system(size: 13))
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Hairline()
            HStack(spacing: 8) {
                Text(RelativeTime.string(for: item.createdAt))
                Text("·")
                Text(metadata)
                Spacer()
                Keycap(glyph: "esc")
                Button(loc("完成", "Done"), action: onClose)
                    .keyboardShortcut(.escape, modifiers: [])
                    .controlSize(.small)
            }
            .font(.system(size: 10.5))
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
        }
        .frame(minWidth: 440, minHeight: 300)
        .background(Theme.windowBackground)
    }
}
