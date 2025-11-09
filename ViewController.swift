import UIKit
import CoreMotion

// small helpers to make CGPoint math easy
func +(a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x+b.x, y: a.y+b.y) }
func -(a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x-b.x, y: a.y-b.y) }
func *(a: CGPoint, s: CGFloat) -> CGPoint { CGPoint(x: a.x*s, y: a.y*s) }
func len(_ a: CGPoint) -> CGFloat { sqrt(a.x*a.x + a.y*a.y) }
func norm(_ a: CGPoint) -> CGPoint { let L = max(len(a), 1e-6); return CGPoint(x:a.x/L, y:a.y/L) }

class BezierView: UIView {
    // fixed ends
    var p0 = CGPoint.zero
    var p3 = CGPoint.zero

    // dynamic
    var p1 = CGPoint.zero
    var p2 = CGPoint.zero
    var v1 = CGPoint.zero
    var v2 = CGPoint.zero

    // physics
    var k: CGFloat = 10.0
    var damping: CGFloat = 7.0

    // motion targets
    var t1 = CGPoint.zero
    var t2 = CGPoint.zero

    override func layoutSubviews() {
        super.layoutSubviews()
        // set up endpoints once
        if p0 == .zero && p3 == .zero {
            let w = bounds.width, h = bounds.height
            p0 = CGPoint(x: w*0.15, y: h*0.5)
            p3 = CGPoint(x: w*0.85, y: h*0.5)
            p1 = CGPoint(x: w*0.35, y: h*0.5)
            p2 = CGPoint(x: w*0.65, y: h*0.5)
            t1 = p1
            t2 = p2
        }
    }

    // cubic point
    func bezierPoint(_ t: CGFloat, _ P0: CGPoint,_ P1: CGPoint,_ P2: CGPoint,_ P3: CGPoint) -> CGPoint {
        let u = 1 - t
        let b0 = u*u*u
        let b1 = 3*u*u*t
        let b2 = 3*u*t*t
        let b3 = t*t*t
        return CGPoint(
            x: b0*P0.x + b1*P1.x + b2*P2.x + b3*P3.x,
            y: b0*P0.y + b1*P1.y + b2*P2.y + b3*P3.y
        )
    }

    // derivative (tangent)
    func bezierTangent(_ t: CGFloat, _ P0: CGPoint,_ P1: CGPoint,_ P2: CGPoint,_ P3: CGPoint) -> CGPoint {
        let u = 1 - t
        return CGPoint(
            x: 3*u*u*(P1.x-P0.x) + 6*u*t*(P2.x-P1.x) + 3*t*t*(P3.x-P2.x),
            y: 3*u*u*(P1.y-P0.y) + 6*u*t*(P2.y-P1.y) + 3*t*t*(P3.y-P2.y)
        )
    }

    func step(dt: CGFloat) {
        // spring accel = -k*(pos - target) - damping*vel
        let a1 = (t1 - p1)*k - v1*damping
        let a2 = (t2 - p2)*k - v2*damping
        v1 = v1 + a1*dt
        v2 = v2 + a2*dt
        p1 = p1 + v1*dt
        p2 = p2 + v2*dt
        setNeedsDisplay()
    }

    override func draw(_ r: CGRect) {
        guard let g = UIGraphicsGetCurrentContext() else { return }
        g.clear(r)
        UIColor.black.setFill()
        g.fill(r)

        // guides
        g.setLineWidth(1)
        UIColor(white: 1, alpha: 0.25).setStroke()
        g.beginPath()
        g.move(to: p0); g.addLine(to: p1)
        g.move(to: p2); g.addLine(to: p3)
        g.strokePath()

        // curve
        g.setLineWidth(3)
        UIColor.systemTeal.setStroke()
        g.beginPath()
        var first = true
        var t: CGFloat = 0
        while t <= 1.0001 {
            let P = bezierPoint(t, p0,p1,p2,p3)
            if first { g.move(to: P); first = false } else { g.addLine(to: P) }
            t += 0.01
        }
        g.strokePath()

        // tangents
        UIColor.systemGreen.setStroke()
        let stepT: CGFloat = 0.1
        var tt: CGFloat = 0
        while tt <= 1.0001 {
            let P = bezierPoint(tt, p0,p1,p2,p3)
            let D = bezierTangent(tt, p0,p1,p2,p3)
            let n = norm(D)
            let L: CGFloat = 16
            g.beginPath()
            g.move(to: P - n*L)
            g.addLine(to: P + n*L)
            g.strokePath()
            tt += stepT
        }

        // dots
        func dot(_ P: CGPoint, _ c: UIColor) {
            c.setFill()
            g.fillEllipse(in: CGRect(x: P.x-4, y: P.y-4, width: 8, height: 8))
        }
        dot(p0,.systemRed); dot(p3,.systemRed)
        dot(p1,.systemYellow); dot(p2,.systemYellow)
    }
}

class ViewController: UIViewController {
    let motion = CMMotionManager()
    let viewBz = BezierView()
    var link: CADisplayLink?
    var last: CFTimeInterval = CACurrentMediaTime()

    override func viewDidLoad() {
        super.viewDidLoad()
        viewBz.frame = view.bounds
        viewBz.autoresizingMask = [.flexibleWidth,.flexibleHeight]
        view.addSubview(viewBz)

        // start motion (attitude => choose pitch/roll)
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 1.0/60.0
            motion.startDeviceMotionUpdates()
        }

        let dl = CADisplayLink(target: self, selector: #selector(tick))
        dl.add(to: .main, forMode: .default)
        link = dl

        // simple pan lets you also drag targets
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        view.addGestureRecognizer(pan)
    }

    @objc func panned(_ gr: UIPanGestureRecognizer) {
        let p = gr.location(in: viewBz)
        // pull both targets toward finger a bit
        viewBz.t1 = CGPoint(x: (viewBz.t1.x*0.6 + p.x*0.4), y: (viewBz.t1.y*0.6 + p.y*0.4))
        // mirror across midpoint of p0-p3
        let mid = CGPoint(x:(viewBz.p0.x+viewBz.p3.x)/2, y:(viewBz.p0.y+viewBz.p3.y)/2)
        let v = CGPoint(x: p.x - mid.x, y: p.y - mid.y)
        let m = CGPoint(x: mid.x - v.x, y: mid.y - v.y)
        viewBz.t2 = CGPoint(x: (viewBz.t2.x*0.6 + m.x*0.4), y: (viewBz.t2.y*0.6 + m.y*0.4))
    }

    @objc func tick() {
        let now = CACurrentMediaTime()
        let dt = CGFloat(min(1/30, now - last))
        last = now

        // map device motion to target offsets (small, spring will smooth)
        if let dm = motion.deviceMotion {
            // pitch = x axis tilt, roll = y axis tilt
            let pitch = CGFloat(dm.attitude.pitch)   // ~ -pi/2..pi/2
            let roll  = CGFloat(dm.attitude.roll)    // ~ -pi..pi

            // scale to pixels (tweak these)
            let sx: CGFloat = 120
            let sy: CGFloat = 80

            // base positions around center between p0 and p3
            let mid = CGPoint(x:(viewBz.p0.x+viewBz.p3.x)/2, y:(viewBz.p0.y+viewBz.p3.y)/2)

            // set targets from tilt (p1 follows, p2 mirrored-ish)
            let off = CGPoint(x: roll*sx, y: pitch*sy)
            viewBz.t1 = mid + off*0.9
            viewBz.t2 = mid - off*0.9
        }

        viewBz.step(dt: dt)
    }

    deinit {
        motion.stopDeviceMotionUpdates()
        link?.invalidate()
    }
}
