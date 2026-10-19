enum Plan {
    static func session(_ id: SessionID) -> Session? { sessions.first { $0.id == id } }

    static func next(after id: SessionID) -> SessionID? {
        if id.day < 3 { return .init(week: id.week, day: id.day + 1) }
        if id.week < 9 { return .init(week: id.week + 1, day: 1) }
        return nil
    }

    static let sessions: [Session] = {
        /// The published plan ends some sessions with a recovery walk followed by the cooldown walk.
        /// Those are one continuous walk, so they are folded into a single longer cooldown: one cue, same total time.
        func s(_ w: Int, _ d: Int, _ work: [Interval]) -> Session {
            var work = work
            var cooldown = Interval.cooldown
            if let last = work.last, last.kind == .walk {
                work.removeLast()
                cooldown = Interval(kind: .cooldown, seconds: last.seconds + Interval.cooldown.seconds)
            }
            return .init(id: .init(week: w, day: d), intervals: [.warmup] + work + [cooldown])
        }
        func rep(_ n: Int, _ p: [Interval]) -> [Interval] { Array((0..<n).map { _ in p }.joined()) }
        let w1 = rep(8, [.run(60), .walk(90)])
        let w2 = rep(6, [.run(90), .walk(120)])
        let w3 = rep(2, [.run(90), .walk(90), .run(180), .walk(180)])
        let w4: [Interval] = [.run(180), .walk(90), .run(300), .walk(150), .run(180), .walk(90), .run(300)]
        let w5d1 = rep(3, [.run(300), .walk(180)])
        let w5d2: [Interval] = [.run(480), .walk(300), .run(480)]
        let w5d3: [Interval] = [.run(1200)]
        let w6d1: [Interval] = [.run(300), .walk(180), .run(480), .walk(180), .run(300)]
        let w6d2: [Interval] = [.run(600), .walk(180), .run(600)]
        let w6d3: [Interval] = [.run(1500)]
        let w7: [Interval] = [.run(1500)]
        let w8: [Interval] = [.run(1680)]
        let w9: [Interval] = [.run(1800)]
        var out: [Session] = []
        for d in 1...3 { out.append(s(1, d, w1)) }
        for d in 1...3 { out.append(s(2, d, w2)) }
        for d in 1...3 { out.append(s(3, d, w3)) }
        for d in 1...3 { out.append(s(4, d, w4)) }
        out += [s(5, 1, w5d1), s(5, 2, w5d2), s(5, 3, w5d3)]
        out += [s(6, 1, w6d1), s(6, 2, w6d2), s(6, 3, w6d3)]
        for d in 1...3 { out.append(s(7, d, w7)) }
        for d in 1...3 { out.append(s(8, d, w8)) }
        for d in 1...3 { out.append(s(9, d, w9)) }
        return out
    }()
}
