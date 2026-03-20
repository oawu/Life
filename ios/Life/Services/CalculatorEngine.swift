import Foundation

@Observable
final class CalculatorEngine {
  var displayText: String = "0"
  var currentValue: UInt64 = 0

  private var firstOperand: UInt64 = 0
  private var secondOperand: UInt64?
  private var pendingOperator: Operator?
  private var isEnteringSecond: Bool = false
  private var justEvaluated: Bool = false

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
    case op(Operator)
    case equal
    case clear
  }

  func press(_ key: Key) {
    switch key {
    case .digit(let digit):
      handleDigit(digit)
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
    firstOperand = 0
    secondOperand = nil
    pendingOperator = nil
    isEnteringSecond = false
    justEvaluated = false
    currentValue = 0
    displayText = "0"
  }

  /// 若有未完成運算，執行計算並回傳結果
  func evaluateIfNeeded() -> UInt64 {
    if let op = pendingOperator, let second = secondOperand {
      return calculate(firstOperand, op, second)
    }
    return currentValue
  }

  // MARK: - Private

  private func handleDigit(_ digit: String) {
    guard let digitValue = UInt64(digit) else {
      return
    }

    if justEvaluated {
      firstOperand = 0
      secondOperand = nil
      pendingOperator = nil
      isEnteringSecond = false
      justEvaluated = false
    }

    if isEnteringSecond {
      let current = secondOperand ?? 0
      let newValue = current * 10 + digitValue

      if digitCount(newValue) > maxDigits {
        return
      }
      if newValue < current {
        return
      }

      secondOperand = newValue
    } else {
      let newValue = firstOperand * 10 + digitValue

      if digitCount(newValue) > maxDigits {
        return
      }
      if newValue < firstOperand {
        return
      }

      firstOperand = newValue
    }
  }

  private func handleOperator(_ op: Operator) {
    justEvaluated = false

    // 連續運算：若已有第二運算數，先計算
    if isEnteringSecond, let second = secondOperand {
      firstOperand = calculate(firstOperand, pendingOperator!, second)
      secondOperand = nil
      currentValue = firstOperand
    }

    pendingOperator = op
    isEnteringSecond = true
    secondOperand = nil
    currentValue = firstOperand
  }

  private func handleEqual() {
    guard let op = pendingOperator else {
      currentValue = firstOperand
      return
    }

    let second = secondOperand ?? 0
    let result = calculate(firstOperand, op, second)

    firstOperand = result
    secondOperand = nil
    pendingOperator = nil
    isEnteringSecond = false
    justEvaluated = true
    currentValue = result
  }

  private func calculate(_ first: UInt64, _ op: Operator, _ second: UInt64) -> UInt64 {
    switch op {
    case .add:
      let range = UInt64.max - first
      return first + (second <= range ? second : range)
    case .subtract:
      return first > second ? first - second : 0
    case .multiply:
      if first == 0 {
        return 0
      }
      let range = UInt64(floor(Double(UInt64.max) / Double(first)))
      return first * (second <= range ? second : range)
    case .divide:
      if second == 0 {
        return first
      }
      return UInt64(ceil(Double(first) / Double(second)))
    }
  }

  private func updateDisplay() {
    var text = formatNumber(firstOperand)

    if let op = pendingOperator {
      text += " \(op)"
      if let second = secondOperand {
        text += " \(formatNumber(second))"
      }
    }

    displayText = text
    currentValue = isEnteringSecond ? (secondOperand ?? firstOperand) : firstOperand
  }

  private func formatNumber(_ value: UInt64) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ","
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
  }

  private func digitCount(_ value: UInt64) -> Int {
    if value == 0 {
      return 1
    }
    return Int(log10(Double(value))) + 1
  }
}
