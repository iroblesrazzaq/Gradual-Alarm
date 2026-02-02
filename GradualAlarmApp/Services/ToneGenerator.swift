import Foundation

final class ToneGenerator {
    static let shared = ToneGenerator()

    private let sampleRate: Double = 44100
    private let duration: Double = 2.0
    private let tempDirectory: URL

    private init() {
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("GradualAlarmTones", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    func toneURL(for name: String, frequency: Double) -> URL? {
        let url = tempDirectory.appendingPathComponent("\(name).wav")
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        return writeTone(to: url, frequency: frequency) ? url : nil
    }

    private func writeTone(to url: URL, frequency: Double) -> Bool {
        let frameCount = Int(sampleRate * duration)
        var samples = [Int16](repeating: 0, count: frameCount)
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            let value = sin(2 * Double.pi * frequency * t)
            samples[i] = Int16(value * Double(Int16.max) * 0.4)
        }

        let byteRate = Int(sampleRate) * 2
        let dataSize = frameCount * 2
        var header = Data()
        header.append("RIFF".data(using: .ascii) ?? Data())
        header.append(UInt32(36 + dataSize).littleEndianData)
        header.append("WAVE".data(using: .ascii) ?? Data())
        header.append("fmt ".data(using: .ascii) ?? Data())
        header.append(UInt32(16).littleEndianData)
        header.append(UInt16(1).littleEndianData)
        header.append(UInt16(1).littleEndianData)
        header.append(UInt32(sampleRate).littleEndianData)
        header.append(UInt32(byteRate).littleEndianData)
        header.append(UInt16(2).littleEndianData)
        header.append(UInt16(16).littleEndianData)
        header.append("data".data(using: .ascii) ?? Data())
        header.append(UInt32(dataSize).littleEndianData)

        var data = Data()
        data.append(header)
        samples.withUnsafeBytes { buffer in
            data.append(buffer.bindMemory(to: UInt8.self))
        }

        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}

extension FixedWidthInteger {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<Self>.size)
    }
}
