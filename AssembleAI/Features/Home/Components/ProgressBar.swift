//
//  ProgressBar.swift
//  AssembleAI
//

import SwiftUI

/// Accessible, animated linear progress bar supporting Dynamic Type and Reduce Motion.
struct ProgressBar: View {
    let value: Double // [0.0 ... 1.0]
    var height: CGFloat = 8
    var fillColor: Color = .assembleBrandPrimary
    var backgroundColor: Color = AppColors.tertiaryBackground
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        GeometryReader { geo in
            let clampedValue = min(max(value, 0.0), 1.0)
            let width = geo.size.width * clampedValue
            
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(backgroundColor)
                    .frame(height: height)
                
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [fillColor, fillColor.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width, height: height)
                    .animation(reduceMotion ? .none : .spring(response: 0.45, dampingFraction: 0.82), value: value)
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(min(max(value, 0.0), 1.0) * 100)) percent")
    }
}

#Preview("Progress Bar") {
    VStack(spacing: 20) {
        ProgressBar(value: 0.25)
        ProgressBar(value: 0.75, height: 10)
        ProgressBar(value: 1.0, fillColor: .green)
    }
    .padding()
}
