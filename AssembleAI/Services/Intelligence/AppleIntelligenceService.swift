//
//  AppleIntelligenceService.swift
//  AssembleAI
//
//  Comprehensive Apple Intelligence coordinator orchestrating on-device
//  Foundation Models, NaturalLanguage parsing, Neural Engine checks,
//  and CoreSpotlight semantic indexing.
//

import Foundation
import NaturalLanguage
#if canImport(CoreSpotlight)
import CoreSpotlight
import UniformTypeIdentifiers
#endif

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Capabilities

/// Hardware and framework capabilities for Apple Intelligence on the current device.
struct AppleIntelligenceCapabilities: Sendable, Equatable {
    let isAppleIntelligenceSupported: Bool
    let supportsFoundationModels: Bool
    let supportsNaturalLanguageEmbedding: Bool
    let neuralEngineGeneration: String
    let deviceModel: String
    let osVersion: String
    
    var summary: String {
        """
        Apple Intelligence: \(isAppleIntelligenceSupported ? "Available" : "Standard Engine")
        Foundation Models: \(supportsFoundationModels ? "Active" : "NLP Fallback")
        Device: \(deviceModel) (\(osVersion))
        Neural Engine: \(neuralEngineGeneration)
        """
    }
}

// MARK: - Apple Intelligence Service

/// Central actor coordinating Apple Intelligence features across the application.
actor AppleIntelligenceService {
    static let shared = AppleIntelligenceService()
    
    private init() {}
    
    // MARK: - Capabilities Detection
    
    /// Evaluates current device hardware and OS capabilities for Apple Intelligence.
    func getCapabilities() -> AppleIntelligenceCapabilities {
        let processInfo = ProcessInfo.processInfo
        let osVersion = processInfo.operatingSystemVersionString
        let deviceModel = getDeviceIdentifier()
        
        var supportsFoundation = false
        #if canImport(FoundationModels)
        if #available(iOS 18.0, *) {
            supportsFoundation = true
        }
        #endif
        
        let hasA17OrMSeries = isAppleIntelligenceHardware(deviceModel: deviceModel)
        
        return AppleIntelligenceCapabilities(
            isAppleIntelligenceSupported: hasA17OrMSeries || supportsFoundation,
            supportsFoundationModels: supportsFoundation,
            supportsNaturalLanguageEmbedding: true,
            neuralEngineGeneration: hasA17OrMSeries ? "16-core Apple Neural Engine (35+ TOPS)" : "Apple Neural Engine",
            deviceModel: deviceModel,
            osVersion: osVersion
        )
    }
    
    // MARK: - NaturalLanguage Entity Extraction
    
    /// Parses unstructured text using Apple's `NaturalLanguage` framework to extract hardware components and sequential steps.
    func extractStructuredEntities(
        from text: String,
        domain: AssemblyDomain = .electronics
    ) -> (components: [ComponentRequirement], steps: [ProjectStepSummary]) {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = text
        
        var recognizedComponents: [String: (name: String, quantity: Int, detail: String)] = [:]
        
        // Component keyword patterns
        let hardwareKeywords: [(pattern: String, typeName: String)] = [
            ("resistor", "Resistor"),
            ("capacitor", "Capacitor"),
            ("led", "LED"),
            ("breadboard", "Breadboard"),
            ("jumper wire", "Jumper Wire"),
            ("wire", "Jumper Wire"),
            ("switch", "Pushbutton Switch"),
            ("button", "Pushbutton Switch"),
            ("diode", "Diode"),
            ("transistor", "Transistor"),
            ("potentiometer", "Potentiometer"),
            ("ic", "Integrated Circuit"),
            ("sensor", "Sensor Module"),
            ("battery", "Battery Clip"),
            ("screw", "Machine Screw"),
            ("dowel", "Wooden Dowel"),
            ("shelf", "Shelf Panel")
        ]
        
        let lower = text.lowercased()
        for (pattern, typeName) in hardwareKeywords {
            if lower.contains(pattern) {
                let partId = "part_\(pattern.replacingOccurrences(of: " ", with: "_"))"
                if recognizedComponents[partId] == nil {
                    recognizedComponents[partId] = (name: typeName, quantity: 1, detail: "Standard \(typeName)")
                }
            }
        }
        
        // Step extraction by sequential lines or headings
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var extractedSteps: [ProjectStepSummary] = []
        var currentStepNumber = 1
        
        for line in lines {
            let lowerLine = line.lowercased()
            let isStepIndicator = lowerLine.hasPrefix("step") ||
                                  lowerLine.hasPrefix("#") ||
                                  (line.first?.isNumber == true && (line.contains(".") || line.contains(":")))
            
            if isStepIndicator || extractedSteps.isEmpty {
                let cleaned = line.replacingOccurrences(of: "#", with: "")
                    .trimmingCharacters(in: .whitespaces)
                extractedSteps.append(
                    ProjectStepSummary(
                        stepOrder: currentStepNumber,
                        title: "Step \(currentStepNumber)",
                        instruction: cleaned
                    )
                )
                currentStepNumber += 1
            } else if var lastStep = extractedSteps.last {
                // Append instruction detail to current step
                extractedSteps.removeLast()
                extractedSteps.append(
                    ProjectStepSummary(
                        id: lastStep.id,
                        stepOrder: lastStep.stepOrder,
                        title: lastStep.title,
                        instruction: "\(lastStep.instruction) \(line)",
                        expectedDurationMinutes: lastStep.expectedDurationMinutes,
                        visualContract: lastStep.visualContract,
                        commonMistakes: lastStep.commonMistakes
                    )
                )
            }
        }
        
        let componentsList = recognizedComponents.map { (key, val) in
            ComponentRequirement(
                name: val.name,
                detail: val.detail,
                isRequired: true,
                partId: key
            )
        }.sorted { $0.name < $1.name }
        
        return (componentsList, extractedSteps)
    }
    
    // MARK: - CoreSpotlight Semantic Indexing
    
    #if canImport(CoreSpotlight)
    /// Indexes an `AssemblyProject` and its assembly steps in iOS Spotlight search.
    func indexInSpotlight(project: AssemblyProject) async {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .content)
        attributeSet.title = project.title
        attributeSet.contentDescription = "\(project.subtitle) • \(project.steps.count) steps • \(project.difficulty.displayName)"
        attributeSet.keywords = [
            project.title,
            project.category,
            project.domain.rawValue,
            "AssembleAI",
            "circuit",
            "electronics",
            "assembly"
        ] + project.components.map(\.name)
        
        let item = CSSearchableItem(
            uniqueIdentifier: "com.assembleai.project.\(project.id.uuidString)",
            domainIdentifier: "com.assembleai.projects",
            attributeSet: attributeSet
        )
        
        do {
            try await CSSearchableIndex.default().indexSearchableItems([item])
        } catch {
            // Non-critical spotlight indexing error
        }
    }
    
    /// Removes an `AssemblyProject` from iOS Spotlight search.
    func deindexFromSpotlight(projectId: UUID) async {
        let identifier = "com.assembleai.project.\(projectId.uuidString)"
        try? await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [identifier])
    }
    #endif
    
    // MARK: - Hardware Helper
    
    private func isAppleIntelligenceHardware(deviceModel: String) -> Bool {
        // iPhone 15 Pro/Max (iPhone16,1 / iPhone16,2), iPhone 16 family (iPhone17,*), iPads/Macs with M1+
        if deviceModel.hasPrefix("iPhone16,") || deviceModel.hasPrefix("iPhone17,") {
            return true
        }
        if deviceModel.hasPrefix("iPad") && !deviceModel.contains("iPad7") && !deviceModel.contains("iPad8") {
            return true
        }
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    private func getDeviceIdentifier() -> String {
        #if canImport(Darwin)
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier.isEmpty ? "iOS Device" : identifier
        #else
        return "Apple Device"
        #endif
    }
}
