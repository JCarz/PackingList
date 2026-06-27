import SwiftUI

struct ToastView: View {
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.callout)
                .foregroundStyle(.primary)

            if let actionTitle, let action {
                Button(actionTitle) {
                    action()
                }
                .font(.callout.weight(.semibold))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .shadow(radius: 8)
        .padding(.horizontal)
        .padding(.bottom, 12)
    }
}

struct ToastModifier: ViewModifier {
    @Binding var message: String?
    let actionTitle: String?
    let duration: TimeInterval
    let action: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    ToastView(message: message, actionTitle: actionTitle, action: action)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .allowsHitTesting(actionTitle != nil && action != nil)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: message)
            .onChange(of: message) { _, newValue in
                guard let newValue else {
                    return
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    if message == newValue {
                        message = nil
                    }
                }
            }
    }
}

extension View {
    func toast(message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message, actionTitle: nil, duration: 2, action: nil))
    }

    func toast(
        message: Binding<String?>,
        actionTitle: String?,
        duration: TimeInterval,
        action: (() -> Void)?
    ) -> some View {
        modifier(ToastModifier(message: message, actionTitle: actionTitle, duration: duration, action: action))
    }
}
