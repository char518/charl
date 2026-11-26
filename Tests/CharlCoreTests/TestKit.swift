import Foundation

var totalChecks = 0
var failedChecks = 0
var currentSuite = ""

func suite(_ name: String, _ body: () -> Void) {
    currentSuite = name
    print("▶ \(name)")
    body()
}

func expect(_ condition: Bool, _ message: String, file: StaticString = #file, line: UInt = #line) {
    totalChecks += 1
    if !condition {
        failedChecks += 1
        print("  ✗ [\(currentSuite)] \(message) (\(file):\(line))")
    }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ label: String, file: StaticString = #file, line: UInt = #line) {
    totalChecks += 1
    if actual != expected {
        failedChecks += 1
        print("  ✗ [\(currentSuite)] \(label): got \(actual), expected \(expected) (\(file):\(line))")
    }
}

func finishTests() -> Never {
    if failedChecks == 0 {
        print("✓ all \(totalChecks) checks passed")
        exit(0)
    } else {
        print("✗ \(failedChecks)/\(totalChecks) checks failed")
        exit(1)
    }
}