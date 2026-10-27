import Foundation
import simd

/// Matches the procedural model's numbered local face normals.
enum RollMath {
    static let faceNormals: [SIMD3<Float>] = [
        [0,1,0], [1,0,0], [0,0,1], [0,0,-1], [-1,0,0], [0,-1,0]
    ]
    static func landing(face: Int, quarterTurn: Int) -> simd_quatf {
        precondition((1...6).contains(face))
        let align = simd_quatf(from: faceNormals[face-1], to: SIMD3<Float>(0,1,0))
        return simd_normalize(simd_quatf(angle: Float(quarterTurn) * .pi/2, axis: [0,1,0]) * align)
    }
    static func upwardFace(_ orientation: simd_quatf) -> Int {
        faceNormals.indices.max { orientation.act(faceNormals[$0]).y < orientation.act(faceNormals[$1]).y }! + 1
    }
    static func ease(_ t: Float) -> Float { t*t*t*(t*(t*6-15)+10) }
    static func orientation(start: simd_quatf, target: simd_quatf, axis: SIMD3<Float>, turns: Float, progress: Float) -> simd_quatf {
        let t = min(1,max(0,progress))
        if t == 0 { return start }
        if t == 1 { return target }
        let eased = ease(t)
        // Full turns are applied separately: slerp alone always takes a short arc.
        let spin = simd_quatf(angle: 2 * .pi * turns * (1-eased), axis: simd_normalize(axis))
        return simd_normalize(spin * simd_slerp(start,target,eased))
    }
    static let impacts: [Float] = [0.58, 0.76, 0.90]
    struct MotionSample {
        let lift: Float
        let scaleY: Float
        var scale: SIMD3<Float> {
            // Preserve volume while the parent rig squashes in world space.
            let width = 1 / sqrt(scaleY)
            return [width,scaleY,width]
        }
    }
    static func motion(_ progress: Float) -> MotionSample {
        let t = min(1,max(0,progress))
        let lift: Float
        if t < 0.58 { lift = 0.28 * sin(.pi*t/0.58) }
        else if t < 0.76 { lift = 0.23 * sin(.pi*(t-0.58)/0.18) }
        else if t < 0.90 { lift = 0.085 * sin(.pi*(t-0.76)/0.14) }
        else { lift = 0.025 * sin(.pi*(t-0.90)/0.10) }
        func pulse(_ start: Float, _ end: Float, _ strength: Float) -> Float {
            guard t > start && t < end else { return 0 }
            return strength * sin(.pi*(t-start)/(end-start))
        }
        let stretch = t < 0.58 ? 0.13 * sin(.pi*t/0.58) : 0
        let squash = pulse(0.55,0.66,0.24) + pulse(0.745,0.82,0.13) + pulse(0.89,0.96,0.06)
        return MotionSample(lift: max(0,lift), scaleY: 1 + stretch - squash)
    }
    static func verticalExtent(_ orientation: simd_quatf) -> Float {
        // Support function of the actual rounded cube (inner half size .39,
        // bevel radius .11), before the world-space squash rig is applied.
        0.39 * (abs(orientation.act(SIMD3<Float>(1,0,0)).y)
                + abs(orientation.act(SIMD3<Float>(0,1,0)).y)
                + abs(orientation.act(SIMD3<Float>(0,0,1)).y)) + 0.11
    }
    static func shadowAppearance(height: Float) -> (spread: Float, opacity: Float) {
        let h = max(0,height)
        return (1 + min(h,1.5)*0.65, 1/(1 + 3*h))
    }

    static func presentationAmount(from: Float, to: Float, elapsed: Float, duration: Float) -> Float {
        let t = min(1,max(0,elapsed/max(0.001,duration)))
        return from + (to-from)*ease(t)
    }

}
