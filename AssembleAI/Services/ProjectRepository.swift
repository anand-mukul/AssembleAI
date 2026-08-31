//
//  ProjectRepository.swift
//  AssembleAI
//

import Foundation

/// Protocol for fetching and managing assembly projects.
protocol ProjectRepository: Sendable {
    /// Fetches all available projects.
    func fetchProjects() async throws -> [AssemblyProject]
    
    /// Fetches a single project by its unique identifier.
    func fetchProject(byId id: UUID) async throws -> AssemblyProject?
    
    /// Fetches recent step activity history.
    func fetchRecentActivity() async throws -> [ActivityItemModel]
}

/// Default implementation for repositories that don't override single-project fetch.
extension ProjectRepository {
    func fetchProject(byId id: UUID) async throws -> AssemblyProject? {
        let all = try await fetchProjects()
        return all.first { $0.id == id }
    }
}

/// Mock project data provider delivering structured prototype assembly projects.
struct MockProjectRepository: ProjectRepository {
    
    func fetchProjects() async throws -> [AssemblyProject] {
        // Simulated micro network delay
        try await Task.sleep(nanoseconds: 100_000_000)
        return MockProjectData.sampleProjects
    }
    
    func fetchRecentActivity() async throws -> [ActivityItemModel] {
        try await Task.sleep(nanoseconds: 50_000_000)
        return MockProjectData.sampleActivity
    }
}

/// Dedicated mock dataset for prototype presentation.
enum MockProjectData {
    
    static let sampleProjects: [AssemblyProject] = [
        // 1. Active Project: LED Circuit
        AssemblyProject(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
            title: "LED Circuit",
            subtitle: "Basic breadboard circuit with resistor & LED",
            category: "Electronics",
            difficulty: .beginner,
            estimatedMinutes: 15,
            totalSteps: 8,
            completedSteps: 5,
            imageName: "bolt.batteryblock.fill",
            isActive: true,
            nextAction: "Connect the signal wire to pin R1",
            description: "Build a simple LED circuit using a breadboard, resistor, LED, and jumper wires. Learn basic pin header connections and current limiting.",
            components: [
                ComponentRequirement(name: "Breadboard", detail: "830 tie-point solderless board", isRequired: true),
                ComponentRequirement(name: "Red LED", detail: "5mm diffuse red LED", isRequired: true),
                ComponentRequirement(name: "220Ω Resistor", detail: "1/4W carbon film resistor", isRequired: true),
                ComponentRequirement(name: "Jumper Wires", detail: "Male-to-male wire set", isRequired: true),
                ComponentRequirement(name: "5V Power Source", detail: "USB breadboard power supply", isRequired: false)
            ],
            steps: [
                ProjectStepSummary(stepOrder: 1, title: "Attach 10K Resistor to R1 Pin Header", instruction: "Insert resistor leads into R1 slots.", isCompleted: true),
                ProjectStepSummary(stepOrder: 2, title: "Attach 100uF Capacitor to C2 Header", instruction: "Insert capacitor leads observing polarity.", isCompleted: true),
                ProjectStepSummary(stepOrder: 3, title: "Connect Anode Lead to Node 12A", instruction: "Align long lead of red LED with pin 12A.", isCompleted: true),
                ProjectStepSummary(stepOrder: 4, title: "Place Current Limiting Resistor", instruction: "Bridge resistor from 12B to ground rail.", isCompleted: true),
                ProjectStepSummary(stepOrder: 5, title: "Insert Ground Jump Wire to Rail", instruction: "Connect black jumper to GND.", isCompleted: true),
                ProjectStepSummary(stepOrder: 6, title: "Connect the signal wire to pin R1", instruction: "Connect red jumper wire from VCC to breadboard positive bus line.", isCompleted: false),
                ProjectStepSummary(stepOrder: 7, title: "Verify Voltage Drop Across Resistor", instruction: "Measure voltage across 220Ω resistor with multimeter.", isCompleted: false),
                ProjectStepSummary(stepOrder: 8, title: "Power Circuit & Observe Illumination", instruction: "Switch power supply ON and confirm LED turns bright red.", isCompleted: false)
            ]
        ),
        
        // 2. Temperature Sensor
        AssemblyProject(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID(),
            title: "Temperature Sensor",
            subtitle: "Thermistor & analog pin setup",
            category: "Electronics",
            difficulty: .beginner,
            estimatedMinutes: 25,
            totalSteps: 12,
            completedSteps: 0,
            imageName: "thermometer.medium",
            isActive: false,
            nextAction: nil,
            description: "Assemble a high-precision NTC thermistor circuit with voltage divider output feeding into an analog microcontroller pin.",
            components: [
                ComponentRequirement(name: "NTC Thermistor 10K", detail: "10K ohm @ 25°C thermal sensor", isRequired: true),
                ComponentRequirement(name: "10K Precision Resistor", detail: "1% metal film resistor", isRequired: true),
                ComponentRequirement(name: "Breadboard", detail: "Half-size breadboard", isRequired: true),
                ComponentRequirement(name: "Jumper Wires", detail: "Male-to-male wire set", isRequired: true)
            ],
            steps: [
                ProjectStepSummary(stepOrder: 1, title: "Insert NTC Thermistor into Row 5", instruction: "Place thermistor leads across A5 and A10.", isCompleted: false)
            ]
        ),
        
        // 3. Mini Weather Station
        AssemblyProject(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333") ?? UUID(),
            title: "Mini Weather Station",
            subtitle: "DHT11 & OLED display assembly",
            category: "Electronics",
            difficulty: .intermediate,
            estimatedMinutes: 45,
            totalSteps: 16,
            completedSteps: 4,
            imageName: "cloud.sun.fill",
            isActive: false,
            nextAction: "Connect I2C SDA wire to pin A4",
            description: "Build an environmental monitoring station with a DHT11 temperature/humidity sensor and an I2C 0.96\" OLED screen.",
            components: [
                ComponentRequirement(name: "DHT11 Sensor", detail: "Digital humidity and temperature sensor module", isRequired: true),
                ComponentRequirement(name: "0.96\" OLED Display", detail: "128x64 I2C display module", isRequired: true),
                ComponentRequirement(name: "Microcontroller Board", detail: "ATmega328P compatible board", isRequired: true),
                ComponentRequirement(name: "4.7K Pull-up Resistors", detail: "Two resistors for I2C bus", isRequired: true)
            ],
            steps: [
                ProjectStepSummary(stepOrder: 1, title: "Mount Microcontroller to Board", instruction: "Align pins carefully.", isCompleted: true)
            ]
        ),
        
        // 4. RGB LED Controller (Completed)
        AssemblyProject(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444") ?? UUID(),
            title: "RGB LED Controller",
            subtitle: "PWM color control assembly",
            category: "Electronics",
            difficulty: .intermediate,
            estimatedMinutes: 30,
            totalSteps: 10,
            completedSteps: 10,
            imageName: "paintpalette.fill",
            isActive: false,
            nextAction: nil,
            description: "Assemble a tri-color common cathode RGB LED circuit controlled via PWM pins with current limiting resistors for each channel.",
            components: [
                ComponentRequirement(name: "RGB LED 5mm", detail: "Common cathode 4-pin RGB LED", isRequired: true),
                ComponentRequirement(name: "330Ω Resistors", detail: "Three 330 ohm channel resistors", isRequired: true),
                ComponentRequirement(name: "Potentiometers 10K", detail: "Three rotary potentiometers", isRequired: false)
            ],
            steps: [
                ProjectStepSummary(stepOrder: 10, title: "Test Color Fading Sequence", instruction: "Verify red, green, and blue PWM outputs.", isCompleted: true)
            ]
        ),
        
        // 5. Servo Motor Setup
        AssemblyProject(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555") ?? UUID(),
            title: "Servo Motor Setup",
            subtitle: "Pulse-width position control",
            category: "Electronics",
            difficulty: .beginner,
            estimatedMinutes: 20,
            totalSteps: 9,
            completedSteps: 0,
            imageName: "gearshape.fill",
            isActive: false,
            nextAction: nil,
            description: "Connect a 9g micro servo motor with decoupling capacitor and external power rail to prevent microcontroller brownouts.",
            components: [
                ComponentRequirement(name: "9g Micro Servo", detail: "SG90 180-degree micro servo motor", isRequired: true),
                ComponentRequirement(name: "100uF Electrolytic Capacitor", detail: "Power rail decoupling capacitor", isRequired: true),
                ComponentRequirement(name: "3-pin Header Strip", detail: "Male pin header adapter", isRequired: true)
            ],
            steps: [
                ProjectStepSummary(stepOrder: 1, title: "Place Decoupling Capacitor across Rail", instruction: "Observe polarity: negative stripe to GND.", isCompleted: false)
            ]
        )
    ]
    
    static let sampleActivity: [ActivityItemModel] = [
        ActivityItemModel(
            stepOrder: 5,
            projectTitle: "LED Circuit",
            timestampDescription: "Today · 5:32 PM"
        ),
        ActivityItemModel(
            stepOrder: 4,
            projectTitle: "LED Circuit",
            timestampDescription: "Today · 5:18 PM"
        ),
        ActivityItemModel(
            stepOrder: 3,
            projectTitle: "LED Circuit",
            timestampDescription: "Yesterday · 4:10 PM"
        )
    ]
}
