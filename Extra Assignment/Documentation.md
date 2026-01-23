# Assignment: Cooperative Savings (ROSCA) Smart Contract

## Student Information
- Name: Rhema Joseph
- Date: January 23, 2026

## Contract Overview

This contract implements a Rotating Savings and Credit Association (ROSCA) on the Stacks blockchain. It enables groups of people to pool monthly contributions and distribute lump sum payouts in rotating order.

**How it works:** 
- A group of N members each commit to deposit X STX monthly for N months
- Each month, all members deposit, and one member receives the full pool (N × X STX)
- The recipient rotates based on pre-assigned positions until everyone has received their payout
- The contract provides transparency, automatic distribution, and creator tools for dispute resolution

**Real-world use case:** Community savings groups common in many countries where members help each other access larger sums for major purchases, emergencies, or investments.

## Assumptions Made

- **Assumption 1:** All amounts are in microSTX (1 STX = 1,000,000 microSTX) for precision
- **Assumption 2:** Cycle duration is measured in blocks (~144 blocks per day on Stacks)
- **Assumption 3:** Members have legal agreements off-chain; the contract cannot enforce continued participation after early payout
- **Assumption 4:** Creator is trusted to manage the group fairly (assign positions, resolve disputes)
- **Assumption 5:** Grace period is fixed at 1440 blocks (~10 days) for all groups
- **Assumption 6:** Once a member receives their payout, they cannot receive another in the same group
- **Assumption 7:** Group creator bears the gas costs for adding members and starting cycles
- **Assumption 8:** All members including the first recipient must deposit before any payout occurs
- **Assumption 9:** STX transfers succeed (contract does not handle transfer failures beyond error codes)
- **Assumption 10:** Block height is reliable for time measurement (no consideration for potential blockchain reorganizations)

## Design Decisions and Tradeoffs

### Decision 1: Monthly Deposits vs Upfront Full Deposit

- **What I chose:** Monthly deposit system where members contribute each cycle
- **Why:** 
  - Lower barrier to entry (only need one month's contribution to start)
  - Matches traditional ROSCA models familiar to target users
  - More accessible for communities with limited capital
  - Requested by stakeholder as primary requirement
- **Tradeoff:** 
  - **Gained:** Accessibility, familiarity, lower initial capital requirement
  - **Lost:** Trustless enforcement (cannot prevent abandonment after receiving payout), requires off-chain legal agreements, higher risk of default

### Decision 2: Creator-Assigned Payout Positions

- **What I chose:** Creator manually assigns each member a payout position when adding them
- **Why:**
  - Provides flexibility for fairness (e.g., someone with urgent need goes first)
  - Allows negotiation within community before blockchain commitment
  - Creator knows community members and their circumstances
  - Simpler than auction or random systems
- **Tradeoff:**
  - **Gained:** Human judgment, flexibility, community-driven fairness, simplicity
  - **Lost:** Potential for creator bias, less "trustless", requires trust in creator's fairness

### Decision 3: Grace Period for Late Payments

- **What I chose:** 10-day (1440 block) grace period after each cycle deadline
- **Why:**
  - Real life has delays (bank transfers, emergencies, technical issues)
  - Reduces unnecessary defaults from minor lateness
  - More humane and practical for real communities
  - Requested specifically by stakeholder
- **Tradeoff:**
  - **Gained:** Flexibility, reduced false defaults, better user experience
  - **Lost:** Delays in cycle progression, some ambiguity about "on-time" vs "late", potential for members to always use grace period

### Decision 4: Creator Override Capabilities

- **What I chose:** Creator can manually mark contributions paid, pause group, and advance cycles
- **Why:**
  - Handles off-chain payments (cash, mobile money) that need on-chain record
  - Provides dispute resolution mechanism
  - Allows recovery from edge cases and technical issues
  - Acknowledges that real-world situations need human judgment
- **Tradeoff:**
  - **Gained:** Practical dispute resolution, handles off-chain reality, flexibility
  - **Lost:** Centralization, requires trust in creator, not fully "trustless"

### Decision 5: Everyone Deposits First (Including Position 1)

- **What I chose:** All members including the first payout recipient must deposit before any payout
- **Why:**
  - Fairness - no one gets "free" early payout
  - Demonstrates commitment from all members
  - Creates initial pool before any distribution
  - Reduces perception of unfairness
- **Tradeoff:**
  - **Gained:** Fairness, equal treatment, demonstrated commitment
  - **Lost:** First recipient temporarily locks more capital (deposits then receives), slightly more complex first cycle

### Decision 6: Simple Linear Rotation (No Interest/Bonuses)

- **What I chose:** Equal payouts for all positions, no time-value adjustments
- **Why:**
  - Mathematical simplicity (easier to understand and explain)
  - Traditional ROSCA model that users know
  - Avoids complex interest calculations and disputes
  - Easier to audit and verify
- **Tradeoff:**
  - **Gained:** Simplicity, familiarity, no calculation errors, clear expectations
  - **Lost:** Economic unfairness (position 10 waits longer but gets same amount), could add interest for later positions

### Decision 7: Single Map for Contributions (Per Member Per Cycle)

- **What I chose:** Separate map tracking each member's payment for each cycle
- **Why:**
  - Precise tracking - know exactly who paid what when
  - Supports auditing and legal evidence
  - Enables "has member paid this cycle?" queries
  - Prevents double-payment bugs
- **Tradeoff:**
  - **Gained:** Precision, auditability, legal evidence, bug prevention
  - **Lost:** More storage operations (higher gas costs), more complex state management

### Decision 8: Contract Holds All Funds (No Separate Escrow)

- **What I chose:** All STX go directly to contract address `(as-contract tx-sender)`
- **Why:**
  - Simpler architecture (one source of truth)
  - Fewer potential bugs from escrow abstraction
  - Clear fund custody (always in contract)
  - Easier to audit total pool balance
- **Tradeoff:**
  - **Gained:** Simplicity, clarity, fewer bugs, easier auditing
  - **Lost:** Less separation of concerns, all eggs in one basket (but that's fine for this use case)

## How to Use This Contract

### Function: create-group

- **Purpose:** Creates a new cooperative savings group
- **Who can call:** Anyone (becomes the creator)
- **Parameters:**
  - `group_id` (string-utf8 50): Unique identifier for the group (e.g., "village-savings-2026-01")
  - `name` (string-utf8 100): Display name (e.g., "Village Savings Group")
  - `description` (optional string-utf8 256): Optional description
  - `deposit_per_member` (uint): Amount each member deposits per cycle in microSTX (e.g., u1000000000 = 1000 STX)
  - `cycle_duration_blocks` (uint): Length of each cycle in blocks (e.g., u4320 ≈ 30 days)
  - `max_members` (uint): Total number of members (e.g., u10)
- **Returns:** `(ok true)` on success, error code on failure
- **Example:**
```clarity
(contract-call? .cooperative-savings create-group
  "village-savings-001"
  "Village Savings Group"
  (some "Monthly savings for our community")
  u1000000000  ;; 1000 STX per member per month
  u4320        ;; ~30 days per cycle
  u10          ;; 10 members total
)
```

### Function: add-member

- **Purpose:** Add a member to the group with assigned payout position
- **Who can call:** Only group creator
- **Parameters:**
  - `group_id` (string-utf8 50): The group identifier
  - `member_address` (principal): The member's wallet address
  - `member_name` (string-utf8 100): Display name for the member
  - `payout_position` (uint): When they receive payout (1 = first, 2 = second, etc.)
- **Returns:** `(ok true)` on success, error code on failure
- **Example:**
```clarity
(contract-call? .cooperative-savings add-member
  "village-savings-001"
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
  "Alice Johnson"
  u1  ;; Alice gets payout first
)
```

### Function: start-first-cycle

- **Purpose:** Begin the first savings cycle (enables deposits)
- **Who can call:** Only group creator
- **Parameters:**
  - `group_id` (string-utf8 50): The group identifier
- **Returns:** `(ok true)` on success, error code on failure
- **Requirements:** All member slots must be filled
- **Example:**
```clarity
(contract-call? .cooperative-savings start-first-cycle
  "village-savings-001"
)
```

### Function: deposit

- **Purpose:** Member deposits their contribution for the current cycle
- **Who can call:** Any group member
- **Parameters:**
  - `group_id` (string-utf8 50): The group identifier
- **Returns:** `(ok true)` on success, error code on failure
- **Requirements:** 
  - Must be within payment window (cycle deadline + grace period)
  - Cannot have already paid this cycle
  - Must have sufficient STX balance
- **Example:**
```clarity
(contract-call? .cooperative-savings deposit
  "village-savings-001"
)
;; Automatically transfers deposit_per_member amount from caller to contract
```

### Function: claim-payout

- **Purpose:** Member claims their payout when it's their turn
- **Who can call:** Any group member (when it's their turn)
- **Parameters:**
  - `group_id` (string-utf8 50): The group identifier
- **Returns:** `(ok true)` on success, error code on failure
- **Requirements:**
  - Current cycle must equal your payout position
  - Must not have already received payout
  - Sufficient contributions must be in pool
- **Example:**
```clarity
(contract-call? .cooperative-savings claim-payout
  "village-savings-001"
)
;; If successful, transfers full pool amount to caller
```

### Function: creator-mark-paid

- **Purpose:** Creator manually marks a member's contribution as paid (dispute resolution)
- **Who can call:** Only group creator
- **Parameters:**
  - `group_id` (string-utf8 50): The group identifier
  - `member_address` (principal): The member's address
  - `cycle` (uint): Which cycle to mark as paid
- **Returns:** `(ok true)` on success, error code on failure
- **Use case:** Member paid off-chain (cash/mobile money) and creator confirms
- **Example:**
```clarity
(contract-call? .cooperative-savings creator-mark-paid
  "village-savings-001"
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
  u3  ;; Mark cycle 3 as paid
)
```

### Function: creator-set-status

- **Purpose:** Pause or resume group operations
- **Who can call:** Only group creator
- **Parameters:**
  - `group_id` (string-utf8 50): The group identifier
  - `new_status` (uint): Status code (u1=ACTIVE, u2=COMPLETED, u3=PAUSED)
- **Returns:** `(ok true)` on success, error code on failure
- **Use case:** Pause during disputes, resume after resolution
- **Example:**
```clarity
(contract-call? .cooperative-savings creator-set-status
  "village-savings-001"
  u3  ;; Pause the group
)
```

### Function: creator-advance-cycle

- **Purpose:** Manually advance to next cycle (dispute resolution)
- **Who can call:** Only group creator
- **Parameters:**
  - `group_id` (string-utf8 50): The group identifier
- **Returns:** `(ok true)` on success, error code on failure
- **Use case:** Skip problematic cycle after resolving disputes
- **Example:**
```clarity
(contract-call? .cooperative-savings creator-advance-cycle
  "village-savings-001"
)
```

### Function: get-group (Read-Only)

- **Purpose:** Retrieve all group information
- **Who can call:** Anyone
- **Parameters:**
  - `group_id` (string-utf8 50): The group identifier
- **Returns:** Group data or none
- **Example:**
```clarity
(contract-call? .cooperative-savings get-group
  "village-savings-001"
)
;; Returns: {creator, name, description, deposit_per_member, cycle_duration_blocks,
;;           max_members, members_count, current_cycle, cycle_start_block, status,
;;           total_pool_balance, created_at}
```

### Function: get-member (Read-Only)

- **Purpose:** Retrieve member information
- **Who can call:** Anyone
- **Parameters:**
  - `group_id` (string-utf8 50): The group identifier
  - `member_address` (principal): The member's address
- **Returns:** Member data or none
- **Example:**
```clarity
(contract-call? .cooperative-savings get-member
  "village-savings-001"
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
)
;; Returns: {member_name, payout_position, has_received_payout, joined_at}
```

### Function: get-contribution (Read-Only)

- **Purpose:** Check if a member paid for a specific cycle
- **Who can call:** Anyone
- **Parameters:**
  - `group_id` (string-utf8 50): The group identifier
  - `member_address` (principal): The member's address
  - `cycle` (uint): Cycle number to check
- **Returns:** Contribution data or none
- **Example:**
```clarity
(contract-call? .cooperative-savings get-contribution
  "village-savings-001"
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
  u3  ;; Check cycle 3
)
;; Returns: {amount, paid_at_block, is_paid}
```

### Function: check-payment-window (Read-Only)

- **Purpose:** Check if current block is within payment window
- **Who can call:** Anyone
- **Parameters:**
  - `group_id` (string-utf8 50): The group identifier
- **Returns:** Payment window status
- **Example:**
```clarity
(contract-call? .cooperative-savings check-payment-window
  "village-savings-001"
)
;; Returns: {current_block, cycle_deadline, grace_deadline,
;;           is_within_cycle, is_within_grace, is_expired}
```

## Known Limitations

### Critical Limitation: Cannot Prevent Abandonment
- **Issue:** After a member receives their payout, nothing in the smart contract can force them to continue depositing in subsequent cycles
- **Impact:** Early payout recipients could abandon the group (e.g., Person #1 gets 10,000 STX in Month 1, then never deposits again)
- **Mitigation:** Requires off-chain legal agreements, social pressure, and community trust. Contract provides transparent evidence for legal enforcement.

### No Automated Cycle Advancement
- **Issue:** Cycles do not automatically advance when all members have paid
- **Impact:** Requires manual payout claim by the designated recipient
- **Rationale:** Keeps contract simpler and gives recipient control over timing

### Fixed Grace Period
- **Issue:** Grace period is hardcoded at 1440 blocks (~10 days) for all groups
- **Impact:** Cannot customize grace period per group
- **Workaround:** Could be parameterized in future version

### No Partial Refunds
- **Issue:** If group fails mid-cycle, no mechanism for proportional refunds
- **Impact:** Funds could be stuck if group dissolves prematurely
- **Workaround:** Creator can use override functions for manual resolution

### Single Payout Per Member
- **Issue:** Each member can only receive one payout per group
- **Impact:** Cannot reuse same group for multiple ROSCA cycles
- **Workaround:** Create new group for subsequent rounds

### No Interest Calculations
- **Issue:** Later recipients wait longer but receive same amount (no time-value compensation)
- **Impact:** Economic unfairness for later positions
- **Justification:** Matches traditional ROSCA model, keeps math simple

### Centralized Creator Control
- **Issue:** Creator has significant power (mark paid, pause, advance cycles)
- **Impact:** Requires trust in creator; not fully "trustless"
- **Justification:** Necessary for real-world dispute resolution

### No Slashing or Penalties
- **Issue:** Missing payment has no on-chain penalty beyond being marked as unpaid
- **Impact:** Relies entirely on off-chain consequences
- **Rationale:** Smart contract cannot access off-chain collateral

### Gas Costs Not Optimized
- **Issue:** Each contribution creates separate map entry (potentially expensive at scale)
- **Impact:** Higher transaction costs for large groups
- **Workaround:** Optimize in future version with batch operations

### Block Height Time Assumptions
- **Issue:** Assumes blocks are mined at consistent rate (~10 minutes)
- **Impact:** Cycle durations could vary if mining rate changes
- **Mitigation:** Use conservative estimates, monitor actual timing

## Future Improvements

### High Priority
1. **Partial Upfront Deposit** - Require 2-3 months upfront to reduce abandonment risk while maintaining accessibility
2. **Automated Cycle Advancement** - Automatically move to next cycle when current recipient claims payout
3. **Interest/Time-Value Adjustments** - Later recipients get bonus for waiting longer
4. **Emergency Dissolution** - Allow proportional refunds if group agrees to dissolve early

### Medium Priority
5. **Configurable Grace Period** - Let creator set grace period per group
6. **Multi-Cycle Groups** - Allow groups to run multiple ROSCA rounds
7. **Batch Operations** - Add members in batch to reduce gas costs
8. **Event Emissions** - Emit events for deposits, payouts, cycle changes for better frontend integration

### Lower Priority
9. **Reputation System** - Track member reliability across multiple groups
10. **Auction-Based Positions** - Members bid for early positions, creating self-enforcing incentives
11. **Multi-Token Support** - Support tokens beyond STX
12. **Delegation** - Allow members to delegate their position to others
13. **Insurance Pool** - Optional collective insurance against defaults

## Testing Notes

### Manual Testing Performed
1. ✅ **Happy Path (3-member group):** Created group, added 3 members, completed all 3 cycles successfully
2. ✅ **Grace Period:** Verified late deposits accepted within grace window, rejected after
3. ✅ **Double Payment Prevention:** Confirmed member cannot deposit twice in same cycle
4. ✅ **Payout Timing:** Verified only correct position can claim during each cycle
5. ✅ **Creator Override:** Tested manual mark-paid, pause/unpause, cycle advancement
6. ✅ **Authorization:** Confirmed only creator can add members, non-members cannot deposit
7. ✅ **Balance Tracking:** Verified pool balance updates correctly after deposits and payouts

### Key Test Cases Verified

**Test Case 1: Complete 3-Member ROSCA**
- Setup: 3 members, 100 STX/month, 3 cycles
- Result: All members deposited each cycle, each received 300 STX payout in turn, group completed ✅

**Test Case 2: Late Payment in Grace Period**
- Setup: Deposit attempted 500 blocks after cycle deadline (within 1440 grace)
- Result: Deposit accepted ✅

**Test Case 3: Late Payment Beyond Grace**
- Setup: Deposit attempted 2000 blocks after cycle deadline (beyond grace)
- Result: Transaction rejected with ERR_GRACE_PERIOD_ENDED ✅

**Test Case 4: Wrong Turn Payout Attempt**
- Setup: Member with position 3 tries to claim during cycle 1
- Result: Transaction rejected with ERR_NOT_YOUR_TURN ✅

**Test Case 5: Double Deposit Prevention**
- Setup: Same member tries to deposit twice in cycle 2
- Result: Second deposit rejected with ERR_ALREADY_PAID ✅

**Test Case 6: Creator Mark-Paid Override**
- Setup: Creator marks member as paid for cycle 2 without on-chain transfer
- Result: Contribution record updated, member can now claim payout ✅

**Test Case 7: Non-Member Deposit Attempt**
- Setup: Random wallet tries to deposit to group
- Result: Transaction rejected with ERR_NOT_MEMBER ✅

### Testing Limitations
- ⚠️ Not tested on mainnet (only testnet/local)
- ⚠️ Not tested with very large groups (>20 members)
- ⚠️ Not stress-tested for gas optimization
- ⚠️ Not tested with actual blockchain reorganizations
- ⚠️ Not formally audited by security professionals

## Security Checklist

### Ownership & Authorization
- [x] Only creator can add members to their groups
- [x] Only creator can start first cycle
- [x] Only creator can use override functions (mark-paid, set-status, advance-cycle)
- [x] Only group members can deposit
- [x] Only designated position can claim payout during their cycle

### State Validation
- [x] Validate all state transitions (cycle advancement, status changes)
- [x] Prevent deposits when group is paused or completed
- [x] Prevent payouts when not enough contributions in pool
- [x] Ensure member cannot receive payout twice
- [x] Check group exists before any operation

### Financial Security
- [x] Prevent double-deposit in same cycle
- [x] Atomic STX transfers (deposit and payout in single transaction)
- [x] Track total pool balance accurately
- [x] Verify sufficient balance before payout
- [x] Check for integer overflow in balance calculations (Clarity handles this automatically)

### Input Validation
- [x] Verify group_id is not empty string
- [x] Validate payout position is within valid range (1 to max_members)
- [x] Check deposit amount is greater than zero
- [x] Ensure cycle duration is positive
- [x] Validate max_members is greater than 1

### Time-Based Security
- [x] Enforce payment deadlines with grace period
- [x] Prevent operations before cycle starts
- [x] Track block heights for cycle timing
- [x] Validate payment window before accepting deposits

### Access Control Edge Cases
- [x] Non-members cannot deposit or claim payouts
- [x] Creator cannot manipulate other creators' groups
- [x] Members cannot modify their payout position after assignment
- [x] Cannot add member to non-existent group

### Additional Security Considerations
- [x] Use `(as-contract tx-sender)` for proper fund custody
- [x] Handle STX transfer failures with try! and proper error codes
- [x] No re-entrancy risk (Clarity's design prevents this)
- [x] No unchecked external calls (all calls are explicit contract calls)

### Known Security Limitations
- ⚠️ **Trust in Creator:** Creator has override powers; members must trust creator's fairness
- ⚠️ **No Rug Pull Protection:** Cannot prevent creator from pausing group indefinitely
- ⚠️ **Abandonment Risk:** Cannot enforce continued participation after payout
- ⚠️ **Off-Chain Dependencies:** Effectiveness relies on legal agreements and social enforcement

---

## Additional Notes

### Recommended Deployment Process
1. Deploy to testnet first (devnet/testnet)
2. Run comprehensive test suite with real STX (testnet tokens)
3. Conduct community pilot with small amounts (10-100 STX)
4. Get legal review of off-chain agreements
5. Consider professional security audit before mainnet deployment with large amounts
6. Deploy to mainnet with conservative initial limits

### Recommended Off-Chain Practices
1. **Legal Agreements:** All members sign binding contract before joining
2. **Identity Verification:** Verify member identities (KYC for larger amounts)
3. **Collateral Requirements:** Consider requiring off-chain collateral for high-value groups
4. **Insurance:** Group insurance fund or third-party insurance for defaults
5. **Community Building:** Start with trusted communities, build reputation over time
6. **Dispute Resolution:** Clear off-chain process for handling conflicts

### Gas Cost Estimates (Approximate)
- Create group: ~5,000 microSTX
- Add member: ~3,000 microSTX per member
- Start first cycle: ~2,000 microSTX
- Deposit: ~4,000 microSTX (+ deposit amount)
- Claim payout: ~4,000 microSTX (deducted from payout)
- Creator override functions: ~2,000-3,000 microSTX