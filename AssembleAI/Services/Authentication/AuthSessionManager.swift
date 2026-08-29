//
//  AuthSessionManager.swift
//  AssembleAI
//

import Foundation
import Combine
import SwiftUI

/// Orchestrates authentication session restoration, token lifecycle, and user session state.
@MainActor
final class AuthSessionManager: ObservableObject {
    @Published private(set) var currentUser: User? = nil
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isRestoringSession: Bool = true
    
    let authService: SupabaseAuthService
    private let userRepository: UserRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(authService: SupabaseAuthService, userRepository: UserRepository) {
        self.authService = authService
        self.userRepository = userRepository
        
        setupSubscriptions()
    }
    
    func restoreSession() async {
        isRestoringSession = true
        defer { isRestoringSession = false }
        
        do {
            if let savedUser = try await userRepository.fetchCurrentUser() {
                self.currentUser = savedUser
                self.isAuthenticated = true
            }
        } catch {
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }
    
    private func setupSubscriptions() {
        authService.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                guard let self = self else { return }
                self.currentUser = user
                self.isAuthenticated = user != nil
                
                Task {
                    if let user = user {
                        try? await self.userRepository.saveUser(user)
                    } else {
                        try? await self.userRepository.deleteCurrentUser()
                    }
                }
            }
            .store(in: &cancellables)
    }
}
