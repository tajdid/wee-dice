# Wee Dice

### A little chance. A wee bit of play.

Meet Wee Dice: a pocket-sized dice game with a big bounce and a little Belfast personality. Give it a tap, fling it with your finger, and watch it tumble, squash, and settle. One die, six possibilities. What will you roll next?

The first game in **Wee Interactions**, a series of small, playful experiences made to feel good in your hands.

![Wee Dice](Demo/cover.png)

## How to play

**Tap to roll.** Send the die into a playful tumble and wait for your number to appear.

**Drag and let go.** Give your roll a little more personality: your gesture shapes the spin, while chance picks the result.

**Watch it land.** A satisfying bounce, a subtle haptic tap, and your number revealed above the die. After a few seconds, it's ready for another go.

Roll for a board game, settle who goes first, or just enjoy one more throw.

## Make it yours

Pick a colour to match your mood: **Coral, Butter, Mint, Sky, Lilac, or Ink**. Choose **Glossy, Matte, or Metallic**, and watch your die change as you play. Your choices are saved for next time.

Soft shadows, recessed pips, and a warm cream backdrop give every roll a little character. Reduced Motion support and accessible roll controls help more people join in.

## See it in action

[Watch the portrait demo](Demo/Wee-Dice-9x16.mp4) — 26 seconds of taps, drags, bounces, and fresh looks, without added captions.

## Play on your iPhone

Wee Dice currently runs from Xcode. Open `LittleDice.xcodeproj`, select the `LittleDice` scheme, choose an iPhone simulator, and press Run. To play on a physical iPhone and feel the haptics, select your own development team in Signing & Capabilities.

Requires an iOS 18+ SDK. The app appears on your phone as **Wee Dice**.

## Behind the bounce

Built with SwiftUI and RealityKit, with a procedurally modelled die and controlled animations. No external packages or downloaded models. Each roll chooses a random result, and the reveal is checked against the face that actually lands on top.

To run the roll-math checks:

```sh
mkdir -p /tmp/wee-dice-checks
xcrun swiftc -module-cache-path /tmp/wee-dice-checks/cache LittleDice/RollMath.swift Tests/RollMathChecks.swift -o /tmp/wee-dice-checks/checks
/tmp/wee-dice-checks/checks
```

Checks cover all 24 landing poses, 1,152 roll paths, bounce geometry, shadows, and result presentation. See the [development notes](Docs/Development-notes.md) for implementation and verification details.
