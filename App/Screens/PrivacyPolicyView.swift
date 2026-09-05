import SwiftUI
import WebKit
import YahpazDomain

struct PrivacyPolicyView: View {
    let onClose: () -> Void
    @State private var loading = true
    @State private var failed = false
    @State private var reloadKey = 0

    private var privacyURL: URL {
        let token = createPrivacyPageToken(
            secret: AppConfig.privacyPageSecret,
            nowSec: Int64(Date().timeIntervalSince1970)
        )
        return URL(string: buildPrivacyPolicyUrl(origin: AppConfig.appOriginString, token: token))!
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                PrivacyWebView(
                    url: privacyURL,
                    reloadKey: reloadKey,
                    onLoading: { loading = $0 },
                    onFailed: { failed = $0 }
                )
                .environment(\.layoutDirection, .leftToRight)
                if loading && !failed {
                    ProgressView()
                        .tint(FieldTheme.accent)
                }
                if failed {
                    VStack(spacing: 12) {
                        Text("טעינת מדיניות הפרטיות נכשלה.")
                            .font(TypeScale.body)
                            .foregroundStyle(FieldTheme.textPrimary)
                            .multilineTextAlignment(.center)
                        PrimaryButton(title: "ניסיון נוסף") {
                            failed = false
                            loading = true
                            reloadKey += 1
                        }
                        GhostButton(title: "סגירה", action: onClose)
                    }
                    .padding(24)
                    .background(FieldTheme.page)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(FieldTheme.page.ignoresSafeArea())
            .navigationTitle("מדיניות פרטיות")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("סגירה", action: onClose)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "he"))
    }
}

private struct PrivacyWebView: UIViewRepresentable {
    let url: URL
    let reloadKey: Int
    var onLoading: (Bool) -> Void
    var onFailed: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoading: onLoading, onFailed: onFailed)
    }

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.navigationDelegate = context.coordinator
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onLoading = onLoading
        context.coordinator.onFailed = onFailed
        if context.coordinator.reloadKey != reloadKey {
            context.coordinator.reloadKey = reloadKey
            onLoading(true)
            onFailed(false)
            uiView.load(URLRequest(url: url))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onLoading: (Bool) -> Void
        var onFailed: (Bool) -> Void
        var reloadKey = 0

        init(onLoading: @escaping (Bool) -> Void, onFailed: @escaping (Bool) -> Void) {
            self.onLoading = onLoading
            self.onFailed = onFailed
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            onLoading(true)
            onFailed(false)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onLoading(false)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onLoading(false)
            onFailed(true)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            onLoading(false)
            onFailed(true)
        }
    }
}
