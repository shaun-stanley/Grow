import AVFoundation
import Foundation
import Observation
import UIKit

enum CameraCaptureStatus: Equatable {
    case idle
    case requestingAccess
    case configuring
    case ready
    case capturing
    case unavailable(String)
    case denied
    case failed(String)

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }

    var message: String {
        switch self {
        case .idle, .requestingAccess:
            "Preparing camera"
        case .configuring:
            "Opening the viewfinder"
        case .ready:
            "Ready"
        case .capturing:
            "Saving today's frame"
        case .unavailable(let reason), .failed(let reason):
            reason
        case .denied:
            "Camera access is off. You can enable it in Settings or import a plant photo."
        }
    }
}

@Observable
final class CameraCaptureService: NSObject {
    static var isCameraAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.sviftstudios.Grow.camera.session")
    private var isConfigured = false
    private var delegates: [Int64: PhotoCaptureDelegate] = [:]

    var status: CameraCaptureStatus = .idle

    var canCapture: Bool {
        status.isReady
    }

    func prepare() {
        guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil else {
            status = .unavailable("Camera is not available on this device. Import a plant photo or use simulator capture.")
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            status = .requestingAccess
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    granted ? self.configureAndStart() : (self.status = .denied)
                }
            }
        case .denied, .restricted:
            status = .denied
        @unknown default:
            status = .failed("Grow could not determine camera permission.")
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func capturePhoto(completion: @escaping (Result<Data, Error>) -> Void) {
        guard status.isReady else { return }
        status = .capturing

        sessionQueue.async { [weak self] in
            guard let self else { return }

            let settings = AVCapturePhotoSettings()
            if self.photoOutput.maxPhotoQualityPrioritization.rawValue >= AVCapturePhotoOutput.QualityPrioritization.quality.rawValue {
                settings.photoQualityPrioritization = .quality
            }

            let settingsID = settings.uniqueID
            let delegate = PhotoCaptureDelegate { result in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.status = result.isSuccess ? .ready : .failed(result.failureMessage ?? "Grow could not capture that frame.")
                    completion(result)
                    self.delegates.removeValue(forKey: settingsID)
                }
            }

            self.delegates[settingsID] = delegate
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    private func configureAndStart() {
        status = .configuring

        sessionQueue.async { [weak self] in
            guard let self else { return }

            do {
                if !self.isConfigured {
                    try self.configureSession()
                    self.isConfigured = true
                }

                if !self.session.isRunning {
                    self.session.startRunning()
                }

                Task { @MainActor in
                    self.status = self.session.isRunning ? .ready : .failed("Grow could not start the camera.")
                }
            } catch {
                Task { @MainActor in
                    self.status = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraCaptureError.noCamera
        }

        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else {
            throw CameraCaptureError.cannotAddInput
        }
        session.addInput(input)

        guard session.canAddOutput(photoOutput) else {
            throw CameraCaptureError.cannotAddOutput
        }
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality
    }
}

nonisolated private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<Data, Error>) -> Void

    init(completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            completion(.failure(error))
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            completion(.failure(CameraCaptureError.noPhotoData))
            return
        }

        completion(.success(data))
    }
}

private enum CameraCaptureError: LocalizedError {
    case noCamera
    case cannotAddInput
    case cannotAddOutput
    case noPhotoData

    var errorDescription: String? {
        switch self {
        case .noCamera:
            "Grow could not find a back camera."
        case .cannotAddInput:
            "Grow could not connect to the camera."
        case .cannotAddOutput:
            "Grow could not prepare photo capture."
        case .noPhotoData:
            "Grow could not read the captured frame."
        }
    }
}

private extension Result where Success == Data, Failure == Error {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var failureMessage: String? {
        if case .failure(let error) = self { return error.localizedDescription }
        return nil
    }
}
