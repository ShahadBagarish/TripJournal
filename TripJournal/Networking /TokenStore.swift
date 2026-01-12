//
//  TokenStore.swift
//  TripJournal
//
//  Created by Shahad Bagarish on 11/01/2026.
//

import Foundation

final class TokenStore: ObservableObject {
    @Published var token: String? {
        didSet {
            UserDefaults.standard.set(token, forKey: "token")
        }
    }
    
    init() {
        token = UserDefaults.standard.string(forKey: "token")
    }
    
    func logout() {
        token = nil
    }
}
