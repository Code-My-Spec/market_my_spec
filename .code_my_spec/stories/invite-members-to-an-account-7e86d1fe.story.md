# Invite Members to an Account

As an account owner or admin, I want to send email invitations to teammates and review/cancel pending invitations, so that I can build out the team that has access to my account. Invitees receive a tokenized link that lets them accept and join the account at the role I assigned.

## Meta
- id: 7e86d1fe-d44d-4bd2-8c1b-da48c4e1422f
- number: 696
- status: in_progress
- component: MarketMySpecWeb.InvitationsLive.New
- personas: agency-owner

## Rules

### Only account members with manage-members permission (owner or admin) can send invitations or cancel pending ones.

#### happy: Owner sends an invitation [993f161d]
Given Alice is the owner of "Acme Marketing"
When Alice submits an invitation for "bob@example.com" with role :member
Then the invitation is created with status :pending
And Bob receives the invitation email

#### failure: Member-role user cannot invite [586a862b]
Given Carol is a :member of "Acme Marketing"
When Carol submits an invitation for "dave@example.com"
Then the invitation is rejected with :not_authorized
And no invitation record is created
And no email is sent

### An invitation cannot be sent if the email is already a member of the account or already has a pending invitation for the account.

#### failure: Invitee is already a member [c9ff3cfd]
Given Bob is already a :member of "Acme Marketing"
When Alice (owner) submits an invitation for Bob's email
Then the invitation is rejected with :already_member
And no new invitation record is created

#### failure: Email already has a pending invitation [c0b97c1d]
Given a pending invitation already exists for "bob@example.com" on "Acme Marketing"
When Alice (owner) submits another invitation for the same email
Then the invitation is rejected with :already_invited
And no duplicate invitation record is created

### An invitation requires a valid email address and a role of :owner, :admin, or :member.

#### failure: Invalid email rejected [dfe7a2bd]
Given Alice is the owner of "Acme Marketing"
When Alice submits an invitation with email "not-an-email" and role :member
Then the invitation is rejected with a changeset error on :email
And no invitation record is created

### Pending invitations for an account are visible to anyone with read-account permission on that account.

#### happy: Owner sees pending invitations [9bcd4279]
Given Alice is the owner of "Acme Marketing"
And two pending invitations exist for "bob@example.com" and "carol@example.com"
When Alice opens the invitations page for "Acme Marketing"
Then both pending invitations are listed with email and role

#### failure: Non-member sees nothing [f009444f]
Given Eve has no membership in "Acme Marketing"
And pending invitations exist for "Acme Marketing"
When Eve calls list_pending_invitations on "Acme Marketing"
Then the returned list is empty

### Accepting a valid invitation token resolves the invitee to an existing user (by email) or creates a new user, and adds them to the account at the assigned role.

#### happy: New user accepts an invitation [acdf84e5]
Given a pending invitation for "bob@example.com" with role :admin on "Acme Marketing"
And no user exists for "bob@example.com"
When Bob visits the acceptance URL with the encoded token
Then a new user is created for "bob@example.com"
And Bob is added as :admin member of "Acme Marketing"
And the invitation status becomes :accepted

#### happy: Existing user accepts an invitation [7f2aa8e9]
Given Bob already has a user account with email "bob@example.com"
And a pending invitation for "bob@example.com" with role :member on "Acme Marketing"
When Bob visits the acceptance URL with the encoded token
Then no new user is created
And Bob's existing user is added as :member of "Acme Marketing"
And the invitation status becomes :accepted

#### failure: Invalid or unknown token rejected [9cf85932]
Given no invitation exists for token "garbage-token"
When a visitor opens the acceptance URL with "garbage-token"
Then acceptance is rejected with :invalid_token
And no user is created
And no membership is granted

### Cancelling a pending invitation prevents it from being accepted afterward.

#### happy: Owner cancels a pending invitation [2374406d]
Given Alice is the owner of "Acme Marketing"
And a pending invitation exists for "bob@example.com"
When Alice cancels the invitation
Then the invitation no longer appears in the pending list
And it is removed (or marked cancelled) so it cannot be accepted

#### failure: Cancelled invitation cannot be accepted [0359e52d]
Given an invitation for "bob@example.com" has been cancelled
When Bob visits the acceptance URL with the original token
Then acceptance is rejected with :invalid_token (or :cancelled)
And Bob is not added as a member

### Invitations expire after a configured window; expired invitations cannot be accepted.

#### failure: Expired invitation rejected [fbfd4f07]
Given an invitation for "bob@example.com" with expires_at in the past
When Bob visits the acceptance URL with the encoded token
Then acceptance is rejected with :expired
And Bob is not added as a member
And the invitation is eligible for cleanup

#### happy: Invitation expires 7 days after creation [47e5753d]
Given the invitation expiry window is 7 days
When Alice (owner) sends an invitation today at noon
Then the invitation's expires_at is exactly 7 days from creation
And the invitation is accepted up until that moment
And rejected with :expired afterward

### An invitation can only be accepted by a user whose email matches the invitation; a visitor signed in as a different user must sign out (or sign in as the invitee) before accepting.

#### happy: Signed-in matching user accepts [118205d7]
Given Bob is signed in as user "bob@example.com"
And a pending invitation for "bob@example.com" exists on "Acme Marketing"
When Bob visits the acceptance URL with the token
Then Bob is added as a member of "Acme Marketing" at the assigned role
And the invitation status becomes :accepted

#### failure: Signed-in mismatched user blocked [6acdd7e1]
Given Carol is signed in as user "carol@example.com"
And a pending invitation for "bob@example.com" exists on "Acme Marketing"
When Carol visits the acceptance URL with Bob's token
Then acceptance is blocked with a sign-out prompt
And Carol is not added as a member of "Acme Marketing"
And the invitation remains :pending

## Questions
- [resolved] What is the invitation expiry window — 7 days, 14 days, 30 days? Implementation has `expires_at` field but no enforced default; cleanup task uses 30 days. Needs a product decision.
- [resolved] If the invitee is signed in as user X but the invitation email belongs to user Y, what happens? Reject? Sign out and require re-auth? Accept anyway (since token is the auth)?
