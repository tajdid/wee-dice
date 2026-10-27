import SwiftUI
import RealityKit
import Combine
import os

final class DiceState: ObservableObject {
    @Published var result: Int = 1
    @Published var showResult = false
    @Published var rolling = false
    @Published var dragging = false
    @Published var customizing = false
    @Published var appearance: DiceAppearance { didSet { appearance.save(to: defaults) } }
    private let defaults: UserDefaults
    var customizationAction: (() -> Void)?
    var rollAction: (() -> Void)?
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.appearance = DiceAppearance.load(from: defaults)
    }
    func openCustomizer() {
        guard !rolling, !dragging else { return }
        customizationAction?()
        customizing = true
    }
}

final class RollController: NSObject, UIGestureRecognizerDelegate {
    private let state: DiceState
    private weak var view: ARView?
    private let die: Entity
    private let rig: Entity
    private let shadow: Entity
    private let impact = UIImpactFeedbackGenerator(style: .soft)
    private var customization: Float = 0
    private var appliedAppearance: DiceAppearance?
    private var studioEnvironment: EnvironmentResource?
    private var idleTime: Float = 0
    private var restingOrientation = simd_quatf(angle: 0, axis: [0,1,0])
    private var active = true
    private var activeObserver: NSObjectProtocol?
    private let home = SIMD3<Float>(0,0.12,0)
    private var posePosition = SIMD3<Float>(0,0.12,0)
    private var poseScale = SIMD3<Float>.one
    private var presentation: Float = 0
    private var presentationFrom: Float = 0
    private var presentationTo: Float = 0
    private var presentationElapsed: Float = 0
    private var presentationDuration: Float = 0.5
    private var resultElapsed: Float?

    private var subscription: (any Cancellable)?
    private var backgroundObserver: NSObjectProtocol?
    private var recognizers: [UIGestureRecognizer] = []
    private var roll: Roll?
    private var dragOrigin = SIMD3<Float>.zero
    private let logger = Logger(subsystem: "com.littleinteractions.LittleDice", category: "Roll")
    private struct Roll {
        let start: simd_quatf
        let target: simd_quatf
        let axis: SIMD3<Float>
        let turns: Float
        let origin: SIMD3<Float>
        let duration: Float
        let source: String
        let reducedMotion: Bool
        var elapsed: Float = 0
    }
    init(state: DiceState, die: Entity, rig: Entity, shadow: Entity, view: ARView) {
        self.state = state; self.die = die; self.rig = rig; self.shadow = shadow; self.view = view
        super.init()
        die.components.set(CollisionComponent(shapes: [.generateBox(size: [1.04,1.04,1.04])]))
        let pan = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
        pan.maximumNumberOfTouches = 1
        let tap = UITapGestureRecognizer(target: self, action: #selector(tap(_:)))
        tap.require(toFail: pan)
        for gesture in [tap,pan] { gesture.delegate = self; view.addGestureRecognizer(gesture) }
        recognizers = [tap,pan]
        subscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            self?.advance(Float(event.deltaTime))
        }
        updateAppearance()
        state.customizationAction = { [weak self] in self?.hideResult() }
        state.rollAction = { [weak self] in self?.beginRoll(velocity: .zero, source: "button") }
        backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.active = false
            if self.roll != nil { self.finish() }
            else if self.state.dragging { self.cancelDrag() }
            self.hideResult(animated: false)
        }
        activeObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.active = true
        }
    }
    func tearDown() {
        subscription?.cancel(); subscription = nil
        if let backgroundObserver { NotificationCenter.default.removeObserver(backgroundObserver) }
        if let activeObserver { NotificationCenter.default.removeObserver(activeObserver) }
        for gesture in recognizers { view?.removeGestureRecognizer(gesture) }
        state.customizationAction = nil
        state.rollAction = nil
        resultElapsed = nil
    }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard roll == nil, !state.customizing, let view else { return false }
        let p: CGPoint
        if let pan = gestureRecognizer as? UIPanGestureRecognizer {
            let current = pan.location(in: view), translation = pan.translation(in: view)
            p = CGPoint(x: current.x-translation.x, y: current.y-translation.y)
        } else { p = gestureRecognizer.location(in: view) }
        return view.entity(at: p) != nil
    }
    @objc private func tap(_ recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended { beginRoll(velocity: CGPoint(x: 350,y: -500), source: "tap") }
    }
    @objc private func pan(_ recognizer: UIPanGestureRecognizer) {
        guard let view else { return }
        switch recognizer.state {
        case .began:
            guard roll == nil else { return }
            hideResult()
            dragOrigin = posePosition
            state.dragging = true
        case .changed:
            guard state.dragging else { return }
            let translation = recognizer.translation(in: view)
            // Camera-plane displacement, bounded to keep the toy on screen.
            let dx = Float(max(-140,min(140,translation.x))) * 0.003
            let dy = Float(max(-110,min(110,translation.y))) * -0.003
            posePosition = dragOrigin + SIMD3<Float>(0.786,0,-0.619)*dx + SIMD3<Float>(-0.30,0.87,-0.38)*dy
            posePosition.y = min(home.y+0.18,max(home.y,posePosition.y))
        case .ended:
            guard state.dragging else { return }
            state.dragging = false
            beginRoll(velocity: recognizer.velocity(in: view), source: "drag")
        case .cancelled, .failed: cancelDrag()
        default: break
        }
    }
    private func cancelDrag() {
        guard state.dragging else { return }
        state.dragging = false
        posePosition = home
        poseScale = .one
        idleTime = 0
    }
    private func beginRoll(velocity: CGPoint, source: String) {
        guard roll == nil, !state.dragging, !state.customizing else { return }
        hideResult()
        let face = Int.random(in: 1...6)
        let target = RollMath.landing(face: face, quarterTurn: Int.random(in: 0..<4))
        let dx = Float(max(-1600,min(1600,velocity.x)))
        let dy = Float(max(-1600,min(1600,velocity.y)))
        let speed = min(1, sqrt(dx*dx+dy*dy)/1600)
        let direction = SIMD3<Float>(-0.30,0.87,-0.38)*dx - SIMD3<Float>(0.786,0,-0.619)*dy
        let axis = simd_length(direction) > 1 ? simd_normalize(direction) : simd_normalize(SIMD3<Float>(1,0.3,-0.6))
        let reducedMotion = UIAccessibility.isReduceMotionEnabled
        impact.prepare()
        roll = Roll(start: die.orientation, target: target, axis: axis,
                    turns: speed > 0.6 ? 3 : 2, origin: posePosition,
                    duration: reducedMotion ? 0.35 : 1.85 + 0.25*speed, source: source, reducedMotion: reducedMotion)
        state.rolling = true
        logger.info("Roll started source=\(source, privacy: .public)")
    }
    private func advance(_ delta: Float) {
        guard active else { return }
        customization += ((state.customizing ? 1 : 0)-customization)*min(1,max(0,delta)*9)
        if customization < 0.0001 { customization = 0 }
        if customization > 0.9999 { customization = 1 }
        advancePresentation(max(0,delta))
        guard var current = roll else {
            if !state.dragging {
                idleTime += max(0,delta)
                let reduced = UIAccessibility.isReduceMotionEnabled
                let lift: Float = reduced ? 0 : 0.035 * (1-cos(idleTime*1.8))
                let yaw: Float = reduced ? 0 : 0.025 * sin(idleTime*1.2)
                die.orientation = simd_quatf(angle: yaw, axis: [0,1,0]) * restingOrientation
                posePosition = home + SIMD3<Float>(0,lift,0)
                poseScale = .one
            }
            applyPresentation()
            updateShadow()
            return
        }
        let previous = current.elapsed/current.duration
        current.elapsed += max(0,delta)
        let t = min(1,current.elapsed/current.duration)
        let flight = current.reducedMotion ? t : min(1,t/0.58)
        let eased = RollMath.ease(flight)
        if current.reducedMotion {
            die.orientation = simd_slerp(current.start,current.target,eased)
        } else {
            die.orientation = RollMath.orientation(start: current.start, target: current.target, axis: current.axis, turns: current.turns, progress: flight)
        }
        let sample = current.reducedMotion ? RollMath.MotionSample(lift: 0.04*sin(.pi*t),scaleY: 1) : RollMath.motion(t)
        poseScale = sample.scale
        let originLift = max(0,current.origin.y-home.y)
        let lift = sample.lift + originLift*(1-eased)
        posePosition = current.origin*(1-eased) + home*eased
        // Account for the rotated rounded cube's support height. Squash acts
        // in world space, so the same impact works with every numbered face.
        posePosition.y = home.y + lift + RollMath.verticalExtent(die.orientation)*sample.scaleY - 0.5
        for (index, contact) in RollMath.impacts.enumerated() where previous < contact && t >= contact {
            // Reduced Motion has one small landing, rather than three bounces.
            if !current.reducedMotion { landingHaptic(index: index) }
        }
        roll = current
        applyPresentation()
        updateShadow()
        if t >= 1 {
            if current.reducedMotion { landingHaptic(index: 0) }
            finish()
        }
    }
    func updateAppearance() {
        guard appliedAppearance != state.appearance else { return }
        state.appearance.apply(to: die)
        if state.appearance.finish == .metallic {
            if studioEnvironment == nil { studioEnvironment = StudioLighting.environment() }
            view?.environment.lighting.resource = studioEnvironment
            view?.environment.lighting.intensityExponent = 0.7
        } else {
            view?.environment.lighting.resource = nil
            view?.environment.lighting.intensityExponent = 0
        }
        appliedAppearance = state.appearance
    }
    private func setPresentation(visible: Bool, animated: Bool = true) {
        presentationFrom = presentation
        presentationTo = visible ? 1 : 0
        presentationElapsed = 0
        presentationDuration = animated && !UIAccessibility.isReduceMotionEnabled ? 0.5 : 0.15
        withAnimation(.easeInOut(duration: Double(presentationDuration))) {
            state.showResult = visible
        }
        if !animated {
            presentation = presentationTo
            presentationElapsed = presentationDuration
            applyPresentation()
            updateShadow()
        }
    }
    private func hideResult(animated: Bool = true) {
        resultElapsed = nil
        if presentationTo != 0 || state.showResult { setPresentation(visible: false, animated: animated) }
    }
    private func advancePresentation(_ delta: Float) {
        if let elapsed = resultElapsed {
            let next = elapsed + delta
            resultElapsed = next
            // Three seconds at full size, after the half-second entrance.
            if next >= presentationDuration + 3 {
                hideResult()
                logger.info("Result reveal dismissed; rolled face preserved")
            }
        }
        presentationElapsed += delta
        presentation = RollMath.presentationAmount(from: presentationFrom, to: presentationTo,
                                                   elapsed: presentationElapsed, duration: presentationDuration)
    }
    private func applyPresentation() {
        let size = (1-0.14*presentation)*(1-0.12*customization)
        rig.scale = poseScale*size
        // Keep the die's base and shadow together as the result layout moves down.
        let baseAdjustment = RollMath.verticalExtent(die.orientation)*poseScale.y*(size-1)
        rig.position = posePosition + SIMD3<Float>(0,baseAdjustment-0.18*presentation+0.55*customization,0)
    }
    private func landingHaptic(index: Int) {
        let strength: CGFloat = [0.42,0.22,0.10][index]
        impact.impactOccurred(intensity: strength)
        impact.prepare()
        logger.info("Landing haptic requested contact=\(index+1) intensity=\(Double(strength))")
    }
    private func updateShadow() {
        let bottom = rig.position.y - RollMath.verticalExtent(die.orientation)*rig.scale.y
        let height = max(0,bottom - (home.y-0.5-0.18*presentation+0.55*customization))
        let appearance = RollMath.shadowAppearance(height: height)
        shadow.position = [rig.position.x,-0.18*presentation+0.55*customization,rig.position.z]
        let size = (1-0.14*presentation)*(1-0.12*customization)
        shadow.scale = [appearance.spread*size,1,appearance.spread*size]
        for (index, child) in shadow.children.enumerated() {
            guard let model = child as? ModelEntity else { continue }
            let t = Float(index)/23
            var material = UnlitMaterial(color: UIColor(white: 0.22, alpha: 1))
            material.blending = .transparent(opacity: .init(floatLiteral: 0.009*(1-t)*appearance.opacity))
            model.model?.materials = [material]
        }
    }
    private func finish() {
        guard let current = roll else { return }
        die.orientation = current.target
        restingOrientation = current.target
        posePosition = home
        poseScale = .one
        idleTime = 0
        // Derive the published result from the actual final transformed normals.
        let result = RollMath.upwardFace(die.orientation)
        let up = die.orientation.act(RollMath.faceNormals[result-1]).y
        assert(up > 0.9999, "Die must settle flat")
        state.result = result
        state.rolling = false
        roll = nil
        if active {
            resultElapsed = 0
            setPresentation(visible: true)
            logger.info("Result reveal started result=\(result)")
        }
        applyPresentation()
        updateShadow()
        logger.info("Roll settled source=\(current.source, privacy: .public) result=\(result) upDot=\(up)")
        UIAccessibility.post(notification: .announcement, argument: "Rolled \(result)")
    }
}
