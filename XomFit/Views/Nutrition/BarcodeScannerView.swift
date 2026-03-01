import SwiftUI
import AVFoundation
import Vision

struct BarcodeScannerView: View {
    @ObservedObject var viewModel: NutritionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var scannedFood: Food?
    @State private var errorMessage: String?
    @State private var isScanning = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isScanning {
                    BarcodeCameraView { barcode in
                        handleBarcode(barcode)
                    }
                    .ignoresSafeArea()
                    
                    // Scan overlay
                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Theme.accent, lineWidth: 3)
                            .frame(width: 280, height: 180)
                        Spacer()
                        
                        Text("Point camera at barcode")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                            .padding(.bottom, 40)
                    }
                }
                
                if let food = scannedFood {
                    FoodSearchView(viewModel: viewModel)
                }
                
                if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text(error)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Try Again") {
                            errorMessage = nil
                            isScanning = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func handleBarcode(_ barcode: String) {
        isScanning = false
        if let food = NutritionService.shared.lookupBarcode(barcode) {
            scannedFood = food
        } else {
            errorMessage = "Food not found for barcode: \(barcode)\nTry searching manually."
        }
    }
}

// MARK: - Camera View (UIViewRepresentable)

struct BarcodeCameraView: UIViewRepresentable {
    let onBarcodeScanned: (String) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        context.coordinator.setupCamera(in: view)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcodeScanned: onBarcodeScanned)
    }
    
    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        let onBarcodeScanned: (String) -> Void
        private var captureSession: AVCaptureSession?
        private var hasScanned = false
        
        init(onBarcodeScanned: @escaping (String) -> Void) {
            self.onBarcodeScanned = onBarcodeScanned
        }
        
        func setupCamera(in view: UIView) {
            let session = AVCaptureSession()
            session.sessionPreset = .high
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else { return }
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "barcode.scan"))
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = UIScreen.main.bounds
            view.layer.addSublayer(previewLayer)
            
            self.captureSession = session
            
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }
        
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard !hasScanned,
                  let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            let request = VNDetectBarcodesRequest { [weak self] request, error in
                guard let results = request.results as? [VNBarcodeObservation],
                      let barcode = results.first,
                      let payload = barcode.payloadStringValue,
                      (barcode.symbology == .ean13 || barcode.symbology == .upce) else { return }
                
                self?.hasScanned = true
                self?.captureSession?.stopRunning()
                
                DispatchQueue.main.async {
                    self?.onBarcodeScanned(payload)
                }
            }
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            try? handler.perform([request])
        }
    }
}
