import RealityKit
import UIKit

/// Right-handed face bases; opposite pairs are 1/6, 2/5 and 3/4.
/// Each face is tiled into nine cells. Pip cells replace the surface with
/// an open ring and a concave bowl, so there is no solid box behind the pips.
enum DiceGeometry {
    struct Surface {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        mutating func triangle(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) {
            let normal = simd_normalize(simd_cross(b-a, c-a))
            let start = UInt32(positions.count)
            positions += [a,b,c]; normals += [normal,normal,normal]
            indices += [start,start+1,start+2]
        }
        mutating func quad(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>) {
            triangle(a,b,c); triangle(a,c,d)
        }
        func mesh(_ name: String) throws -> MeshResource {
            var descriptor = MeshDescriptor(name: name)
            descriptor.positions = MeshBuffers.Positions(positions)
            // Weld normals across cell boundaries for continuous glossy highlights.
            func key(_ p: SIMD3<Float>) -> String { "\(Int((p.x*100000).rounded())),\(Int((p.y*100000).rounded())),\(Int((p.z*100000).rounded()))" }
            var sums: [String: SIMD3<Float>] = [:]
            for i in positions.indices { sums[key(positions[i]), default: .zero] += normals[i] }
            descriptor.normals = MeshBuffers.Normals(positions.map { simd_normalize(sums[key($0)]!) })
            descriptor.primitives = .triangles(indices)
            return try MeshResource.generate(from: [descriptor])
        }
    }
    static let patterns: [[(Int,Int)]] = [
        [(1,1)], [(0,2),(2,0)], [(0,2),(1,1),(2,0)],
        [(0,0),(0,2),(2,0),(2,2)], [(0,0),(0,2),(1,1),(2,0),(2,2)],
        [(0,0),(0,1),(0,2),(2,0),(2,1),(2,2)]
    ]
    static func make() -> Entity {
        var shell = Surface(), bowls = Surface()
        let faces: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>, Int)] = [
            ([0,1,0],[1,0,0],[0,0,-1],1),
            ([1,0,0],[0,0,-1],[0,1,0],2),
            ([0,0,1],[1,0,0],[0,1,0],3),
            ([0,0,-1],[-1,0,0],[0,1,0],4),
            ([-1,0,0],[0,0,1],[0,1,0],5),
            ([0,-1,0],[1,0,0],[0,0,1],6)
        ]
        for (normal,u,v,number) in faces {
            func point(_ x: Float, _ y: Float, _ depth: Float = 0) -> SIMD3<Float> {
                let p = normal * 0.5 + u*x + v*y
                let inner = simd_clamp(p, SIMD3<Float>(repeating: -0.39), SIMD3<Float>(repeating: 0.39))
                return inner + simd_normalize(p-inner)*0.11 - normal*depth
            }
            for row in 0..<3 { for col in 0..<3 {
                let cx = Float(col-1)/3, cy = Float(row-1)/3
                let half: Float = 1/6
                if patterns[number-1].contains(where: { $0.0 == col && $0.1 == row }) {
                    let segments = 48
                    func perimeterAngle(_ index: Int) -> Float {
                        let side = (index / 12) % 4
                        let t = Float(index % 12) / 12
                        let q: SIMD2<Float>
                        switch side {
                        case 0: q = [1, -1 + 2*t]
                        case 1: q = [1 - 2*t, 1]
                        case 2: q = [-1, 1 - 2*t]
                        default: q = [-1 + 2*t, -1]
                        }
                        return atan2(q.y,q.x)
                    }
                    for k in 0..<segments {
                        let a = perimeterAngle(k)
                        let b = perimeterAngle(k+1)
                        func ring(_ angle: Float, _ radius: Float, _ depth: Float) -> SIMD3<Float> {
                            point(cx+cos(angle)*radius, cy+sin(angle)*radius, depth)
                        }
                        func square(_ angle: Float) -> SIMD3<Float> {
                            let x = cos(angle), y = sin(angle)
                            let scale = half/max(abs(x),abs(y))
                            return point(cx+x*scale, cy+y*scale)
                        }
                        for step in 0..<16 {
                            let t0 = Float(step)/16, t1 = Float(step+1)/16
                            func band(_ angle: Float, _ t: Float) -> SIMD3<Float> {
                                let x = cos(angle), y = sin(angle)
                                let outer = half/max(abs(x),abs(y))
                                let radius = outer*(1-t)+0.087*t
                                return point(cx+x*radius,cy+y*radius)
                            }
                            shell.quad(band(a,t0),band(b,t0),band(b,t1),band(a,t1))
                        }
                        shell.quad(ring(a,0.087,0),ring(b,0.087,0),ring(b,0.076,0.012),ring(a,0.076,0.012))
                        for j in 0..<8 {
                            let r0 = Float(j)/8, r1 = Float(j+1)/8
                            func bowl(_ angle: Float, _ r: Float) -> SIMD3<Float> {
                                ring(angle, 0.076*r, 0.035 - 0.023*r*r)
                            }
                            if j == 0 { bowls.triangle(bowl(a,0),bowl(a,r1),bowl(b,r1)) }
                            else { bowls.quad(bowl(a,r0),bowl(a,r1),bowl(b,r1),bowl(b,r0)) }
                        }
                    }
                } else {
                    for y in 0..<12 { for x in 0..<12 {
                        let x0 = cx-half+Float(x)/36, x1 = cx-half+Float(x+1)/36
                        let y0 = cy-half+Float(y)/36, y1 = cy-half+Float(y+1)/36
                        shell.quad(point(x0,y0),point(x1,y0),point(x1,y1),point(x0,y1))
                    }}
                }
            }}
        }
        let root = Entity()
        do {
            let body = ModelEntity(mesh: try shell.mesh("Rounded coral shell"), materials: [DiceAppearance().shellMaterial])
            body.name = "shell"
            root.addChild(body)
            let pips = ModelEntity(mesh: try bowls.mesh("Recessed ivory bowls"), materials: [DiceAppearance().pipMaterial])
            pips.name = "pips"
            root.addChild(pips)
        } catch { assertionFailure("Procedural die mesh failed: \(error)") }
        return root
    }
    static func shadowMesh(radius: Float) -> MeshResource {
        var surface = Surface()
        for i in 0..<96 {
            let a = Float(i)*2 * .pi/96, b = Float(i+1)*2 * .pi/96
            surface.triangle(.zero, [cos(b)*radius,0,sin(b)*radius*0.78], [cos(a)*radius,0,sin(a)*radius*0.78])
        }
        return try! surface.mesh("Soft shadow")
    }
}
