import AVFoundation
import SwiftUI
import Vision
import YahpazDomain

struct PlateScanView: View {
    var onDismiss: () -> Void
    var onPlateScanned: (String) -> Void

    @State private var statusText = "כוונו את המצלמה ללוחית"
    @State private var previewHint: String?
    @State private var permissionDenied = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if !permissionDenied {
                CameraPreview(
                    onText: handleOCR,
                    onCameraError: { statusText = "לא ניתן לפתוח את המצלמה" }
                )
                .ignoresSafeArea()
            }
            VStack {
                HStack {
                    Text("סריקה ניסיונית")
                        .font(TypeScale.label)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    .accessibilityLabel("סגירה")
                }
                Spacer()
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(FieldTheme.accent, lineWidth: 2)
                    .frame(height: 120)
                VStack(alignment: .leading, spacing: 6) {
                    Text(statusText)
                        .font(TypeScale.bodyStrong)
                        .foregroundStyle(.white)
                    if let previewHint {
                        Text(previewHint)
                            .font(TypeScale.numeric)
                            .foregroundStyle(FieldTheme.accent)
                    }
                    if permissionDenied {
                        Button("אפשרו מצלמה") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(TypeScale.bodyStrong)
                        .foregroundStyle(FieldTheme.accent)
                    } else {
                        Button("הקלדה ידנית", action: onDismiss)
                            .font(TypeScale.body)
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.black.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(16)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .task { await requestCamera() }
    }

    private func requestCamera() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionDenied = false
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permissionDenied = !granted
            if !granted { statusText = "נדרשת הרשאת מצלמה לסריקה" }
        default:
            permissionDenied = true
            statusText = "נדרשת הרשאת מצלמה לסריקה"
        }
    }

    private func handleOCR(_ text: String, confirm: (String?) -> String?) {
        let top = extractIsraeliPlateCandidates(text).first
        let confirmed = confirm(top)
        previewHint = top.map(formatPlate)
        statusText = {
            if let confirmed { return "מזהה \(formatPlate(confirmed))…" }
            if let top { return "מזהה \(formatPlate(top))…" }
            return "כוונו את המצלמה ללוחית"
        }()
        if let confirmed {
            onPlateScanned(confirmed)
        }
    }
}

private struct CameraPreview: UIViewRepresentable {
    var onText: (_ text: String, _ confirm: (String?) -> String?) -> Void
    var onCameraError: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onText: onText)
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        context.coordinator.attach(to: view, onCameraError: onCameraError)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    static func dismantleUIView(_ uiView: PreviewView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        private let onText: (_ text: String, _ confirm: (String?) -> String?) -> Void
        private let session = AVCaptureSession()
        private let output = AVCaptureVideoDataOutput()
        private let queue = DispatchQueue(label: "yahpaz.plate-scan")
        private var confirmState = PlateScanConfirmState()
        private var delivered = false
        private var busy = false

        init(onText: @escaping (_ text: String, _ confirm: (String?) -> String?) -> Void) {
            self.onText = onText
        }

        func attach(to view: PreviewView, onCameraError: @escaping () -> Void) {
            session.beginConfiguration()
            session.sessionPreset = .hd1280x720
            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input)
            else {
                session.commitConfiguration()
                DispatchQueue.main.async { onCameraError() }
                return
            }
            session.addInput(input)
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: queue)
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            view.previewLayer.session = session
            view.previewLayer.videoGravity = .resizeAspectFill
            session.commitConfiguration()
            queue.async { [session] in
                session.startRunning()
            }
        }

        func stop() {
            queue.async { [session] in
                if session.isRunning { session.stopRunning() }
            }
        }

        func captureOutput(
            _ output: AVCaptureOutput,
            didOutput sampleBuffer: CMSampleBuffer,
            from connection: AVCaptureConnection
        ) {
            if delivered || busy { return }
            busy = true
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                busy = false
                return
            }
            let request = VNRecognizeTextRequest { [weak self] request, _ in
                defer { self?.busy = false }
                guard let self, !self.delivered else { return }
                let text = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                DispatchQueue.main.async {
                    self.onText(text) { top in
                        let next = advancePlateScanConfirm(self.confirmState, topCandidate: top)
                        self.confirmState = next.state
                        if next.confirmed != nil {
                            self.delivered = true
                        }
                        return next.confirmed
                    }
                }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            try? handler.perform([request])
        }
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
