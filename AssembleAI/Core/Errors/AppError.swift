//
//  AppError.swift
//  AssembleAI
//

import Foundation

/// Unified application error taxonomy mapping Supabase, SwiftData, and networking errors into user-friendly messages.
enum AppError: LocalizedError, Equatable {
    case authentication(String)
    case network(String)
    case database(String)
    case storage(String)
    case unauthorized
    case notFound
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .authentication(let message):
            return message.isEmpty ? "Authentication failed. Please verify your credentials." : message
        case .network:
            return "Unable to connect to server. Please check your network connection."
        case .database:
            return "We couldn't sync your project data. Please try again."
        case .storage:
            return "Unable to upload or retrieve asset evidence."
        case .unauthorized:
            return "You do not have permission to perform this action."
        case .notFound:
            return "The requested record could not be found."
        case .unknown(let message):
            return message.isEmpty ? "An unexpected error occurred. Please try again." : message
        }
    }
}
