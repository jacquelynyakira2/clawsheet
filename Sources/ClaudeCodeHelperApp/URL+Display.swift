import Foundation

extension URL {
    var humanReadableDocsURL: URL {
        guard absoluteString.hasPrefix("https://code.claude.com/docs/"),
              pathExtension == "md" else {
            return self
        }
        return deletingPathExtension()
    }
}
