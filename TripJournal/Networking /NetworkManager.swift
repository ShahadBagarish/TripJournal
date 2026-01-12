//
//  NetworkManager.swift
//  TripJournal
//
//  Created by Shahad Bagarish on 11/01/2026.
//

import Foundation

enum APIConfig {
    static let baseURL = URL(string: "http://localhost:8000")!
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case http(Int, Data?)
    case decoding(Error)
    case encoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL."
        case .invalidResponse: return "Invalid server response."
        case .http(let code, _): return "Server error (\(code))."
        case .decoding(let err): return "Decoding error: \(err.localizedDescription)"
        case .encoding(let err): return "Encoding error: \(err.localizedDescription)"
        }
    }
}

class NetworkManager {
    
    let baseURL: URL
    var tokenProvider: () -> String?
    

    init(baseURL: URL, tokenProvider: @escaping () -> String? = { nil }) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
    }
    
    // MARK: - JSON request
    func sendJSON<T: Decodable, Body: Encodable>(
        _ path: String,
        method: String,
        body: Body?,
        requiresAuth: Bool = false
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if requiresAuth, let token = tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            do {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                throw APIError.encoding(error)
            }
        }

        return try await perform(request)
    }
    
    // MARK: - Form URL Encoded request (for /token)
    func sendForm<T: Decodable>(
        _ path: String,
        method: String = "POST",
        form: [String: String],
        requiresAuth: Bool = false
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        if requiresAuth, let token = tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = form
            .map { key, value in
                "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            }
            .joined(separator: "&")
            .data(using: .utf8)

        return try await perform(request)
    }
    
    // MARK: - Core perform
    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        guard (200...299).contains(http.statusCode) else {
            throw APIError.http(http.statusCode, data)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}



