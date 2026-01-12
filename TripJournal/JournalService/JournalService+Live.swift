//
//  JournalService+Live.swift
//  TripJournal
//
//  Created by Shahad Bagarish on 11/01/2026.
//

import Foundation
import Combine
import AuthenticationServices

private func formURLEncode(_ params: [String: String]) -> Data {
    let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._* ")
    let encoded = params.map { key, value -> String in
        let k = key.addingPercentEncoding(withAllowedCharacters: allowed)?.replacingOccurrences(of: " ", with: "+") ?? key
        let v = value.addingPercentEncoding(withAllowedCharacters: allowed)?.replacingOccurrences(of: " ", with: "+") ?? value
        return "\(k)=\(v)"
    }
    .joined(separator: "&")
    return Data(encoded.utf8)
}

enum NetworkError: Error {
    case badUrl
    case badResponse
    case failedToDecodeResponse
}

let baseURL = URL(string: "http://localhost:8000")

extension URLRequest {
    mutating func addHeaders(_ headers: [String : String]){
        for (key, value) in headers {
            setValue(value, forHTTPHeaderField: key)
        }
    }
}

class JournalServiceLive: JournalService {
    
    private func makeRequest(endpoint: String,
                             method: String,
                             headers: [String: String] = [:],
                             body: Data? = nil) throws -> URLRequest {
        guard let baseURL = baseURL else {
            throw NetworkError.badUrl
        }
        guard let url = URL(string: endpoint, relativeTo: baseURL) else {
            throw NetworkError.badUrl
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addHeaders(headers)
        
        if request.value(forHTTPHeaderField: "Accept") == nil {
            request.setValue("application/json", forHTTPHeaderField: "Accept")
        }
        
        if let accessToken = token?.accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }

        print("Request URL: \(request.url?.absoluteString ?? "nil")")
        print("Request Headers: \(request.allHTTPHeaderFields ?? [:])")
        print("Request Body: \(body != nil ? String(data: body!, encoding: .utf8) ?? "nil" : "nil")")

        return request
    }
    
    @Published private(set) var token: AuthToken? = KeychainService.load()
    
    var isAuthenticated: AnyPublisher<Bool, Never> {
        $token
            .map { $0 != nil }
            .eraseToAnyPublisher()
    }

    func register(username: String, password: String) async throws -> AuthToken {
        let requestBody = ["username": username, "password": password]
        let requestData = try JSONEncoder().encode(requestBody)
        
        var request = try makeRequest(endpoint: "register", method: "POST", body: requestData)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let response = response as? HTTPURLResponse else {
            throw NetworkError.badResponse
        }
        
        guard response.statusCode == 200 else {
            print("Register failed with status code: \(response.statusCode)")
            throw NetworkError.badResponse
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            print("Register response data: \(String(data: data, encoding: .utf8) ?? "nil")")
            let token = try decoder.decode(AuthToken.self, from: data)
            self.token = token
            KeychainService.save(token)
            return token
        } catch {
            print("Register decode failed. Raw body: \(String(data: data, encoding: .utf8) ?? "<non-utf8>")")
            throw NetworkError.failedToDecodeResponse
        }
    }

    func logOut() {
        self.token = nil
        KeychainService.delete()
    }

    func logIn(username: String, password: String) async throws -> AuthToken {
        
        let requestData = formURLEncode([ "username": username, "password": password])
        print("DEBUG: \(username) and \(password)")
        
        var request = try makeRequest(endpoint: "token", method: "POST", body: requestData)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let response = response as? HTTPURLResponse else {
            throw NetworkError.badResponse
        }
        
        guard response.statusCode == 200 else {
            print("Login failed with status code: \(response.statusCode)")
            throw NetworkError.badResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            let token = try decoder.decode(AuthToken.self, from: data)
            self.token = token
            KeychainService.save(token)
            return token
        } catch {
            print("Login decode failed:", error)
            print("Raw body:", String(data: data, encoding: .utf8) ?? "<non-utf8>")
            throw NetworkError.failedToDecodeResponse
        }
    }
    
    private let apiDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    
    private let apiEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    func createTrip(with request: TripCreate) async throws -> Trip {
        let requestData = try apiEncoder.encode(request)
        
        var request = try makeRequest(endpoint: "trips", method: "POST", body: requestData)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let response = response as? HTTPURLResponse else {
            throw NetworkError.badResponse
        }
        
        guard response.statusCode == 200 else {
            print("Create trip failed with status code: \(response.statusCode)")
            throw NetworkError.badResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            print("Create trip response data: \(String(data: data, encoding: .utf8) ?? "nil")")
            let trip = try apiDecoder.decode(Trip.self, from: data)
            return trip
        } catch {
            print("Failed to decode create trip response: \(error)")
            throw NetworkError.failedToDecodeResponse
        }
    }


    func getTrips() async throws -> [Trip] {
        let request = try makeRequest(endpoint: "trips", method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let response = response as? HTTPURLResponse else {
            throw NetworkError.badResponse
        }
        
        guard response.statusCode == 200 else {
            print("Get trips failed with status code: \(response.statusCode)")
            throw NetworkError.badResponse
        }
        
        
        do {
            print("Get trips response data: \(String(data: data, encoding: .utf8) ?? "nil")")
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let trips = try apiDecoder.decode([Trip].self, from: data)
            return trips
        } catch {
            print("Failed to decode get trips response: \(error)")
            throw NetworkError.failedToDecodeResponse
        }
    }

    func getTrip(withId tripId: Trip.ID) async throws -> Trip {
        let request = try makeRequest(endpoint: "trips/\(tripId)", method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let response = response as? HTTPURLResponse else {
            throw NetworkError.badResponse
        }
        
        guard response.statusCode == 200 else {
            print("Get trip failed with status code: \(response.statusCode)")
            throw NetworkError.badResponse
        }
        
        do {
            print("Get trip response data: \(String(data: data, encoding: .utf8) ?? "nil")")
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let trip = try apiDecoder.decode(Trip.self, from: data)
            return trip
        } catch {
            print("Failed to decode get trip response: \(error)")
            throw NetworkError.failedToDecodeResponse
        }
    }

    func updateTrip(withId tripId: Trip.ID, and request: TripUpdate) async throws -> Trip {
        let requestData = try apiEncoder.encode(request)
        var request = try makeRequest(endpoint: "trips/\(tripId)", method: "PUT", body: requestData)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let response = response as? HTTPURLResponse else {
            throw NetworkError.badResponse
        }
        
        guard response.statusCode == 200 else {
            print("Update trip failed with status code: \(response.statusCode)")
            throw NetworkError.badResponse
        }
        
        do {
            print("Update trip response data: \(String(data: data, encoding: .utf8) ?? "nil")")
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let trip = try apiDecoder.decode(Trip.self, from: data)
            return trip
        } catch {
            print("Failed to decode update trip response: \(error)")
            throw NetworkError.failedToDecodeResponse
        }
    }

    func deleteTrip(withId tripId: Trip.ID) async throws {
        let request = try makeRequest(endpoint: "trips/\(tripId)", method: "DELETE")
        _ = try await URLSession.shared.data(for: request)
    }

    func createEvent(with request: EventCreate) async throws -> Event {
        let requestData = try apiEncoder.encode(request)
        var request = try makeRequest(endpoint: "events", method: "POST", body: requestData)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let response = response as? HTTPURLResponse else {
            throw NetworkError.badResponse
        }
        
        guard response.statusCode == 200 else {
            print("Create event failed with status code: \(response.statusCode)")
            throw NetworkError.badResponse
        }
        
        do {
            print("Create event response data: \(String(data: data, encoding: .utf8) ?? "nil")")
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let event = try apiDecoder.decode(Event.self, from: data)
            return event
        } catch {
            print("Failed to decode create event response: \(error)")
            throw NetworkError.failedToDecodeResponse
        }
    }

    func getEvents() async throws -> [Event] {
        let request = try makeRequest(endpoint: "events", method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let response = response as? HTTPURLResponse else {
            throw NetworkError.badResponse
        }
        
        guard response.statusCode == 200 else {
            print("Get events failed with status code: \(response.statusCode)")
            throw NetworkError.badResponse
        }
        
        do {
            print("Get events response data: \(String(data: data, encoding: .utf8) ?? "nil")")
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let events = try apiDecoder.decode([Event].self, from: data)
            return events
        } catch {
            print("Failed to decode get events response: \(error)")
            throw NetworkError.failedToDecodeResponse
        }
    }

    func getEvent(withId eventId: Event.ID) async throws -> Event {
        let request = try makeRequest(endpoint: "events/\(eventId)", method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let response = response as? HTTPURLResponse else {
            throw NetworkError.badResponse
        }
        
        guard response.statusCode == 200 else {
            print("Get event failed with status code: \(response.statusCode)")
            throw NetworkError.badResponse
        }
        
        do {
            print("Get event response data: \(String(data: data, encoding: .utf8) ?? "nil")")
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let event = try apiDecoder.decode(Event.self, from: data)
            return event
        } catch {
            print("Failed to decode get event response: \(error)")
            throw NetworkError.failedToDecodeResponse
        }
    }

    func updateEvent(withId eventId: Event.ID, and request: EventUpdate) async throws -> Event {
        let requestData = try apiEncoder.encode(request)
        var request = try makeRequest(endpoint: "events/\(eventId)", method: "PUT", body: requestData)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let response = response as? HTTPURLResponse else {
            throw NetworkError.badResponse
        }
        
        guard response.statusCode == 200 else {
            print("Update event failed with status code: \(response.statusCode)")
            throw NetworkError.badResponse
        }
        
        do {
            print("Update event response data: \(String(data: data, encoding: .utf8) ?? "nil")")
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let event = try apiDecoder.decode(Event.self, from: data)
            return event
        } catch {
            print("Failed to decode update event response: \(error)")
            throw NetworkError.failedToDecodeResponse
        }
    }

    func deleteEvent(withId eventId: Event.ID) async throws {
        let request = try makeRequest(endpoint: "events/\(eventId)", method: "DELETE")
        _ = try await URLSession.shared.data(for: request)
    }

    func createMedia(with request: MediaCreate) async throws -> Media {
        let requestData = try apiEncoder.encode(request)
        var request = try makeRequest(endpoint: "media", method: "POST", body: requestData)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let response = response as? HTTPURLResponse else {
            throw NetworkError.badResponse
        }
        
        guard (200...299).contains(response.statusCode) else {
            print("Create media failed with status code: \(response.statusCode)")
            print("Server body:", String(data: data, encoding: .utf8) ?? "<non-utf8>")
            throw NetworkError.badResponse
        }
        
        do {
            print("Create media response data: \(String(data: data, encoding: .utf8) ?? "nil")")
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let media = try decoder.decode(Media.self, from: data)
            return media
        } catch {
            print("Failed to decode create media response: \(error)")
            throw NetworkError.failedToDecodeResponse
        }
    }

    func getMedia() async throws -> [Media] {
        let request = try makeRequest(endpoint: "media", method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let response = response as? HTTPURLResponse else {
            throw NetworkError.badResponse
        }
        
        guard (200...299).contains(response.statusCode) else {
            print("Get media failed with status code: \(response.statusCode)")
            throw NetworkError.badResponse
        }
        
        do {
            print("Get media response data: \(String(data: data, encoding: .utf8) ?? "nil")")
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let media = try decoder.decode([Media].self, from: data)
            return media
        } catch {
            print("Failed to decode get media response: \(error)")
            throw NetworkError.failedToDecodeResponse
        }
    }

    func getMedia(withId mediaId: Media.ID) async throws -> Media {
        let request = try makeRequest(endpoint: "media/\(mediaId)", method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let response = response as? HTTPURLResponse else {
            throw NetworkError.badResponse
        }
        
        guard (200...299).contains(response.statusCode) else {
            print("Get media failed with status code: \(response.statusCode)")
            throw NetworkError.badResponse
        }
        
        do {
            print("Get media response data: \(String(data: data, encoding: .utf8) ?? "nil")")
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let media = try decoder.decode(Media.self, from: data)
            return media
        } catch {
            print("Failed to decode get media response: \(error)")
            throw NetworkError.failedToDecodeResponse
        }
    }

    func deleteMedia(withId mediaId: Media.ID) async throws {
        let request = try makeRequest(endpoint: "media/\(mediaId)", method: "DELETE")
        _ = try await URLSession.shared.data(for: request)
    }
}

