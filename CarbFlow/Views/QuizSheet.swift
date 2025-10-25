import SwiftUI
import UIKit

struct QuizSheet: View {
    let quiz: Quiz
    @Binding var isPresented: Bool
    let onCorrect: () -> Void

    @StateObject private var engine: QuizEngine
    @State private var selectedIndex: Int?
    @State private var feedback: Feedback?
    @State private var showConfetti = false

    init(quiz: Quiz, isPresented: Binding<Bool>, hasStoredCorrectAnswer: Bool, onCorrect: @escaping () -> Void) {
        self.quiz = quiz
        self._isPresented = isPresented
        self.onCorrect = onCorrect
        _engine = StateObject(wrappedValue: QuizEngine(quiz: quiz))
        if hasStoredCorrectAnswer {
            _selectedIndex = State(initialValue: quiz.correctIndex)
            _feedback = State(initialValue: Feedback(isCorrect: true, message: "Correct!"))
        } else {
            _selectedIndex = State(initialValue: nil)
            _feedback = State(initialValue: nil)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(quiz.question)
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 12) {
                            ForEach(quiz.options.indices, id: \.self) { index in
                                Button {
                                    guard feedback?.isCorrect != true else { return }
                                    selectedIndex = index
                                    if feedback?.isCorrect == false {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            feedback = nil
                                        }
                                    }
                                } label: {
                                    HStack(alignment: .center, spacing: 12) {
                                        Image(systemName: selectionIconName(for: index))
                                            .foregroundColor(iconColor(for: index))
                                        Text(quiz.options[index])
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .foregroundColor(.primary)
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(optionBackground(for: index))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(optionBorder(for: index), lineWidth: optionBorder(for: index) == .clear ? 0 : 2)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(feedback?.isCorrect == true)
                            }
                        }

                        if let feedback {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: feedback.isCorrect ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                        .foregroundColor(feedback.isCorrect ? .green : .red)
                                    Text(feedback.message)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(feedback.isCorrect ? .green : .red)
                                }
                                if let explanation = quiz.explanation, feedback.isCorrect {
                                    Text(explanation)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .transition(.opacity)
                        }

                        Spacer(minLength: 12)

                        Button(action: submit) {
                            Text(feedback?.isCorrect == true ? "Close" : "Submit")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .foregroundColor(.white)
                        }
                        .disabled((selectedIndex == nil) && feedback?.isCorrect != true)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                ConfettiView(isActive: showConfetti)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
            .navigationTitle("Quick Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
        }
        .onDisappear {
            showConfetti = false
        }
        .onAppear {
            engine.start()
        }
    }

    private func submit() {
        if feedback?.isCorrect == true {
            isPresented = false
            return
        }

        let result = engine.submit(selection: selectedIndex)

        switch result {
        case .failure(let failure):
            handleSubmissionFailure(failure)
            return
        case .success(let isCorrect):
            guard let selectedIndex else { return }

            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                feedback = Feedback(
                    isCorrect: isCorrect,
                    message: isCorrect ? "Correct!" : "Not quite. Try again."
                )
            }

            if isCorrect {
                onCorrect()
                showConfetti = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    showConfetti = false
                }
            }
        }
    }

    private func handleSubmissionFailure(_ failure: QuizEngine.SubmissionFailure) {
        switch failure {
        case .missingSelection:
            break
        case .invalidSelection, .missingContent, .scoringMismatch:
            withAnimation(.easeInOut(duration: 0.2)) {
                feedback = Feedback(isCorrect: false, message: failureMessage(for: failure))
            }
        }
    }

    private func optionBackground(for index: Int) -> Color {
        if let feedback {
            if feedback.isCorrect && index == quiz.correctIndex {
                return Color.green.opacity(0.18)
            }
            if !feedback.isCorrect && selectedIndex == index {
                return Color.red.opacity(0.18)
            }
        }
        return selectedIndex == index ? Color.accentColor.opacity(0.12) : Color(.systemGray6)
    }

    private func optionBorder(for index: Int) -> Color {
        if let feedback {
            if feedback.isCorrect && index == quiz.correctIndex {
                return Color.green.opacity(0.7)
            }
            if !feedback.isCorrect && selectedIndex == index {
                return Color.red.opacity(0.6)
            }
        }
        return Color.clear
    }

    private func iconColor(for index: Int) -> Color {
        if let feedback {
            if feedback.isCorrect && index == quiz.correctIndex {
                return .green
            }
            if !feedback.isCorrect && selectedIndex == index {
                return .red
            }
        }
        return .accentColor
    }

    private func selectionIconName(for index: Int) -> String {
        if let feedback, feedback.isCorrect && index == quiz.correctIndex {
            return "checkmark.circle.fill"
        }
        return selectedIndex == index ? "largecircle.fill.circle" : "circle"
    }

    private struct Feedback {
        let isCorrect: Bool
        let message: String
    }

    private func failureMessage(for failure: QuizEngine.SubmissionFailure) -> String {
        switch failure {
        case .missingSelection:
            return "Select an answer to continue."
        case .invalidSelection:
            return "That option isn't available. Please try again."
        case .missingContent, .scoringMismatch:
            return "We couldn't grade this quiz right now. Please close and retry later."
        }
    }
}

private struct ConfettiView: UIViewRepresentable {
    let isActive: Bool

    func makeUIView(context: Context) -> ConfettiUIView {
        ConfettiUIView()
    }

    func updateUIView(_ uiView: ConfettiUIView, context: Context) {
        if isActive {
            uiView.play()
        } else {
            uiView.stop()
        }
    }
}

private final class ConfettiUIView: UIView {
    private let emitter = CAEmitterLayer()
    private var isPlaying = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        emitter.emitterShape = .line
        emitter.emitterCells = ConfettiUIView.makeEmitterCells()
        emitter.birthRate = 0
        layer.addSublayer(emitter)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        emitter.frame = bounds
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: -10)
        emitter.emitterSize = CGSize(width: max(bounds.width, 1), height: 1)
    }

    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        emitter.beginTime = CACurrentMediaTime()
        emitter.birthRate = 1
    }

    func stop() {
        guard isPlaying else { return }
        isPlaying = false
        emitter.birthRate = 0
    }

    private static func makeEmitterCells() -> [CAEmitterCell] {
        let colors: [UIColor] = [
            UIColor.systemPink,
            UIColor.systemTeal,
            UIColor.systemYellow,
            UIColor.systemPurple,
            UIColor.systemGreen
        ]

        return colors.enumerated().map { index, color in
            let cell = CAEmitterCell()
            cell.name = "confetti\(index)"
            cell.contents = makeImage(color: color).cgImage
            cell.birthRate = 10
            cell.lifetime = 3.2
            cell.lifetimeRange = 1.0
            cell.velocity = 200
            cell.velocityRange = 80
            cell.yAcceleration = 260
            cell.emissionLongitude = .pi
            cell.emissionRange = .pi / 9
            cell.spin = 3
            cell.spinRange = 4
            cell.scale = 0.35
            cell.scaleRange = 0.2
            return cell
        }
    }

    private static func makeImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 10, height: 16)
        return UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 3)
                .fill()
        }
    }
}

#Preview {
    QuizSheet(
        quiz: Quiz(
            day: 2,
            question: "What is ketosis?",
            options: ["A high-carb state", "Using fat for fuel"],
            correctIndex: 1,
            explanation: "Ketosis is when the body uses fat-derived ketones for energy."
        ),
        isPresented: .constant(true),
        hasStoredCorrectAnswer: false
    ) {}
}
