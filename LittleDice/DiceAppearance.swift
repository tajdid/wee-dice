import SwiftUI
import RealityKit

enum DiceColour: String, CaseIterable, Identifiable, Codable {
    case coral, butter, mint, sky, lilac, ink
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var tint: UIColor {
        switch self {
        case .coral: return UIColor(red: 0.94, green: 0.27, blue: 0.14, alpha: 1)
        case .butter: return UIColor(red: 0.98, green: 0.80, blue: 0.36, alpha: 1)
        case .mint: return UIColor(red: 0.47, green: 0.77, blue: 0.64, alpha: 1)
        case .sky: return UIColor(red: 0.42, green: 0.68, blue: 0.88, alpha: 1)
        case .lilac: return UIColor(red: 0.72, green: 0.59, blue: 0.85, alpha: 1)
        case .ink: return UIColor(red: 0.13, green: 0.17, blue: 0.23, alpha: 1)
        }
    }
    var darkPips: Bool { self != .coral && self != .ink }
}

enum DiceFinish: String, CaseIterable, Identifiable, Codable {
    case glossy, matte, metallic
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var detail: String {
        switch self {
        case .glossy: return "A smooth surface with a soft shine."
        case .matte: return "Soft highlights. A quieter kind of toy."
        case .metallic: return "A reflective finish that catches the studio light."
        }
    }
}

struct DiceAppearance: Codable, Equatable {
    var colour: DiceColour = .coral
    var finish: DiceFinish = .glossy
    static let storageKey = "weeDice.appearance.v1"
    static func load(from defaults: UserDefaults) -> Self {
        guard let data = defaults.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return saved
    }
    func save(to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
    var shellMaterial: PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: colour.tint)
        switch finish {
        case .glossy:
            material.roughness = .init(floatLiteral: 0.24)
            material.clearcoat = .init(floatLiteral: 0.65)
            material.clearcoatRoughness = .init(floatLiteral: 0.18)
        case .matte:
            material.roughness = .init(floatLiteral: 0.85)
            material.clearcoat = .init(floatLiteral: 0)
        case .metallic:
            material.metallic = .init(floatLiteral: 0.82)
            material.roughness = .init(floatLiteral: 0.25)
            material.clearcoat = .init(floatLiteral: 0.12)
        }
        return material
    }
    var pipMaterial: PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: colour.darkPips
            ? UIColor(red: 0.15, green: 0.16, blue: 0.17, alpha: 1)
            : UIColor(red: 1, green: 0.94, blue: 0.80, alpha: 1))
        material.roughness = .init(floatLiteral: 0.38)
        return material
    }
    func apply(to die: Entity) {
        // Update only materials: numbered geometry and orientation are preserved.
        (die.findEntity(named: "shell") as? ModelEntity)?.model?.materials = [shellMaterial]
        (die.findEntity(named: "pips") as? ModelEntity)?.model?.materials = [pipMaterial]
    }
}

struct AppearanceSheet: View {
    @ObservedObject var dice: DiceState
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Capsule().fill(Color.black.opacity(0.18))
                .frame(width: 36, height: 5).frame(maxWidth: .infinity)
                .padding(.top, -10)
                .accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline) {
                Text("Make it yours").font(.system(size: 26, weight: .medium, design: .serif))
                Spacer()
                Button("Reset") { dice.appearance = DiceAppearance() }
                    .font(.system(size: 14, weight: .medium))
                    .accessibilityLabel("Reset to coral glossy")
                Button { dice.customizing = false } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                        .frame(width: 32, height: 32).background(.black.opacity(0.05), in: Circle())
                }.accessibilityLabel("Done customizing")
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 0) {
                    ForEach(DiceColour.allCases) { colour in
                        Button { dice.appearance.colour = colour } label: {
                            VStack(spacing: 7) {
                                Circle().fill(Color(uiColor: colour.tint)).frame(width: 36, height: 36)
                                    .overlay {
                                        if dice.appearance.colour == colour {
                                            Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(colour.darkPips ? Color.black.opacity(0.7) : .white)
                                        }
                                    }
                                Text(colour.title).font(.system(size: 10))
                            }.frame(maxWidth: .infinity, minHeight: 58).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(colour.title) colour")
                        .accessibilityAddTraits(dice.appearance.colour == colour ? .isSelected : [])
                    }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Picker("Finish", selection: $dice.appearance.finish) {
                    ForEach(DiceFinish.allCases) { finish in Text(finish.title).tag(finish) }
                }.pickerStyle(.segmented)
                Text(dice.appearance.finish.detail)
                    .font(.system(size: 12)).opacity(0.5)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .foregroundStyle(Color(red: 0.27, green: 0.24, blue: 0.22))
        .padding(24)
        .frame(maxWidth: .infinity)
        .frame(height: 360, alignment: .top)
        .background(Color.white, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
        .ignoresSafeArea(edges: .bottom)
        .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { value in
            if value.translation.height > 70 { dice.customizing = false }
        })
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { dice.customizing = false }
    }
}

/// A generated studio panorama supplies broad reflections for metal. It ships
/// with the scene procedurally, so there is no external HDR or asset download.
enum StudioLighting {
    static func environment() -> EnvironmentResource? {
        let width = 512, height = 256
        var pixels = [UInt8](repeating: 0, count: width*height*4)
        for y in 0..<height { for x in 0..<width {
            let u = Float(x)/Float(width), v = Float(y)/Float(height)
            func panel(_ cx: Float, _ cy: Float, _ wx: Float, _ wy: Float) -> Float {
                let dx = min(abs(u-cx),1-abs(u-cx))/wx
                let dy = abs(v-cy)/wy
                return exp(-pow(dx,6)-pow(dy,6))
            }
            let light = min(1, 0.60 + 0.40*panel(0.23,0.36,0.10,0.17) + 0.35*panel(0.73,0.32,0.13,0.12))
            let i = (y*width+x)*4
            pixels[i] = UInt8(light*255); pixels[i+1] = UInt8(light*250)
            pixels[i+2] = UInt8(light*240); pixels[i+3] = 255
        }}
        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: width*4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return nil }
        return try? EnvironmentResource(equirectangular: image, withName: "Wee Dice studio")
    }
}
