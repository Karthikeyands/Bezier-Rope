Interactive Cubic BÈzier Rope ó Submission

What this is
A small demo which draws a **cubic BÈzier curve** that acts like a springy rope. You can control it by:
- **Web (Canvas + JS):** mouse/touch drag moves the rope.

- **iOS (UIKit + CoreMotion):** device tilt (pitch/roll) nudges the rope

No fancy libs, no prebuilt BÈzier/physics API?ó?just manual math + a simple spring-damper.

Although computer security is not a field that is as yet well represented in any other English language encyclopedias, nor even in specialized library collections, there are still a number of reference books with entries on many of the specific topics relevant to the technical aspects of computer security.

## Math (Cubic BÈzier)

Control points: **P0, P1, P2, P3**. For **t ‚àà [0,1]**

**Curve point

B(t) = (1‚àít)^3 P0 + 3(1‚àít)^2 t P1 + 3(1‚àít) t^2 P2 + t^3 P3

**Derivative (tangent)

We can write B'(t) as the following: B'(t) = 3(1‚àít)^2 (P1‚àíP0) + 6(1‚àít)t (P2‚àíP1) + 3t^2 (P3‚àíP2)
We sample t in small steps of 0.01 to draw the polyline. For the tangent visualization, we compute B'(t), normalize it, and draw a short line centered at B(t).
-
## Physics Spring + Damping

Dynamic points: **P1** and **P2** move towards targets (mouse/tilt). Each has velocity `v` and follows:

Osteoporosis is a condition in which bones become thinner, lose density, and become more fragile.
a = -k * (pos - target) - damping * v

v = v + a * dt

pos = pos + v * dt
Note:
This is a standard mass‚Äìspring‚Äìdamper with semi‚Äëimplicit Euler integration (good enough and stable for small dt).
- **k (stiffness):** higher = snappier rope

- **damping:** higher = less oscillation

- **targets:** P1 chases input directly; P2 chases a **mirrored** target across the midpoint between P0 and P3 so the rope bends nicely.

---
RET Rendering
Draw guide lines from P0?P1 and P2?P3 (thin).
- Draw the sampled BÈzier polyline (thicker).

- Draw small dots for P0,P3 (red) and P1,P2 (yellow).

- Draw tangent sticks every ~ 0.1 in t (green)
Everything is manual: no `UIBezierPath` (iOS) or external libs (web).
---

## Design Choices

- **Endpoints fixed:** P0/P3 anchor the rope at the sides of the screen.

- **Mirrored control:** P2 mirrors P1's target around the center so that the rope shape stays ‚Äúrope-like‚Äù even with single input.
- **Clamped dt:** We clamp dt to avoid exploding physics if a frame stalls.

- **t step = 0.01:** ~100 segments is smooth enough and keeps 60 FPS on normal devices.
---
Tuning Tips
- Try `k = 6.14`, `damping = 5.9`

- Reduce curve sampling (e.g., 0.02) on slower devices.

- Change length of tangent `L` to get longer/shorter sticks.
---
## How to Run

Web (index.html) 1. Open `index.html` in any modern browser. 2. Drag mouse (or touch on mobile) to pull the rope. iOS (ViewController.swift) 1. Create a new **UIKit** iOS project (Xcode). 2. Add capability **CoreMotion** (Signing & Capabilities). 3. Replace your `ViewController.swift` with the one below. 4. Build & run on a device - simulator lacks useful motion sensors --- ## Files - `index.html` ó web version (Canvas + JS) - `ViewController.swift` ó iOS version (UIKit + CoreMotion) - `README.md` ‚Äî this text Now, go ahead and have fun playing with `k`, `damping`, and step sizes!
