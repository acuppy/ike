#!/usr/bin/env swift
import AppKit
import Foundation

// Renders the Ike app icon: 2x2 grid with Q2 (top-right) highlighted in green.

let baseSize: CGFloat = 1024
let cornerRatio: CGFloat = 0.225        // macOS squircle
let gridInsetRatio: CGFloat = 0.16
let cellPaddingRatio: CGFloat = 0.012
let cellCornerRatio: CGFloat = 0.12

let backgroundColor = NSColor(red: 0.12, green: 0.13, blue: 0.16, alpha: 1.0)  // near-black
let mutedColor = NSColor(white: 1.0, alpha: 0.08)
let mutedStroke = NSColor(white: 1.0, alpha: 0.18)
let highlightColor = NSColor(red: 0.32, green: 0.80, blue: 0.42, alpha: 1.0)
let highlightShadow = NSColor(red: 0.20, green: 0.55, blue: 0.28, alpha: 1.0)

func renderIcon(size: CGFloat) -> NSBitmapImageRep {
    let px = Int(size)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: px,
        pixelsHigh: px,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { fatalError("can't make bitmap rep") }

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let scale = size / baseSize

    // Background squircle
    let bgRect = NSRect(x: 0, y: 0, width: size, height: size)
    let bgPath = NSBezierPath(
        roundedRect: bgRect,
        xRadius: size * cornerRatio,
        yRadius: size * cornerRatio
    )
    backgroundColor.setFill()
    bgPath.fill()

    // Grid cells
    let gridInset = size * gridInsetRatio
    let gridRect = NSRect(
        x: gridInset,
        y: gridInset,
        width: size - 2 * gridInset,
        height: size - 2 * gridInset
    )
    let cellSize = gridRect.width / 2
    let cellPad = size * cellPaddingRatio
    let cellCorner = cellSize * cellCornerRatio

    func cellRect(col: Int, row: Int) -> NSRect {
        // row 0 = bottom, row 1 = top (macOS coords)
        NSRect(
            x: gridRect.minX + CGFloat(col) * cellSize + cellPad,
            y: gridRect.minY + CGFloat(row) * cellSize + cellPad,
            width: cellSize - 2 * cellPad,
            height: cellSize - 2 * cellPad
        )
    }

    let q1 = cellRect(col: 0, row: 1) // top-left:  urgent + important
    let q2 = cellRect(col: 1, row: 1) // top-right: important, not urgent  <-- highlighted
    let q3 = cellRect(col: 0, row: 0) // bottom-left
    let q4 = cellRect(col: 1, row: 0) // bottom-right

    // Muted cells (fill + stroke)
    for rect in [q1, q3, q4] {
        let path = NSBezierPath(roundedRect: rect, xRadius: cellCorner, yRadius: cellCorner)
        mutedColor.setFill()
        path.fill()
        mutedStroke.setStroke()
        path.lineWidth = max(1, 4 * scale)
        path.stroke()
    }

    // Q2 highlight with a soft inset shadow accent
    let q2Path = NSBezierPath(roundedRect: q2, xRadius: cellCorner, yRadius: cellCorner)
    highlightColor.setFill()
    q2Path.fill()

    // Inner darker band along the bottom for depth
    NSGraphicsContext.saveGraphicsState()
    q2Path.addClip()
    let bandRect = NSRect(x: q2.minX, y: q2.minY, width: q2.width, height: q2.height * 0.22)
    highlightShadow.withAlphaComponent(0.45).setFill()
    NSBezierPath(rect: bandRect).fill()
    NSGraphicsContext.restoreGraphicsState()

    return rep
}

func save(_ rep: NSBitmapImageRep, to url: URL) throws {
    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icon", code: 1)
    }
    try png.write(to: url)
}

let args = CommandLine.arguments
guard args.count == 2 else {
    print("Usage: generate_icon.swift <output_dir>")
    exit(1)
}
let outputDir = URL(fileURLWithPath: args[1])
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

// macOS AppIcon set: 16, 32, 64, 128, 256, 512, 1024
let sizes: [(name: String, px: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for entry in sizes {
    let rep = renderIcon(size: CGFloat(entry.px))
    let url = outputDir.appendingPathComponent(entry.name)
    try save(rep, to: url)
    print("wrote \(entry.name) (\(entry.px)px)")
}

// Contents.json for the appiconset
let contents = """
{
  "images" : [
    {"filename":"icon_16x16.png","idiom":"mac","scale":"1x","size":"16x16"},
    {"filename":"icon_16x16@2x.png","idiom":"mac","scale":"2x","size":"16x16"},
    {"filename":"icon_32x32.png","idiom":"mac","scale":"1x","size":"32x32"},
    {"filename":"icon_32x32@2x.png","idiom":"mac","scale":"2x","size":"32x32"},
    {"filename":"icon_128x128.png","idiom":"mac","scale":"1x","size":"128x128"},
    {"filename":"icon_128x128@2x.png","idiom":"mac","scale":"2x","size":"128x128"},
    {"filename":"icon_256x256.png","idiom":"mac","scale":"1x","size":"256x256"},
    {"filename":"icon_256x256@2x.png","idiom":"mac","scale":"2x","size":"256x256"},
    {"filename":"icon_512x512.png","idiom":"mac","scale":"1x","size":"512x512"},
    {"filename":"icon_512x512@2x.png","idiom":"mac","scale":"2x","size":"512x512"}
  ],
  "info" : {"author":"xcode","version":1}
}
"""
try contents.write(to: outputDir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("wrote Contents.json")
