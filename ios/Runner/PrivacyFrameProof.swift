import CoreVideo
import IOSurface

/// Confirms the current proof and checks that the surface contains only the opaque transition frame.
enum PrivacyFrameProof {
  static func matches(_ proof: UInt64, on surface: IOSurfaceRef) -> Bool {
    let width = IOSurfaceGetWidth(surface)
    let height = IOSurfaceGetHeight(surface)
    let stride = IOSurfaceGetBytesPerRow(surface)
    let pixelSize = IOSurfaceGetBytesPerElement(surface)
    let format = IOSurfaceGetPixelFormat(surface)

    switch (format, pixelSize) {
    case (kCVPixelFormatType_32BGRA, 4),
         (kCVPixelFormatType_40ARGBLEWideGamut, 8),
         (kCVPixelFormatType_64RGBAHalf, 8):
      break
    default:
      return false
    }
    guard width >= 128, height >= 400, stride >= width * pixelSize,
          stride <= IOSurfaceGetAllocSize(surface) / height,
          IOSurfaceLock(surface, [.readOnly, .avoidSync], nil) == 0 else { return false }
    defer { IOSurfaceUnlock(surface, [.readOnly, .avoidSync], nil) }
    let base = IOSurfaceGetBaseAddress(surface)

    let row = base.advanced(by: (height / 2) * stride)
    for bit in 0..<64 {
      let x = Int(Double(width) * (0.125 + 0.75 * (Double(bit) + 0.5) / 64))
      let pixel = row.advanced(by: x * pixelSize)
      let white = (proof >> (63 - bit)) & 1 == 1
      guard matchesPixel(pixel, format: format, white: white) else { return false }
    }
    // A matching strip alone cannot rule out a partially drawn frame. Check the matte
    // and allow a pixel of rounding only at the edges of the proof bars.
    let left = Double(width) / 8
    let barWidth = Double(width) * 0.75 / 64
    let top = Double(height) * 0.4975
    let bottom = Double(height) * 0.5025
    func isWhiteBar(at column: Double) -> Bool {
      let position = (column - left) / barWidth
      guard position >= 0, position < 64 else { return true }
      return (proof >> (63 - Int(position))) & 1 == 1
    }

    for y in 0..<height {
      let row = base.advanced(by: y * stride)
      let center = Double(y) + 0.5
      if center < top - 1 || center > bottom + 1 {
        for x in 0..<width {
          guard matchesPixel(row.advanced(by: x * pixelSize), format: format, white: true) else { return false }
        }
      } else {
        let nearStripEdge = center < top + 1 || center > bottom - 1
        for x in 0..<width {
          let column = Double(x) + 0.5
          let pixel = row.advanced(by: x * pixelSize)
          let leftColor = isWhiteBar(at: column - 1)
          let rightColor = isWhiteBar(at: column + 1)
          if leftColor == rightColor && !nearStripEdge {
            guard matchesPixel(pixel, format: format, white: leftColor) else { return false }
          } else if !matchesPixel(pixel, format: format, white: true) &&
                    (leftColor && rightColor || !matchesPixel(pixel, format: format, white: false)) {
            return false
          }
        }
      }
    }
    return true
  }

  private static func matchesPixel(_ pixel: UnsafeRawPointer, format: OSType, white: Bool) -> Bool {
    if format == kCVPixelFormatType_32BGRA {
      let bytes = pixel.assumingMemoryBound(to: UInt8.self)
      guard bytes[3] >= 245 else { return false }
      return white ? min(bytes[0], bytes[1], bytes[2]) >= 245 : max(bytes[0], bytes[1], bytes[2]) <= 10
    }

    let words = pixel.assumingMemoryBound(to: UInt16.self)
    if format == kCVPixelFormatType_64RGBAHalf {
      // In half-float, 0x3c00 encodes 1.0 and 0x2c00 encodes 0.0625.
      let opaque = 0x3b80...0x3c80
      guard opaque.contains(Int(words[3])) else { return false }
      return (0..<3).allSatisfy { white ? opaque.contains(Int(words[$0])) : words[$0] <= 0x2c00 }
    }

    // XR stores 10-bit components in the upper bits of four little-endian words.
    // Black is encoded near 384 and white near 895. Accept either channel order for opaque black.
    var bright = 0
    var dark = 0
    for component in 0..<4 {
      let value = Int(UInt16(littleEndian: words[component]) >> 6)
      if value >= 840 { bright += 1 }
      if (345...425).contains(value) { dark += 1 }
    }
    return white ? bright == 4 : bright == 1 && dark == 3
  }
}
