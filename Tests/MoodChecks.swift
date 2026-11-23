import Foundation
@main struct MoodChecks {
 static func main() {
  precondition(MoodRules.classify(.zero) == .neutral)
  for mood in MoodKind.allCases { precondition(MoodRules.classify(mood.preset) == mood) }
  precondition(MoodRules.classify([9,-9]) == .calm)
  precondition(MoodKind.low.world == "candy" && MoodKind.tense.mode == .breath)
  precondition(MoodRules.parameters(for:.low).window == 0.28)
  precondition(MoodRules.parameters(for:.tense).exhaleOk == 6)
  var session = EnergySession();session.pace = 4
  precondition(session.handle(.started(.init(time:0))) == [20])
  precondition(session.energy == 20)
  for i in 1...4 { _ = session.handle(.started(.init(time:Double(i)))) }
  precondition(session.energy == 100)
  precondition(session.handle(.started(.init(time:6))).isEmpty)
  print("Mood recommendation and pace checks passed")
 }
}
