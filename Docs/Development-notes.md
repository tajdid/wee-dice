# Little interactions / 001 — Dice

Native SwiftUI + RealityKit prototype, completed through Phase 3.

Open `LittleDice.xcodeproj`, select LittleDice and an iPhone simulator, then Run. Requires Xcode with an iOS 18+ SDK. No packages or downloaded models. Select a signing team only for a physical device.

## Phase 1

Procedural rounded coral cube with 21 recessed concave ivory pips, glossy clearcoat, warm key/fill lighting, cream #F3F0E9 background, soft contact shadow, and portrait showcase typography. Face layout: +Y 1, -Y 6, +X 2, -X 5, +Z 3, -Z 4. Opposite faces sum to seven.

## Phase 2

Tap the die to roll. Drag it within a bounded camera plane, then release to roll; release direction controls the tumble axis and release speed controls the turn count and duration. The caption also acts as an accessible Roll button. Gestures start only on the die's collision proxy, and inputs during a roll are ignored.

Each roll independently chooses a uniform random face from 1–6 and one of four landing yaws. A frame-driven quaternion path combines two or three complete turns with interpolation toward that flat landing. The settled result is derived from the final transformed face normals, rather than copied from the intended random result. The app announces the result for VoiceOver. Cancelled drags return home; resigning active settles a roll or cancels a drag. Scene subscriptions and gesture recognizers are removed on view teardown.

## Phase 3

Rolls now stretch in flight, squash on impact, and rebound through three diminishing arcs. A separate parent rig deforms the die in world space, so every numbered face squashes vertically. The rounded-cube support height keeps the bottom above the floor throughout rotation and deformation. Scale returns exactly to one and the face orientation is exact before idle resumes.

Idle motion gently floats and yaws the die. Yaw keeps the upward normal vertical, so the displayed face stays accurate. The shadow follows horizontal movement, broadens and fades with height, and tightens on landing. Soft UIKit impact feedback is requested at three contact points with decreasing intensities (0.42, 0.22, 0.10), prepared before rolling.

Reduced Motion uses a short interpolation with a small lift and a single landing haptic, disabling idle movement, full spins, repeated bounce, and squash. This path is implemented and builds, but the simulator UI checks below exercised the normal-motion path.

## Result reveal

After the final bounce settles, a large result (for example, “4 UP”) fades, scales, and slides into view above the die. The die scales to 86% and moves subtly downward, with its shadow moving and scaling alongside it. The lower title and instructions fade out during the reveal. After a 0.5-second entrance and a three-second hold, the number fades out and the original size/layout returns over 0.5 seconds. The rolled orientation and result are preserved; the die does not reset to one.

A new tap or drag dismisses the current reveal and cancels its countdown. Presentation changes use the scene's frame clock, with no delayed callbacks that can hide a newer result. Reduced Motion uses a shorter 0.15-second transition. The intro now uses centered typography and “Tap or drag to roll the dice”, matching the reference layout. The persistent small result caption is replaced by the temporary large result.

The result reveal build succeeded in Xcode 27.1 and was run in the iPhone 18 Pro simulator. Observed “4 UP” with four pips on top, then the restored starting layout with that same face. Runtime timestamps show the reveal begins after settling and starts dismissal 3.5 seconds later. Math checks cover all 24 poses through the shrink/return, keeping the die base and shadow aligned without changing the upward face. Original bounce and roll checks still pass. Tap and drag rolls were re-exercised after the change.

Current demo: `Result-reveal.mp4`. Verification: `Result-reveal-verification.txt`.

## Trade-offs and remaining device checks

Motion and the layered translucent shadow remain art-directed, rather than a rigid-body physics simulation or physical light receiver. The collision box is used for gesture hit testing. Camera framing leaves extra room for tumbling corners; drag height is bounded. Mesh generation is synchronous at launch. Physical iPhone frame rate, gloss, and haptic feel still need checking. Simulator haptic diagnostics verify event requests and timing, not physical feedback. No app icon or distribution setup yet.

## Verification

- Xcode 27.1 Debug build succeeded for iPhone 18 Pro, iOS 27.0 simulator. Installed and launched successfully. Only build warning: skipped App Intents metadata extraction, as the app has no App Intents dependency.
- Exercised actual taps, drag/release, repeated taps during a roll, background taps, and the accessible Roll button in Device Hub's simulator UI.
- Visually compared upward-facing pips with displayed results after tap and drag rolls (including 4 and 2).
- Runtime diagnostics confirmed tap/drag source and upward normal dot product 1.000000 at each inspected landing.
- Standalone math checks passed all 24 landing poses and 1,152 roll paths sampled at 241 frames each, checking finite unit quaternions, continuity, exact endpoints, and final face detection. Tests include equivalent opposite quaternion signs.

Run the math checks from this project directory:

```sh
mkdir -p /tmp/littledice-checks
xcrun swiftc -module-cache-path /tmp/littledice-checks/cache LittleDice/RollMath.swift Tests/RollMathChecks.swift -o /tmp/littledice-checks/checks
/tmp/littledice-checks/checks
```

`Phase1-iPhone.png` preserves the first form study. `Phase2-iPhone.png` shows a settled result; `Phase2-rolls.mp4` records simulator interaction. `Phase2-verification.txt` contains the check summary and roll diagnostics. Phase 3 verification additionally passed all 24 bounce poses sampled over 601 frames each: volume-preserving squash, positive scale, floor clearance, correct upward face during rebound and idle yaw, and monotonic shadow falloff. The 1,152 original roll-path checks still pass. The final build succeeded, and final simulator tap/drag rolls settled on 3 and 2 with upward-normal dot products of 1.000000. Each roll emitted three decreasing haptic requests at the expected contacts. Recorded frames were inspected for visible squash, rebound, idle movement, and shadow changes.

`Phase3-motion.mp4` is the current simulator recording; `Phase3-iPhone.png` is an idle result screenshot; `Phase3-verification.txt` contains the latest check summary and runtime diagnostics. No subsequent phases have been implemented.

## Physical iPhone installation — 27 October 2026

Configured automatic signing with the user's Personal Team. Built the current result-reveal version for the connected iPhone 17 Pro running iOS 27.0.1. Signature verification passed. Installed `com.littleinteractions.LittleDice`, then launched successfully after the user trusted the developer profile. A subsequent device process query confirmed LittleDice was running.

The development profile expires on 3 November 2026 at 10:57 Dubai time. Build and install again from this Mac to renew it. The user is now testing gesture feel, animations, and physical haptics; those subjective checks are not marked verified by the agent.

## Make it yours — colour and finish

The live bottom sheet offers Coral, Butter, Mint, Sky, Lilac and Ink; Glossy, Matte and Metallic; and a reset to coral gloss. The die moves up into a smaller preview while the sheet is open. Closing the sheet returns to its regular composition. Rolling is disabled while customizing, and the sheet cannot open mid-roll. Opening the sheet dismisses any active result reveal without changing the die's result.

Preferences are encoded in local UserDefaults and restored on launch, with a safe default if saved data cannot be decoded. Pip colour switches to dark charcoal for the four light palettes, and ivory for Coral and Ink. Named model children allow material-only updates without rebuilding meshes or changing orientation. Metallic uses a generated studio panorama; Glossy and Matte use the normal scene lighting. The visible series name is Wee Interactions and the installed app is now named Wee Dice; its existing bundle identifier is retained so it updates the same installed app.

Verification: simulator and signed iPhone builds succeeded. Exercised all six palette controls, all three finish controls, reset, closing/reopening the picker, and persistence of Mint Metallic across an app relaunch. Visually checked pip contrast and live preview placement. Existing 24-pose result, bounce, shadow and 1,152 roll-path checks pass. Final simulator runtime recorded a tap roll with upward-normal dot product 1.000000 and the expected result reveal/return. The signed update was installed and launched successfully on the user's iPhone 17 Pro; a process query confirmed it remained running. Physical appearance and feel can now be reviewed on the phone.

Appearance panel layout update: white background, full screen width with no horizontal insets, anchored to the bottom safe area. A custom SwiftUI bottom panel replaces the system floating sheet. It retains the close button, downward-swipe dismissal, live preview, and accessibility escape action. Simulator and signed iPhone builds passed; full-width white layout and closing were visually verified in the simulator.

Panel polish: rounded top corners (28pt), no Colour/Finish section headings, and centered multiline finish descriptions. White full-width background retained. Simulator and signed device builds succeeded; updated layout visually verified before iPhone installation.
