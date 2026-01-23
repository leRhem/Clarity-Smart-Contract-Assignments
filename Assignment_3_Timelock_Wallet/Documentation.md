# Assignment 3: Time-locked Wallet

## Student Information
- Name: Rhema Joseph
- Date: January 9, 2026

## Contract Overview
This contract implements a time-locked savings wallet where users can deposit STX tokens that cannot be withdrawn until a specified number of blocks have passed. This simulates vesting schedules, savings accounts with withdrawal penalties, or escrow with time-based release conditions. The contract safely holds user funds and enforces temporal access control using blockchain block heights.

## Assumptions Made
- Multiple deposits by the same user are allowed and balances accumulate
- When making additional deposits, the unlock time extends to the LATER of existing or new unlock height
- Withdrawals are all-or-nothing (must withdraw entire balance)
- Block height is monotonically increasing (blocks never go backwards)
- Once withdrawn, all data for that user is cleared (fresh start for next deposit)
- 1 STX = 1,000,000 micro-STX (standard Stacks denomination)
- No minimum or maximum deposit amounts (though zero is rejected)
- Contract never takes ownership - acts purely as escrow

## Design Decisions and Tradeoffs

### Decision 1: Using `block-height` Instead of `stacks-block-height`
- **What I chose:** Used `block-height` throughout the contract
- **Why:** Modern Clarity (post-2.0) uses `block-height` as the standard. `stacks-block-height` is deprecated and may not work in newer environments.
- **Tradeoff:**
  - **Gained:** Future compatibility, cleaner syntax, follows current best practices
  - **Gave up:** Backwards compatibility with very old Clarity versions (pre-2.0)

### Decision 2: Accumulating Deposits with Extended Lock Times
- **What I chose:** Allow multiple deposits, taking the LATER unlock time when adding to existing balance
- **Why:** Without this rule, a user could:
  1. Deposit 1000 STX locked for 1 year
  2. Immediately deposit 1 STX locked for 1 day
  3. Withdraw all 1001 STX after 1 day (defeating the original 1-year lock)
- **Tradeoff:**
  - **Gained:** Security - prevents lock-time manipulation, ensures time-lock integrity
  - **Gave up:** Flexibility - users cannot have separate deposits with different unlock times

### Decision 3: All-or-Nothing Withdrawal
- **What I chose:** Users must withdraw their entire balance in one transaction
- **Why:** Simplifies contract logic and prevents edge cases around partial unlock times. Clearer UX - users know exactly when ALL their funds become available.
- **Tradeoff:**
  - **Gained:** Simplicity, gas efficiency, no complex partial-withdrawal logic
  - **Gave up:** Flexibility - cannot withdraw portions as they unlock incrementally

### Decision 4: Using `contract-caller` in Withdraw
- **What I chose:** Transfer to `contract-caller` instead of `tx-sender` in the withdraw function
- **Why:** When inside `(as-contract ...)` context, `tx-sender` becomes the contract address. `contract-caller` preserves the original caller's address across context switches.
- **Tradeoff:**
  - **Gained:** Correct recipient address, prevents funds being locked in contract
  - **Gave up:** Slight additional complexity in understanding (but this is the correct pattern)

### Decision 5: Clearing All User Data on Withdrawal
- **What I chose:** Delete both balance and unlock-height maps when user withdraws
- **Why:** Clean state - prevents confusion about "zero balance but unlock-height exists". Saves storage space. User gets fresh start for next deposit.
- **Tradeoff:**
  - **Gained:** Clean state management, reduced storage costs, simpler queries
  - **Gave up:** Historical data - cannot see when user previously withdrew

### Decision 6: No Emergency Withdrawal Function
- **What I chose:** Did NOT implement early withdrawal with penalty
- **Why:** This is a HARD time-lock. Adding escape hatches defeats the purpose and introduces attack vectors. If users need flexibility, they should lock for shorter periods.
- **Tradeoff:**
  - **Gained:** True time-lock guarantee, simpler contract, fewer attack surfaces
  - **Gave up:** User convenience in emergencies (but this is intentional - commitment device)

## How to Use This Contract

### Function: deposit
- **Purpose:** Lock STX tokens until a future block height
- **Parameters:** 
  - `amount`: uint - Amount in micro-STX (1 STX = 1,000,000 micro-STX)
  - `lock-blocks`: uint - Number of blocks to lock for (~144 blocks = 1 day)
- **Returns:** `(ok true)` on success
- **Errors:**
  - `(err u304)` - Amount must be greater than zero
  - `(err u302)` - STX transfer failed
- **Example:**
```clarity
;; Lock 5 STX for approximately 7 days (1008 blocks)
(contract-call? .timelock-wallet deposit u5000000 u1008)
```

### Function: withdraw
- **Purpose:** Withdraw all locked STX after unlock time has passed
- **Parameters:** None (withdraws caller's entire balance)
- **Returns:** `(ok amount)` where amount is the withdrawn balance
- **Errors:**
  - `(err u303)` - No balance to withdraw
  - `(err u301)` - Still locked (unlock block height not yet reached)
  - `(err u302)` - STX transfer failed
- **Example:**
```clarity
;; Withdraw all available funds
(contract-call? .timelock-wallet withdraw)
;; Returns: (ok u5000000) - withdrew 5 STX
```

### Function: extend-lock
- **Purpose:** Add more blocks to the current lock period (cannot shorten)
- **Parameters:** 
  - `additional-blocks`: uint - Blocks to add to current unlock height
- **Returns:** `(ok new-unlock-height)` with the updated unlock block
- **Errors:**
  - `(err u303)` - No balance exists to extend
- **Example:**
```clarity
;; Add 144 more blocks (~1 day) to lock period
(contract-call? .timelock-wallet extend-lock u144)
;; Returns: (ok u12500) - new unlock height
```

### Function: get-balance
- **Purpose:** Check locked balance for any user
- **Parameters:** 
  - `user`: principal - Address to check
- **Returns:** uint - Balance in micro-STX (0 if none)
- **Example:**
```clarity
(contract-call? .timelock-wallet get-balance 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
;; Returns: u5000000
```

### Function: get-unlock-height
- **Purpose:** Check when a user's funds unlock
- **Parameters:** 
  - `user`: principal - Address to check
- **Returns:** uint - Block height when funds unlock (0 if no deposit)
- **Example:**
```clarity
(contract-call? .timelock-wallet get-unlock-height 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
;; Returns: u12500 - unlocks at block 12,500
```

### Function: get-total-locked
- **Purpose:** Get total STX locked across all users
- **Parameters:** None
- **Returns:** uint - Total locked in micro-STX
- **Example:**
```clarity
(contract-call? .timelock-wallet get-total-locked)
;; Returns: u50000000 - 50 STX total locked
```

### Function: is-unlocked
- **Purpose:** Check if a user's funds are currently unlocked
- **Parameters:** 
  - `user`: principal - Address to check
- **Returns:** bool - true if unlocked, false if still locked
- **Example:**
```clarity
(contract-call? .timelock-wallet is-unlocked 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
;; Returns: true or false
```

### Function: blocks-until-unlock
- **Purpose:** Calculate remaining blocks until unlock
- **Parameters:** 
  - `user`: principal - Address to check
- **Returns:** uint - Blocks remaining (0 if already unlocked)
- **Example:**
```clarity
(contract-call? .timelock-wallet blocks-until-unlock 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
;; Returns: u500 - 500 blocks remaining (~3.5 days)
```

## Future Improvements
- **Partial withdrawals:** Allow users to withdraw portions of balance as they unlock
- **Multiple time-locked buckets:** Each user could have separate deposits with independent unlock times
- **Beneficiary designation:** Allow depositor to specify who can withdraw (estate planning)
- **Interest/yield:** Integrate with DeFi protocols to earn yield on locked funds
- **NFT receipt tokens:** Issue NFTs representing locked deposits (transferable claims)
- **Streaming unlocks:** Linear vesting where funds unlock gradually block-by-block
- **Event emissions:** Add print statements for deposit/withdraw events for indexing
- **Emergency withdrawal with penalty:** Configurable early access with % fee
- **Batch operations:** Deposit to multiple contracts or withdraw from multiple locks at once
- **Time-weighted voting:** Use locked balance for governance (longer locks = more voting power)

## Testing Notes

### Test Case 1: Basic Deposit
- Deposited 1,000,000 micro-STX (1 STX) with 100 block lock
- Verified balance shows u1000000
- Verified unlock-height = current block + 100
- Verified total-locked increased by deposit amount
- ✅ PASSED

### Test Case 2: Successful Withdrawal After Lock Period
- Deposited funds with 10 block lock
- Advanced blockchain or waited 10+ blocks
- Called withdraw successfully
- Verified received correct amount
- Verified balance and unlock-height cleared
- Verified total-locked decreased
- ✅ PASSED

### Test Case 3: Early Withdrawal Rejected
- Deposited funds with 1000 block lock
- Attempted immediate withdrawal
- Verified returned ERR-STILL-LOCKED (u301)
- Verified funds remained in contract
- ✅ PASSED

### Test Case 4: Multiple Deposits Accumulate
- Made first deposit of 1 STX with 100 block lock
- Made second deposit of 2 STX with 50 block lock
- Verified total balance = 3 STX
- Verified unlock-height remained at later time (100 blocks from first deposit)
- ✅ PASSED

### Test Case 5: Extend Lock Period
- Deposited with 100 block lock
- Called extend-lock with 50 additional blocks
- Verified new unlock-height = original + 50
- ✅ PASSED

### Test Case 6: Zero Amount Rejected
- Attempted deposit with amount u0
- Verified returned ERR-INVALID-AMOUNT (u304)
- ✅ PASSED

### Test Case 7: No Balance Withdrawal Rejected
- Called withdraw without any deposit
- Verified returned ERR-NO-BALANCE (u303)
- ✅ PASSED

### Test Case 8: Multiple Users Independent Balances
- User A deposited 5 STX
- User B deposited 3 STX
- Verified each user's balance tracked separately
- Verified total-locked = 8 STX
- User A withdrew - User B's balance unaffected
- ✅ PASSED

### Test Case 9: Helper Functions Accuracy
- Verified is-unlocked returns false before unlock, true after
- Verified blocks-until-unlock counts down correctly
- Verified returns u0 when already unlocked
- ✅ PASSED

## Security Considerations

### Implemented Protections:
- ✅ Atomic operations - deposit and withdrawal cannot be partially completed
- ✅ Access control - only depositor can withdraw their funds
- ✅ Time-lock enforcement - mathematically impossible to withdraw early
- ✅ Balance validation - cannot withdraw more than deposited
- ✅ Lock-time manipulation prevention - additional deposits cannot shorten lock
- ✅ Clean state on withdrawal - no orphaned data
- ✅ Underflow protection - total-locked decreases safely


## Block Time Reference Guide

**Stacks Block Times (~10 minutes per block):**
- 1 hour ≈ 6 blocks
- 1 day ≈ 144 blocks
- 1 week ≈ 1,008 blocks
- 1 month ≈ 4,320 blocks
- 1 year ≈ 52,560 blocks

**Example Lock Periods:**
```clarity
;; Lock for 1 day
(deposit u1000000 u144)

;; Lock for 1 week
(deposit u5000000 u1008)

;; Lock for 1 month
(deposit u10000000 u4320)
```