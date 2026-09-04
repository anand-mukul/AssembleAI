//
//  ConcurrencyExtensions.swift
//  AssembleAI
//
//  Swift 6 Strict Concurrency retro-conformance and Sendable extensions.
//

import Foundation
#if canImport(CoreVideo)
import CoreVideo

#if compiler(>=6.0)
extension CVBuffer: @retroactive @unchecked Sendable {}
#else
extension CVBuffer: @unchecked Sendable {}
#endif

#endif
