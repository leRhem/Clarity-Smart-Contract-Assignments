;; ============================================================================
;; SIMPLE ESCROW CONTRACT - COMPLETE IMPLEMENTATION
;; ============================================================================
;; Two-party escrow where buyer deposits STX, then either:
;; - Releases funds to seller (on successful delivery)
;; - Refunds themselves (if seller fails to deliver)
;; ============================================================================

;; DATA VARIABLES
(define-data-var escrow-count uint u0)

;; CONSTANTS - ESCROW STATUS
(define-constant STATUS-PENDING u1)
(define-constant STATUS-COMPLETED u2)
(define-constant STATUS-REFUNDED u3)

;; DATA MAPS
(define-map escrows 
    uint
    {
        buyer: principal,
        seller: principal,
        amount: uint,
        status: uint,
        created-at: uint
    }
)

;; ERROR CONSTANTS
(define-constant ERR-NOT-BUYER (err u400))
(define-constant ERR-NOT-FOUND (err u401))
(define-constant ERR-NOT-PENDING (err u402))
(define-constant ERR-TRANSFER-FAILED (err u403))
(define-constant ERR-INVALID-AMOUNT (err u404))

;; ============================================================================
;; PRIVATE HELPER FUNCTIONS
;; ============================================================================

;; IS-BUYER
;; -----------------------------------------------------------------------------
;; Check if the caller is the buyer of a specific escrow
;; @param escrow-id: The escrow to check
;; @param caller: The principal to verify
;; @returns true if caller is buyer, false otherwise
;; -----------------------------------------------------------------------------
(define-private (is-buyer (escrow-id uint) (caller principal))
    (match (map-get? escrows escrow-id)
        escrow 
        (is-eq caller (get buyer escrow))
        false
    )
)

;; ============================================================================
;; PUBLIC FUNCTIONS
;; ============================================================================

;; CREATE-ESCROW
;; -----------------------------------------------------------------------------
;; Buyer creates an escrow and deposits STX
;; The STX is held by the contract until buyer releases or refunds
;; @param seller: The seller's principal address
;; @param amount: Amount of STX to escrow (in micro-STX)
;; @returns (ok escrow-id) with the new escrow's ID
;; -----------------------------------------------------------------------------
(define-public (create-escrow (seller principal) (amount uint))
    (let
        (
            (escrow-id (+ (var-get escrow-count) u1))
        )
        
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        
        (asserts! (not (is-eq tx-sender seller)) ERR-INVALID-AMOUNT)
        
        ;; Transfer STX from buyer to this contract
        (unwrap! 
            (stx-transfer? amount tx-sender (as-contract tx-sender))
            ERR-TRANSFER-FAILED
        )
        
        (map-set escrows
            escrow-id
            {
                buyer: tx-sender,
                seller: seller,
                amount: amount,
                status: STATUS-PENDING,
                created-at: block-height
            }
        )
        
        (var-set escrow-count escrow-id)
        
        (ok escrow-id)
    )
)

;; RELEASE-FUNDS
;; -----------------------------------------------------------------------------
;; Buyer approves and releases escrowed funds to seller
;; This is called when buyer is satisfied with seller's delivery
;; @param escrow-id: The escrow to release
;; @returns (ok true) on success
;; -----------------------------------------------------------------------------
(define-public (release-funds (escrow-id uint))
    (let
        (
            (escrow (unwrap! (map-get? escrows escrow-id) ERR-NOT-FOUND))
            (buyer (get buyer escrow))
            (seller (get seller escrow))
            (amount (get amount escrow))
            (status (get status escrow))
        )
        
        (asserts! (is-eq tx-sender buyer) ERR-NOT-BUYER)
        
        (asserts! (is-eq status STATUS-PENDING) ERR-NOT-PENDING)
        
        ;; Transfer STX from contract to seller
        (unwrap!
            (as-contract (stx-transfer? amount tx-sender seller))
            ERR-TRANSFER-FAILED
        )
        
        ;; Update escrow status to COMPLETED
        (map-set escrows 
            escrow-id
            (merge escrow {status: STATUS-COMPLETED})
        )
        
        (ok true)
    )
)

;; REFUND
;; -----------------------------------------------------------------------------
;; Buyer cancels the escrow and gets their money back
;; This is called when seller fails to deliver or buyer changes mind
;; @param escrow-id: The escrow to refund
;; @returns (ok true) on success
;; -----------------------------------------------------------------------------
(define-public (refund (escrow-id uint))
    (let
        (
            (escrow (unwrap! (map-get? escrows escrow-id) ERR-NOT-FOUND))
            (buyer (get buyer escrow))
            (amount (get amount escrow))
            (status (get status escrow))
        )
        
        (asserts! (is-eq tx-sender buyer) ERR-NOT-BUYER)
        
        (asserts! (is-eq status STATUS-PENDING) ERR-NOT-PENDING)
        
        ;; Transfer STX from contract back to buyer
        (unwrap!
            (as-contract (stx-transfer? amount tx-sender buyer))
            ERR-TRANSFER-FAILED
        )
        
        (map-set escrows 
            escrow-id
            (merge escrow {status: STATUS-REFUNDED})
        )
        
        (ok true)
    )
)

;; ============================================================================
;; READ-ONLY FUNCTIONS
;; ============================================================================

;; GET-ESCROW
;; -----------------------------------------------------------------------------
;; Retrieves all details about a specific escrow
;; @param escrow-id: The escrow ID to look up
;; @returns (some {...}) with escrow data, or none if not found
;; -----------------------------------------------------------------------------
(define-read-only (get-escrow (escrow-id uint))
    (map-get? escrows escrow-id)
)

;; GET-ESCROW-COUNT
;; -----------------------------------------------------------------------------
;; Returns the total number of escrows created
;; @returns Total count
;; -----------------------------------------------------------------------------
(define-read-only (get-escrow-count)
    (var-get escrow-count)
)

;; IS-ESCROW-PENDING
;; -----------------------------------------------------------------------------
;; Check if an escrow is still in pending status
;; @param escrow-id: The escrow to check
;; @returns true if pending, false otherwise
;; -----------------------------------------------------------------------------
(define-read-only (is-escrow-pending (escrow-id uint))
    (match (map-get? escrows escrow-id)
        escrow (is-eq (get status escrow) STATUS-PENDING)
        false
    )
)

;; GET-BUYER
;; -----------------------------------------------------------------------------
;; Get the buyer of a specific escrow
;; @param escrow-id: The escrow to check
;; @returns (some buyer-principal) or none
;; -----------------------------------------------------------------------------
(define-read-only (get-buyer (escrow-id uint))
    (match (map-get? escrows escrow-id)
        escrow (some (get buyer escrow))
        none
    )
)

;; GET-SELLER
;; -----------------------------------------------------------------------------
;; Get the seller of a specific escrow
;; @param escrow-id: The escrow to check
;; @returns (some seller-principal) or none
;; -----------------------------------------------------------------------------
(define-read-only (get-seller (escrow-id uint))
    (match (map-get? escrows escrow-id)
        escrow (some (get seller escrow))
        none
    )
)

;; GET-STATUS-STRING
;; -----------------------------------------------------------------------------
;; Returns human-readable status (helper for debugging/UIs)
;; @param escrow-id: The escrow to check
;; @returns Status as string
;; -----------------------------------------------------------------------------
(define-read-only (get-status-string (escrow-id uint))
    (match (map-get? escrows escrow-id)
        escrow 
            (if (is-eq (get status escrow) STATUS-PENDING)
                "pending"
                (if (is-eq (get status escrow) STATUS-COMPLETED)
                    "completed"
                    "refunded"
                )
            )
        "not-found"
    )
)
