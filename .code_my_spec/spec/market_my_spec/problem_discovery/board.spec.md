# MarketMySpec.ProblemDiscovery.Board

Projection module that assembles a Board view for a Frame: surviving Candidates with their scores, RedTeamVerdicts, and the Frame's threshold/kill_condition values. Read-only; no schema. The "killable in one click" UI (story 739) renders this projection.

## Type

module

## Dependencies

- MarketMySpec.ProblemDiscovery.Frame
- MarketMySpec.ProblemDiscovery.Candidate
- MarketMySpec.ProblemDiscovery.PaidJobSignal
- MarketMySpec.ProblemDiscovery.RedTeamVerdict
