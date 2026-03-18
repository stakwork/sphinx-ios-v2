//
//  SpeechTranscriptionManager.swift
//  sphinx
//
//  Wraps AVAudioEngine + SFSpeechRecognizer to provide live speech-to-text.
//

import Speech
import AVFoundation

final class SpeechTranscriptionManager {
    private let recognizer = SFSpeechRecognizer(locale: Locale.current)
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var isRunning = false

    func requestPermission(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async { completion(status == .authorized) }
        }
    }

    func startTranscribing(
        textHandler: @escaping (String) -> Void,
        errorHandler: @escaping (Error) -> Void
    ) {
        guard !isRunning else { return }
        isRunning = true
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
        recognitionTask = recognizer?.recognitionTask(with: recognitionRequest!) { result, error in
            if let result = result {
                DispatchQueue.main.async { textHandler(result.bestTranscription.formattedString) }
            }
            if let error = error {
                DispatchQueue.main.async { errorHandler(error) }
            }
        }
    }

    func stopTranscribing() {
        guard isRunning else { return }
        isRunning = false
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setCategory(.playback)
    }
}
