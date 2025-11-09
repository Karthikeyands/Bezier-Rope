import UIKit

/**
 A custom UIView that handles all "from-scratch" Core Graphics rendering.
 It draws the Bézier curve by manually sampling points, avoiding all built-in
 high-level APIs like CGContextAddCurveToPoint. [20, 21]
 */
class RopeView: UIView {

    // The four control points for the curve.
    // These are updated by the ViewController.
    private var p0: CGPoint =.zero
    private var p1: CGPoint =.zero
    private var p2: CGPoint =.zero
    private var p3: CGPoint =.zero
    
    // Public method for the ViewController to push new state
    func updatePoints(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint) {
        self.p0 = p0
        self.p1 = p1
        self.p2 = p2
        self.p3 = p3
    }

    // --- 1. MAIN DRAWING METHOD ---
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        // --- 1. Draw the Curve Path (Manual Sampling) --- [20, 21]
        context.beginPath()
        context.setStrokeColor(UIColor.systemBlue.cgColor)
        context.setLineWidth(3.0)

        // Get the start point
        let p_start = getPointOnCubicBezier(p0: p0, p1: p1, p2: p2, p3: p3, t: 0)
        context.move(to: p_start)

        // Sample the curve at small increments of t
        let step: CGFloat = 0.01
        for t in stride(from: step, through: 1.0, by: step) {
            let p = getPointOnCubicBezier(p0: p0, p1: p1, p2: p2, p3: p3, t: t)
            context.addLine(to: p) // Use simple lineTo
        }
        context.strokePath()

        // --- 2. Draw Control Points ---
        drawCircle(context: context, p: p0, radius: 6, color:.systemBlue) // Anchor
        drawCircle(context: context, p: p3, radius: 6, color:.systemBlue) // Anchor
        drawCircle(context: context, p: p1, radius: 8, color:.systemRed)  // Dynamic
        drawCircle(context: context, p: p2, radius: 8, color:.systemRed)  // Dynamic
        
        // --- 3. Draw Tangents ---
        drawTangentAt(context: context, t: 0.25)
        drawTangentAt(context: context, t: 0.5)
        drawTangentAt(context: context, t: 0.75)
    }

    // --- 2. BEZIER MATH (FROM SCRATCH) ---

    /**
     Calculates the (x, y) coordinate on a cubic Bézier curve at parameter t.
     B(t) = (1-t)^3*P0 + 3(1-t)^2*t*P1 + 3(1-t)*t^2*P2 + t^3*P3
     [1]
     */
    func getPointOnCubicBezier(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, t: CGFloat) -> CGPoint {
        let oneMinusT = 1 - t
        let oneMinusT_sq = oneMinusT * oneMinusT
        let oneMinusT_cub = oneMinusT_sq * oneMinusT

        let t_sq = t * t
        let t_cub = t_sq * t

        let x = oneMinusT_cub * p0.x +
                  3 * oneMinusT_sq * t * p1.x +
                  3 * oneMinusT * t_sq * p2.x +
                  t_cub * p3.x

        let y = oneMinusT_cub * p0.y +
                  3 * oneMinusT_sq * t * p1.y +
                  3 * oneMinusT * t_sq * p2.y +
                  t_cub * p3.y

        return CGPoint(x: x, y: y)
    }
    
    /**
     Calculates the (x, y) coordinate on a QUADRATIC Bézier curve at t.
     Used to evaluate the hodograph (derivative). [1]
     */
    func getPointOnQuadraticBezier(p0: CGPoint, p1: CGPoint, p2: CGPoint, t: CGFloat) -> CGPoint {
        let oneMinusT = 1 - t
        let oneMinusT_sq = oneMinusT * oneMinusT
        let t_sq = t * t

        let x = oneMinusT_sq * p0.x + 2 * oneMinusT * t * p1.x + t_sq * p2.x
        let y = oneMinusT_sq * p0.y + 2 * oneMinusT * t * p1.y + t_sq * p2.y

        return CGPoint(x: x, y: y)
    }

    /**
     Calculates the tangent vector (derivative) of the cubic curve at t.
     The derivative of a cubic curve is a quadratic curve. [6]
     */
    func getTangentOnCubicBezier(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, t: CGFloat) -> CGPoint {
        // Calculate the control points of the hodograph (derivative curve)
        let q0 = CGPoint(x: 3 * (p1.x - p0.x), y: 3 * (p1.y - p0.y))
        let q1 = CGPoint(x: 3 * (p2.x - p1.x), y: 3 * (p2.y - p1.y))
        let q2 = CGPoint(x: 3 * (p3.x - p2.x), y: 3 * (p3.y - p2.y))

        // Get the point on the quadratic derivative curve
        return getPointOnQuadraticBezier(p0: q0, p1: q1, p2: q2, t: t)
    }

    /**
     Normalizes a vector (scales it to a length of 1).
     */
    func normalize(_ vector: CGPoint) -> CGPoint {
        let mag = sqrt(vector.x * vector.x + vector.y * vector.y)
        // Check for zero-length vector to prevent divide-by-zero
        if mag < 0.0001 {
            return.zero
        }
        return CGPoint(x: vector.x / mag, y: vector.y / mag)
    }

    // --- 3. HELPER DRAWING FUNCTIONS ---
    
    func drawCircle(context: CGContext, p: CGPoint, radius: CGFloat, color: UIColor) {
        context.beginPath()
        context.setFillColor(color.cgColor)
        context.addArc(center: p, radius: radius, startAngle: 0, endAngle: 2 *.pi, clockwise: true)
        context.fillPath()
    }

    func drawTangentAt(context: CGContext, t: CGFloat) {
        let p = getPointOnCubicBezier(p0: p0, p1: p1, p2: p2, p3: p3, t: t)
        let v = getTangentOnCubicBezier(p0: p0, p1: p1, p2: p2, p3: p3, t: t)
        let dir = normalize(v)
        let length: CGFloat = 25.0
        let p_end = CGPoint(x: p.x + dir.x * length, y: p.y + dir.y * length)

        context.beginPath()
        context.setStrokeColor(UIColor.systemGreen.cgColor)
        context.setLineWidth(2.0)
        context.move(to: p)
        context.addLine(to: p_end)
        context.strokePath()
    }
}