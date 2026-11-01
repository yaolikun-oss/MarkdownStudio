import Foundation
import SwiftUI

/// Browser shortcuts are intentionally stored separately from reading bookmarks.
struct QuickSite: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var address: String

    static let defaults = [
        QuickSite(title: "ChatGPT", address: "https://chatgpt.com"),
        QuickSite(title: "Gemini", address: "https://gemini.google.com")
    ]

    static func decode(_ json: String) -> [QuickSite] {
        guard let data = json.data(using: .utf8),
              let sites = try? JSONDecoder().decode([QuickSite].self, from: data) else { return defaults }
        return sites
    }

    static func encode(_ sites: [QuickSite]) -> String {
        guard let data = try? JSONEncoder().encode(sites) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }
}

struct QuickSitesBar: View {
    @AppStorage("browser.quickSites.v1") private var storage = ""
    @State private var editing = false
    @State private var name = ""
    @State private var address = ""
    @State private var editingID: UUID?
    let currentURL: URL?
    let currentTitle: String
    let open: (URL) -> Void

    private var sites: [QuickSite] { QuickSite.decode(storage) }
    private func update(_ values: [QuickSite]) { storage = QuickSite.encode(values) }

    var body: some View {
        HStack(spacing: 5) {
            Text("常用网站").font(.system(size: 11)).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(sites) { site in
                        Button(site.title) { if let url = URL(string: site.address), WebBrowserSession.isWebURL(url) { open(url) } }
                            .buttonStyle(.plain).font(.system(size: 11)).lineLimit(1)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
                            .help("打开常用网站：\(site.address)")
                    }
                }
            }
            Button { editing.toggle() } label: { Image(systemName: "ellipsis.circle") }
                .buttonStyle(.plain).help("管理常用网站")
                .popover(isPresented: $editing) { management }
        }
        .padding(.horizontal, 9).frame(height: 29)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
    }

    private var management: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("常用网站").font(.headline)
            Text("快捷入口，与左侧的网页收藏分开保存。")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(Array(sites.enumerated()), id: \.element.id) { index, site in
                HStack {
                    VStack(alignment: .leading) {
                        Text(site.title).lineLimit(1)
                        Text(site.address).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Button { var a = sites; guard index > 0 else { return }; a.swapAt(index, index - 1); update(a) } label: { Image(systemName: "arrow.up") }
                        .disabled(index == 0).help("上移")
                    Button { var a = sites; guard index + 1 < a.count else { return }; a.swapAt(index, index + 1); update(a) } label: { Image(systemName: "arrow.down") }
                        .disabled(index + 1 == sites.count).help("下移")
                    Button { name = site.title; address = site.address; editingID = site.id } label: { Image(systemName: "pencil") }
                        .help("编辑常用网站")
                    Button { update(sites.filter { $0.id != site.id }) } label: { Image(systemName: "trash") }
                        .help("移除此快捷方式")
                }
            }
            Divider()
            TextField("名称", text: $name)
            TextField("网址", text: $address)
            HStack {
                Button("使用当前网页") { name = currentTitle; address = currentURL?.absoluteString ?? ""; editingID = nil }
                    .disabled(currentURL == nil)
                Spacer()
                if editingID != nil { Button("取消编辑") { name = ""; address = ""; editingID = nil } }
                Button(editingID == nil ? "添加" : "保存") {
                    let value = address.trimmingCharacters(in: .whitespacesAndNewlines)
                    let normalized = value.contains("://") ? value : "https://" + value
                    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          let url = URL(string: normalized), WebBrowserSession.isWebURL(url) else { return }
                    let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    var values = sites
                    if let id = editingID, let index = values.firstIndex(where: { $0.id == id }) {
                        values[index].title = title; values[index].address = url.absoluteString
                    } else { values.append(QuickSite(title: title, address: url.absoluteString)) }
                    update(values)
                    name = ""; address = ""; editingID = nil
                }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(14).frame(width: 330)
    }
}
