import SwiftUI

struct OnboardingView: View {
    @Binding var isDone: Bool
    @State private var appeared  = false
    @State private var orbFloat  = false
    @State private var ctaBreathe = false
    @State private var ringRotate = false

    var body: some View {
        ZStack {
            AmbientBackground()

            VStack(spacing: 0) {
                Spacer()
                heroSection
                Spacer()
                featuresSection
                Spacer(minLength: 36)
                ctaButton
                    .padding(.bottom, 52)
            }
            .padding(.horizontal, 28)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.65).delay(0.1)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true).delay(0.8)) {
                orbFloat = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(1.6)) {
                ctaBreathe = true
            }
            withAnimation(.linear(duration: 14).repeatForever(autoreverses: false).delay(0.4)) {
                ringRotate = true
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 28) {
            ZStack {
                // Outer glow — breathes
                Circle()
                    .fill(Color.violet.opacity(0.09))
                    .frame(width: 210, height: 210)
                    .blur(radius: 40)
                    .scaleEffect(orbFloat ? 1.20 : 0.85)

                // Slow rotating arc
                Circle()
                    .trim(from: 0, to: 0.65)
                    .stroke(
                        AngularGradient(
                            colors: [Color.violet.opacity(0), Color.violet.opacity(0.55), Color.violet.opacity(0)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 1, lineCap: .round)
                    )
                    .frame(width: 156, height: 156)
                    .rotationEffect(.degrees(ringRotate ? 360 : 0))

                // Static inner ring
                Circle()
                    .strokeBorder(Color.violet.opacity(orbFloat ? 0.32 : 0.14), lineWidth: 1)
                    .frame(width: 112, height: 112)

                // Icon backdrop
                Circle()
                    .fill(Color.violet.opacity(0.10))
                    .frame(width: 86, height: 86)
                    .overlay {
                        Circle().strokeBorder(Color.violet.opacity(0.18), lineWidth: 0.5)
                    }

                // Icon — floats
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40, weight: .thin))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, Color.violet],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .offset(y: orbFloat ? -5 : 3)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.52)

            VStack(spacing: 10) {
                Text("LocalAI")
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .gradientForeground([.white, Color.violet.opacity(0.72)])
                    .glow(Color.violet, radius: 20)

                Text("Нейросеть прямо\nна твоём iPhone")
                    .font(.system(size: 18, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.txt2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 22)
        }
    }

    // MARK: - Features (3-column grid)

    private var featuresSection: some View {
        HStack(spacing: 10) {
            FeatureCell(
                icon: "lock.fill",
                color: Color(hex: "34C759"),
                title: "Приватно",
                sub: "Данные не\nпокидают\nустройство",
                delay: 0.10
            )
            FeatureCell(
                icon: "wifi.slash",
                color: Color.orange,
                title: "Офлайн",
                sub: "Работает\nбез\nинтернета",
                delay: 0.20
            )
            FeatureCell(
                icon: "cpu",
                color: Color.violet,
                title: "GPT-3.5",
                sub: "7B модели\nна твоём\niPhone",
                delay: 0.30
            )
        }
    }

    // MARK: - CTA

    private var ctaButton: some View {
        VStack(spacing: 14) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) { isDone = true }
            } label: {
                HStack(spacing: 10) {
                    Text("Начать")
                        .font(.system(size: 18, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                        .offset(x: ctaBreathe ? 4 : 0)
                }
                // Dark text on bright teal — more distinctive than white on purple
                .foregroundStyle(Color(hex: "07090F"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.violet)
                        .shadow(
                            color: Color.violet.opacity(ctaBreathe ? 0.40 : 0.18),
                            radius: 22, y: 6
                        )
                }
            }
            .buttonStyle(PressButtonStyle())
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 22)
            .scaleEffect(appeared ? 1 : 0.9)

            Text("Бесплатно · Без регистрации · Без облака")
                .font(.system(size: 12))
                .foregroundStyle(Color.txt3)
                .opacity(appeared ? 1 : 0)
        }
    }
}

// MARK: - Feature Cell

private struct FeatureCell: View {
    let icon: String
    let color: Color
    let title: String
    let sub: String
    let delay: Double

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 50, height: 50)
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(color.opacity(0.22), lineWidth: 0.5)
                    }
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(color)
                    .scaleEffect(appeared ? 1 : 0.3)
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.txt1)
                Text(sub)
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.txt2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 8)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.borderHi, lineWidth: 0.5)
                }
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.86)
        .offset(y: appeared ? 0 : 18)
        .onAppear {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.68).delay(delay + 0.4)) {
                appeared = true
            }
        }
    }
}
