import SwiftUI

struct CalculatorView: View {
  @Bindable var engine: CalculatorEngine

  private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

  var body: some View {
    VStack(spacing: 12) {
      // 顯示列
      HStack {
        Spacer()
        Text(engine.displayText + " 元")
          .font(.system(size: 40, weight: .semibold, design: .rounded))
          .lineLimit(1)
          .minimumScaleFactor(0.5)
          .contentTransition(.numericText())
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)

      // 鍵盤
      LazyVGrid(columns: columns, spacing: 12) {
        ForEach(keys, id: \.label) { key in
          CalculatorButton(key: key) {
            withAnimation(.easeInOut(duration: 0.1)) {
              engine.press(key.engineKey)
            }
          }
        }
      }
    }
    .padding(.horizontal, 16)
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

      KeyDef(label: "C", engineKey: .clear, style: .clear),
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
        .font(.system(size: 24, weight: .medium, design: .rounded))
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
    case .digit:  return Color(.secondarySystemBackground)
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
