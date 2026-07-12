#!/usr/bin/env swift
import AppKit

let viewport: CGFloat = 108
let out = 512
let discScale: CGFloat = 1.35

func color(_ hex: String) -> CGColor {
    var v: UInt64 = 0
    Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&v)
    return CGColor(
        red: CGFloat((v >> 16) & 0xFF) / 255,
        green: CGFloat((v >> 8) & 0xFF) / 255,
        blue: CGFloat(v & 0xFF) / 255,
        alpha: 1
    )
}

let space = CGColorSpaceCreateDeviceRGB()
let scale = CGFloat(out) / viewport

guard let ctx = CGContext(
    data: nil, width: out, height: out, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("context") }

ctx.scaleBy(x: scale, y: scale)

func vGradient(top: String, bottom: String, y0: CGFloat, y1: CGFloat) -> CGGradient {
    CGGradient(colorsSpace: space, colors: [color(top), color(bottom)] as CFArray, locations: [0, 1])!
}

// CoreGraphics origin is bottom-left; the vector's top is y=0, so flip Y coordinates.
func flip(_ y: CGFloat) -> CGFloat { viewport - y }

func fillDisc(cx: CGFloat, cy: CGFloat, r: CGFloat, gradientTop: String, gradientBottom: String) {
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: cx - r, y: flip(cy) - r, width: 2 * r, height: 2 * r))
    ctx.clip()
    let g = vGradient(top: gradientTop, bottom: gradientBottom, y0: 0, y1: 0)
    ctx.drawLinearGradient(
        g,
        start: CGPoint(x: cx, y: flip(cy - r)),
        end: CGPoint(x: cx, y: flip(cy + r)),
        options: []
    )
    ctx.restoreGState()
}

func fillCircle(cx: CGFloat, cy: CGFloat, r: CGFloat, fill: String) {
    ctx.setFillColor(color(fill))
    ctx.fillEllipse(in: CGRect(x: cx - r, y: flip(cy) - r, width: 2 * r, height: 2 * r))
}

let rDisc = 25.5 * discScale
let rLabel = 7.65 * discScale
let rSpindle = 2.1 * discScale

let bg = vGradient(top: "#D0EC10", bottom: "#3FA561", y0: 0, y1: viewport)
ctx.drawLinearGradient(
    bg,
    start: CGPoint(x: 54, y: viewport),
    end: CGPoint(x: 54, y: 0),
    options: []
)

fillDisc(cx: 54, cy: 54, r: rDisc, gradientTop: "#4A4A50", gradientBottom: "#25252F")
fillCircle(cx: 54, cy: 54, r: rLabel, fill: "#327345")
fillCircle(cx: 54, cy: 54, r: rSpindle, fill: "#4A4A4F")

guard let image = ctx.makeImage() else { fatalError("image") }
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("png") }

let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let path = dir.appendingPathComponent("ic_launcher_playstore.png")
try png.write(to: path)
print("saved \(path.path) (\(out)x\(out))")
