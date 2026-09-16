import Foundation

enum TatoebaEndpoint {
    static func sentences(for word: String) -> URL? {
        guard var components = URLComponents(string: "https://api.tatoeba.org/unstable/sentences") else {
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: "q", value: word),
            URLQueryItem(name: "lang", value: "jpn"),
            URLQueryItem(name: "sort", value: "relevance"),
            URLQueryItem(name: "trans:lang", value: "eng")
        ]

        return components.url
    }
}
