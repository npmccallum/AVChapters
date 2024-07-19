import AVFoundation

extension AVMutableMovie {
    /// A convenience function for writing chapters into a movie file.
    ///
    /// This function checks a bunch of invariants to ensure the resulting chapter track is valid.
    /// For example, tracks must span the entirety of their corresponding track. Likewise, the
    /// chapters must be contiguous.
    ///
    /// You must make sure to associate this resulting track with the main track. For example:
    ///
    /// ```swift
    /// let cTrack = mutableMovie.writeChaptersTrack(...)
    /// let vTracks = try await mutableMovie.loadTracks(withMediaType: .video)
    /// vTracks.first!.addTrackAssociation(to: cTrack, type: .chapterList)
    /// ```
    public func writeChapters(
        _ chapters: [Chapter],
        asLanguage: String? = nil,
        to: AVMediaDataStorage? = nil,
        options: [String : Any]? = nil
    ) throws -> AVMutableMovieTrack {
        // An empty chapter list track is invalid.
        if chapters.isEmpty {
            throw AVError(AVError.invalidVideoComposition)
        }

        // Ensure that chapter starts align.
        for (i, chapter) in chapters.enumerated() {
            let prev: CMTime = if i == 0 {
                .zero
            } else {
                chapters[i - 1].time.end
            }

            if chapter.time.start != prev {
                throw AVError(AVError.compositionTrackSegmentsNotContiguous)
            }
        }

        // Ensure the final chapter end aligns to the video track.
        if chapters.last!.time.end != duration {
            throw AVError(AVError.invalidCompositionTrackSegmentDuration)
        }

        // Create the chapters track.
        guard let track = addMutableTrack(
            withMediaType: .text,
            copySettingsFrom: nil,
            options: options
        ) else {
            throw AVError(AVError.unknown)
        }

        // Set up the parameters.
        track.mediaDataStorage = to ?? self.defaultMediaDataStorage
        track.languageCode = asLanguage
        track.isEnabled = false

        // Add all the chapters.
        for chapter in chapters {
            let buffer = try chapter.toTextSampleBuffer()
            try track.append(buffer, decodeTime: nil, presentationTime: nil)
            if !track.insertMediaTimeRange(chapter.time, into: chapter.time) {
                throw AVError(AVError.unknown)
            }
        }

        return track
    }
}
