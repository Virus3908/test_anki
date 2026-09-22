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
            URLQueryItem(name: "trans:lang", value: "eng"),
            URLQueryItem(name: "trans:is_orphan", value: "no"),
            URLQueryItem(name: "trans:is_unapproved", value: "no"),
            URLQueryItem(name: "is_orphan", value: "no"),
            URLQueryItem(name: "license", value: "CC BY 2.0 FR,CC0 1.0"),
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "showtrans", value: "matching")
        ]

        return components.url
    }
}
