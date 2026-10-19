import Testing
import Foundation
@testable import Couch5k

func pt(_ lat: Double, _ lon: Double, t: TimeInterval, acc: Double = 5) -> RoutePointValue {
    .init(latitude: lat, longitude: lon, timestamp: Date(timeIntervalSince1970: t), horizontalAccuracy: acc)
}

struct DistanceCalculatorTests {
    @Test func rejectsInaccuratePoints() {
        var d = DistanceCalculator()
        #expect(d.add(pt(0, 0, t: 0)) == true)
        #expect(d.add(pt(0, 0.001, t: 10, acc: 50)) == false)
        #expect(d.add(pt(0, 0.001, t: 10, acc: -1)) == false)
        #expect(d.totalMeters == 0)
    }

    @Test func sumsSegments() {
        var d = DistanceCalculator()
        d.add(pt(0, 0, t: 0)); d.add(pt(0, 0.001, t: 10)); d.add(pt(0, 0.002, t: 20))
        #expect(abs(d.totalMeters - 222.6) < 1)   // 0.001° lon at equator ≈ 111.3 m
        #expect(d.accepted.count == 3)
    }

    @Test func skipsSegmentAcrossPause() {
        var d = DistanceCalculator()
        d.add(pt(0, 0, t: 0)); d.markPauseGap(); d.add(pt(0, 0.01, t: 100)); d.add(pt(0, 0.011, t: 110))
        #expect(abs(d.totalMeters - 111.3) < 1)
    }
}

struct PaceCalculatorTests {
    @Test func rollingPaceOverWindow() {
        // 3 m/s east for 40 s → 1 km takes ~333 s
        let pts = (0...40).map { pt(0, Double($0) * 3 / 111_320, t: Double($0)) }
        let p = PaceCalculator.rollingPace(points: pts, now: Date(timeIntervalSince1970: 40))
        #expect(p != nil)
        #expect(abs(p! - 333.3) < 5)
    }

    @Test func nilWhenTooLittleDistance() {
        let pts = (0...40).map { pt(0, Double($0) * 0.1 / 111_320, t: Double($0)) }
        #expect(PaceCalculator.rollingPace(points: pts, now: Date(timeIntervalSince1970: 40)) == nil)
    }
}
