import Foundation

@Observable
final class CalculatorEngine {
  var displayText: String = "0"
  var currentValue: Double = 0

  private var firstOperand: String = ""
  private var secondOperand: String = ""
  private var pendingOperator: Operator?
  private var isEnteringSecond: Bool = false
  private var justEvaluated: Bool = false
  private var hasError: Bool = false

  private let maxDigits = 12

  enum Operator: CustomStringConvertible {
    case add, subtract, multiply, divide

    var description: String {
      switch self {
      case .add:      return "+"
      case .subtract: return "-"
      case .multiply: return "×"
      case .divide:   return "÷"
      }
    }
  }

  enum Key {
    case digit(String)
    case dot
    case op(Operator)
    case equal
    case clear
  }

  func press(_ key: Key) {
    if hasError {
      if case .clear = key { } else {
        reset()
      }
    }

    switch key {
    case .digit(let digit):
      handleDigit(digit)
    case .dot:
      handleDot()
    case .op(let op):
      handleOperator(op)
    case .equal:
      handleEqual()
    case .clear:
      reset()
    }

    updateDisplay()
  }

  func reset() {
    firstOperand = ""
    secondOperand = ""
    pendingOperator = nil
    isEnteringSecond = false
    justEvaluated = false
    hasError = false
    currentValue = 0
    displayText = "0"
  }

  /// 若有未完成運算，執行計算並回傳結果
  func evaluateIfNeeded() -> Double {
    if let op = pendingOperator, !secondOperand.isEmpty {
      let first = Double(firstOperand) ?? 0
      let second = Double(secondOperand) ?? 0
      if let result = calculate(first, op, second) {
        return result
      }
    }
    return currentValue
  }

  // MARK: - Private

  private func handleDigit(_ digit: String) {
    if justEvaluated {
      firstOperand = ""
      secondOperand = ""
      pendingOperator = nil
      isEnteringSecond = false
      justEvaluated = false
    }

    if isEnteringSecond {
      if secondOperand.replacingOccurrences(of: ".", with: "").count >= maxDigits {
        return
      }
      if secondOperand == "0" {
        secondOperand = digit
      } else {
        secondOperand += digit
      }
    } else {
      if firstOperand.replacingOccurrences(of: ".", with: "").count >= maxDigits {
        return
      }
      if firstOperand == "0" {
        firstOperand = digit
      } else {
        firstOperand += digit
      }
    }
  }

  private func handleDot() {
    if justEvaluated {
      firstOperand = "0"
      secondOperand = ""
      pendingOperator = nil
      isEnteringSecond = false
      justEvaluated = false
    }

    if isEnteringSecond {
      if secondOperand.contains(".") {
        return
      }
      if secondOperand.isEmpty {
        secondOperand = "0"
      }
      secondOperand += "."
    } else {
      if firstOperand.contains(".") {
        return
      }
      if firstOperand.isEmpty {
        firstOperand = "0"
      }
      firstOperand += "."
    }
  }

  private func handleOperator(_ op: Operator) {
    justEvaluated = false

    if isEnteringSecond && !secondOperand.isEmpty {
      let first = Double(firstOperand) ?? 0
      let second = Double(secondOperand) ?? 0
      guard let result = calculate(first, pendingOperator!, second) else {
        return
      }
      firstOperand = formatNumber(result)
      secondOperand = ""
      currentValue = result
    }

    if firstOperand.isEmpty {
      firstOperand = "0"
    }

    pendingOperator = op
    isEnteringSecond = true
    currentValue = Double(firstOperand) ?? 0
  }

  private func handleEqual() {
    guard let op = pendingOperator else {
      currentValue = Double(firstOperand) ?? 0
      return
    }

    let first = Double(firstOperand) ?? 0
    let second = secondOperand.isEmpty ? 0 : (Double(secondOperand) ?? 0)

    guard let result = calculate(first, op, second) else {
      return
    }

    firstOperand = formatNumber(result)
    secondOperand = ""
    pendingOperator = nil
    isEnteringSecond = false
    justEvaluated = true
    currentValue = result
  }

  private func calculate(_ first: Double, _ op: Operator, _ second: Double) -> Double? {
    switch op {
    case .add:      return first + second
    case .subtract: return first - second
    case .multiply: return first * second
    case .divide:
      if second == 0 {
        hasError = true
        displayText = "錯誤"
        currentValue = 0
        return nil
      }
      return first / second
    }
  }

  private func updateDisplay() {
    if hasError {
      return
    }

    var text = formatDisplay(firstOperand.isEmpty ? "0" : firstOperand)

    if let op = pendingOperator {
      text += " \(op)"
      if !secondOperand.isEmpty {
        text += " \(formatDisplay(secondOperand))"
      }
    }

    displayText = text
    currentValue = Double(isEnteringSecond && !secondOperand.isEmpty ? secondOperand : firstOperand) ?? 0
  }

  private func formatDisplay(_ value: String) -> String {
    if value.contains(".") {
      let parts = value.split(separator: ".", maxSplits: 1)
      let intPart = formatInteger(String(parts[0]))
      let decPart = parts.count > 1 ? String(parts[1]) : ""
      return decPart.isEmpty ? "\(intPart)." : "\(intPart).\(decPart)"
    }
    return formatInteger(value)
  }

  private func formatInteger(_ value: String) -> String {
    guard let number = Int(value) else {
      return value
    }
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ","
    return formatter.string(from: NSNumber(value: number)) ?? value
  }

  private func formatNumber(_ value: Double) -> String {
    if value == value.rounded() && abs(value) < 1e15 {
      return String(format: "%.0f", value)
    }
    let result = String(value)
    // 移除尾端多餘的零
    if result.contains(".") {
      return result.replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
        .replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)
    }
    return result
  }
}
