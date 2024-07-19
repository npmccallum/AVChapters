import AVFoundation

extension AVAsset {
    /// Reads chapters for the preferred languages.
    public func readChapters(
        bestMatchingPreferredLanguages preferredLanguages: [String]
    ) async throws -> [Chapter] {
        let chapterGroups = try await loadChapterMetadataGroups(
            bestMatchingPreferredLanguages: preferredLanguages
        )

        var chapters: [Chapter] = []

        for group in chapterGroups {
            let titleItems = AVMetadataItem.metadataItems(
                from: group.items,
                filteredByIdentifier: .commonIdentifierTitle
            )

            for titleItem in titleItems {
                if let name = try await titleItem.load(.stringValue) {
                    chapters.append(Chapter(name: name, time: group.timeRange))
                    break
                }
            }
        }

        return chapters
    }
}
