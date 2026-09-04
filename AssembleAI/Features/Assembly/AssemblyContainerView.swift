//
//  AssemblyContainerView.swift
//  AssembleAI
//

import SwiftUI
import AVFoundation

/// Single task-flow container orchestrating phase view transitions for the assembly session.
struct AssemblyContainerView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: AssemblyViewModel
    
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
                            dismiss()
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
                            dismiss()
                            router.pop()
                        }
                    )
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    
                case .camera:
                    AssemblyCameraView(
                        currentStep: viewModel.currentStep,
                        allSteps: viewModel.project.steps.map { summary in
                            AssemblyStep(
                                id: summary.id,
                                projectId: viewModel.project.id,
                                stepOrder: summary.stepOrder,
                                title: summary.title,
                                instruction: summary.instruction,
                                visualContract: summary.visualContract
                            )
                        },
                        activeGuidance: viewModel.activeGuidance,
                        liveTutorEnabled: viewModel.liveTutorEnabled,
                        liveStatus: viewModel.liveStatus,
                        currentTutorMessage: viewModel.currentTutorMessage,
                        userTranscript: viewModel.liveUserTranscript,
                        isListening: viewModel.isListening,
                        isPaused: viewModel.isLivePaused,
                        onStartLiveStream: { stream in
                            viewModel.startLiveTutor(frameStream: stream)
                        },
                        onStopLiveStream: {
                            viewModel.stopLiveTutor()
                        },
                        onToggleVoice: {
                            viewModel.toggleVoiceInput()
                        },
                        onTogglePause: {
                            viewModel.toggleLivePause()
                        },
                        onAnalyze: { capturedPhoto in
                            viewModel.triggerAnalysis(capturedImage: capturedPhoto, viewSize: geo.size)
                        },
                        onClose: {
                            viewModel.stopLiveTutor()
                            dismiss()
                            router.pop()
                        }
                    )
                    .ignoresSafeArea()
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
                        currentStep: viewModel.currentStep,
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
                            dismiss()
                            router.pop()
                        }
                    )
                    .transition(.opacity)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .animation(.easeInOut(duration: 0.3), value: viewModel.phase)
    }
}

#Preview("Assembly Container View") {
    AssemblyContainerView(project: MockProjectData.sampleProjects[0])
        .environmentObject(AppRouter())
}
