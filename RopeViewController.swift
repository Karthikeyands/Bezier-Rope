import UIKit
import CoreMotion

class RopeViewController: UIViewController {

    // --- 1. STATE & PROPERTIES ---
    
    private var ropeView: RopeView!
    private let motionManager = CMMotionManager()
    private var displayLink: CADisplayLink?

    // Target position driven by the gyroscope
    private var targetPosition = CGPoint.zero

    // Physics parameters
    private let physicsSettings = SpringParameters(
        mass: 1.0,
        stiffness: 200.0,
        damping: 10.0
    )

    // Physics state for the two dynamic control points
    private var p1_state: PhysicsState!
    private var p2_state: PhysicsState!

    // Fixed anchor points
    private let p0 = CGPoint(x: 50, y: 400)
    private let p3 = CGPoint(x: 350, y: 400)


    // --- 2. VIEW LIFECYCLE & SETUP ---

    override func loadView() {
        // Initialize the custom RopeView and set it as the main view
        ropeView = RopeView(frame:.zero)
        ropeView.backgroundColor =.systemBackground
        self.view = ropeView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize target and physics points to the center
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        targetPosition = center
        
        // Set fixed anchors relative to view bounds
        let p0_abs = CGPoint(x: 50, y: center.y)
        let p3_abs = CGPoint(x: view.bounds.width - 50, y: center.y)
        
        // Initialize dynamic points
        p1_state = PhysicsState(position: CGPoint(x: view.bounds.midX - 100, y: center.y))
        p2_state = PhysicsState(position: CGPoint(x: view.bounds.midX + 100, y: center.y))
        
        // Pass initial points to the view for drawing
        ropeView.updatePoints(p0: p0_abs, p1: p1_state.position, p2: p2_state.position, p3: p3_abs)
        
        startGyroscope()
        startAnimationLoop()
    }

    // --- 3. CORE MOTION (GYROSCOPE) ---
    
    private func startGyroscope() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 60.0 // Match display FPS
            
            // Start updates and provide a handler block [15, 16, 17]
            motionManager.startDeviceMotionUpdates(to:.main) { [weak self] (data, error) in
                guard let self = self, let data = data else { return }
                
                // Get the attitude (orientation) data [19, 18]
                let attitude = data.attitude
                self.updateTargetWithAttitude(attitude)
            }
        } else {
            print("Gyroscope not available. Using center point as target.")
            self.targetPosition = self.view.center
        }
    }
    
    /**
     Maps 3D gyroscope data (roll, pitch) to 2D screen coordinates. [18]
     - Roll (side-to-side tilt) maps to screen X.
     - Pitch (up/down tilt) maps to screen Y.
     */
    private func updateTargetWithAttitude(_ attitude: CMAttitude) {
        let screenSize = self.view.bounds.size
        
        // attitude.roll: Tilting side-to-side (longitudinal axis) [18]
        let roll = attitude.roll
        
        // attitude.pitch: Tilting up/down (lateral axis) [18]
        let pitch = attitude.pitch

        // Remap roll from a sensible range [-π/2, π/2] to [0, screen.width]
        let targetX = remap(roll, -(.pi / 2),.pi / 2, 0, screenSize.width)
        
        // Remap pitch from a sensible range [-π/2, 0] (e.g., flat to vertical) to [0, screen.height]
        let targetY = remap(pitch, -(.pi / 2), 0, 0, screenSize.height)
        
        // Clamp values to stay within screen bounds
        self.targetPosition.x = max(0, min(screenSize.width, targetX))
        self.targetPosition.y = max(0, min(screenSize.height, targetY))
    }

    // --- 4. ANIMATION LOOP (CADisplayLink) ---

    private func startAnimationLoop() {
        // CADisplayLink is a timer synchronized with the display's refresh rate [12]
        displayLink = CADisplayLink(target: self, selector: #selector(step))
        displayLink?.add(to:.current, forMode:.default)
    }

    @objc private func step(displaylink: CADisplayLink) {
        // Calculate frame-rate-independent delta-time (dt) [12]
        let dt = displaylink.targetTimestamp - displaylink.timestamp
        
        // 1. Update logic
        update(dt: dt)
        
        // 2. Trigger render
        // Pass the new points to the view
        ropeView.updatePoints(
            p0: p0,
            p1: p1_state.position,
            p2: p2_state.position,
            p3: p3
        )
        // Tell the view it needs to re-draw
        ropeView.setNeedsDisplay()
    }
    
    // --- 5. PHYSICS UPDATE ---
    
    private func update(dt: TimeInterval) {
        let dt_cg = CGFloat(dt)
        
        // Update both points based on the same physics function
        p1_state = springStep(state: p1_state, target: targetPosition, dt: dt_cg)
        p2_state = springStep(state: p2_state, target: targetPosition, dt: dt_cg)
    }
    
    /**
     Calculates the next physics state using Semi-Implicit Euler integration.
     Based on Hooke's Law and linear damping. [8]
     a = (-k * (pos - target) - d * v) / m
     */
    private func springStep(state: PhysicsState, target: CGPoint, dt: CGFloat) -> PhysicsState {
        let (m, k, d) = (physicsSettings.mass, physicsSettings.stiffness, physicsSettings.damping)
        var newState = state

        // --- Update X-axis ---
        let F_spring_x = -k * (state.position.x - target.x)
        let F_damp_x = -d * state.velocity.x
        let ax = (F_spring_x + F_damp_x) / m
        
        newState.velocity.x += ax * dt
        newState.position.x += newState.velocity.x * dt
        
        // --- Update Y-axis ---
        let F_spring_y = -k * (state.position.y - target.y)
        let F_damp_y = -d * state.velocity.y
        let ay = (F_spring_y + F_damp_y) / m
        
        newState.velocity.y += ay * dt
        newState.position.y += newState.velocity.y * dt
        
        return newState
    }
    
    // --- 6. HELPER STRUCTS & FUNCTIONS ---

    private struct PhysicsState {
        var position: CGPoint =.zero
        var velocity: CGPoint =.zero // Using CGPoint as a 2D vector
    }
    
    private struct SpringParameters {
        let mass: CGFloat
        let stiffness: CGFloat // k
        let damping: CGFloat   // d
    }

    // Helper to remap a value from one range to another
    private func remap(_ value: CGFloat, _ from1: CGFloat, _ to1: CGFloat, _ from2: CGFloat, _ to2: CGFloat) -> CGFloat {
        return (value - from1) / (to1 - from1) * (to2 - from2) + from2
    }
    
    deinit {
        // Clean up resources
        displayLink?.invalidate()
        motionManager.stopDeviceMotionUpdates()
    }
}