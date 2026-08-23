# Research: XomFit on Garmin via Connect IQ

**Status**: Research complete — not started
**Created**: 2026-08-22
**Verified against**: ConnectIQ Mobile SDK for iOS **1.8.0** (released 2026-01-15), official Garmin docs

## Correction to earlier advice

I previously told Dominick that Garmin watch communication "routes through the
Garmin Connect Mobile app", making it a three-app chain. **That is wrong for
iOS.** From Garmin's own SDK documentation:

> Unlike the Mobile SDK for Android, apps created with the Mobile SDK for iOS are
> standalone apps and do not directly rely on GCM app to communicate with a
> wearable device. They do, however, require GCM to initially discover Connect
> IQ-compatible devices that are available for communication, or to install
> Monkey C applications on the wearable device.

So Garmin Connect is needed for **device discovery** and **installing the watch
app** — not for ongoing messaging. After pairing, XomFit talks to the watch
directly over Bluetooth. That is materially better than described, and it makes
this more viable than the earlier recommendation assumed.

The other reason given for skipping it — "you have Apple Watch now" — also
doesn't apply: Dominick wears a Garmin. The Apple Watch app shipped in v2.7.6
does nothing for him personally.

## What it actually takes

Two codebases, because they share no language, toolchain or store.

### 1. The watch app — Monkey C

- Language: **Monkey C**, Garmin's own. Java-shaped.
- Toolchain: Connect IQ SDK + VS Code extension, includes a device simulator.
- Distribution: **Connect IQ Store**, separate submission and review, free
  Garmin developer account.
- Haptics: `Attention.vibrate()` — the thing this whole exercise is for.

### 2. The iOS side — inside xomfit-ios

- SDK is a **Swift Package**: `https://github.com/garmin/connectiq-companion-app-sdk-ios`
  (binary `ConnectIQ.xcframework`, swift-tools 5.7).
- Requires the **`-ObjC` linker flag** — the SDK uses Objective-C categories and
  won't link correctly without it.
- Requires a **Bluetooth usage description** in Info.plist.
- Requires a **custom URL scheme** (or universal links) so Garmin Connect can
  launch back into XomFit after device discovery.
- Optional **background execution mode** and a `CBCentralManager` restoration
  identifier if messaging needs to survive backgrounding.
- Messaging: `sendMessage:toApp:progress:completion:`, with an `isTransient`
  variant for high-frequency updates — which a per-second rest countdown is.
- Payloads convert to Monkey C types: `NSString`, `NSNumber`, `NSArray`,
  `NSDictionary`, `NSNull`. Garmin's docs stress keeping messages **small**.

## Open design question

A Connect IQ **device app** takes over the watch screen. If the lifter is also
recording a native Garmin strength activity, the two compete for the display.
Worth deciding early whether XomFit's Garmin app:

- **replaces** the native activity (records the workout itself), or
- **runs alongside** it as a glance/widget, accepting reduced capability.

This is a UX decision that shapes the whole build, and it has no equivalent on
Apple Watch, where `HKWorkoutSession` coexists with the system.

## Repo structure

**Separate repo for the watch app.** `xomfit-garmin`.

- Different language, toolchain and store — nothing is shared with the Swift code.
- `xomfit-ios` CI would need the Connect IQ SDK installed to build it, which is
  pure overhead on every Swift PR.
- Release cadence is independent: Connect IQ Store review is separate from
  TestFlight.

**The iOS integration stays in `xomfit-ios`** — the Swift Package, URL scheme,
Bluetooth permission and message-sending code are ordinary iOS work.

So: one new repo, plus a feature branch here.

## Prerequisites (Dominick)

1. ~~Install the Connect IQ SDK + VS Code Monkey C extension.~~ Done.
2. **Register as a Connect IQ developer**: https://www.garmin.com/en-US/forms/ciq-registration/
   It is a plain form, not an application to be approved, and there is no fee.
   Publishing later happens by uploading a `.iq` file (produced by the VS Code
   command `Monkey C: Export Project`) to the Connect IQ Store.
3. ~~Confirm the Garmin model.~~ **Venu 4.**

## Target device: Venu 4

From Garmin's compatible-devices list:

| Device | Screen | Display | API level |
|---|---|---|---|
| Venu 4 41mm | 390 x 390 round | AMOLED | **6.0** |
| Venu 4 45mm (and D2 Air X15) | 454 x 454 round | AMOLED | **6.0** |

Two screen sizes for the one product name, so even "support the Venu 4" means
two layouts. Both are round AMOLED at API 6.0 — current-generation, so nothing
here is constrained by old hardware.

## On "make it work for all"

The compatible list runs to roughly **158 devices**, spanning API 1.4 to 6.0,
screens from 205x148 to 454x486, round / rectangle / semi-round, and both
Memory-In-Pixel and AMOLED. Supporting all of them is not a starting point — it
is a long tail of layout and memory work, and the oldest devices have materially
less of both.

Recommended instead:

- **Build against Venu 4** (API 6.0, both sizes) as the development target.
- **Declare a minimum of API 5.x** in the manifest, which covers the modern
  AMOLED generation — Venu 2/3/4, recent Forerunner, Fenix 7/8, Epix — and is
  most of what is currently sold.
- **Widen later** from real requests. Every added device family is a layout to
  verify in the simulator, and the older MIP devices need different UI work
  entirely.

That is not a compromise so much as the normal way Connect IQ apps ship: the
manifest declares its device list, and the list grows.

## Honest assessment

The *hello world* is genuinely small. What makes this a project rather than a
task is the surface area: a second language, a second store review, a device
compatibility matrix, tight memory limits, and a pairing flow that depends on
Garmin Connect being installed.

Worth doing **if wrist feedback during lifting matters**. Everything else Garmin
already works — activities import through Apple Health automatically, in the
background as of v2.7.7.
