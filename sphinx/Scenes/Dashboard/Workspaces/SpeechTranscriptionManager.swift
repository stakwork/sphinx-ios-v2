//
//  SpeechTranscriptionManager.swift
//  sphinx
//
//  Wraps AVAudioEngine + SFSpeechRecognizer to provide live speech-to-text.
//

import Speech
import AVFoundation

final class SpeechTranscriptionManager: @unchecked Sendable {
    private let recognizer = SFSpeechRecognizer(locale: Locale.current)
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var isRunning = false

    /// Cleared before we cancel so the completion callback never fires into the caller.
    private var activeTextHandler: ((String) -> Void)?
    private var activeErrorHandler: ((Error) -> Void)?

    func requestPermission(completion: @escaping @Sendable (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in completion(status == .authorized) }
        }
    }

    func startTranscribing(
        textHandler: @escaping (String) -> Void,
        errorHandler: @escaping (Error) -> Void
    ) {
        guard !isRunning else { return }
        isRunning = true
        activeTextHandler = textHandler
        activeErrorHandler = errorHandler

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        audioEngine.prepare()
        try? audioEngine.start()

        recognitionTask = recognizer?.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            guard let self else { return }
            if let result = result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor [weak self] in self?.activeTextHandler?(text) }
            }
            if let error = error {
                // Ignore cancellation — that's us stopping intentionally.
                let nsErr = error as NSError
                let isCancelled = nsErr.domain == "kAFAssistantErrorDomain" && nsErr.code == 216
                    || nsErr.domain == NSCocoaErrorDomain && nsErr.code == NSUserCancelledError
                    || nsErr.domain == "kAFAssistantErrorDomain" && nsErr.code == 0
                    || nsErr.code == 301  // AVAudioSession interruption / session deactivated
                if !isCancelled {
                    Task { @MainActor [weak self] in self?.activeErrorHandler?(error) }
                }
            }
        }
    }

    func stopTranscribing() {
        guard isRunning else { return }
        isRunning = false
        // Nil out handlers BEFORE cancelling so the callback can't call back into the VC.
        activeTextHandler = nil
        activeErrorHandler = nil

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setCategory(.playback)
    }
}
