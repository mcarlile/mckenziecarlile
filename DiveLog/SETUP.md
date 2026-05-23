# DiveLog – iOS App Setup

## Create the Xcode Project

1. Open Xcode → **File → New → Project**
2. Choose **iOS → App**
3. Product Name: `DiveLog`
4. Bundle ID: `com.yourname.divelog`
5. Interface: **SwiftUI**, Language: **Swift**
6. Minimum deployment: **iOS 17.0**

## Add Source Files

Drag the `DiveLog/` source folder into your Xcode project, ticking  
**"Copy items if needed"** and **"Create groups"**.

Replace the generated `ContentView.swift` and `<AppName>App.swift` with  
the ones in `App/`.

## Xcode Capabilities (required)

In **Signing & Capabilities**, add:

| Capability | Notes |
|---|---|
| **HealthKit** | Enable "Clinical Health Records" off, leave "Background Delivery" off |
| **iCloud** | Enable **CloudKit** (for future buddy-sync phase) |

## Earth Texture Assets

In your **Assets.xcassets**, add three image sets:

| Asset name | Download source |
|---|---|
| `earth_color` | NASA Blue Marble (public domain) — 4096×2048 JPEG |
| `earth_specular` | NASA water/land mask — grayscale |
| `earth_normal` | Any free Earth normal map |

The globe renders as a solid ocean blue if textures are absent — you can  
skip this for initial testing.

## Swift Package Dependencies

**File → Add Package Dependencies…**

- `https://github.com/nicklockwood/SwiftFormat` (optional dev tool)

No runtime dependencies required — the app uses only system frameworks:  
`HealthKit`, `SceneKit`, `Charts`, `MapKit`, `CloudKit`.

## Custom File Type (Dive Sharing)

The `.divelog` file extension lets buddies open shared dive packages  
directly in DiveLog via AirDrop / Messages. The `Info.plist` already  
declares the UTI — Xcode will pick it up automatically.
