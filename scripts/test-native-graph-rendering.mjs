import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'gitmac-native-graph-'));
try {
  const file = await fs.readFile(path.join(root, 'GitMac/Features/CommitGraph/Components/GraphRow.swift'), 'utf8');
  let component = file.split('// MARK: - Shared graph drawing\n')[1];
  if (!component?.includes('enum GraphDrawingContext') || !component.includes('final class NativeGraphDrawingView')) throw Error('Production extraction boundary changed');
  if (process.argv.includes('--dash-control')) component = component.replace('context.setLineDash(phase: style.dashPhase, lengths: style.dash)', '// deliberate missing dash control');
  const probe = (await fs.readFile(path.join(root, 'GitMac/Core/Utils/MemoryPressureHandler.swift'), 'utf8')).split('/// Handles memory pressure')[0];
  const production = path.join(temporary, 'ActualGraphDrawing.swift');
  await fs.writeFile(production, 'import SwiftUI\nimport AppKit\n' + probe + '\n' + component);
  const harness = String.raw`import SwiftUI
import AppKit
@main struct GraphDrawingChecks {
    @MainActor static func main() throws {
        var checks = 0, failures = 0
        func check(_ condition: Bool, _ label: String) {
            checks += 1
            if !condition { failures += 1; print("FAIL " + label) }
        }
        let red = Color(.sRGB, red: 1, green: 0, blue: 0, opacity: 1)
        let blue = Color(.sRGB, red: 0, green: 0, blue: 1, opacity: 1)
        func bitmap(width: Int = 128, height: Int = 96, scale: Int, white: Bool = false,
                    draw: (CGContext) -> Void) throws -> [UInt8] {
            let w = width * scale, h = height * scale
            var data = [UInt8](repeating: 0, count: w * h * 4)
            try data.withUnsafeMutableBytes { bytes in
                guard let context = CGContext(data: bytes.baseAddress, width: w, height: h,
                    bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw NSError(domain: "bitmap", code: 1) }
                if white { context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: w, height: h)) }
                context.translateBy(x: 0, y: CGFloat(h))
                context.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))
                draw(context)
            }
            return data
        }
        func pixel(_ data: [UInt8], _ x: Int, _ y: Int, scale: Int, width: Int = 128, height: Int = 96) -> [Int] {
            // The drawing CTM already maps top-left logical points to bitmap rows.
            let offset = (y * scale * width * scale + x * scale) * 4
            return data[offset..<offset + 4].map(Int.init)
        }
        func isBlue(_ value: [Int]) -> Bool { value[2] > 220 && value[0] < 20 && value[3] > 220 }
        for scale in [1, 2] {
            let filled = try bitmap(scale: scale) { cg in
                GraphDrawingContext.native(cg).fill(Path(CGRect(x: 8, y: 8, width: 20, height: 20)), with: .color(red))
            }
            check(pixel(filled, 16, 16, scale: scale) == [255, 0, 0, 255], "opaque fill uses sRGB color at scale \(scale)")
            check(pixel(filled, 48, 16, scale: scale)[3] == 0, "fill does not cover outside its path")
            let alpha = try bitmap(scale: scale, white: true) { cg in
                GraphDrawingContext.native(cg).fill(Path(CGRect(x: 8, y: 8, width: 20, height: 20)), with: .color(red.opacity(0.25)))
            }
            let alphaPixel = pixel(alpha, 16, 16, scale: scale)
            check(alphaPixel[0] == 255 && abs(alphaPixel[1] - 191) <= 1 && abs(alphaPixel[2] - 191) <= 1 && alphaPixel[3] == 255,
                  "opacity blends over existing background at scale \(scale)")
            var line = Path(); line.move(to: CGPoint(x: 8, y: 44)); line.addLine(to: CGPoint(x: 104, y: 44))
            let butt = try bitmap(scale: scale) { cg in
                GraphDrawingContext.native(cg).stroke(line, with: .color(blue), lineWidth: 6)
            }
            check(isBlue(pixel(butt, 48, 44, scale: scale)), "straight lane stroke is visible")
            check(pixel(butt, 6, 44, scale: scale)[3] == 0, "default butt cap ends at endpoint")
            let round = try bitmap(scale: scale) { cg in
                GraphDrawingContext.native(cg).stroke(line, with: .color(blue), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            }
            check(isBlue(pixel(round, 6, 44, scale: scale)), "round cap extends the endpoint")
            let dashed = try bitmap(scale: scale) { cg in
                GraphDrawingContext.native(cg).stroke(line, with: .color(blue), style: StrokeStyle(lineWidth: 4, dash: [6, 4]))
            }
            check(isBlue(pixel(dashed, 10, 44, scale: scale)), "dash paints its initial segment")
            check(pixel(dashed, 16, 44, scale: scale)[3] == 0, "stash/WIP dash leaves a real gap")
            check(isBlue(pixel(dashed, 20, 44, scale: scale)), "dash resumes after the gap")
            let shifted = try bitmap(scale: scale) { cg in
                GraphDrawingContext.native(cg).stroke(line, with: .color(blue), style: StrokeStyle(lineWidth: 4, dash: [6, 4], dashPhase: 2))
            }
            check(pixel(shifted, 14, 44, scale: scale)[3] == 0 && isBlue(pixel(shifted, 18, 44, scale: scale)), "dash phase is preserved")
            var curve = Path(); curve.move(to: CGPoint(x: 8, y: 84))
            curve.addCurve(to: CGPoint(x: 104, y: 12), control1: CGPoint(x: 8, y: 48), control2: CGPoint(x: 104, y: 48))
            let curved = try bitmap(scale: scale) { cg in
                GraphDrawingContext.native(cg).stroke(curve, with: .color(blue), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
            check(isBlue(pixel(curved, 56, 48, scale: scale)), "cubic curve passes its independently calculated midpoint")
            check(pixel(curved, 56, 12, scale: scale)[3] == 0, "curve does not become a straight horizontal segment")
            let circle = try bitmap(scale: scale) { cg in
                GraphDrawingContext.native(cg).fill(Circle().path(in: CGRect(x: 54, y: 38, width: 20, height: 20)), with: .color(red))
            }
            check(pixel(circle, 64, 48, scale: scale) == [255, 0, 0, 255] && pixel(circle, 48, 48, scale: scale)[3] == 0, "node circle preserves interior and exterior")
            let view = NativeGraphDrawingView(frame: CGRect(x: 0, y: 0, width: 128, height: 96))
            var observed: CGSize?
            view.renderer = { context, size in
                observed = size
                context.fill(Path(CGRect(x: 0, y: 0, width: 200, height: 200)), with: .color(red))
            }
            let clipped = try bitmap(width: 200, height: 200, scale: scale) { cg in
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
                view.draw(view.bounds)
                NSGraphicsContext.restoreGraphicsState()
            }
            check(observed == CGSize(width: 128, height: 96), "native callback receives logical points, not Retina backing pixels")
            check(pixel(clipped, 100, 40, scale: scale, width: 200, height: 200)[3] == 255,
                  "native view draws inside its actual bounds")
            check(pixel(clipped, 140, 40, scale: scale, width: 200, height: 200)[3] == 0,
                  "native view clips outside its bounds")
            check(view.isFlipped && view.intrinsicContentSize == NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric),
                  "top-left coordinates do not introduce intrinsic window minimum feedback")
            check(view.hitTest(NSPoint(x: 10, y: 10)) == nil, "decorative renderer does not steal minimap/row gestures")
        }
        let hosted = NSHostingView(rootView: GraphCanvas { _, _ in }.frame(width: 128, height: 96))
        check(hosted.fittingSize == NSSize(width: 128, height: 96), "SwiftUI caller keeps explicit graph surface size")
        print("NATIVE_GRAPH_CHECKS: \(checks) checks, \(failures) failures")
        if failures != 0 { exit(1) }
    }
}
`;
  const main = path.join(temporary, 'Checks.swift'); await fs.writeFile(main, harness);
  const sdk = execFileSync('xcrun', ['--sdk', 'macosx', '--show-sdk-path'], { encoding: 'utf8' }).trim();
  const binary = path.join(temporary, 'checks');
  execFileSync('/usr/bin/xcrun', ['swiftc', '-parse-as-library', '-swift-version', '5', '-target', 'arm64-apple-macosx14.0', '-sdk', sdk,
    production, main, '-o', binary], { stdio: 'inherit', timeout: 120000 });
  execFileSync(binary, [], { stdio: 'inherit', timeout: 30000 });
} finally { await fs.rm(temporary, { recursive: true, force: true }); }
