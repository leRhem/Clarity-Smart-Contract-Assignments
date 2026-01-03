# Assignment 2: Simple Voting System

## Student Information
- Name: Rhema Joseph
- Date: January 4, 2026

## Contract Overview
This contract implements a decentralized voting system where users can create proposals and vote on them. Each proposal has a time limit (measured in blocks), and each user can vote only once per proposal. The system prevents double-voting and tracks vote counts in real-time. Once voting closes, no additional votes can be cast.

## Assumptions Made
- Proposals cannot be deleted or cancelled once created
- Voting duration is measured in blockchain blocks (not time/minutes)
- Once a vote is cast, it cannot be changed or withdrawn
- All proposals are public - anyone can see proposal details and vote counts
- The creator of a proposal can vote on their own proposal
- When block-height reaches end-height, voting is considered closed (deadline has passed)
- Vote counts start at zero and can only increase (no negative votes)
- There is no "abstain" option - votes are binary (yes or no)

## Design Decisions and Tradeoffs

### Decision 1: Using Composite Keys for Vote Tracking
- **What I chose:** Used a map with composite key `{proposal-id: uint, voter: principal}` to track votes
- **Why:** Need to track which specific user voted on which specific proposal. A single key (just user OR just proposal) wouldn't work because:
  - Users can vote on multiple proposals
  - Multiple users can vote on the same proposal
  - Each (user + proposal) combination must be unique
- **Tradeoff:**
  - **Gained:** Perfect tracking of every vote, prevents double-voting, enables per-user-per-proposal queries
  - **Gave up:** Slightly more complex data structure than a simple map, requires both pieces of data for lookups

### Decision 2: Time Boundary Using `<` Instead of `<=`
- **What I chose:** Used `(< block-height end-height)` for checking if voting is open
- **Why:** If a user is asked to attend a meeting, arriving at the exact meeting time is already late. Similarly, when voting has a deadline at block X, that block represents "time's up" not "last chance to vote." This provides mathematical precision: duration of 50 blocks means blocks 0-49, not 0-50.
- **Tradeoff:**
  - **Gained:** Clear, unambiguous deadline; prevents edge-case disputes about "exactly at end-height"
  - **Gave up:** Slightly less forgiving to last-minute voters; some might argue end-height should be inclusive



## How to Use This Contract

### Function: create-proposal
- **Purpose:** Create a new voting proposal with a specified duration
- **Parameters:** 
  - `title`: (string-utf8 100) - The proposal title/question
  - `description`: (string-utf8 500) - Detailed description of the proposal
  - `duration`: uint - How many blocks the voting will remain open
- **Returns:** `(ok proposal-id)` with the new proposal's ID
- **Example:**
```clarity
(contract-call? .voting-system create-proposal 
    u"Should we implement feature X?" 
    u"This feature would provide benefits Y and Z" 
    u1000)
;; Returns: (ok u1) - Proposal #1 created, voting open for 1000 blocks
```

### Function: vote
- **Purpose:** Cast a vote (yes or no) on an active proposal
- **Parameters:** 
  - `proposal-id`: uint - The ID of the proposal to vote on
  - `vote-for`: bool - true for YES, false for NO
- **Returns:** `(ok true)` on success
- **Errors:**
  - `(err u200)` - Proposal not found
  - `(err u201)` - Voting has closed (past end-height)
  - `(err u202)` - User has already voted on this proposal
- **Example:**
```clarity
;; Vote YES on proposal #1
(contract-call? .voting-system vote u1 true)

;; Vote NO on proposal #2
(contract-call? .voting-system vote u2 false)
```

### Function: get-proposal
- **Purpose:** Retrieve all details about a specific proposal
- **Parameters:** 
  - `proposal-id`: uint - The proposal ID to look up
- **Returns:** `(some {...})` with proposal data, or `none` if not found
- **Example:**
```clarity
(contract-call? .voting-system get-proposal u1)
;; Returns: (some {title: u"...", description: u"...", yes-votes: u5, no-votes: u3, end-height: u2050, creator: 'ST1...})
```

### Function: has-voted
- **Purpose:** Check if a specific user has voted on a specific proposal
- **Parameters:** 
  - `proposal-id`: uint - The proposal to check
  - `user`: principal - The user's address to check
- **Returns:** `true` if the user has voted, `false` if not
- **Example:**
```clarity
(contract-call? .voting-system has-voted u1 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
;; Returns: true or false
```

### Function: get-vote-totals
- **Purpose:** Get the current yes and no vote counts for a proposal
- **Parameters:** 
  - `proposal-id`: uint - The proposal to check
- **Returns:** `{yes-votes: uint, no-votes: uint}`
- **Example:**
```clarity
(contract-call? .voting-system get-vote-totals u1)
;; Returns: {yes-votes: u10, no-votes: u7}
```

## Known Limitations
- No vote delegation or proxy voting
- Cannot change vote after casting it
- No "abstain" or "neutral" vote option
- Voting duration cannot be extended once proposal is created
- No way to cancel or delete a proposal once created
- Vote counts can theoretically overflow at u340282366920938463463374607431768211455 (but practically impossible)
- No weighted voting - all votes have equal weight
- Cannot retrieve a list of who voted (only whether a specific user voted)
- No minimum participation requirement (proposal "passes" even with 1 total vote)
- No mechanism to determine "winning" outcome - just tracks vote counts

## Future Improvements
- Add proposal cancellation (creator-only function)
- Implement vote changing (within time limit)
- Add proposal categories or tags for organization
- Enable proposal search/filtering functionality
- Add minimum participation threshold (quorum)
- Implement automatic result declaration when voting closes
- Add reputation system based on voting history
- Enable batch voting on multiple proposals
- Add time-weighted voting (early votes worth more/less)
- Implement delegation/proxy voting
- Add "abstain" vote option
- Create dashboard showing user's voting history
- Add events/notifications when proposals are created
- Enable proposal amendments or revisions

## Testing Notes

### Test Case 1: Create Proposal Successfully
- Created proposal with title "Test Proposal", description "Testing", duration 100 blocks
- Verified returned `(ok u1)` for first proposal
- Retrieved proposal and confirmed all fields correct
- Confirmed yes-votes and no-votes both u0
- ✅ PASSED

### Test Case 2: Vote on Active Proposal
- Created proposal with duration 100 blocks
- Cast YES vote on proposal
- Verified returned `(ok true)`
- Checked vote totals and confirmed yes-votes increased to u1
- ✅ PASSED

### Test Case 3: Prevent Double Voting
- Created proposal and voted YES
- Attempted to vote again (both YES and NO)
- Verified returned error u202 (ERR-ALREADY-VOTED)
- Confirmed vote count remained at u1 (no double-count)
- ✅ PASSED

### Test Case 4: Voting After Deadline
- Created proposal with duration u1 (1 block)
- Advanced blockchain or waited for block to pass
- Attempted to vote after end-height
- Verified returned error u201 (ERR-VOTING-CLOSED)
- ✅ PASSED

### Test Case 5: Vote on Non-Existent Proposal
- Attempted to vote on proposal #999 (never created)
- Verified returned error u200 (ERR-NOT-FOUND)
- ✅ PASSED

### Test Case 6: Multiple Users Voting
- User A created proposal
- User A voted YES
- User B voted NO on same proposal
- User C voted YES on same proposal
- Verified final counts: yes-votes u2, no-votes u1
- Verified all three users show has-voted = true
- ✅ PASSED

### Test Case 7: Creator Can Vote on Own Proposal
- User A created proposal
- User A voted on their own proposal
- Verified vote was accepted and counted
- ✅ PASSED

### Test Case 8: Multiple Concurrent Proposals
- Created 3 different proposals
- Different users voted on different proposals
- Verified votes tracked separately for each proposal
- Verified proposal IDs incremented correctly (u1, u2, u3)
- ✅ PASSED

## Security Considerations

### Implemented Protections:
- ✅ Double-voting prevention via composite key tracking
- ✅ Time-based access control (can't vote after deadline)
- ✅ Proposal existence validation
- ✅ Atomic vote recording and count updates
- ✅ Type safety with explicit u0 initialization
- ✅ No integer overflow in practical use cases

### Potential Vulnerabilities (Future Hardening):
- No rate limiting on proposal creation (could spam proposals)
- No minimum duration validation (could create instant-close proposals with u0 duration)
- No maximum duration validation (could create extremely long proposals)
- No validation on title/description length (already limited by type, but could add min length)
- No governance over inappropriate proposals
- No protection against block timestamp manipulation (minor concern)