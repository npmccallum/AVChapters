import XCTest
import AVFoundation
import AVChapters

class BlankVideoWriter {
    var duration: CMTime

    private let frameRate: Int32 = 30
    private let size: CGSize = CGSize(width: 1920, height: 1080)
    private let movie: AVAssetWriter
    private let video: AVAssetWriterInput
    private let text: AVAssetWriterInput?
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private var lastChapter: Chapter? = nil

    init(url: URL, chapters: Bool) throws {
        duration = CMTime(value: 0, timescale: frameRate)

        movie = try AVAssetWriter(outputURL: url, fileType: .mov)
        video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height
        ])

        video.expectsMediaDataInRealTime = true
        assert(movie.canAdd(video))
        movie.add(video)

        adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: video,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: size.width,
                kCVPixelBufferHeightKey as String: size.height
            ]
        )

        text = switch chapters {
        case true: AVAssetWriterInput(mediaType: .text, outputSettings: nil)
        case false: nil
        }

        if let text = self.text {
            let chapterList = AVAssetTrack.AssociationType.chapterList.rawValue
            video.addTrackAssociation(withTrackOf: text, type: chapterList)
            text.expectsMediaDataInRealTime = true
            text.marksOutputTrackAsEnabled = false
            text.languageCode = "en"
            assert(movie.canAdd(text))
            movie.add(text)
        }
    }

    func start() {
        lastChapter = nil
        duration.value = 0
        assert(movie.startWriting())
        movie.startSession(atSourceTime: .zero)
    }

    func mark() throws {
        guard let text = text else { return }

        let start: CMTime = if let last = lastChapter {
            last.time.end
        } else {
            .zero
        }

        let chapter = Chapter(
            name: "Mark",
            time: CMTimeRange(start: start, end: self.duration)
        )

        try text.append(chapter.toTextSampleBuffer())
        lastChapter = chapter
    }

    func appendBlankFrame() async throws -> Bool {
        // Create the buffer.
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pixelBuffer)
        assert(status == kCVReturnSuccess)
        guard let buffer = pixelBuffer else { return false }

        // Clear the pixel buffer (set to black)
        CVPixelBufferLockBaseAddress(buffer, [])
        let baseAddress = CVPixelBufferGetBaseAddress(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        memset(baseAddress, 0, bytesPerRow * height)
        CVPixelBufferUnlockBaseAddress(buffer, [])

        // Wait until the writer is ready for more data
        while !video.isReadyForMoreMediaData {
            try await Task.sleep(nanoseconds: 1_000_000)
        }

        if adaptor.append(buffer, withPresentationTime: self.duration) {
            self.duration.value += 1
            return true
        }

        return false
    }

    func stop() async {
        video.markAsFinished()
        await movie.finishWriting()
    }
}

final class Tests: XCTestCase {
    var tempfile: URL?

    override func setUp() {
        tempfile = URL(
            fileURLWithPath: NSTemporaryDirectory(),
            isDirectory: true
        )
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("mov")
    }

    override func tearDownWithError() throws {
        if let file = tempfile {
            try FileManager.default.removeItem(at: file)
            tempfile = nil
        }
    }

    func writeVideo(_ chapters: Bool) async throws {
        let writer = try BlankVideoWriter(url: tempfile!, chapters: chapters)

        writer.start()

        // Write three second of video...
        for _ in 0..<3 {
            for _ in 0..<writer.duration.timescale {
                let result = try await writer.appendBlankFrame()
                assert(result)
            }

            // ... with chapters every second.
            try writer.mark()
        }

        await writer.stop()
    }

    func addChapters() async throws {
        // Modify the movie.
        let movie = AVMutableMovie(url: tempfile!)
        movie.defaultMediaDataStorage = AVMediaDataStorage(url: tempfile!)

        // Load the video track.
        let video = try await movie.loadTracks(withMediaType: .video).first!
        assert(video.associatedTracks(ofType: .chapterList).isEmpty)

        // Create the chapters.
        let outputChapters = (0..<3).map { i in
            Chapter (
                name: "Mark",
                time: CMTimeRange(
                    start: CMTime(value: i * 30, timescale: 30),
                    duration: CMTime(value: 30, timescale: 30)
                )
            )
        }

        // Write out the chapters track.
        let track = try movie.writeChapters(
            outputChapters,
            asLanguage: "eng"
        )

        video.addTrackAssociation(to: track, type: .chapterList)
        try movie.writeHeader(to: tempfile!, fileType: .mov)
    }

    func checkChapters() async throws {
        let asset = AVURLAsset(url: tempfile!)
        let metadata = try await asset.load(.availableChapterLocales)
        let language = metadata.first!.language.languageCode!.identifier
        let chapters = try await asset.readChapters(bestMatchingPreferredLanguages: [language])

        assert(chapters.count == 3)
        for (i, chapter) in chapters.enumerated() {
            assert(chapter.name == "Mark")
            assert(chapter.time.start.seconds == Double(i))
            assert(chapter.time.duration.seconds == 1)
        }
    }

    func checkEmptyChapters() async throws {
        let chapters = try await AVURLAsset(url: tempfile!)
            .readChapters(bestMatchingPreferredLanguages: [])
        assert(chapters.isEmpty)
    }

    func testAssetWriter() async throws {
        try await writeVideo(true)
        try await checkChapters()
    }

    func testMutableMovie() async throws {
        try await writeVideo(false)
        try await checkEmptyChapters()
        try await addChapters()
        try await checkChapters()
    }
}
