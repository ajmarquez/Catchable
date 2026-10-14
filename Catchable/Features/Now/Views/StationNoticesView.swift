import SwiftUI
import Translation

struct StationNoticesView: View {
    let station: String
    let notices: [ServiceNotice]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(station).font(.headline)
                    Text("Information supplied by the transit provider. Some station-display announcements may not be available.")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(notices) { notice in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(notice.text).textSelection(.enabled)
                            if #available(iOS 17.4, *) {
                                NativeNoticeTranslation(text: notice.text)
                            } else {
                                Text("Translation requires iOS 17.4 or later.").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Divider()
                    }
                }.padding()
            }.background(.white)
                .navigationTitle("Announcements")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

@available(iOS 17.4, *)
private struct NativeNoticeTranslation: View {
    let text: String
    @State private var translating = false
    var body: some View {
        Button("Translate", systemImage: "translate") { translating = true }
            .translationPresentation(isPresented: $translating, text: text)
    }
}
