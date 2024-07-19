import AVFoundation

public struct Chapter {
    public var name: String
    public var time: CMTimeRange

    /// Creates a new chapter with the given name and time.
    ///
    /// Please note that you are responsible to ensure that chapters have contiguous times.
    public init(name: String, time: CMTimeRange) {
        self.name = name
        self.time = time
    }

    /// Creates a text sample buffer for use in adding chapter samples to a text track.
    ///
    /// This can be used with multiple track creation approaches. For example, it should
    /// work with both `AVAssetWriter` and `AVMutableMovie`.
    public func toTextSampleBuffer(
        at timing: CMSampleTimingInfo? = nil,
        with ext: CMFormatDescription.Extensions? = nil
    ) throws -> CMSampleBuffer {
        // Create the timing info.
        let timingInfo = timing ?? CMSampleTimingInfo(
            duration: self.time.duration,
            presentationTimeStamp: self.time.start,
            decodeTimeStamp: self.time.start
        )

        // Create the text format description.
        let formatDescription = try CMTextFormatDescription(
            mediaType: .text,
            mediaSubType: .qt,
            extensions: ext ?? Chapter.defaultExtensions()
        )

        // Create the block buffer containing our sample data.
        let blockBuffer = try self.nameToBlockBuffer()

        // Create the full sample buffer.
        return try CMSampleBuffer(
            dataBuffer: blockBuffer,
            formatDescription: formatDescription,
            numSamples: 1,
            sampleTimings: [timingInfo],
            sampleSizes: [blockBuffer.dataLength]
        )
    }

    /// Creates a new text block buffer.
    ///
    /// This is the format that will go into the sample for a text track.
    ///
    /// The format is simple:
    ///   big-endian 16-bit length || unterminated UTF-8 data
    ///
    /// In the past, the QuickTime File Format specification suggested the
    /// use of an `encd` atom after this data. This atom is no longer
    /// mentioned in the QTFF spec. Further, there is a comment about the
    /// `encd` atom in the ffmpeg source code implying that this atom is not
    /// actually used in practice. Therefore, we are not appending it here.
    private func nameToBlockBuffer() throws -> CMBlockBuffer {
        let utf8Data = self.name.data(using: .utf8)!

        let blockBuffer = try CMBlockBuffer(length: 2 + utf8Data.count)
        try blockBuffer.assureBlockMemory()

        try blockBuffer.withUnsafeMutableBytes { dst in
            dst.storeBytes(
                of: CFSwapInt16HostToBig(UInt16(utf8Data.count)),
                as: UInt16.self
            )
        }

        if !utf8Data.isEmpty {
            try blockBuffer.withUnsafeMutableBytes(atOffset: 2) { dst in
                utf8Data.withUnsafeBytes { src in dst.copyMemory(from: src) }
            }
        }

        return blockBuffer
    }

    private static func defaultExtensions() -> CMFormatDescription.Extensions {
        var extensions = CMFormatDescription.Extensions()
        extensions[.textJustification] = .textJustification(.left)
        extensions[.displayFlags] = .textDisplayFlags([])

        extensions[.backgroundColor] = .qtTextColor(
            red: 0,
            green: 0,
            blue: 0,
            alpha: 0
        )

        extensions[.defaultTextBox] = .textRect(
            top: 0,
            left: 0,
            bottom: 0,
            right: 0
        )

        extensions[.defaultStyle] = .qtTextDefaultStyle(
            startChar: 0,
            height: 0,
            ascent: 0,
            localFontID: 0,
            fontFace: .all,
            fontSize: 0,
            foregroundColor: .qtTextColor(red: 0, green: 0, blue: 0, alpha: 0),
            defaultFontName: nil
        )

        return extensions
    }
}
