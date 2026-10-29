import SwiftUI
import AppKit

/// A field title followed by an info button that explains the field, like Push Hero's inline docs.
struct HelpLabel: View {
    let title: String
    let help: String

    init(_ title: String, _ help: String) {
        self.title = title
        self.help = help
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            InfoButton(text: help)
        }
    }
}

struct InfoButton: View {
    let text: String
    @State private var isShowing = false

    var body: some View {
        Button {
            isShowing.toggle()
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .imageScale(.small)
        }
        .buttonStyle(.plain)
        .help("Explain this field")
        .popover(isPresented: $isShowing, arrowEdge: .bottom) {
            Text(text)
                .font(.callout)
                .textSelection(.enabled)
                .frame(width: 340, alignment: .leading)
                .padding()
        }
    }
}

struct CopyButton: View {
    let text: String
    var label: String = "Copy"

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        } label: {
            Label(label, systemImage: "doc.on.doc")
        }
        .disabled(text.isEmpty)
    }
}

struct StatusDot: View {
    let item: SendHistoryItem

    var color: Color {
        if item.localError != nil { return .orange }
        return item.isSuccess ? .green : .red
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
    }
}

struct MonospacedBlock: View {
    let text: String

    var body: some View {
        ScrollView(.horizontal) {
            Text(text.isEmpty ? "(empty)" : text)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct ToastView: View {
    let toast: Toast

    private var symbol: String {
        switch toast.style {
        case .success: return "checkmark.circle.fill"
        case .failure: return "xmark.octagon.fill"
        case .info: return "info.circle.fill"
        }
    }

    private var tint: Color {
        switch toast.style {
        case .success: return .green
        case .failure: return .red
        case .info: return .blue
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title).font(.headline)
                if let detail = toast.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 460, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
    }
}

struct SectionHeader: View {
    let title: String
    let symbol: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.headline)
    }
}
