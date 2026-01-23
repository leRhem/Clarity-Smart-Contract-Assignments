# Assignment 4: Simple Escrow Contract

## Student Information
- Name: Rhema Joseph
- Date: January 9, 2026

## Contract Overview
This contract implements a trustless two-party escrow service where a buyer deposits STX to pay for goods/services from a seller. The contract holds the funds until the buyer either releases them to the seller (on successful delivery) or refunds themselves (if delivery fails). This protects both parties: the seller knows payment is secured, and the buyer retains control until satisfied.

## Assumptions Made
- Only the buyer can release funds or request refunds (seller has no control)
- Escrows cannot be deleted or cancelled by anyone except the buyer
- Once an escrow is completed or refunded, its state is permanent
- There is no dispute resolution mechanism - buyer has full discretion
- There is no time limit - escrows can remain pending indefinitely
- Buyer and seller must be different addresses (cannot escrow to yourself)
- No partial releases - must release the full escrowed amount
- Contract charges no fees (0% marketplace fee in this version)

## Design Decisions and Tradeoffs

### Decision 1: Buyer Has Complete Control
- **What I chose:** Only the buyer can call `release-funds` or `refund`
- **Why:** The buyer is the customer paying for a product/service. They should have final say on whether they're satisfied. Seller delivers first, then buyer releases payment.
- **Tradeoff:**
  - **Gained:** Strong buyer protection, prevents seller from taking funds prematurely
  - **Gave up:** Seller protection - malicious buyer could refuse to release even after delivery (requires off-chain trust or arbitration)

### Decision 2: Three-State Status System
- **What I chose:** STATUS-PENDING (u1), STATUS-COMPLETED (u2), STATUS-REFUNDED (u3)
- **Why:** Clear, unambiguous states that form a one-way state machine:
  ```
  PENDING → COMPLETED (cannot go back)
  PENDING → REFUNDED (cannot go back)
  ```
  Using constants instead of strings prevents typos and saves gas.
- **Tradeoff:**
  - **Gained:** Type safety, gas efficiency, clear state transitions
  - **Gave up:** Human-readable status in map data (but we add helper function for this)

### Decision 3: No Time-Based Release
- **What I chose:** Did NOT implement auto-release after X blocks
- **Why:** Keeps contract simple. Time-based release is complex:
  - Who triggers it? (Costs gas)
  - What if seller never delivers but time expires?
  - Different transactions need different timelines
- **Tradeoff:**
  - **Gained:** Simplicity, flexibility (works for instant or month-long deliveries)
  - **Gave up:** Automatic dispute resolution, protection against buyer who disappears

### Decision 4: Using `merge` for Status Updates
- **What I chose:** `(map-set escrows id (merge escrow {status: NEW-STATUS}))`
- **Why:** Preserves all other escrow fields (buyer, seller, amount, created-at) while only updating status. Cleaner than reconstructing the entire map entry.
- **Tradeoff:**
  - **Gained:** Code clarity, less repetition, easier to maintain
  - **Gave up:** Tiny bit more gas than explicit reconstruction (negligible)

### Decision 5: Preventing Self-Escrow
- **What I chose:** Added validation `(not (is-eq tx-sender seller))`
- **Why:** Escrow makes no sense if buyer and seller are the same person. This prevents accidents and potential exploits.
- **Tradeoff:**
  - **Gained:** Prevents logical errors, saves users from wasting gas
  - **Gave up:** Edge case flexibility (someone might want to test with same address, but they can use different wallets)

### Decision 6: No Marketplace Fee (Yet)
- **What I chose:** Transfer full amount to seller, no % taken by contract
- **Why:** Assignment spec mentions this as "bonus challenge." Starting simple. Fee logic adds complexity in calculation and splitting payments.
- **Tradeoff:**
  - **Gained:** Simplicity, easy to understand and test
  - **Gave up:** Revenue model for marketplace operator (can add later)

## How to Use This Contract

### Function: create-escrow
- **Purpose:** Buyer creates an escrow and deposits STX
- **Parameters:** 
  - `seller`: principal - The seller's address who will receive payment
  - `amount`: uint - Amount of micro-STX to escrow
- **Returns:** `(ok escrow-id)` with the newly created escrow's ID
- **Errors:**
  - `(err u404)` - Amount must be > 0, or buyer and seller cannot be same
  - `(err u403)` - STX transfer failed
- **Example:**
```clarity
;; Buyer creates escrow for 10 STX to seller
(contract-call? .escrow create-escrow 
    'ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC 
    u10000000)
;; Returns: (ok u1) - Escrow #1 created
```

### Function: release-funds
- **Purpose:** Buyer releases escrowed funds to seller (successful delivery)
- **Parameters:** 
  - `escrow-id`: uint - The escrow to release
- **Returns:** `(ok true)` on success
- **Errors:**
  - `(err u401)` - Escrow not found
  - `(err u400)` - Caller is not the buyer
  - `(err u402)` - Escrow is not pending (already completed or refunded)
  - `(err u403)` - STX transfer failed
- **Example:**
```clarity
;; Buyer releases payment after receiving goods
(contract-call? .escrow release-funds u1)
;; Seller receives the STX, escrow status becomes COMPLETED
```

### Function: refund
- **Purpose:** Buyer cancels escrow and gets their money back
- **Parameters:** 
  - `escrow-id`: uint - The escrow to refund
- **Returns:** `(ok true)` on success
- **Errors:**
  - `(err u401)` - Escrow not found
  - `(err u400)` - Caller is not the buyer
  - `(err u402)` - Escrow is not pending
  - `(err u403)` - STX transfer failed
- **Example:**
```clarity
;; Buyer cancels and gets refund (seller didn't deliver)
(contract-call? .escrow refund u1)
;; Buyer receives their STX back, escrow status becomes REFUNDED
```

### Function: get-escrow
- **Purpose:** Retrieve all details about an escrow
- **Parameters:** 
  - `escrow-id`: uint - The escrow to look up
- **Returns:** `(some {...})` with all escrow data, or `none` if not found
- **Example:**
```clarity
(contract-call? .escrow get-escrow u1)
;; Returns: (some {
;;   buyer: 'ST1...,
;;   seller: 'ST2...,
;;   amount: u10000000,
;;   status: u1,
;;   created-at: u5000
;; })
```

### Function: get-escrow-count
- **Purpose:** Get total number of escrows ever created
- **Parameters:** None
- **Returns:** uint - Total count
- **Example:**
```clarity
(contract-call? .escrow get-escrow-count)
;; Returns: u25 - 25 escrows have been created
```

### Function: is-escrow-pending
- **Purpose:** Quick check if an escrow is still pending (not completed/refunded)
- **Parameters:** 
  - `escrow-id`: uint
- **Returns:** bool - true if pending, false otherwise
- **Example:**
```clarity
(contract-call? .escrow is-escrow-pending u1)
;; Returns: true or false
```

### Function: get-buyer
- **Purpose:** Get the buyer of a specific escrow
- **Parameters:** 
  - `escrow-id`: uint
- **Returns:** `(some principal)` or `none`
- **Example:**
```clarity
(contract-call? .escrow get-buyer u1)
;; Returns: (some 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### Function: get-seller
- **Purpose:** Get the seller of a specific escrow
- **Parameters:** 
  - `escrow-id`: uint
- **Returns:** `(some principal)` or `none`
- **Example:**
```clarity
(contract-call? .escrow get-seller u1)
;; Returns: (some 'ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC)
```

### Function: get-status-string
- **Purpose:** Get human-readable status (helper for UIs)
- **Parameters:** 
  - `escrow-id`: uint
- **Returns:** string - "pending", "completed", "refunded", or "not-found"
- **Example:**
```clarity
(contract-call? .escrow get-status-string u1)
;; Returns: "completed"
```

## Known Limitations
- No dispute resolution - buyer has absolute power
- No arbitration or third-party oversight
- No time limits - escrows can be pending forever
- No partial releases (all-or-nothing)
- No transfer of escrow ownership
- No seller protections against malicious buyers
- No marketplace fees (could be added as bonus)
- Cannot modify amount or seller after creation
- No batch operations (create/release multiple at once)
- No escrow history tracking for users

## Future Improvements
- **Arbitration system:** Add third-party arbitrator who can resolve disputes
- **Time-based auto-release:** Release to seller after X blocks if buyer doesn't respond
- **Milestone-based escrow:** Partial releases as seller completes milestones
- **Marketplace fees:** Take 1-5% fee for platform operator
- **Reputation system:** Track buyer/seller reliability scores
- **Multi-signature release:** Require multiple parties to approve release
- **Escrow amendments:** Allow parties to modify terms if both agree
- **Cancellation penalties:** Charge fee if buyer refunds frivolously
- **Insurance pool:** Collect small fee to build fund for disputed transactions
- **Event emissions:** Add print statements for indexing and notifications

## Testing Notes

### Test Case 1: Create Escrow Successfully
- Buyer created escrow with 5 STX to seller address
- Verified returned `(ok u1)` for first escrow
- Verified buyer's balance decreased by 5 STX
- Verified contract holds 5 STX
- Verified escrow data stored correctly with STATUS-PENDING
- ✅ PASSED

### Test Case 2: Release Funds to Seller
- Buyer created escrow
- Buyer called release-funds
- Verified seller received full amount
- Verified escrow status changed to STATUS-COMPLETED (u2)
- Verified contract balance decreased
- ✅ PASSED

### Test Case 3: Buyer Refunds
- Buyer created escrow
- Buyer called refund
- Verified buyer received their money back
- Verified escrow status changed to STATUS-REFUNDED (u3)
- ✅ PASSED

### Test Case 4: Non-Buyer Cannot Release
- Buyer created escrow
- Seller (different address) attempted to call release-funds
- Verified returned ERR-NOT-BUYER (u400)
- Verified funds remained in contract
- ✅ PASSED

### Test Case 5: Cannot Act on Completed Escrow
- Buyer created and released escrow (status COMPLETED)
- Buyer attempted to call release-funds again
- Verified returned ERR-NOT-PENDING (u402)
- Attempted to call refund
- Verified also returned ERR-NOT-PENDING
- ✅ PASSED

### Test Case 6: Cannot Act on Refunded Escrow
- Buyer created and refunded escrow (status REFUNDED)
- Buyer attempted to release funds
- Verified returned ERR-NOT-PENDING
- ✅ PASSED

### Test Case 7: Multiple Concurrent Escrows
- Created 3 escrows between different buyer/seller pairs
- Verified each tracked independently
- Released escrow #1, refunded escrow #2, left escrow #3 pending
- Verified correct states and balances for all
- ✅ PASSED

### Test Case 8: Zero Amount Rejected
- Attempted to create escrow with u0 amount
- Verified returned ERR-INVALID-AMOUNT (u404)
- ✅ PASSED

### Test Case 9: Self-Escrow Rejected
- Attempted to create escrow where buyer and seller are same address
- Verified returned ERR-INVALID-AMOUNT (u404)
- ✅ PASSED

### Test Case 10: Query Functions Work
- Created escrow
- Verified get-buyer returns correct principal
- Verified get-seller returns correct principal
- Verified is-escrow-pending returns true initially
- After release, verified is-escrow-pending returns false
- Verified get-status-string returns correct strings
- ✅ PASSED

## Security Considerations

### Implemented Protections:
- ✅ Authorization checks - only buyer can act
- ✅ State machine enforcement - cannot reverse completed/refunded states
- ✅ Atomic operations - fund transfer and state update happen together
- ✅ Self-escrow prevention - buyer and seller must differ
- ✅ Amount validation - cannot create zero-amount escrow
- ✅ Existence checks - cannot act on non-existent escrows

### Attack Scenarios (Mitigated):
- ❌ **Reentrancy:** Not possible in Clarity
- ❌ **Double-spending:** State changes prevent acting twice
- ❌ **Unauthorized release:** Only buyer can release
- ⚠️ **Malicious buyer:** Buyer could refuse to release even after delivery
  - Mitigation: Use reputation system, arbitration, or time-based auto-release
- ⚠️ **Seller never delivers:** Buyer gets stuck with pending escrow
  - Mitigation: Buyer can always refund

### Recommended Enhancements:
1. Add time-based auto-release (if buyer doesn't act in X blocks, auto-release to seller)
2. Implement reputation scoring
3. Add arbitrator role for disputes
4. Consider insurance/bonding for high-value escrows

## Comparison to Real-World Escrow Services

**Traditional Escrow (e.g., Escrow.com):**
- Third party holds funds
- Dispute resolution included
- Charges 3-5% fees
- Can take days/weeks

**This Smart Contract:**
- Contract holds funds (trustless)
- No built-in dispute resolution (buyer decides)
- No fees (currently)
- Instant settlement

**Use Cases:**
- ✅ Small transactions between semi-trusted parties
- ✅ Digital goods delivery (provable on-chain)
- ✅ Service payments with clear deliverables
- ❌ High-value transactions without arbitration
- ❌ Complex multi-party deals