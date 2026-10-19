import Testing
@testable import Couch5k

struct ElevationCalculatorTests {
    @Test func noiseUnderThresholdAddsNothing() {
        var e = ElevationCalculator()
        for a in [100.0, 101.2, 99.4, 100.8, 99.9, 101.5, 100.1] { e.add(altitude: a, verticalAccuracy: 4) }
        #expect(e.gainMeters == 0)
    }

    @Test func steadyClimbCounts() {
        var e = ElevationCalculator()
        for a in stride(from: 100.0, through: 120.0, by: 1.0) { e.add(altitude: a, verticalAccuracy: 4) }
        #expect(abs(e.gainMeters - 18) <= 3)        // counted in 3 m steps from the last reference
    }

    @Test func descentResetsReferenceSoNextClimbCounts() {
        var e = ElevationCalculator()
        for a in [100.0, 110.0, 100.0, 110.0] { e.add(altitude: a, verticalAccuracy: 4) }
        #expect(e.gainMeters == 20)
    }

    @Test func ignoresInaccurateAndMissingAltitude() {
        var e = ElevationCalculator()
        e.add(altitude: 100, verticalAccuracy: 4)
        e.add(altitude: 150, verticalAccuracy: 30)
        e.add(altitude: 150, verticalAccuracy: -1)
        e.add(altitude: nil, verticalAccuracy: 4)
        #expect(e.gainMeters == 0)
    }
}
