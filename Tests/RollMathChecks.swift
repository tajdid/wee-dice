import Foundation
import simd

@main
struct RollMathChecks {
    static func main() {
        var checked = 0
        // All 24 cube poses, each rolled from all 24 starting poses.
        for face in 1...6 { for yaw in 0..<4 {
            let target = RollMath.landing(face: face, quarterTurn: yaw)
            precondition(RollMath.upwardFace(target) == face)
            precondition(target.act(RollMath.faceNormals[face-1]).y > 0.9999)
            precondition(RollMath.upwardFace(simd_quatf(vector: -target.vector)) == face)
            for startFace in 1...6 { for startYaw in 0..<4 {
                let start = RollMath.landing(face: startFace, quarterTurn: startYaw)
                for turns: Float in [2,3] {
                    let axis = simd_normalize(SIMD3<Float>(-0.3,0.87,0.6))
                    var previous = start
                    for step in 0...240 {
                        let q = RollMath.orientation(start: start, target: target, axis: axis, turns: turns, progress: Float(step)/240)
                        precondition(q.vector.x.isFinite && q.vector.y.isFinite && q.vector.z.isFinite && q.vector.w.isFinite)
                        precondition(abs(simd_length(q.vector)-1) < 0.00001)
                        // Quaternion sign is immaterial; reject discontinuous frame jumps.
                        precondition(abs(simd_dot(previous.vector,q.vector)) > 0.98)
                        if step == 0 { precondition(abs(simd_dot(q.vector,start.vector)) > 0.99999) }
                        if step == 240 { precondition(RollMath.upwardFace(q) == face) }
                        previous = q
                    }
                    checked += 1
                }
            }}
        }}
        // World-space squash must preserve volume and never move the bottom
        // through the floor, for any face or landing yaw.
        for face in 1...6 { for yaw in 0..<4 {
            let target = RollMath.landing(face: face, quarterTurn: yaw)
            let axis = simd_normalize(SIMD3<Float>(1,0.3,-0.6))
            for frame in 0...600 {
                let t = Float(frame)/600
                let q = RollMath.orientation(start: RollMath.landing(face: 1,quarterTurn: 0), target: target, axis: axis, turns: 3, progress: min(1,t/0.58))
                let sample = RollMath.motion(t)
                precondition(sample.lift >= 0 && sample.scaleY > 0.7 && sample.scaleY < 1.15)
                precondition(abs(sample.scale.x*sample.scale.y*sample.scale.z-1) < 0.00001)
                let extent = RollMath.verticalExtent(q)
                precondition(extent >= 0.4999 && extent <= 0.786)
                let center = 0.12 + sample.lift + extent*sample.scaleY - 0.5
                precondition(center - extent*sample.scaleY >= -0.38001)
                if t >= 0.58 { precondition(RollMath.upwardFace(q) == face) }
                for phase: Float in [0,0.8,2.4,4.7] {
                    let idle = simd_quatf(angle: 0.025*sin(phase),axis: [0,1,0])*target
                    precondition(idle.act(RollMath.faceNormals[face-1]).y > 0.9999)
                }
            }
        }}
        for t: Float in [0,1] {
            precondition(abs(RollMath.motion(t).lift) < 0.00001)
            precondition(abs(RollMath.motion(t).scaleY-1) < 0.00001)
        }
        var last = RollMath.shadowAppearance(height: 0)
        for step in 1...100 {
            let next = RollMath.shadowAppearance(height: Float(step)/100)
            precondition(next.spread >= last.spread && next.opacity < last.opacity)
            precondition(next.opacity > 0 && next.opacity <= 1)
            last = next
        }
        for face in 1...6 { for yaw in 0..<4 {
            let q = RollMath.landing(face: face,quarterTurn: yaw)
            for frame in 0...100 {
                let elapsed = Float(frame)/100*0.5
                let p = RollMath.presentationAmount(from: 0,to: 1,elapsed: elapsed,duration: 0.5)
                precondition(p >= 0 && p <= 1)
                let size = 1-0.14*p
                let center = 0.12 + RollMath.verticalExtent(q)*(size-1)-0.18*p
                // The die base and shadow move down by exactly the same amount.
                precondition(abs(center-RollMath.verticalExtent(q)*size-(-0.38-0.18*p)) < 0.00001)
                precondition(RollMath.upwardFace(q) == face)
                let returning = RollMath.presentationAmount(from: p,to: 0,elapsed: 0.5,duration: 0.5)
                precondition(returning == 0)
            }
        }}
        print("PASS: result reveal/return for 24 poses; base/shadow alignment and face preserved.")
        print("PASS: 24 bounce poses; volume-preserving squash, floor clearance, idle face accuracy, and shadow falloff.")
        print("PASS: all 24 landing poses; \(checked) roll paths, normalized and continuous, with accurate final face.")
    }
}
