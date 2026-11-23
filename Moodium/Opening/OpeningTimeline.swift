// Frame ranges ported directly from Unity OpeningVideoTimeline.cs (30 fps).
enum OpeningTimeline {
    struct Segment: Equatable {
        let start: Int
        let end: Int
        var startSeconds: Double { Double(start) / 30 }
        var endSeconds: Double { Double(end) / 30 }
    }
    struct Language {
        let entry: Int
        let question: Segment
        let yes: Segment
        let no: Segment
    }
    static let language = Segment(start: 734, end: 968)
    static let chinese = Language(entry: 968, question: .init(start: 1240, end: 1410), yes: .init(start: 1410, end: 1873), no: .init(start: 2058, end: 2409))
    static let english = Language(entry: 2507, question: .init(start: 2811, end: 2959), yes: .init(start: 2959, end: 3417), no: .init(start: 3567, end: 3929))
    static let sticker = Segment(start: 1240, end: 1380)
}
