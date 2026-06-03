# Money as Validation

## Executive summary

"People paying" beats "people clicking" beats "people saying" — in that order, by a
wide margin. Every practitioner covered here converges on the same hierarchy: actual
cash transfer is the only signal that cannot be faked by politeness, social pressure,
or optimism bias. The pipeline's money gate implements this hierarchy structurally.

---

## Canonical sources

### Amy Hoy — Sales Safari / Stacking the Bricks (2011–present)

Hoy's core argument: traditional validation (surveys, interviews) is "observing lions
in a zoo." People lack skin in the game, so they default to optimistic, polite answers
that don't predict purchase behavior. Her alternative — Sales Safari — is ethnographic
observation of natural behavior in watering holes (forums, community boards) where
people self-report problems without knowing they're being researched. Crucially, she
treats what people _do_ (spend money, hire someone, publicly complain) as the only
valid data point. "Validation" through stated intent she calls a technique "for the
land of wishin' and hopin'."

Source: "Validation is backwards," Stacking the Bricks, ~2013.
https://stackingthebricks.com/validation-is-backwards/

### Rob Fitzpatrick — The Mom Test (2013)

Fitzpatrick's key observation: "People stop lying when you ask them for money."
His validation hierarchy is explicit — the strongest commitment signal, in order, is
(1) money (pre-order, deposit, LOI with a number), (2) reputation commitment (intro to
a decision-maker), (3) time commitment (a scheduled next call). Anything weaker than
these is "compliments," which are noise. His frame for a bad interview outcome: you got
lots of excited nods and no calendar invite, no check, no intro. That means nothing.

Source: _The Mom Test_, Rob Fitzpatrick, 2013. https://www.momtestbook.com/

### Patrick McKenzie (patio11) — Pricing and value signal (2006–present)

McKenzie's primary pricing thesis — "charge more" — carries a validation corollary:
if someone is already paying a freelancer $2,000 for a thing that could be a $200/mo
product, _that_ is your demand signal. The existence of a service economy around a
pain is stronger evidence than any survey. His writing on SaaS pricing also warns that
low prices attract tire-kickers; demonstrated spend history (e.g., Upwork's
`totalSpent`) is a proxy for real willingness to pay, not stated budget.

Source: Kalzumeus Greatest Hits. https://www.kalzumeus.com/greatest-hits/

### Rob Walling — SaaS validation via pre-sales (2014 MicroConf)

Walling's standard: email prospects _before_ building and ask for a credit card or
commitment. When he mailed 17 people for Drip, he was not asking "would you use this?"
— he was asking "will you pay $99/month starting now." The number who say yes (not
"probably yes," not "sounds interesting") is your validation count. Everything else is
noise.

Source: MicroConf 2014 talk, "Validate Your Idea."
https://www.phraseexpander.com/microconf-2014/rob-walling-validate-idea-launch7k-microconf-2014/

---

## Mapping to the 5-stage pipeline

**Score stage (money gate, axis 1)**

The pipeline already implements the correct hierarchy:
- `total_spent` (demonstrated cash transfer) > job `budget` (stated intent, labeled
  "garbage on Upwork")
- `hire_rate` gate filters tire-kickers: high spend + low hire = posts widely, converts
  rarely = noise tier

The Fitzpatrick hierarchy maps directly to the Score output tiers:
- `strong` = someone paying now, repeatedly (`total_spent >= $5k`, `hire_rate >= 40%`)
- `thin` = willing client, unproven scale
- `noise` = posts widely, hires rarely = validation theater in marketplace form
- `unknown` = no client signal at all

**Frame stage**

Hoy's watering-hole method is the correct framing for what the Frame stage should do:
the query string should be derived from observed pain language, not invented
vocabulary. If the market calls it "workflow rebuild" and you frame it as "automation
migration," the Gather stage will miss signal.

---

## Where our intent doc is silent / contradictory

- The pipeline treats `totalSpent` as a proxy for "willingness to pay for a product."
  Fitzpatrick and Walling would flag this as one step removed: someone paying a
  _freelancer_ is not the same as someone who would pay for _software_. The pipeline's
  own opportunity_brief.md acknowledges this explicitly ("services demand ≠ product
  demand"). The money gate is a valid first gate but needs a second-stage qualifier —
  "would they buy a tool?" — that can only come from interviews.

- None of the sources above treat freelance-marketplace spend as a final answer. They
  treat it as a conversation-starter or lead list. The pipeline correctly calls its
  output "early signal, not validated business."
