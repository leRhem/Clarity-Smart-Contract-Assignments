;; ============================================================================
;; TIME-LOCKED WALLET CONTRACT - COMPLETE IMPLEMENTATION
;; ============================================================================
;; This contract allows users to deposit STX with a time lock.
;; Funds cannot be withdrawn until the specified block height is reached.
;; ============================================================================

;; DATA MAPS
;; -----------------------------------------------------------------------------

(define-map balances principal uint)

(define-map unlock-heights principal uint)

;; DATA VARIABLES
;; -----------------------------------------------------------------------------

(define-data-var total-locked uint u0)

;; ERROR CONSTANTS
;; -----------------------------------------------------------------------------

(define-constant ERR-NOTHING-TO-WITHDRAW (err u300))
(define-constant ERR-STILL-LOCKED (err u301))
(define-constant ERR-TRANSFER-FAILED (err u302))
(define-constant ERR-NO-BALANCE (err u303))
(define-constant ERR-INVALID-AMOUNT (err u304))

;; ============================================================================
;; PUBLIC FUNCTIONS
;; ============================================================================

;; DEPOSIT FUNCTION
;; -----------------------------------------------------------------------------
;; Allows users to deposit STX with a lock period
;; @param amount: Amount of micro-STX to deposit (1 STX = 1,000,000 micro-STX)
;; @param lock-blocks: Number of blocks to lock funds for
;; @returns (ok true) on success
;; -----------------------------------------------------------------------------
(define-public (deposit (amount uint) (lock-blocks uint))
    (let
        (
            (unlock-height (+ stacks-block-height lock-blocks))
            (current-balance (default-to u0 (map-get? balances tx-sender)))
            (new-balance (+ current-balance amount))
        )
        
        ;; Amount must be greater than zero
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        
        ;; Transfer STX from user to this contract)
        (unwrap! 
            (stx-transfer? amount tx-sender (as-contract tx-sender))
            ERR-TRANSFER-FAILED
        )
        
        ;; Update user's balance in the map
        (map-set balances tx-sender new-balance)
        
        ;; Set or extend unlock height
        (match (map-get? unlock-heights tx-sender)
            existing-unlock-height
                (map-set unlock-heights tx-sender 
                    (if (> unlock-height existing-unlock-height)
                        unlock-height
                        existing-unlock-height
                    )
                )
            (map-set unlock-heights tx-sender unlock-height)
        )
        
        ;; Update total locked amount
        (var-set total-locked (+ (var-get total-locked) amount))
        
        (ok true)
    )
)

;; WITHDRAW FUNCTION
;; -----------------------------------------------------------------------------
;; Allows users to withdraw their locked STX after unlock time
;; @returns (ok amount-withdrawn) on success
;; -----------------------------------------------------------------------------
(define-public (withdraw)
    (let
        (
            (user-balance (default-to u0 (map-get? balances tx-sender)))
            (user-unlock-height (default-to u0 (map-get? unlock-heights tx-sender)))
        )
        
        ;; User must have a balance
        (asserts! (> user-balance u0) ERR-NO-BALANCE)
        
        ;; Current block must be >= unlock height
        (asserts! (>= stacks-block-height user-unlock-height) ERR-STILL-LOCKED)
        
        ;; Transfer STX from contract back to user
        (unwrap!
            (as-contract (stx-transfer? user-balance tx-sender contract-caller))
            ERR-TRANSFER-FAILED
        )
        
        ;; Clear user's balance
        (map-delete balances tx-sender)
        
        ;; Clear user's unlock height
        (map-delete unlock-heights tx-sender)
        
        ;; Update total locked amount
        (var-set total-locked (- (var-get total-locked) user-balance))
        
        ;; Return the amount withdrawn
        (ok user-balance)
    )
)

;; EXTEND-LOCK FUNCTION
;; -----------------------------------------------------------------------------
;; Allows users to extend their lock period (but not shorten it)
;; @param additional-blocks: Number of blocks to add to current unlock height
;; @returns (ok new-unlock-height) on success
;; -----------------------------------------------------------------------------
(define-public (extend-lock (additional-blocks uint))
    (let
        (
            (current-unlock (default-to u0 (map-get? unlock-heights tx-sender)))
            (new-unlock (+ current-unlock additional-blocks))
        )
        
        ;; User must have a balance (can't extend nothing)
        (asserts! 
            (> (default-to u0 (map-get? balances tx-sender)) u0)
            ERR-NO-BALANCE
        )
        
        ;; Update unlock height
        (map-set unlock-heights tx-sender new-unlock)
        
        ;; Return the new unlock height
        (ok new-unlock)
    )
)

;; GET-BALANCE
;; -----------------------------------------------------------------------------
;; Returns the locked balance for a specific user
;; @param user: The principal to check
;; @returns Balance amount (0 if no balance)
;; -----------------------------------------------------------------------------
(define-read-only (get-balance (user principal))
    (default-to u0 (map-get? balances user))
)

;; GET-UNLOCK-HEIGHT
;; -----------------------------------------------------------------------------
;; Returns the block height when a user's funds unlock
;; @param user: The principal to check
;; @returns Unlock block height (0 if no deposit)
;; -----------------------------------------------------------------------------
(define-read-only (get-unlock-height (user principal))
    (default-to u0 (map-get? unlock-heights user))
)

;; GET-TOTAL-LOCKED
;; -----------------------------------------------------------------------------
;; Returns total STX locked in the contract across all users
;; @returns Total locked amount
;; -----------------------------------------------------------------------------
(define-read-only (get-total-locked)
    (var-get total-locked)
)

;; IS-UNLOCKED
;; -----------------------------------------------------------------------------
;; Check if a user's funds are currently unlocked
;; @param user: The principal to check
;; @returns true if unlocked, false if still locked
;; -----------------------------------------------------------------------------
(define-read-only (is-unlocked (user principal))
    (let
        (
            (unlock-height (default-to u0 (map-get? unlock-heights user)))
        )
        (>= stacks-block-height unlock-height)
    )
)

;; BLOCKS-UNTIL-UNLOCK
;; -----------------------------------------------------------------------------
;; Calculate how many blocks until a user's funds unlock
;; @param user: The principal to check
;; @returns Number of blocks remaining (0 if already unlocked)
;; -----------------------------------------------------------------------------
(define-read-only (blocks-until-unlock (user principal))
    (let
        (
            (unlock-height (default-to u0 (map-get? unlock-heights user)))
        )
        (if (>= stacks-block-height unlock-height)
            u0
            (- unlock-height stacks-block-height)
        )
    )
)
