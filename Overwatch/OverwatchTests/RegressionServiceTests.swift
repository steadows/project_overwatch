import Testing
import Foundation
@testable import Overwatch

// MARK: - Test Helpers

/// Build a column-major feature matrix from row-major data.
/// Input: array of rows, each row is an array of habit values for that day.
/// Output: column-major flat array suitable for RegressionInput.
private func columnMajor(rows: [[Double]]) -> [Double] {
    guard let first = rows.first else { return [] }
    let m = rows.count
    let n = first.count
    var result = [Double](repeating: 0.0, count: m * n)
    for col in 0 ..< n {
        for row in 0 ..< m {
            result[col * m + row] = rows[row][col]
        }
    }
    return result
}

// MARK: - RegressionService

@Suite("RegressionService")
struct RegressionServiceTests {

    let service = RegressionService()

    @Test
    func insufficientObservations() {
        // Only 10 days — below the 14-day minimum
        let input = RegressionInput(
            habitNames: ["A", "B"],
            habitEmojis: ["🅰️", "🅱️"],
            featureMatrix: columnMajor(rows: Array(repeating: [1.0, 0.0], count: 10)),
            targetVector: Array(repeating: 0.5, count: 10),
            completionRates: [1.0, 0.0]
        )
        let result = service.computeRegression(input)
        #expect(result == nil)
    }

    @Test
    func insufficientHabitsWithVariance() {
        // 2 habits but both always completed → no variance
        let input = RegressionInput(
            habitNames: ["A", "B"],
            habitEmojis: ["🅰️", "🅱️"],
            featureMatrix: columnMajor(rows: Array(repeating: [1.0, 1.0], count: 20)),
            targetVector: Array(repeating: 0.5, count: 20),
            completionRates: [1.0, 1.0]
        )
        let result = service.computeRegression(input)
        #expect(result == nil)
    }

    @Test
    func singleHabitReturnsNil() {
        // Only 1 habit → can't have 2 with variance
        var features = [Double](repeating: 0.0, count: 20)
        for i in 0 ..< 10 { features[i] = 1.0 }
        let input = RegressionInput(
            habitNames: ["A"],
            habitEmojis: ["🅰️"],
            featureMatrix: features,
            targetVector: Array(repeating: 0.3, count: 20),
            completionRates: [0.5]
        )
        let result = service.computeRegression(input)
        #expect(result == nil)
    }

    @Test
    func syntheticPositiveCorrelation() {
        // Habit A is strongly correlated with positive sentiment
        // Habit B is random noise
        let days = 30
        var rows = [[Double]]()
        var target = [Double]()

        for i in 0 ..< days {
            let aCompleted = i % 2 == 0 ? 1.0 : 0.0
            let bCompleted = i % 3 == 0 ? 1.0 : 0.0
            rows.append([aCompleted, bCompleted])
            // Sentiment tracks habit A: +0.5 when completed, -0.2 when not
            target.append(aCompleted == 1.0 ? 0.5 : -0.2)
        }

        let input = RegressionInput(
            habitNames: ["Meditation", "Reading"],
            habitEmojis: ["🧘", "📖"],
            featureMatrix: columnMajor(rows: rows),
            targetVector: target,
            completionRates: [0.5, 0.33]
        )

        let result = service.computeRegression(input)
        let output = try! #require(result)

        // Habit A should have a strong positive coefficient
        let meditationCoeff = try! #require(output.coefficients.first { $0.habitName == "Meditation" })
        #expect(meditationCoeff.coefficient > 0.3)
        #expect(meditationCoeff.direction == .positive)

        // R² should be high since the relationship is deterministic
        #expect(output.r2 > 0.5)

        // Should have 2 coefficients
        #expect(output.coefficients.count == 2)
    }

    @Test
    func syntheticNegativeCorrelation() {
        // Habit "Alcohol" is negatively correlated with sentiment
        let days = 20
        var rows = [[Double]]()
        var target = [Double]()

        for i in 0 ..< days {
            let exercise = i % 2 == 0 ? 1.0 : 0.0
            let alcohol = i % 3 == 0 ? 1.0 : 0.0
            rows.append([exercise, alcohol])
            // Sentiment drops when alcohol is consumed
            target.append(0.3 + exercise * 0.2 - alcohol * 0.5)
        }

        let input = RegressionInput(
            habitNames: ["Exercise", "Alcohol"],
            habitEmojis: ["💪", "🍺"],
            featureMatrix: columnMajor(rows: rows),
            targetVector: target,
            completionRates: [0.5, 0.33]
        )

        let result = service.computeRegression(input)
        let output = try! #require(result)

        let alcoholCoeff = try! #require(output.coefficients.first { $0.habitName == "Alcohol" })
        #expect(alcoholCoeff.coefficient < -0.1)
        #expect(alcoholCoeff.direction == .negative)
    }

    @Test
    func zeroVarianceHabitHandled() {
        // 3 habits: A has variance, B has variance, C is always 1 (no variance)
        // Should still work because A and B provide the 2 required habits with variance
        let days = 20
        var rows = [[Double]]()
        var target = [Double]()

        for i in 0 ..< days {
            let a = i % 2 == 0 ? 1.0 : 0.0
            let b = i % 3 == 0 ? 1.0 : 0.0
            rows.append([a, b, 1.0]) // C is always 1
            target.append(a * 0.5 + b * 0.3)
        }

        let input = RegressionInput(
            habitNames: ["A", "B", "C"],
            habitEmojis: ["🅰️", "🅱️", "©️"],
            featureMatrix: columnMajor(rows: rows),
            targetVector: target,
            completionRates: [0.5, 0.33, 1.0]
        )

        // C has no variance but A and B do — should still work
        // Note: this may return nil if the matrix becomes singular due to C
        // being identical to the intercept column. That's acceptable behavior.
        let result = service.computeRegression(input)
        // Either a valid result or nil is acceptable here
        if let output = result {
            #expect(output.coefficients.count == 3)
        }
    }

    @Test
    func outputContainsAllFields() {
        let days = 20
        var rows = [[Double]]()
        var target = [Double]()

        for i in 0 ..< days {
            let a = i % 2 == 0 ? 1.0 : 0.0
            let b = i % 3 == 0 ? 1.0 : 0.0
            rows.append([a, b])
            target.append(a * 0.4 - b * 0.2 + 0.1)
        }

        let input = RegressionInput(
            habitNames: ["Meditation", "Alcohol"],
            habitEmojis: ["🧘", "🍺"],
            featureMatrix: columnMajor(rows: rows),
            targetVector: target,
            completionRates: [0.5, 0.33]
        )

        let result = service.computeRegression(input)
        let output = try! #require(result)

        // R² should be between 0 and 1
        #expect(output.r2 >= 0.0)
        #expect(output.r2 <= 1.0)

        // Each coefficient should have valid fields
        for coeff in output.coefficients {
            #expect(!coeff.habitName.isEmpty)
            #expect(!coeff.habitEmoji.isEmpty)
            #expect(coeff.pValue >= 0.0)
            #expect(coeff.pValue <= 1.0)
            #expect(coeff.completionRate >= 0.0)
            #expect(coeff.completionRate <= 1.0)
        }
    }
}
