import Foundation

/// An object that can be used to create a new trip.

struct TripCreate: Codable {
    let name: String
    let startDate: Date
    let endDate: Date
    
    enum CodingKeys: String, CodingKey {
        case name
        case startDate = "start_date"
        case endDate = "end_date"
    }
    
    init(name: String, startDate: Date, endDate: Date) {
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"  // ISO 8601 format
        
        try container.encode(name, forKey: .name)
        try container.encode(dateFormatter.string(from: startDate), forKey: .startDate)
        try container.encode(dateFormatter.string(from: endDate), forKey: .endDate)
    }
}

/// An object that can be used to update an existing trip.
struct TripUpdate: Codable {
    let name: String
    let startDate: Date
    let endDate: Date
}

/// An object that can be used to create a media.
struct MediaCreate: Codable {
    let eventId: Event.ID
    let base64Data: Data
}

/// An object that can be used to create a new event.
struct EventCreate: Codable {
    let tripId: Trip.ID
    let name: String
    let note: String?
    let date: Date
    let location: Location?
    let transitionFromPrevious: String?
}

/// An object that can be used to update an existing event.
struct EventUpdate: Codable {
    var name: String
    var note: String?
    var date: Date
    var location: Location?
    var transitionFromPrevious: String?
}
