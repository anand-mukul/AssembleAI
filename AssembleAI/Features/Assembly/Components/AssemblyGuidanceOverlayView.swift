//
//  AssemblyGuidanceOverlayView.swift
//  AssembleAI
//

import SwiftUI
import UIKit

/// Camera guidance overlay rendering target bounding boxes, move arrows (source -> destination), warning callouts, and success banners over live camera preview.
struct AssemblyGuidanceOverlayView: View {
    let guidance: GuidanceOverlay
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulseAnimating = false
    @State private var moveArrowOffset: CGFloat = 0.0
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                switch guidance.style {
                case .target:
                    if let targetRect = guidance.targetRegion {
                        renderTargetBox(rect: targetRect)
                    } else {
                        renderFloatingLabel(title: guidance.title, message: guidance.message, color: .assembleBrandPrimary)
                    }
                    
                case .move:
                    if let source = guidance.sourceRegion, let dest = guidance.destinationRegion {
                        renderMoveGuidance(source: source, destination: dest)
                    } else {
                        renderFloatingLabel(title: guidance.title, message: guidance.message, color: AppColors.error)
                    }
                    
                case .warning:
                    renderFloatingLabel(title: guidance.title, message: guidance.message, color: AppColors.warning)
                    
                case .success:
                    renderSuccessBanner(title: guidance.title, message: guidance.message)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear {
            triggerGuidanceHaptic(style: guidance.style)
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    isPulseAnimating = true
                }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    moveArrowOffset = 1.0
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(guidance.title). \(guidance.message)")
    }
    
    // MARK: - Target Highlight Overlay (.target)
    
    @ViewBuilder
    private func renderTargetBox(rect: CGRect) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.assembleBrandPrimary, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .frame(width: rect.width, height: rect.height)
                .scaleEffect(reduceMotion ? 1.0 : (isPulseAnimating ? 1.05 : 0.95))
                .position(x: rect.midX, y: rect.midY)
            
            VStack(spacing: 2) {
                Text("TARGET")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(guidance.message)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.assembleBrandPrimary))
            .position(x: rect.midX, y: rect.minY - 18)
        }
    }
    
    // MARK: - Move Guidance Overlay (.move: source -> destination)
    
    @ViewBuilder
    private func renderMoveGuidance(source: CGRect, destination: CGRect) -> some View {
        ZStack {
            // Source Box (Current Incorrect Position)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.error, style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                .frame(width: source.width, height: source.height)
                .position(x: source.midX, y: source.midY)
            
            Text("CURRENT")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(AppColors.error))
                .position(x: source.midX, y: source.minY - 12)
            
            // Destination Box (Target Correct Position)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.success, lineWidth: 2)
                .frame(width: destination.width, height: destination.height)
                .scaleEffect(reduceMotion ? 1.0 : (isPulseAnimating ? 1.04 : 0.96))
                .position(x: destination.midX, y: destination.midY)
            
            Text("MOVE HERE")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(AppColors.success))
                .position(x: destination.midX, y: destination.minY - 12)
            
            // Connector Arrow Line (Source -> Destination)
            Path { path in
                path.move(to: CGPoint(x: source.midX, y: source.midY))
                path.addLine(to: CGPoint(x: destination.midX, y: destination.midY))
            }
            .stroke(
                Color.yellow,
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [8, 4], dashPhase: reduceMotion ? 0 : -moveArrowOffset * 12)
            )
            
            // Floating Move Instruction Card
            renderFloatingLabel(title: guidance.title, message: guidance.message, color: AppColors.error)
        }
    }
    
    // MARK: - Floating Material Card
    
    private func renderFloatingLabel(title: String, message: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(Color.black.opacity(0.35))
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .strokeBorder(color.opacity(0.35), lineWidth: 0.5)
        )
        .padding(.horizontal, AppSpacing.screenEdge)
        .padding(.top, 100)
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - Success Banner (.success)
    
    private func renderSuccessBanner(title: String, message: String) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(AppColors.success)
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.lg)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(Color.black.opacity(0.35))
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .strokeBorder(AppColors.success.opacity(0.35), lineWidth: 0.5)
        )
        .padding(.horizontal, AppSpacing.screenEdge)
    }
    
    // MARK: - Haptic Trigger Helper
    
    private func triggerGuidanceHaptic(style: GuidanceStyle) {
        switch style {
        case .target:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .move, .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

#Preview("Assembly Guidance Overlay - Move") {
    ZStack {
        Color.black
        AssemblyGuidanceOverlayView(
            guidance: GuidanceOverlay(
                title: "Wrong position",
                message: "Move component lead one slot to the right (Row 15).",
                sourceRegion: CGRect(x: 100, y: 300, width: 90, height: 60),
                destinationRegion: CGRect(x: 230, y: 300, width: 90, height: 60),
                style: .move
            )
        )
    }
}
