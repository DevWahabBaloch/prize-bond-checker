import CoreVideo
import IOSurface
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  private let currentProof: UInt64 = 0x8123_4567_89ab_cdef

  func testPresentedProofAcceptsOnlyTheCurrentOpaqueFrame() throws {
    for format in [kCVPixelFormatType_32BGRA, kCVPixelFormatType_40ARGBLEWideGamut, kCVPixelFormatType_64RGBAHalf] {
      let frame = try makeFrame(proof: currentProof, format: format)
      XCTAssertTrue(PrivacyFrameProof.matches(currentProof, on: frame))
      XCTAssertFalse(PrivacyFrameProof.matches(0x9fed_cba9_8765_4321, on: frame))
    }
  }

  func testPresentedProofRejectsMissingAndPartialDraws() throws {
    let blank = try makeFrame(proof: nil)
    XCTAssertFalse(PrivacyFrameProof.matches(currentProof, on: blank))

    let incomplete = try makeFrame(proof: currentProof)
    XCTAssertEqual(IOSurfaceLock(incomplete, [], nil), 0)
    let pixel = IOSurfaceGetBaseAddress(incomplete).assumingMemoryBound(to: UInt32.self)
    pixel[0] = 0xff00_0000
    IOSurfaceUnlock(incomplete, [], nil)
    XCTAssertFalse(PrivacyFrameProof.matches(currentProof, on: incomplete))
  }

  func testPresentedProofRejectsAnUnsupportedSurfaceFormat() throws {
    let frame = try makeFrame(proof: currentProof, format: kCVPixelFormatType_32ARGB)
    XCTAssertFalse(PrivacyFrameProof.matches(currentProof, on: frame))
  }

  private func makeFrame(
    proof: UInt64?,
    format: OSType = kCVPixelFormatType_32BGRA
  ) throws -> IOSurfaceRef {
    let width = 512
    let height = 800
    let extended = format == kCVPixelFormatType_40ARGBLEWideGamut || format == kCVPixelFormatType_64RGBAHalf
    let pixelSize = extended ? 8 : 4
    let surface = try XCTUnwrap(IOSurfaceCreate([
      kIOSurfaceWidth: width,
      kIOSurfaceHeight: height,
      kIOSurfaceBytesPerElement: pixelSize,
      kIOSurfaceBytesPerRow: width * pixelSize,
      kIOSurfaceAllocSize: width * height * pixelSize,
      kIOSurfacePixelFormat: format,
    ] as CFDictionary))
    XCTAssertEqual(IOSurfaceLock(surface, [], nil), 0)
    defer { IOSurfaceUnlock(surface, [], nil) }
    let base = IOSurfaceGetBaseAddress(surface)
    for y in 0..<height {
      for x in 0..<width {
        let cell = (Double(x) + 0.5 - Double(width) / 8) / (Double(width) * 0.75 / 64)
        var white = true
        if let proof, (398..<402).contains(y), cell >= 0, cell < 64 {
          white = (proof >> (63 - Int(cell))) & 1 == 1
        }
        let pixel = base.advanced(by: (y * width + x) * pixelSize)
        if extended {
          let xr = format == kCVPixelFormatType_40ARGBLEWideGamut
          let bright: UInt16 = xr ? 894 << 6 : 0x3c00
          let dark: UInt16 = xr ? 384 << 6 : 0
          let words = pixel.assumingMemoryBound(to: UInt16.self)
          for component in 0..<3 {
            words[component] = white ? bright : dark
          }
          words[3] = bright
        } else {
          pixel.storeBytes(of: white ? UInt32.max : UInt32(0xff00_0000), as: UInt32.self)
        }
      }
    }
    return surface
  }
}
