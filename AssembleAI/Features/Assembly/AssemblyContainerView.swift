//
//  AssemblyContainerView.swift
//  AssembleAI
//

import SwiftUI
import AVFoundation

/// Single task-flow container orchestrating phase view transitions for the assembly session.
struct AssemblyContainerView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: AssemblyViewModel
    @StateObject private var cameraService = CameraService()
    
    init(project: AssemblyProject) {
        _viewModel = StateObject(wrappedValue: AssemblyViewModel(project: project))
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                switch viewModel.phase {
                case .intro:
                    AssemblyIntroView(
                        project: viewModel.project,
                        onBegin: {
                            viewModel.beginAssembly()
                        },
                        onBack: {
                            router.pop()
                        }
                    )
                    .transition(.opacity)
                    
                case .instruction:
                    StepInstructionView(
                        stepOrder: viewModel.stepOrderLabel,
                        totalSteps: viewModel.totalStepsCount,
                        title: viewModel.currentStep.title,
                        instruction: viewModel.currentStep.instruction,
                        onScanSetup: {
                            viewModel.openCamera()
                        },
                        onClose: {
                            router.pop()
                        }
                    )
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    
                case .camera:
                    AssemblyCameraView(
                        currentStep: viewModel.currentStep,
                        activeGuidance: viewModel.activeGuidance,
                        onAnalyze: {
                            Task {
                                let capturedPhoto = try? await cameraService.capturePhoto()
                                cameraService.stopSession()
                                viewModel.triggerAnalysis(capturedImage: capturedPhoto, viewSize: geo.size)
                            }
                        },
                        onClose: {
                            cameraService.stopSession()
                            router.pop()
                        }
                    )
                    .transition(.opacity)
                    
                case .analyzing:
                    AnalysisView()
                        .transition(.opacity)
                    
                case .visionDebug(let observation):
                    VisionDebugView(
                        image: viewModel.capturedImage,
                        observation: observation,
                        onContinue: {
                            viewModel.proceedFromVisionDebug()
                        }
                    )
                    .transition(.opacity)
                    
                case .verification(let result):
                    VerificationResultView(
                        result: result,
                        onContinue: {
                            viewModel.proceedFromVerification(result: result)
                        },
                        onShowErrorGuidance: {
                            viewModel.proceedFromVerification(result: result)
                        },
                        onRetry: {
                            viewModel.retryCurrentStep()
                        }
                    )
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .opacity))
                    
                case .errorGuidance(let result):
                    ErrorGuidanceView(
                        stepOrder: viewModel.stepOrderLabel,
                        result: result,
                        onScanAgain: {
                            viewModel.retryCurrentStep()
                        }
                    )
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    
                case .stepCompleted(let result):
                    StepCompletedView(
                        stepOrder: viewModel.stepOrderLabel,
                        totalSteps: viewModel.totalStepsCount,
                        result: result,
                        onNextStep: {
                            viewModel.nextStep()
                        }
                    )
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .opacity))
                    
                case .completed:
                    AssemblyCompletedView(
                        project: viewModel.project,
                        session: viewModel.session,
                        onDone: {
                            router.transitionToHome()
                        }
                    )
                    .transition(.opacity)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .animation(.easeInOut(duration: 0.3), value: viewModel.phase)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                cameraService.stopSession()
            } else if newPhase == .active && viewModel.phase == .camera {
                if cameraService.authorizationStatus == .authorized {
                    cameraService.startSession()
                }
            }
        }
    }
}

#Preview("Assembly Container View") {
    AssemblyContainerView(project: MockProjectData.sampleProjects[0])
        .environmentObject(AppRouter())
}
