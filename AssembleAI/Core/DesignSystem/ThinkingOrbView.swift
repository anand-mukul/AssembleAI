//
//  ThinkingOrb.swift
//  AssembleAI
//
//  Native Swift/SwiftUI implementation of Jakub Antalik's Thinking Orbs
//  from Libraries.dev (npm: thinking-orbs).
//
//  Features all nine hand-tuned animated states rendered on a 2D Metal-accelerated Canvas:
//  - working:    particles on tilted orbits
//  - searching:  scan meridian sweeps a dotted globe
//  - solving:    bands scramble in quarter turns, then click back
//  - listening:  waveform rolls through latitude rings
//  - connecting: constellation wires itself, packets running the edges
//  - weaving:    three strands plait around the sphere
//  - composing:  undulating multi-band sash
//  - breathing:  face-on ring slowly morphing
//  - shaping:    dotted outline morphs circle → triangle → square
//

import SwiftUI

// MARK: - Thinking Orb State

/// The nine hand-tuned animated states from Libraries.dev (thinking-orbs).
enum ThinkingOrbState: String, CaseIterable, Sendable, Equatable {
    case working     // particles on tilted orbits
    case searching   // scan meridian sweeps a dotted globe
    case solving     // bands scramble in quarter turns, then click back
    case listening   // waveform rolls through latitude rings
    case connecting  // constellation wires itself, packets running the edges
    case weaving     // three strands plait around the sphere
    case composing   // undulating multi-band sash
    case breathing   // face-on ring slowly morphing
    case shaping     // dotted outline morphs circle → triangle → square
    
    // Semantic backward-compatibility aliases
    static var live: ThinkingOrbState { .breathing }
    static var speaking: ThinkingOrbState { .composing }
    static var verifying: ThinkingOrbState { .solving }
    static var paused: ThinkingOrbState { .breathing }
}

extension ThinkingOrbState: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        let lower = value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = ThinkingOrbState(rawValue: lower) {
            self = direct
        } else {
            switch lower {
            case "live": self = .breathing
            case "speaking": self = .composing
            case "verifying", "checking": self = .solving
            case "paused": self = .breathing
            default: self = .working
            }
        }
    }
}

// MARK: - Thinking Orb Size Presets

/// Tuned size scale presets matching Libraries.dev specifications:
/// - 64 (chat-avatar scale)
/// - 20 (inline-text scale)
/// Each carries its own hand-tuned dot count, dot radius, and speed tuning.
enum ThinkingOrbSize: Sendable, Equatable {
    case px64
    case px20
    case custom(CGFloat)
    
    var points: CGFloat {
        switch self {
        case .px64: return 64.0
        case .px20: return 20.0
        case .custom(let val): return val
        }
    }
}

// MARK: - Internal Math Engine & Models

private struct OrbDot: Sendable {
    var x: Double
    var y: Double
    var z: Double
    var r: Double
    var white: Double
    var a: Double
}

private struct OrbLine: Sendable {
    var x1: Double
    var y1: Double
    var x2: Double
    var y2: Double
    var white: Double
    var a: Double
    var w: Double
}

private struct OrbFrame: Sendable {
    var dots: [OrbDot]
    var lines: [OrbLine]
}

private struct PresetOptions: Sendable {
    var latRings: Int? = nil
    var lonDensity: Int? = nil
    var rings: Int? = nil
    var lanes: Int? = nil
    var segs: Int? = nil
    var orbitN: Int? = nil
    var ghostN: Int? = nil
    var nodeN: Int? = nil
    var strandN: Int? = nil
    var signals: Int? = nil
    var iconD: Double? = nil
    var rBase: Double? = nil
    var rDepth: Double? = nil
    var rActive: Double? = nil
    var rDot: Double? = nil
    var ghostR: Double? = nil
    var ghostA: Double? = nil
    var partR: Double? = nil
    var partRDepth: Double? = nil
    var nodeR: Double? = nil
    var nodeRDepth: Double? = nil
    var rBoost: Double? = nil
    var inkFar: Double? = nil
    var inkSpan: Double? = nil
    var rsPow: Double? = nil
    var rMin: Double? = nil
    var scanMul: Double? = nil
    var dimBase: Double? = nil
    var moveCount: Int? = nil
    var thr: Double? = nil
    var lineW: Double? = nil
    var turns: Double? = nil
    var spin: Double? = nil
    var faceOn: Double? = nil
    var wobMul: Double? = nil
    var bandMul: Double? = nil
    var spread: Double? = nil
    var particles: Int? = nil
}

// MARK: - Math Primitives (1:1 Port of engine.es.js)

@inline(__always)
private func lerp(_ n: Double, _ s: Double, _ t: Double) -> Double {
    n + (s - n) * t
}

@inline(__always)
private func fract(_ n: Double) -> Double {
    n - floor(n)
}

@inline(__always)
private func hash2D(_ n: Double, _ s: Double) -> Double {
    let t = sin(n * 12.9898 + s * 78.233) * 43758.5453
    return t - floor(t)
}

private func noise2D(_ n: Double, _ s: Double) -> Double {
    let t = floor(n), r = floor(s)
    var a = n - t, o = s - r
    a = a * a * (3.0 - 2.0 * a)
    o = o * o * (3.0 - 2.0 * o)
    let c = hash2D(t, r), M = hash2D(t + 1.0, r), h = hash2D(t, r + 1.0), m = hash2D(t + 1.0, r + 1.0)
    return c + (M - c) * a + (h - c) * o + (c - M - h + m) * a * o
}

private func fibonacciSphere(_ n: Int, _ s: Int) -> (Double, Double, Double) {
    let t = Double.pi * (3.0 - sqrt(5.0))
    let r = 1.0 - 2.0 * (Double(n) + 0.5) / Double(s)
    let a = sqrt(max(0.0, 1.0 - r * r))
    let o = Double(n) * t
    return (a * cos(o), r, a * sin(o))
}

@inline(__always)
private func angleDiff(_ n: Double, _ s: Double) -> Double {
    atan2(sin(n - s), cos(n - s))
}

@inline(__always)
private func radiusScale(_ n: Double, _ s: Double) -> Double {
    pow(n / 300.0, s)
}

private func makeProj(yaw: Double, pitch: Double, cx: Double, cy: Double, scale: Double) -> (Double, Double, Double) -> (x: Double, y: Double, z: Double) {
    let sinPitch = sin(pitch), cosPitch = cos(pitch)
    let sinYaw = sin(yaw), cosYaw = cos(yaw)
    return { m, D, p in
        let e = m * cosYaw + p * sinYaw
        let l = -m * sinYaw + p * cosYaw
        let R = D * cosPitch - l * sinPitch
        let w = D * sinPitch + l * cosPitch
        return (cx + e * scale, cy - R * scale, w)
    }
}

private func finalizeFrame(dots: [OrbDot], lines: [OrbLine], rMin: Double = 0.3) -> OrbFrame {
    var validDots: [OrbDot] = []
    validDots.reserveCapacity(dots.count)
    for var dot in dots {
        if dot.a >= 0.02 {
            dot.r = max(rMin, dot.r)
            validDots.append(dot)
        }
    }
    validDots.sort { $0.z < $1.z }
    let validLines = lines.filter { $0.a >= 0.02 }
    return OrbFrame(dots: validDots, lines: validLines)
}

// MARK: - Nine Mode Generators

private func generateBraid(n: Double, s: Double, opts: PresetOptions) -> OrbFrame {
    let r = n / 2.0, a = n / 2.0, o = n / 2.0 * 0.76
    let proj = makeProj(yaw: s * 0.4, pitch: 0.3, cx: r, cy: a, scale: 1.0)
    let M = radiusScale(n, opts.rsPow ?? 0.6)
    var dots: [OrbDot] = []
    let ghostN = opts.ghostN ?? 150
    for e in 0..<ghostN {
        let l = fibonacciSphere(e, ghostN)
        let pt = proj(l.0 * o, l.1 * o, l.2 * o)
        let u = (pt.z / o + 1.0) / 2.0
        dots.append(OrbDot(x: pt.x, y: pt.y, z: pt.z, r: 0.8 * M, white: 0.78, a: 0.1 + 0.22 * u))
    }
    let strandN = opts.strandN ?? 52, turns = opts.turns ?? 3.0
    for e in 0..<3 {
        let l = Double(e) / 3.0 * 2.0 * Double.pi
        for R in 0..<strandN {
            let w = (fract(Double(R) / Double(strandN) + s * 0.045) * 2.0 - 1.0) * 0.96
            let i = sqrt(max(0.0, 1.0 - w * w))
            let u = min(1.0, (1.0 - abs(w)) / 0.1)
            let y = w * Double.pi * turns + l
            let b = 1.0 + 0.075 * sin(w * Double.pi * turns * 2.0 + l * 2.0 + s * 0.8)
            let f = i * o * b
            let pt = proj(cos(y) * f, w * o * b, sin(y) * f)
            let d = (pt.z / o + 1.0) / 2.0
            dots.append(OrbDot(
                x: pt.x,
                y: pt.y,
                z: pt.z,
                r: ((opts.rBase ?? 1.2) + (opts.rDepth ?? 1.8) * d) * M,
                white: 0.55 - 0.45 * d,
                a: u * (0.45 + 0.55 * d)
            ))
        }
    }
    return finalizeFrame(dots: dots, lines: [], rMin: opts.rMin ?? 0.3)
}

private func generateGlobe(n: Double, s: Double, opts: PresetOptions) -> OrbFrame {
    let a = n / 2.0, o = n / 2.0, c = n / 2.0 * 0.82
    let M = 0.4 + 0.06 * sin(s * 0.35)
    let proj = makeProj(yaw: s * 0.5, pitch: M, cx: a, cy: o, scale: c)
    let m = s * (0.5 + (1.7 - 0.5) * (opts.scanMul ?? 1.0))
    let D = radiusScale(n, opts.rsPow ?? 0.6)
    let p = opts.dimBase ?? 1.0
    var dots: [OrbDot] = []
    let latRings = opts.latRings ?? 17
    let lonDensity = opts.lonDensity ?? 44
    for w in 0...latRings {
        let i = -Double.pi / 2.0 + Double(w) / Double(latRings) * Double.pi
        let u = cos(i), y = sin(i)
        let b = max(1, Int(round(abs(u) * Double(lonDensity))))
        for f in 0..<b {
            let P = Double(f) / Double(b) * 2.0 * Double.pi
            let pt = proj(u * cos(P), y, u * sin(P))
            let v = (pt.z + 1.0) / 2.0
            let k = angleDiff(P + s * 0.5, m)
            let N = exp(-(k * k) / 0.18) * max(0.0, pt.z)
            dots.append(OrbDot(
                x: pt.x,
                y: pt.y,
                z: pt.z,
                r: ((opts.rBase ?? 0.6) + (opts.rDepth ?? 1.7) * v + (opts.rBoost ?? 1.0) * N) * D,
                white: (opts.inkFar ?? 0.62) - (opts.inkSpan ?? 0.54) * v,
                a: p + (1.0 - p) * min(1.0, N)
            ))
        }
    }
    return finalizeFrame(dots: dots, lines: [], rMin: opts.rMin ?? 0.3)
}

private struct RubikMove: Sendable {
    let axis: Int
    let lo: Double
    let hi: Double
    let ang: Double
}

private func makeRubikMoves(_ n: Int) -> [RubikMove] {
    var s: [RubikMove] = []
    for t in 0..<n {
        let r = min(2, Int(floor(hash2D(Double(t), 2.3) * 3.0)))
        let a = -1.0 + 0.5 * Double(min(3, Int(floor(hash2D(Double(t), 5.9) * 4.0))))
        let o = hash2D(Double(t), 7.7) < 0.5 ? 1.0 : -1.0
        s.append(RubikMove(axis: r, lo: a, hi: a + 0.5, ang: o * Double.pi / 2.0))
    }
    return s
}

private func rubikTimeline(time: Double, count: Int, moveDur: Double, pauseDur: Double) -> (amount: [Double], active: Int) {
    let a = 2.0 * Double(count) * moveDur + pauseDur
    let o = time.truncatingRemainder(dividingBy: a)
    var c = Array(repeating: 0.0, count: count)
    var M = -1
    if o < 2.0 * Double(count) * moveDur {
        let h = Int(floor(o / moveDur))
        let m = (o - Double(h) * moveDur) / moveDur
        let p = 1.0 - pow(1.0 - min(1.0, m / 0.7), 3.0)
        if h < count {
            for e in 0..<h { c[e] = 1.0 }
            c[h] = p; M = h
        } else {
            let e = 2 * count - 1 - h
            for l in 0..<e { c[l] = 1.0 }
            c[e] = 1.0 - p; M = e
        }
    }
    return (c, M)
}

private func rotateRubikPoint(pt: (Double, Double, Double), moves: [RubikMove], tl: (amount: [Double], active: Int)) -> (Double, Double, Double, Bool) {
    var (r, a, o) = pt
    var c = false
    for M in 0..<moves.count {
        if tl.amount[M] <= 0 { continue }
        let h = moves[M]
        let m = h.axis == 0 ? r : (h.axis == 1 ? a : o)
        if m < h.lo || m >= h.hi { continue }
        if M == tl.active { c = true }
        let D = h.ang * tl.amount[M]
        let p = cos(D), e = sin(D)
        if h.axis == 0 {
            let l = a * p - o * e
            o = a * e + o * p; a = l
        } else if h.axis == 1 {
            let l = r * p + o * e
            o = -r * e + o * p; r = l
        } else {
            let l = r * p - a * e
            a = r * e + a * p; r = l
        }
    }
    return (r, a, o, c)
}

private func generateRubik(n: Double, s: Double, opts: PresetOptions) -> OrbFrame {
    let r = n / 2.0, a = n / 2.0, o = n / 2.0 * 0.82
    let proj = makeProj(yaw: s * 0.55, pitch: 0.35 + 0.1 * sin(s * 0.9), cx: r, cy: a, scale: o)
    let M = radiusScale(n, opts.rsPow ?? 0.6)
    let h = opts.moveCount ?? 14
    let m = makeRubikMoves(h)
    let D = rubikTimeline(time: s, count: h, moveDur: 0.42, pauseDur: 1.2)
    var p: [OrbDot] = []
    let e = opts.latRings ?? 15, l = opts.lonDensity ?? 40
    for R in 0...e {
        let w = -Double.pi / 2.0 + Double(R) / Double(e) * Double.pi
        let i = cos(w), u = sin(w)
        let y = max(1, Int(round(abs(i) * Double(l))))
        for b in 0..<y {
            let f = Double(b) / Double(y) * 2.0 * Double.pi
            let (P, x, g, d) = rotateRubikPoint(pt: (i * cos(f), u, i * sin(f)), moves: m, tl: D)
            let (v, k, N) = proj(P, x, g)
            let z = (N + 1.0) / 2.0
            p.append(OrbDot(
                x: v,
                y: k,
                z: N,
                r: ((opts.rBase ?? 0.6) + (opts.rDepth ?? 1.7) * z + (d ? (opts.rActive ?? 0.3) : 0.0)) * M,
                white: (opts.inkFar ?? 0.62) - (opts.inkSpan ?? 0.54) * z - (d ? 0.14 : 0.0),
                a: 1.0
            ))
        }
    }
    return finalizeFrame(dots: p, lines: [], rMin: opts.rMin ?? 0.3)
}

private func generateWave(n: Double, s: Double, opts: PresetOptions) -> OrbFrame {
    let r = n / 2.0, a = n / 2.0, o = n / 2.0 * 0.874
    let proj = makeProj(yaw: s * 0.18, pitch: 0.38, cx: r, cy: a, scale: 1.0)
    let M = radiusScale(n, opts.rsPow ?? 0.6)
    var dots: [OrbDot] = []
    let m = opts.rings ?? 15, D = opts.lonDensity ?? 40
    for p in 0...m {
        let e = -Double.pi / 2.0 + Double(p) / Double(m) * Double.pi
        let l = cos(e), R = sin(e)
        let w = 0.62 * sin(s * 2.1 - Double(p) * 0.52) + 0.38 * sin(s * 1.27 + Double(p) * 0.83)
        let i = o * (0.88 + 0.105 * w)
        let u = max(1, Int(round(abs(l) * Double(D))))
        for y in 0..<u {
            let b = Double(y) / Double(u) * 2.0 * Double.pi
            let pt = proj(l * cos(b) * i, R * i, l * sin(b) * i)
            let g = (pt.z / o + 1.0) / 2.0
            let d = max(0.0, w)
            dots.append(OrbDot(
                x: pt.x,
                y: pt.y,
                z: pt.z,
                r: ((opts.rBase ?? 0.6) + (opts.rDepth ?? 1.7) * g) * (1.0 + 0.4 * d) * M,
                white: 0.66 - 0.56 * g - 0.1 * d,
                a: 1.0
            ))
        }
    }
    return finalizeFrame(dots: dots, lines: [], rMin: opts.rMin ?? 0.3)
}

private func smoothstepPoly(_ n: Double) -> Double {
    n * n * (3.0 - 2.0 * n)
}

private func buildShapeInterpolator(_ pts: [(Double, Double)]) -> (Double) -> (Double, Double) {
    let s = pts.count
    var t: [Double] = []
    var r = 0.0
    for a in 0..<s {
        let o = pts[a], c = pts[(a + 1) % s]
        let M = hypot(c.0 - o.0, c.1 - o.1)
        t.append(M); r += M
    }
    return { a in
        var o = a * r, c = 0
        while o > t[c] && c < s - 1 {
            o -= t[c]; c += 1
        }
        let M = pts[c], h = pts[(c + 1) % s]
        let m = t[c] > 0 ? min(1.0, o / t[c]) : 0.0
        return (M.0 + (h.0 - M.0) * m, M.1 + (h.1 - M.1) * m)
    }
}

private let shapeCircle: (Double) -> (Double, Double) = { n in
    let s = -Double.pi / 2.0 + n * 2.0 * Double.pi
    return (cos(s) * 0.24, sin(s) * 0.24)
}

private let shapeTriangle = buildShapeInterpolator([
    (0.0, -0.26),
    (0.24, 0.16),
    (-0.24, 0.16)
])

private let shapeSquare = buildShapeInterpolator([
    (0.0, -0.2),
    (0.2, -0.2),
    (0.2, 0.2),
    (-0.2, 0.2),
    (-0.2, -0.2)
])

private func generateMorph(n: Double, s: Double, opts: PresetOptions) -> OrbFrame {
    let H = [shapeCircle, shapeTriangle, shapeSquare]
    let V = 1.4, ot = 0.9, Q = V + ot
    let r = H.count
    let a = s.truncatingRemainder(dividingBy: Q * Double(r))
    let o = Int(floor(a / Q))
    let c = a - Double(o) * Q
    let M = c > V ? smoothstepPoly((c - V) / ot) : 0.0
    let h = opts.spread ?? 1.0
    let m = H[o]
    let D = H[(o + 1) % r]
    let p = 160
    var e: [(Double, Double)] = []
    for x in 0..<p {
        let g = Double(x) / Double(p)
        let d = m(g), v = D(g)
        e.append(((d.0 + (v.0 - d.0) * M) * h, (d.1 + (v.1 - d.1) * M) * h))
    }
    var l: [Double] = []
    var R = 0.0
    for x in 0..<p {
        let g = e[x], d = e[(x + 1) % p]
        let v = hypot(d.0 - g.0, d.1 - g.1)
        l.append(v); R += v
    }
    let w = max(6, Int(round(34.0 * (opts.iconD ?? 1.0))))
    let i = (opts.rDot ?? 0.021) * 1.35 * h
    let u = 1.0 + 0.02 * sin(c * 3.1)
    var y: [OrbDot] = []
    let b = n / 2.0
    var f = 0, P = 0.0
    for x in 0..<w {
        let g = Double(x) / Double(w) * R
        while P + l[f] < g && f < p - 1 {
            P += l[f]; f += 1
        }
        let d = e[f], v = e[(f + 1) % p]
        let k = l[f] > 0 ? min(1.0, (g - P) / l[f]) : 0.0
        let N = (d.0 + (v.0 - d.0) * k) * u
        let z = (d.1 + (v.1 - d.1) * k) * u
        y.append(OrbDot(
            x: b + N * n,
            y: b + z * n,
            z: 0.0,
            r: max(0.35, i * n),
            white: 0.1,
            a: 1.0
        ))
    }
    return finalizeFrame(dots: y, lines: [], rMin: opts.rMin ?? 0.25)
}

private func generateOrbits(n: Double, s: Double, opts: PresetOptions) -> OrbFrame {
    let r = n / 2.0, a = n / 2.0, o = n / 2.0 * 0.82
    let proj = makeProj(yaw: s * 0.12, pitch: 0.3, cx: r, cy: a, scale: 1.0)
    let M = radiusScale(n, opts.rsPow ?? 0.6)
    var h: [OrbDot] = []
    let m = opts.orbitN ?? 12, D = opts.ghostN ?? 40, p = opts.particles ?? 3
    for e in 0..<m {
        let l = hash2D(Double(e), 1.7)
        let R = hash2D(Double(e), 5.2)
        let w = hash2D(Double(e), 8.9)
        let i = o * (0.45 + 0.52 * l)
        let u = l * 2.0 * Double.pi
        let y = acos(2.0 * R - 1.0)
        let b = sin(y) * cos(u), f = cos(y), P = sin(y) * sin(u)
        var x = -f, g = b
        let d = 0.0, v = max(1e-6, sqrt(x * x + g * g))
        x /= v; g /= v
        let k = f * d - P * g, N = P * x - b * d, z = b * g - f * x
        let O = (0.25 + 0.55 * w) * (w > 0.5 ? 1.0 : -1.0)
        for B in 0..<D {
            let I = Double(B) / Double(D) * 2.0 * Double.pi
            let pt = proj(
                (x * cos(I) + k * sin(I)) * i,
                (g * cos(I) + N * sin(I)) * i,
                (d * cos(I) + z * sin(I)) * i
            )
            let C = (pt.z / i + 1.0) / 2.0
            h.append(OrbDot(
                x: pt.x,
                y: pt.y,
                z: pt.z,
                r: (opts.ghostR ?? 0.9) * M,
                white: 0.72,
                a: (opts.ghostA ?? 0.5) * (0.4 + 0.6 * C)
            ))
        }
        for B in 0..<p {
            let I = s * O + Double(B) / Double(p) * 2.0 * Double.pi + R * 6.0
            let pt = proj(
                (x * cos(I) + k * sin(I)) * i,
                (g * cos(I) + N * sin(I)) * i,
                (d * cos(I) + z * sin(I)) * i
            )
            let C = (pt.z / i + 1.0) / 2.0
            h.append(OrbDot(
                x: pt.x,
                y: pt.y,
                z: pt.z,
                r: ((opts.partR ?? 1.2) + (opts.partRDepth ?? 1.6) * C) * M,
                white: 0.3 - 0.22 * C,
                a: 1.0
            ))
        }
    }
    return finalizeFrame(dots: h, lines: [], rMin: opts.rMin ?? 0.3)
}

private func generateRibbon(n: Double, s: Double, opts: PresetOptions) -> OrbFrame {
    let r = n / 2.0, a = n / 2.0, o = n / 2.0 * 0.78
    let c = opts.spin ?? 1.0
    let M = 0.3
    let proj = makeProj(yaw: s * 0.1 * c, pitch: M, cx: r, cy: a, scale: 1.0)
    let m = radiusScale(n, opts.rsPow ?? 0.6)
    var D: [OrbDot] = []
    let p = opts.ghostN ?? 150
    if p > 0 {
        for z in 0..<p {
            let O = fibonacciSphere(z, p)
            let pt = proj(O.0 * o, O.1 * o, O.2 * o)
            let A = (pt.z / o + 1.0) / 2.0
            D.append(OrbDot(x: pt.x, y: pt.y, z: pt.z, r: 0.8 * m, white: 0.78, a: 0.1 + 0.22 * A))
        }
    }
    let faceOn = opts.faceOn != nil && opts.faceOn! > 0
    let e = s * 0.24 * c
    let l = faceOn ? -M : (0.55 + 0.3 * sin(s * 0.18) * c)
    let R = cos(e), w = 0.0, i = sin(e)
    let u = -i * sin(l), y = cos(l), b = R * sin(l)
    let f = w * b - i * y, P = i * u - R * b, x = R * y - w * u
    let g = 0.23 * (opts.wobMul ?? 1.0)
    let d = faceOn ? (o / (1.0 + 0.85 * g)) : o
    let v = opts.lanes ?? 5, k = opts.segs ?? 88
    let N = max(1, Int(round(Double(v) * (opts.bandMul ?? 1.0))))
    for z in 0..<N {
        let O = (Double(z) - Double(N - 1) / 2.0) * 0.075
        let B = abs(Double(z) - Double(N - 1) / 2.0) / max(1.0, Double(N - 1) / 2.0)
        for I in 0..<k {
            let S = Double(I) / Double(k) * 2.0 * Double.pi
            let A = (0.16 * sin(S * 3.0 - s * 1.7 + Double(z) * 0.22) + 0.07 * sin(S * 5.0 + s * 1.1)) * (opts.wobMul ?? 1.0)
            let T = faceOn ? (1.0 + A) : 1.0
            let C = faceOn ? O : (O + A)
            let q = R * cos(S) + u * sin(S) + f * C
            let F = w * cos(S) + y * sin(S) + P * C
            let j = i * cos(S) + b * sin(S) + x * C
            let W = sqrt(q * q + F * F + j * j)
            let Y = d * T
            let pt = proj(q / W * Y, F / W * Y, j / W * Y)
            let K = (pt.z / o + 1.0) / 2.0
            D.append(OrbDot(
                x: pt.x,
                y: pt.y,
                z: pt.z,
                r: ((opts.rBase ?? 1.1) + (opts.rDepth ?? 1.7) * K) * (1.0 - 0.25 * B) * m,
                white: 0.52 - 0.44 * K + 0.18 * B,
                a: 0.4 + 0.6 * K
            ))
        }
    }
    return finalizeFrame(dots: D, lines: [], rMin: opts.rMin ?? 0.3)
}

private func generateWeb(n: Double, s: Double, opts: PresetOptions) -> OrbFrame {
    let r = n / 2.0, a = n / 2.0, o = n / 2.0 * 0.8 * (opts.spread ?? 1.0)
    let proj = makeProj(yaw: s * 0.12, pitch: 0.32, cx: r, cy: a, scale: o)
    let M = radiusScale(n, opts.rsPow ?? 0.6)
    let h = opts.nodeN ?? 30, m = opts.thr ?? 0.72, D = opts.nodeR ?? 1.4, p = opts.nodeRDepth ?? 1.8
    var e: [(Double, Double, Double)] = []
    for i in 0..<h {
        let u = fibonacciSphere(i, h)
        let y = u.0 + 0.3 * (noise2D(Double(i) * 0.31 + 9.0, s * 0.24) - 0.5) * 2.0
        let b = u.1 + 0.3 * (noise2D(Double(i) * 0.53 + 27.0, s * 0.21) - 0.5) * 2.0
        let f = u.2 + 0.3 * (noise2D(Double(i) * 0.77 + 55.0, s * 0.27) - 0.5) * 2.0
        let P = sqrt(y * y + b * b + f * f)
        e.append((y / P, b / P, f / P))
    }
    var lines: [OrbLine] = []
    var dots: [OrbDot] = []
    for i in 0..<h {
        for u in (i + 1)..<h {
            let y = e[i].0 - e[u].0, b = e[i].1 - e[u].1, f = e[i].2 - e[u].2
            let P = sqrt(y * y + b * b + f * f)
            if P >= m { continue }
            let (x, g, d) = proj(e[i].0, e[i].1, e[i].2)
            let (v, k, N) = proj(e[u].0, e[u].1, e[u].2)
            let z = ((d + N) / 2.0 + 1.0) / 2.0
            lines.append(OrbLine(
                x1: x, y1: g, x2: v, y2: k,
                white: 0.42,
                a: (1.0 - P / m) * (0.3 + 0.55 * z),
                w: max(0.6, (opts.lineW ?? 0.8) * M)
            ))
        }
    }
    for i in 0..<h {
        let (u, y, b) = proj(e[i].0, e[i].1, e[i].2)
        let f = (b + 1.0) / 2.0
        let P = 1.0 + 0.25 * sin(s * 1.4 + Double(i) * 2.7)
        dots.append(OrbDot(x: u, y: y, z: b, r: (D + p * f) * P * M, white: 0.55 - 0.45 * f, a: 1.0))
    }
    let w = opts.signals ?? 5
    for i in 0..<w {
        let u = Int(floor(s * 0.55 + Double(i) * 7.31))
        let y = Int(floor(hash2D(Double(u), Double(i) * 3.1 + 1.7) * Double(h)))
        let b = Int(floor(hash2D(Double(u), Double(i) * 5.7 + 4.2) * Double(h)))
        if y == b || y >= h || b >= h { continue }
        let f = fract(s * 0.55 + Double(i) * 7.31)
        let P = lerp(e[y].0, e[b].0, f)
        let x = lerp(e[y].1, e[b].1, f)
        let g = lerp(e[y].2, e[b].2, f)
        let d = max(1e-6, sqrt(P * P + x * x + g * g))
        let (v, k, N) = proj(P / d, x / d, g / d)
        let z = (N + 1.0) / 2.0
        dots.append(OrbDot(x: v, y: k, z: N, r: (D * 1.5 + p * z) * M, white: 0.05, a: 0.5 + 0.5 * z))
    }
    return finalizeFrame(dots: dots, lines: lines, rMin: opts.rMin ?? 0.3)
}

// MARK: - Preset Resolution Engine

private func scaleCount(_ opts: inout PresetOptions, factor: Double) {
    let a = sqrt(factor)
    if let v = opts.latRings { opts.latRings = max(2, Int(round(Double(v) * a))) }
    if let v = opts.lonDensity { opts.lonDensity = max(2, Int(round(Double(v) * a))) }
    if let v = opts.rings { opts.rings = max(2, Int(round(Double(v) * a))) }
    if let v = opts.lanes { opts.lanes = max(2, Int(round(Double(v) * a))) }
    if let v = opts.segs { opts.segs = max(2, Int(round(Double(v) * a))) }
    if let v = opts.orbitN { opts.orbitN = max(1, Int(round(Double(v) * factor))) }
    if let v = opts.ghostN { opts.ghostN = max(1, Int(round(Double(v) * factor))) }
    if let v = opts.nodeN { opts.nodeN = max(1, Int(round(Double(v) * factor))) }
    if let v = opts.strandN { opts.strandN = max(1, Int(round(Double(v) * factor))) }
    if let v = opts.signals { opts.signals = max(1, Int(round(Double(v) * factor))) }
    if let v = opts.iconD { opts.iconD = max(0.02, v * factor) }
}

private func scaleSize(_ opts: inout PresetOptions, factor: Double) {
    if let v = opts.rBase { opts.rBase = v * factor }
    if let v = opts.rDepth { opts.rDepth = v * factor }
    if let v = opts.rActive { opts.rActive = v * factor }
    if let v = opts.rDot { opts.rDot = v * factor }
    if let v = opts.ghostR { opts.ghostR = v * factor }
    if let v = opts.partR { opts.partR = v * factor }
    if let v = opts.partRDepth { opts.partRDepth = v * factor }
    if let v = opts.nodeR { opts.nodeR = v * factor }
    if let v = opts.nodeRDepth { opts.nodeRDepth = v * factor }
}

private func resolveModeAndPreset(state: ThinkingOrbState, size: CGFloat) -> (mode: String, speed: Double, opts: PresetOptions) {
    let isSmall = size <= 32.0
    switch state {
    case .working:
        var opts = PresetOptions()
        opts.orbitN = 12
        opts.ghostN = 40
        opts.ghostR = 0.9
        opts.ghostA = 0.5
        opts.particles = 3
        opts.partR = 1.2
        opts.partRDepth = 1.6
        opts.rsPow = 0.6
        opts.rMin = 0.3
        let speed = isSmall ? 3.9 : 1.885
        scaleCount(&opts, factor: isSmall ? 0.238 : 1.0)
        scaleSize(&opts, factor: isSmall ? 2.4 : 1.0)
        return ("orbits", speed, opts)
        
    case .searching:
        var opts = PresetOptions()
        opts.latRings = 17
        opts.lonDensity = 44
        opts.rBase = 0.6
        opts.rDepth = 1.7
        opts.rBoost = 1.0
        opts.inkFar = 0.62
        opts.inkSpan = 0.54
        opts.rsPow = 0.6
        opts.rMin = 0.3
        let speed = isSmall ? 2.665 : 2.015
        scaleCount(&opts, factor: isSmall ? 0.105 : 0.42)
        scaleSize(&opts, factor: isSmall ? 1.75 : 1.15)
        opts.scanMul = isSmall ? 4.335 : 4.08
        opts.dimBase = 0.45
        return ("globe", speed, opts)
        
    case .solving:
        var opts = PresetOptions()
        opts.latRings = 15
        opts.lonDensity = 40
        opts.moveCount = 14
        opts.rBase = 0.6
        opts.rDepth = 1.7
        opts.rActive = 0.3
        opts.inkFar = 0.62
        opts.inkSpan = 0.54
        opts.rsPow = 0.6
        opts.rMin = 0.3
        let speed = isSmall ? 1.95 : 1.82
        scaleCount(&opts, factor: isSmall ? 0.088 : 0.35)
        scaleSize(&opts, factor: isSmall ? 1.9 : 1.05)
        return ("rubik", speed, opts)
        
    case .listening:
        var opts = PresetOptions()
        opts.rings = 15
        opts.lonDensity = 40
        opts.rBase = 0.6
        opts.rDepth = 1.7
        opts.rsPow = 0.6
        opts.rMin = 0.3
        let speed = isSmall ? 3.998 : 4.388
        scaleCount(&opts, factor: isSmall ? 0.105 : 0.341)
        scaleSize(&opts, factor: isSmall ? 1.6 : 1.0)
        return ("wave", speed, opts)
        
    case .connecting:
        var opts = PresetOptions()
        opts.nodeN = 30
        opts.thr = 0.72
        opts.signals = 5
        opts.nodeR = 1.4
        opts.nodeRDepth = 1.8
        opts.lineW = 0.8
        opts.rsPow = 0.6
        opts.rMin = 0.3
        let speed = isSmall ? 6.63 : 3.315
        scaleCount(&opts, factor: isSmall ? 0.25 : 1.35)
        scaleSize(&opts, factor: isSmall ? 1.52 : 0.95)
        return ("web", speed, opts)
        
    case .weaving:
        var opts = PresetOptions()
        opts.strandN = 52
        opts.turns = 3.0
        opts.ghostN = 150
        opts.rBase = 1.2
        opts.rDepth = 1.8
        opts.rsPow = 0.6
        opts.rMin = 0.3
        let speed = isSmall ? 2.75 : 1.625
        scaleCount(&opts, factor: isSmall ? 0.1125 : 0.5)
        scaleSize(&opts, factor: isSmall ? 1.36 : 1.0)
        return ("braid", speed, opts)
        
    case .composing:
        var opts = PresetOptions()
        opts.lanes = 5
        opts.segs = 88
        opts.ghostN = 150
        opts.rBase = 1.1
        opts.rDepth = 1.7
        opts.rsPow = 0.6
        opts.rMin = 0.3
        let speed = isSmall ? 3.12 : 2.34
        scaleCount(&opts, factor: isSmall ? 0.051 : 0.25)
        scaleSize(&opts, factor: isSmall ? 1.073 : 0.85)
        opts.spin = 0.0
        opts.bandMul = isSmall ? 4.94 : 3.9
        opts.wobMul = 1.0
        return ("ribbon", speed, opts)
        
    case .breathing:
        var opts = PresetOptions()
        opts.lanes = 5
        opts.segs = 88
        opts.ghostN = 0
        opts.faceOn = 1.0
        opts.rBase = 1.1
        opts.rDepth = 1.7
        opts.rsPow = 0.6
        opts.rMin = 0.3
        let speed = isSmall ? 3.78 : 3.24
        scaleCount(&opts, factor: isSmall ? 0.028 : 0.25)
        scaleSize(&opts, factor: isSmall ? 1.622 : 0.956)
        opts.spin = 0.0
        opts.bandMul = isSmall ? 3.968 : 3.627
        opts.wobMul = isSmall ? 0.565 : 0.368
        return ("ring", speed, opts)
        
    case .shaping:
        var opts = PresetOptions()
        opts.rDot = 0.021
        opts.iconD = 1.0
        opts.rMin = 0.25
        let speed = isSmall ? 2.08 : 2.405
        scaleCount(&opts, factor: isSmall ? 0.53 : 0.702)
        scaleSize(&opts, factor: isSmall ? 1.011 : 0.395)
        opts.spread = 1.45
        return ("morph", speed, opts)
    }
}

private func computeFrame(state: ThinkingOrbState, size: Double, time: Double) -> OrbFrame {
    let resolved = resolveModeAndPreset(state: state, size: size)
    let s = time * resolved.speed
    switch resolved.mode {
    case "orbits": return generateOrbits(n: size, s: s, opts: resolved.opts)
    case "globe": return generateGlobe(n: size, s: s, opts: resolved.opts)
    case "rubik": return generateRubik(n: size, s: s, opts: resolved.opts)
    case "wave": return generateWave(n: size, s: s, opts: resolved.opts)
    case "web": return generateWeb(n: size, s: s, opts: resolved.opts)
    case "braid": return generateBraid(n: size, s: s, opts: resolved.opts)
    case "ribbon", "ring": return generateRibbon(n: size, s: s, opts: resolved.opts)
    case "morph": return generateMorph(n: size, s: s, opts: resolved.opts)
    default: return generateOrbits(n: size, s: s, opts: resolved.opts)
    }
}

// MARK: - ThinkingOrb SwiftUI Component (Libraries.dev Official API)

/// Thought-orb loading indicator for AI interfaces with nine hand-tuned animated states.
///
/// Usage:
/// ```swift
/// ThinkingOrb(state: .searching, size: 64)
/// ThinkingOrb(state: "listening", size: 20)
/// ```
struct ThinkingOrb: View {
    let state: ThinkingOrbState
    var size: CGFloat
    var speed: Double
    var dark: Bool?
    var paused: Bool
    var customColor: Color?
    
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    init(
        state: ThinkingOrbState = .working,
        size: CGFloat = 64.0,
        speed: Double = 1.0,
        dark: Bool? = nil,
        paused: Bool = false,
        customColor: Color? = nil
    ) {
        self.state = state
        self.size = size
        self.speed = speed
        self.dark = dark
        self.paused = paused
        self.customColor = customColor
    }
    
    init(
        state: ThinkingOrbState = .working,
        size: ThinkingOrbSize,
        speed: Double = 1.0,
        dark: Bool? = nil,
        paused: Bool = false,
        customColor: Color? = nil
    ) {
        self.init(state: state, size: size.points, speed: speed, dark: dark, paused: paused, customColor: customColor)
    }
    
    /// Convenience initializer mapping from LiveTutorStatus for AssembleAI backwards compatibility
    init(
        status: LiveTutorStatus,
        diameter: CGFloat = 24.0,
        speed: Double = 1.0,
        dark: Bool? = nil,
        paused: Bool = false,
        customColor: Color? = nil
    ) {
        let mappedState: ThinkingOrbState
        switch status {
        case .live: mappedState = .breathing
        case .listening: mappedState = .listening
        case .speaking: mappedState = .composing
        case .verifying: mappedState = .solving
        case .paused: mappedState = .breathing
        }
        self.init(
            state: mappedState,
            size: diameter,
            speed: speed,
            dark: dark,
            paused: status == .paused || paused,
            customColor: customColor
        )
    }
    
    /// Convenience initializer accepting diameter parameter
    init(
        state: ThinkingOrbState,
        diameter: CGFloat,
        speed: Double = 1.0,
        dark: Bool? = nil,
        paused: Bool = false,
        customColor: Color? = nil
    ) {
        self.init(state: state, size: diameter, speed: speed, dark: dark, paused: paused, customColor: customColor)
    }
    
    var body: some View {
        let isEffectPaused = paused || reduceMotion
        
        ZStack {
            // Ambient Apple Intelligence Glow Aura for chat-avatar scale (diameter >= 36)
            if size >= 36.0 && !isEffectPaused {
                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate * speed
                    let rotation = Angle.degrees(time * 30.0.truncatingRemainder(dividingBy: 360.0))
                    let pulse = 1.0 + sin(time * 2.0) * 0.06
                    
                    AngularGradient(
                        gradient: Gradient(colors: Color.appleIntelligenceGradient),
                        center: .center
                    )
                    .clipShape(Circle())
                    .rotationEffect(rotation)
                    .scaleEffect(pulse)
                    .frame(width: size * 1.15, height: size * 1.15)
                    .blur(radius: size * 0.18)
                    .opacity(0.24)
                }
            }
            
            // High-Performance 2D Canvas Renderer
            TimelineView(.animation(paused: isEffectPaused)) { timeline in
                let time = isEffectPaused ? 0.0 : (timeline.date.timeIntervalSinceReferenceDate * speed)
                let frame = computeFrame(state: state, size: Double(size), time: time)
                
                Canvas { context, canvasSize in
                    let isDarkTheme = dark ?? (systemColorScheme == .dark)
                    
                    // 1. Paint Lines (Constellation edges in .connecting state)
                    for line in frame.lines {
                        let c = min(1.0, max(0.0, line.white))
                        let lum = isDarkTheme ? c : (1.0 - c)
                        let lineColor: Color
                        if let custom = customColor {
                            lineColor = custom.opacity(line.a * lum)
                        } else {
                            lineColor = Color(white: lum, opacity: line.a)
                        }
                        var path = Path()
                        path.move(to: CGPoint(x: line.x1, y: line.y1))
                        path.addLine(to: CGPoint(x: line.x2, y: line.y2))
                        context.stroke(path, with: .color(lineColor), lineWidth: line.w)
                    }
                    
                    // 2. Paint Dots
                    for dot in frame.dots {
                        let c = min(1.0, max(0.0, dot.white))
                        let lum = isDarkTheme ? c : (1.0 - c)
                        let dotColor: Color
                        if let custom = customColor {
                            dotColor = custom.opacity(dot.a * lum)
                        } else {
                            dotColor = Color(white: lum, opacity: dot.a)
                        }
                        let rect = CGRect(
                            x: dot.x - dot.r,
                            y: dot.y - dot.r,
                            width: dot.r * 2.0,
                            height: dot.r * 2.0
                        )
                        context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                    }
                }
            }
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("AI indicator: \(state.rawValue)")
    }
}

// MARK: - Backwards Compatibility Alias

/// Alias for seamless integration across existing views.
typealias ThinkingOrbView = ThinkingOrb

// MARK: - Preview Playground (All 9 States)

#Preview("Thinking Orbs — All 9 States") {
    ScrollView {
        VStack(spacing: 28) {
            Text("Thinking Orbs (Libraries.dev)")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top, 16)
            
            // Grid of all 9 states at 64px scale
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90, maximum: 110))], spacing: 20) {
                ForEach(ThinkingOrbState.allCases, id: \.self) { orbState in
                    VStack(spacing: 8) {
                        ThinkingOrb(state: orbState, size: 64)
                        Text(orbState.rawValue)
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(8)
                }
            }
            
            Divider().background(Color.white.opacity(0.2))
            
            // Inline text scale (20px)
            HStack(spacing: 16) {
                ThinkingOrb(state: .searching, size: 20)
                Text("Searching components…")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            
            HStack(spacing: 16) {
                ThinkingOrb(state: .listening, size: 20)
                Text("Listening to question…")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            
            HStack(spacing: 16) {
                ThinkingOrb(state: .solving, size: 20)
                Text("Solving alignment…")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
        }
        .padding()
    }
    .background(Color.black.ignoresSafeArea())
}
