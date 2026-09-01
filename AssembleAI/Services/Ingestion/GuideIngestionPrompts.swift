//
//  GuideIngestionPrompts.swift
//  AssembleAI
//

import Foundation

/// Structured system prompts for AI-assisted guide extraction.
///
/// These prompts instruct the on-device Foundation Model to extract structured
/// assembly data from unstructured guide text. The model output must be valid JSON
/// conforming to the AssembleAI project schema.
enum GuideIngestionPrompts {
    
    /// Builds the extraction prompt for converting raw guide text into an AssemblyProject JSON.
    static func buildExtractionPrompt(
        guideText: String,
        format: GuideSourceFormat,
        domain: AssemblyDomain
    ) -> String {
        """
        SYSTEM: You are a precision assembly guide parser for the AssembleAI application.
        Your task is to extract structured assembly project data from the provided guide text.
        
        RULES:
        1. Output ONLY a single valid JSON object. No explanatory text before or after the JSON.
        2. Use snake_case for all JSON keys.
        3. Extract a clear title, description, difficulty level, and estimated time.
        4. Identify all required components (bill of materials) with names, descriptions, and quantities.
        5. Break the guide into sequential numbered steps. Each step must have a clear title and instruction.
        6. For electronics projects: identify pin coordinates (e.g., "Row 10", "Pin A5"), component values (e.g., "220 ohm"), and polarity requirements.
        7. For physical/furniture projects: identify spatial positions, fastener types, and orientation rules.
        8. Identify common mistakes where the text warns about errors or provides troubleshooting tips.
        9. The "difficulty" field must be one of: "Beginner", "Intermediate", "Advanced".
        10. The "domain" field must be "\(domain.rawValue)".
        
        JSON SCHEMA:
        {
          "schema_version": "1.0.0",
          "domain": "\(domain.rawValue)",
          "title": "string",
          "subtitle": "string",
          "category": "string",
          "difficulty": "Beginner|Intermediate|Advanced",
          "estimated_minutes": number,
          "total_steps": number,
          "description": "string",
          "components": [
            {
              "name": "string",
              "detail": "string",
              "is_required": boolean,
              "part_id": "string (lowercase_with_underscores)",
              "component_type": "string",
              "quantity": number
            }
          ],
          "steps": [
            {
              "step_order": number,
              "title": "string",
              "instruction": "string",
              "expected_duration_minutes": number,
              "visual_contract": {
                "required_component_ids": ["string"],
                "pin_placements": [
                  {
                    "part_id": "string",
                    "from_pin": { "row": "string", "column": "string" },
                    "to_pin": { "row": "string", "column": "string" },
                    "tolerance_mm": number
                  }
                ],
                "spatial_placements": [
                  {
                    "part_id": "string",
                    "location_description": "string",
                    "orientation": "string",
                    "quantity": number
                  }
                ],
                "expected_connections": [
                  { "from_node": "string", "to_node": "string", "connection_type": "string" }
                ],
                "orientation_constraints": [
                  { "part_id": "string", "rule": "string", "marker_type": "string" }
                ]
              },
              "common_mistakes": [
                {
                  "condition": "string",
                  "explanation": "string",
                  "correction_action": "string",
                  "severity": "minor|moderate|critical"
                }
              ]
            }
          ]
        }
        
        \(componentTypeReference(for: domain))
        
        SOURCE FORMAT: \(format.rawValue)
        
        GUIDE TEXT:
        ---
        \(guideText)
        ---
        
        Output the JSON now:
        """
    }
    
    /// Reference list of valid component_type values for the model.
    private static func componentTypeReference(for domain: AssemblyDomain) -> String {
        switch domain {
        case .electronics:
            return """
            COMPONENT TYPES (electronics): resistor, capacitor_electrolytic, capacitor_ceramic, led, integrated_circuit, jumper_wire, connector, sensor, motor, potentiometer, transistor, diode, crystal, board, custom
            ORIENTATION MARKER TYPES: anode_cathode, polarity_stripe, ic_notch, pin1_dot, flat_edge, label_direction, not_applicable
            """
        case .physical:
            return """
            COMPONENT TYPES (physical): screw, bolt, nut, bracket, panel, shelf, dowel, cam_lock, hinge, rail, custom
            ORIENTATION MARKER TYPES: label_direction, flat_edge, not_applicable
            """
        case .hybrid:
            return """
            COMPONENT TYPES (all): resistor, capacitor_electrolytic, capacitor_ceramic, led, integrated_circuit, jumper_wire, connector, sensor, motor, potentiometer, transistor, diode, crystal, board, screw, bolt, nut, bracket, panel, shelf, dowel, cam_lock, hinge, rail, custom
            ORIENTATION MARKER TYPES: anode_cathode, polarity_stripe, ic_notch, pin1_dot, flat_edge, label_direction, not_applicable
            """
        }
    }
}
