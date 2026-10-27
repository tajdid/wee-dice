import SwiftUI
import RealityKit

@main
struct LittleDiceApp: App {
    var body: some SwiftUI.Scene { WindowGroup { ContentView() } }
}

struct ContentView: View {
    @StateObject private var dice = DiceState()
    private let ink = Color(red: 0.27, green: 0.24, blue: 0.22)
    var body: some View {
        ZStack {
            Color(red: 243/255, green: 240/255, blue: 233/255).ignoresSafeArea()
            DiceScene(state: dice).ignoresSafeArea().accessibilityHidden(true)
            GeometryReader { geometry in
                Text("\(dice.result) UP")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .tracking(-2)
                    .foregroundStyle(ink)
                    .scaleEffect(dice.showResult ? 1 : 0.88)
                    .opacity(dice.showResult ? 1 : 0)
                    .offset(y: dice.showResult ? 0 : 14)
                    .position(x: geometry.size.width/2, y: geometry.size.height*0.265)
                    .accessibilityHidden(!dice.showResult)
            }.allowsHitTesting(false)
            VStack(spacing: 12) {
                HStack {
                    Text("WEE INTERACTIONS").font(.system(size: 11, weight: .semibold, design: .monospaced)).tracking(2.2)
                    Spacer()
                    Text("001").font(.system(size: 12, design: .monospaced))
                }.opacity(0.55)
                Spacer()
                VStack(spacing: 8) {
                    Text("A little chance.")
                        .font(.system(size: 38, weight: .medium, design: .serif))
                    Button { dice.rollAction?() } label: {
                        Text("Tap or drag to roll the dice")
                            .font(.system(size: 14))
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(dice.rolling || dice.dragging || dice.showResult)
                    .accessibilityLabel("Roll die. Current result \(dice.result)")
                    .opacity(0.55)
                }
                .opacity(dice.showResult ? 0 : 1)
                .offset(y: dice.showResult ? 8 : 0)
                .accessibilityHidden(dice.showResult)
            }
            .foregroundStyle(ink)
            .padding(.horizontal, 30)
            .padding(.top, 26)
            .padding(.bottom, 76)
            VStack {
                Spacer()
                Button { dice.openCustomizer() } label: {
                    Label("Make it yours", systemImage: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 16).frame(minHeight: 44)
                        .background(ink.opacity(0.045), in: Capsule())
                }
                .buttonStyle(.plain).foregroundStyle(ink.opacity(0.7))
                .disabled(dice.rolling || dice.dragging)
            }.padding(.bottom, 12)

        }
        .overlay(alignment: .bottom) {
            if dice.customizing {
                AppearanceSheet(dice: dice)
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.easeInOut(duration: 0.28), value: dice.customizing)
    }
}

struct DiceScene: UIViewRepresentable {
    @ObservedObject var state: DiceState
    final class Coordinator { var controller: RollController? }
    func makeCoordinator() -> Coordinator { Coordinator() }
    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.controller?.tearDown()
        coordinator.controller = nil
    }
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(UIColor(red: 243/255, green: 240/255, blue: 233/255, alpha: 1))
        let root = AnchorEntity(world: .zero)
        view.scene.addAnchor(root)
        let die = DiceGeometry.make()
        let rig = Entity()
        rig.position.y = 0.12
        rig.addChild(die)
        root.addChild(rig)
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 36
        camera.look(at: [0, -0.12, 0], from: [4.485, 3.6225, 5.6925], relativeTo: nil)
        root.addChild(camera)
        let key = DirectionalLight()
        key.light.intensity = 2200
        key.light.color = UIColor(red: 1, green: 0.92, blue: 0.82, alpha: 1)
        key.look(at: .zero, from: [-3, 5, 4], relativeTo: nil)
        root.addChild(key)
        let fill = PointLight()
        fill.light.intensity = 550
        fill.light.attenuationRadius = 12
        fill.position = [3, 2, -2]
        root.addChild(fill)
        // Layered translucent ellipses give a soft, height-adjustable contact shadow
        // in non-AR rendering, where receiver shadows vary across devices.
        let shadowRig = Entity()
        root.addChild(shadowRig)
        for i in 0..<24 {
            let t = Float(i) / 23
            var shadowMaterial = UnlitMaterial(color: UIColor(white: 0.22, alpha: 1))
            shadowMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.009 * (1-t)))
            let shadow = ModelEntity(mesh: .generatePlane(width: 1.05 + t * 0.65, depth: 0.86 + t * 0.55), materials: [shadowMaterial])
            shadow.position = [0.08, -0.43 + Float(i) * 0.0001, -0.02]
            // A circular mesh avoids the hard corners of a plane.
            shadow.model?.mesh = DiceGeometry.shadowMesh(radius: 0.58 + t * 0.30)
            shadowRig.addChild(shadow)
        }
        context.coordinator.controller = RollController(state: state, die: die, rig: rig, shadow: shadowRig, view: view)
        return view
    }
    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.controller?.updateAppearance()
    }
}
