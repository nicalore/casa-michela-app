// Generates the launcher icons and launch images for iOS and Android from
// assets/images/logo.png: the round logo as the badge of the HTML mockup
// (white ring, turquoise halo) over the sea gradient of the mobile backdrop.
//
//   cd frontend && swift tool/make_app_icons.swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor
{
    return CGColor(
        colorSpace: srgb,
        components: [
            CGFloat((hex >> 16) & 0xFF) / 255,
            CGFloat((hex >> 8) & 0xFF) / 255,
            CGFloat(hex & 0xFF) / 255,
            alpha,
        ]
    )!
}

// AppTheme.trialDeepWater, trialTealDeep, trialSeaGreen, trialLagoon, trialTurquoise.
let seaColors = [color(0x0B3350), color(0x0B6478), color(0x12907F), color(0x1AA27E)]
let seaStops: [CGFloat] = [0, 0.45, 0.75, 1]
let halo = color(0x17B3A3, alpha: 0.35)
let white = color(0xFFFFFF)

// Ring widths as fractions of the logo radius: 5px and 8px on the mockup's 96px badge.
let whiteRingFactor: CGFloat = 36 / 348
let haloRingFactor: CGFloat = 20 / 348
let badgeFactor: CGFloat = 1 + whiteRingFactor + haloRingFactor

let frontend = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let logoURL = frontend.appendingPathComponent("assets/images/logo.png")
let iosAssets = frontend.appendingPathComponent("ios/Runner/Assets.xcassets")
let androidRes = frontend.appendingPathComponent("android/app/src/main/res")

guard let logoSource = CGImageSourceCreateWithURL(logoURL as CFURL, nil),
      let logo = CGImageSourceCreateImageAtIndex(logoSource, 0, nil)
else
{
    fatalError("Cannot read \(logoURL.path); run from frontend/")
}

func canvas(_ size: Int, opaque: Bool) -> CGContext
{
    let alpha = opaque ? CGImageAlphaInfo.noneSkipLast : CGImageAlphaInfo.premultipliedLast
    let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: srgb,
        bitmapInfo: alpha.rawValue
    )!

    context.interpolationQuality = .high

    return context
}

func square(_ center: CGPoint, radius: CGFloat) -> CGRect
{
    return CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
}

// The 160° line of the backdrop, ends on the corners like the browser lays it out.
func paintSea(_ context: CGContext, in rect: CGRect)
{
    let gradient = CGGradient(colorsSpace: srgb, colors: seaColors as CFArray, locations: seaStops)!
    let angle = 160.0 * CGFloat.pi / 180
    let dx = sin(angle)
    let dy = -cos(angle)
    let length = abs(rect.width * dx) + abs(rect.height * dy)
    let center = CGPoint(x: rect.midX, y: rect.midY)

    // Core Graphics has y going up: the screen-space direction is flipped.
    let start = CGPoint(x: center.x - dx * length / 2, y: center.y + dy * length / 2)
    let end = CGPoint(x: center.x + dx * length / 2, y: center.y - dy * length / 2)

    context.drawLinearGradient(
        gradient,
        start: start,
        end: end,
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
}

func paintBadge(_ context: CGContext, center: CGPoint, logoRadius: CGFloat)
{
    let whiteRadius = logoRadius * (1 + whiteRingFactor)
    let haloRadius = logoRadius * badgeFactor

    context.setFillColor(halo)
    context.fillEllipse(in: square(center, radius: haloRadius))
    context.setFillColor(white)
    context.fillEllipse(in: square(center, radius: whiteRadius))

    paintLogo(context, center: center, radius: logoRadius)
}

func paintLogo(_ context: CGContext, center: CGPoint, radius: CGFloat)
{
    context.saveGState()
    context.addEllipse(in: square(center, radius: radius))
    context.clip()
    context.draw(logo, in: square(center, radius: radius))
    context.restoreGState()
}

// Full bleed: iOS rounds the corners itself.
func appIcon(_ size: Int) -> CGContext
{
    let context = canvas(size, opaque: true)
    let side = CGFloat(size)

    paintSea(context, in: CGRect(x: 0, y: 0, width: side, height: side))
    paintBadge(context, center: CGPoint(x: side / 2, y: side / 2), logoRadius: side * 0.34)

    return context
}

// Android before adaptive icons draws the bitmap as is: rounded and inset.
func legacyIcon(_ size: Int) -> CGContext
{
    let context = canvas(size, opaque: false)
    let side = CGFloat(size)
    let inset = CGRect(x: 0, y: 0, width: side, height: side).insetBy(dx: side * 0.04, dy: side * 0.04)

    context.addPath(CGPath(roundedRect: inset, cornerWidth: inset.width * 0.2, cornerHeight: inset.width * 0.2, transform: nil))
    context.clip()
    paintSea(context, in: inset)
    paintBadge(context, center: CGPoint(x: side / 2, y: side / 2), logoRadius: inset.width * 0.34)

    return context
}

// Adaptive foreground: the badge inside the 66/108 safe zone launchers never mask.
func adaptiveForeground(_ size: Int) -> CGContext
{
    let context = canvas(size, opaque: false)
    let side = CGFloat(size)

    paintBadge(context, center: CGPoint(x: side / 2, y: side / 2), logoRadius: side * 0.61 / 2 / badgeFactor)

    return context
}

func adaptiveBackground(_ size: Int) -> CGContext
{
    let context = canvas(size, opaque: true)
    let side = CGFloat(size)

    paintSea(context, in: CGRect(x: 0, y: 0, width: side, height: side))

    return context
}

// The badge alone, centred on the launch screen's own colour.
func launchBadge(_ size: Int) -> CGContext
{
    let context = canvas(size, opaque: false)
    let side = CGFloat(size)

    paintBadge(context, center: CGPoint(x: side / 2, y: side / 2), logoRadius: side / 2 / badgeFactor)

    return context
}

func write(_ context: CGContext, to url: URL)
{
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!

    CGImageDestinationAddImage(destination, context.makeImage()!, nil)

    guard CGImageDestinationFinalize(destination)
    else
    {
        fatalError("Cannot write \(url.path)")
    }

    print("wrote \(url.path.replacingOccurrences(of: frontend.path + "/", with: ""))")
}

// iOS: every slot Xcode lists, at its point size times its scale.
let appIconSet = iosAssets.appendingPathComponent("AppIcon.appiconset")
let contents = try! JSONSerialization.jsonObject(
    with: Data(contentsOf: appIconSet.appendingPathComponent("Contents.json"))
) as! [String: Any]

for image in contents["images"] as! [[String: Any]]
{
    let points = Double((image["size"] as! String).split(separator: "x")[0])!
    let scale = Double((image["scale"] as! String).dropLast())!

    write(appIcon(Int((points * scale).rounded())), to: appIconSet.appendingPathComponent(image["filename"] as! String))
}

let launchPoints = 132
let launchImageSet = iosAssets.appendingPathComponent("LaunchImage.imageset")

for (scale, suffix) in [(1, ""), (2, "@2x"), (3, "@3x")]
{
    write(launchBadge(launchPoints * scale), to: launchImageSet.appendingPathComponent("LaunchImage\(suffix).png"))
}

// Android: one bitmap per density bucket.
let densities: [(String, Double)] = [("mdpi", 1), ("hdpi", 1.5), ("xhdpi", 2), ("xxhdpi", 3), ("xxxhdpi", 4)]

for (bucket, density) in densities
{
    let folder = androidRes.appendingPathComponent("mipmap-\(bucket)")
    let px = { (dp: Int) in Int((Double(dp) * density).rounded()) }

    write(legacyIcon(px(48)), to: folder.appendingPathComponent("ic_launcher.png"))
    write(adaptiveForeground(px(108)), to: folder.appendingPathComponent("ic_launcher_foreground.png"))
    write(adaptiveBackground(px(108)), to: folder.appendingPathComponent("ic_launcher_background.png"))
    write(launchBadge(px(launchPoints)), to: folder.appendingPathComponent("launch_image.png"))
}
