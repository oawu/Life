import SwiftUI

struct CalculatorView: View {
    @Bindable var engine: CalculatorEngine
    var currency: Currency = .twd

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(spacing: 12) {
            // 顯示列
            HStack {
                Text(currency.name)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(currency == .twd ? Color(.secondaryLabel) : .white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(currency == .twd ? Color(.tertiarySystemFill) : .orange)
                    .clipShape(Capsule())

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    let parts = engine.displayText.components(separatedBy: " ")
                    ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                        if ["+", "-", "×", "÷"].contains(part) {
                            Text(part)
                                .font(.system(size: 36, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        } else {
                            Text(part)
                                .font(.system(size: 40, weight: .semibold, design: .rounded))
                                .contentTransition(.numericText())
                        }
                    }

                    Text(currency.unitLabel)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            }
            .padding(.horizontal, 0)
            .padding(.top, 4)

            Divider()

            // 鍵盤
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(keys, id: \.label) { key in
                    CalculatorButton(key: key) {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            engine.press(key.engineKey)
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal, 12)
    }

    private var keys: [KeyDef] {
        [
            KeyDef(label: "7", engineKey: .digit("7"), style: .digit),
            KeyDef(label: "8", engineKey: .digit("8"), style: .digit),
            KeyDef(label: "9", engineKey: .digit("9"), style: .digit),
            KeyDef(label: "÷", engineKey: .op(.divide), style: .op),

            KeyDef(label: "4", engineKey: .digit("4"), style: .digit),
            KeyDef(label: "5", engineKey: .digit("5"), style: .digit),
            KeyDef(label: "6", engineKey: .digit("6"), style: .digit),
            KeyDef(label: "×", engineKey: .op(.multiply), style: .op),

            KeyDef(label: "1", engineKey: .digit("1"), style: .digit),
            KeyDef(label: "2", engineKey: .digit("2"), style: .digit),
            KeyDef(label: "3", engineKey: .digit("3"), style: .digit),
            KeyDef(label: "-", engineKey: .op(.subtract), style: .op),

            KeyDef(label: "清除", engineKey: .clear, style: .clear),
            KeyDef(label: "0", engineKey: .digit("0"), style: .digit),
            KeyDef(label: "=", engineKey: .equal, style: .equal),
            KeyDef(label: "+", engineKey: .op(.add), style: .op),
        ]
    }
}

// MARK: - Key Definitions

private struct KeyDef {
    let label: String
    let engineKey: CalculatorEngine.Key
    let style: KeyStyle
}

private enum KeyStyle {
    case digit
    case op
    case equal
    case clear
}

// MARK: - Calculator Button

private struct CalculatorButton: View {
    let key: KeyDef
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Text(key.label)
                .font(.system(size: key.style == .clear ? 16 : 24, weight: .medium, design: .rounded))
                .foregroundStyle(foregroundColor)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var foregroundColor: Color {
        switch key.style {
        case .digit:  return .primary
        case .op:     return .white
        case .equal:  return .white
        case .clear:  return .red
        }
    }

    private var backgroundColor: Color {
        switch key.style {
        case .digit:  return Color(.quaternarySystemFill)
        case .op:     return .orange
        case .equal:  return .blue
        case .clear:  return Color(.systemRed).opacity(0.15)
        }
    }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    CalculatorView(engine: CalculatorEngine())
        .background(Color(.systemGroupedBackground))
}
