import Testing
@testable import Couch5k

struct PaceDeltaTests {
    @Test func fasterWhenFewerSecondsPerKm() {
        let d = paceDelta(300, 330, miles: false)
        #expect(d == PaceDelta(faster: true, text: "0:30 faster"))
    }

    @Test func slowerInMiles() {
        let d = paceDelta(330, 300, miles: true)       // 30 s/km is 48 s/mi
        #expect(d == PaceDelta(faster: false, text: "0:48 slower"))
    }

    @Test func nilUnderTwoSecondsOrWithoutBaseline() {
        #expect(paceDelta(300, 301, miles: false) == nil)
        #expect(paceDelta(300, nil, miles: false) == nil)
        #expect(paceDelta(nil, 300, miles: false) == nil)
    }
}
