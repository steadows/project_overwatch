import Foundation
import Accelerate

// MARK: - RegressionInput

/// Input data for a linear regression: feature matrix (habits x days) and target vector (sentiment scores).
struct RegressionInput: Sendable {
    /// Habit names in column order.
    let habitNames: [String]
    /// Habit emoji in column order (matches habitNames).
    let habitEmojis: [String]
    /// Feature matrix in column-major order: element [row, col] = featureMatrix[col * observationCount + row].
    /// Each value is 1.0 (habit completed that day) or 0.0 (not completed).
    let featureMatrix: [Double]
    /// Target vector: daily sentiment scores, length = number of days.
    let targetVector: [Double]
    /// Habit completion rates (0.0-1.0), one per habit.
    let completionRates: [Double]

    /// Number of observations (days).
    var observationCount: Int { targetVector.count }
    /// Number of features (habits).
    var featureCount: Int { habitNames.count }
}

// MARK: - RegressionOutput

/// Result of a linear regression analysis.
struct RegressionOutput: Sendable {
    /// Per-habit coefficients with statistical metadata.
    let coefficients: [HabitCoefficient]
    /// R-squared: proportion of variance explained (0.0-1.0).
    let r2: Double
    /// Y-intercept of the regression model.
    let intercept: Double
}

// MARK: - RegressionService

/// Performs ordinary least-squares linear regression using Accelerate.
///
/// Thread-safe value-type service (no mutable state). Computes how each habit
/// correlates with daily sentiment scores via the normal equation:
/// β = (X'X)^(-1) X'y
final class RegressionService: Sendable {

    /// Minimum observations required for a meaningful regression.
    private static let minimumObservations = 14
    /// Minimum habits with variance required.
    private static let minimumHabitsWithVariance = 2

    // MARK: - Public API

    /// Compute OLS regression of habit completion against sentiment scores.
    ///
    /// - Returns: `RegressionOutput` with per-habit coefficients, R², and intercept.
    ///   Returns `nil` if there are fewer than 14 observations or fewer than 2 habits with variance.
    func computeRegression(_ input: RegressionInput) -> RegressionOutput? {
        let m = input.observationCount   // rows (days)
        let n = input.featureCount       // columns (habits)

        guard m >= Self.minimumObservations, n >= 1 else { return nil }

        // Check: need at least 2 habits with variance
        let habitsWithVariance = countHabitsWithVariance(input.featureMatrix, rows: m, cols: n)
        guard habitsWithVariance >= Self.minimumHabitsWithVariance else { return nil }

        // Build augmented matrix X with intercept column [1 | features], column-major
        // nAug = n + 1 (intercept + habits)
        let nAug = n + 1

        // X is m x nAug, column-major
        var X = [Double](repeating: 0.0, count: m * nAug)

        // Column 0: intercept (all 1s)
        for row in 0 ..< m {
            X[row] = 1.0
        }
        // Columns 1..n: habit features from input (column-major)
        for col in 0 ..< n {
            let srcOffset = col * m
            let dstOffset = (col + 1) * m
            for row in 0 ..< m {
                X[dstOffset + row] = input.featureMatrix[srcOffset + row]
            }
        }

        let y = input.targetVector

        // Normal equation: β = (X'X)^(-1) X'y
        // Step 1: Compute X'X (nAug x nAug)
        var XtX = [Double](repeating: 0.0, count: nAug * nAug)
        // X'X = Σ over rows: x_i * x_i'
        // Using vDSP for dot products column by column
        for i in 0 ..< nAug {
            for j in i ..< nAug {
                var dot = 0.0
                vDSP_dotprD(
                    Array(X[(i * m) ..< (i * m + m)]), 1,
                    Array(X[(j * m) ..< (j * m + m)]), 1,
                    &dot,
                    vDSP_Length(m)
                )
                XtX[j * nAug + i] = dot  // column-major
                XtX[i * nAug + j] = dot  // symmetric
            }
        }

        // Step 2: Compute X'y (nAug x 1)
        var Xty = [Double](repeating: 0.0, count: nAug)
        for i in 0 ..< nAug {
            var dot = 0.0
            vDSP_dotprD(
                Array(X[(i * m) ..< (i * m + m)]), 1,
                y, 1,
                &dot,
                vDSP_Length(m)
            )
            Xty[i] = dot
        }

        // Step 3: Solve (X'X) β = X'y via Cholesky decomposition
        // Since X'X is symmetric positive semi-definite, use dposv_ or manual inversion
        guard let beta = solveSymmetric(XtX, rhs: Xty, n: nAug) else {
            return nil
        }

        let intercept = beta[0]
        let rawCoefficients = Array(beta[1...])

        // Compute R-squared
        let r2 = computeR2(X: X, y: y, beta: beta, rows: m, nAug: nAug)

        // Compute residuals for p-values
        let residuals = computeResiduals(X: X, y: y, beta: beta, rows: m, nAug: nAug)
        let df = m - nAug
        let pValues = computePValues(
            XtX: XtX,
            residuals: residuals,
            coefficients: rawCoefficients,
            nAug: nAug,
            df: df
        )

        // Build HabitCoefficient array
        var habitCoefficients: [HabitCoefficient] = []
        for i in 0 ..< n {
            let coeff = rawCoefficients[i]
            let pValue = i < pValues.count ? pValues[i] : 1.0
            let completionRate = i < input.completionRates.count ? input.completionRates[i] : 0.0

            let direction: HabitCoefficient.Direction
            if coeff > 0.01 { direction = .positive }
            else if coeff < -0.01 { direction = .negative }
            else { direction = .neutral }

            habitCoefficients.append(HabitCoefficient(
                habitName: input.habitNames[i],
                habitEmoji: input.habitEmojis[i],
                coefficient: coeff,
                pValue: pValue,
                completionRate: completionRate,
                direction: direction
            ))
        }

        return RegressionOutput(
            coefficients: habitCoefficients,
            r2: max(0, min(r2, 1.0)),
            intercept: intercept
        )
    }

    // MARK: - Linear Solve (Gaussian Elimination with Partial Pivoting)

    /// Solve Ax = b for symmetric A using Gaussian elimination with partial pivoting.
    private func solveSymmetric(_ A: [Double], rhs b: [Double], n: Int) -> [Double]? {
        // Augmented matrix [A | b] stored row-major for easier pivoting
        var aug = [Double](repeating: 0.0, count: n * (n + 1))
        for row in 0 ..< n {
            for col in 0 ..< n {
                aug[row * (n + 1) + col] = A[col * n + row] // A is column-major → row-major
            }
            aug[row * (n + 1) + n] = b[row]
        }

        // Forward elimination with partial pivoting
        for col in 0 ..< n {
            // Find pivot
            var maxVal = abs(aug[col * (n + 1) + col])
            var maxRow = col
            for row in (col + 1) ..< n {
                let val = abs(aug[row * (n + 1) + col])
                if val > maxVal {
                    maxVal = val
                    maxRow = row
                }
            }

            guard maxVal > 1e-12 else { return nil } // Singular matrix

            // Swap rows
            if maxRow != col {
                for k in 0 ..< (n + 1) {
                    let temp = aug[col * (n + 1) + k]
                    aug[col * (n + 1) + k] = aug[maxRow * (n + 1) + k]
                    aug[maxRow * (n + 1) + k] = temp
                }
            }

            // Eliminate below
            let pivot = aug[col * (n + 1) + col]
            for row in (col + 1) ..< n {
                let factor = aug[row * (n + 1) + col] / pivot
                for k in col ..< (n + 1) {
                    aug[row * (n + 1) + k] -= factor * aug[col * (n + 1) + k]
                }
            }
        }

        // Back substitution
        var x = [Double](repeating: 0.0, count: n)
        for row in stride(from: n - 1, through: 0, by: -1) {
            var sum = aug[row * (n + 1) + n]
            for col in (row + 1) ..< n {
                sum -= aug[row * (n + 1) + col] * x[col]
            }
            x[row] = sum / aug[row * (n + 1) + row]
        }

        return x
    }

    // MARK: - R-Squared

    private func computeR2(X: [Double], y: [Double], beta: [Double], rows: Int, nAug: Int) -> Double {
        let yMean = y.reduce(0, +) / Double(rows)
        var ssRes = 0.0
        var ssTot = 0.0

        for row in 0 ..< rows {
            var predicted = 0.0
            for col in 0 ..< nAug {
                predicted += beta[col] * X[col * rows + row]
            }
            let residual = y[row] - predicted
            ssRes += residual * residual
            let deviation = y[row] - yMean
            ssTot += deviation * deviation
        }

        guard ssTot > 1e-12 else { return 0.0 }
        return 1.0 - (ssRes / ssTot)
    }

    // MARK: - Residuals

    private func computeResiduals(X: [Double], y: [Double], beta: [Double], rows: Int, nAug: Int) -> [Double] {
        var residuals = [Double](repeating: 0.0, count: rows)
        for row in 0 ..< rows {
            var predicted = 0.0
            for col in 0 ..< nAug {
                predicted += beta[col] * X[col * rows + row]
            }
            residuals[row] = y[row] - predicted
        }
        return residuals
    }

    // MARK: - P-Values

    /// Compute approximate p-values for each habit coefficient using t-statistics.
    private func computePValues(
        XtX: [Double],
        residuals: [Double],
        coefficients: [Double],
        nAug: Int,
        df: Int
    ) -> [Double] {
        let n = coefficients.count // number of habits (nAug - 1)
        guard df > 0 else {
            return [Double](repeating: 1.0, count: n)
        }

        // Residual variance σ² = Σ(residuals²) / df
        let ssr = residuals.reduce(0.0) { $0 + $1 * $1 }
        let sigma2 = ssr / Double(df)

        // Invert X'X to get (X'X)^(-1) for standard errors
        guard let XtXinv = invertMatrix(XtX, n: nAug) else {
            return [Double](repeating: 1.0, count: n)
        }

        // SE(βi) = sqrt(σ² * (X'X)^(-1)_ii)
        // p-value from t-statistic using normal approximation (good for df > ~30)
        var pValues = [Double](repeating: 1.0, count: n)
        for i in 0 ..< n {
            let diagIdx = (i + 1) * nAug + (i + 1) // diagonal of (X'X)^(-1), offset by 1 for intercept
            let variance = sigma2 * XtXinv[diagIdx]
            guard variance > 1e-12 else { continue }

            let se = sqrt(variance)
            let tStat = abs(coefficients[i]) / se

            // 2-tailed p-value approximation using the complementary error function
            // For t-distribution with large df, this converges to the normal distribution
            // p ≈ erfc(|t| / sqrt(2))
            pValues[i] = erfc(tStat / sqrt(2.0))
        }

        return pValues
    }

    // MARK: - Matrix Inversion (Gauss-Jordan)

    /// Invert an n x n matrix (column-major) using Gauss-Jordan elimination.
    private func invertMatrix(_ A: [Double], n: Int) -> [Double]? {
        // Build [A | I] augmented matrix, row-major
        var aug = [Double](repeating: 0.0, count: n * 2 * n)
        for row in 0 ..< n {
            for col in 0 ..< n {
                aug[row * (2 * n) + col] = A[col * n + row] // column-major → row-major
            }
            aug[row * (2 * n) + n + row] = 1.0 // Identity
        }

        let stride = 2 * n

        for col in 0 ..< n {
            // Partial pivoting
            var maxVal = abs(aug[col * stride + col])
            var maxRow = col
            for row in (col + 1) ..< n {
                let val = abs(aug[row * stride + col])
                if val > maxVal {
                    maxVal = val
                    maxRow = row
                }
            }
            guard maxVal > 1e-12 else { return nil }

            if maxRow != col {
                for k in 0 ..< stride {
                    let temp = aug[col * stride + k]
                    aug[col * stride + k] = aug[maxRow * stride + k]
                    aug[maxRow * stride + k] = temp
                }
            }

            // Scale pivot row
            let pivot = aug[col * stride + col]
            for k in 0 ..< stride {
                aug[col * stride + k] /= pivot
            }

            // Eliminate column in all other rows
            for row in 0 ..< n where row != col {
                let factor = aug[row * stride + col]
                for k in 0 ..< stride {
                    aug[row * stride + k] -= factor * aug[col * stride + k]
                }
            }
        }

        // Extract inverse (right half), convert back to column-major
        var inv = [Double](repeating: 0.0, count: n * n)
        for row in 0 ..< n {
            for col in 0 ..< n {
                inv[col * n + row] = aug[row * stride + n + col]
            }
        }

        return inv
    }

    // MARK: - Helpers

    /// Count how many habit columns have non-zero variance (not all 0 or all 1).
    private func countHabitsWithVariance(_ matrix: [Double], rows: Int, cols: Int) -> Int {
        var count = 0
        for col in 0 ..< cols {
            var sum = 0.0
            for row in 0 ..< rows {
                sum += matrix[col * rows + row]
            }
            let mean = sum / Double(rows)
            if mean > 1e-6, mean < (1.0 - 1e-6) {
                count += 1
            }
        }
        return count
    }
}
