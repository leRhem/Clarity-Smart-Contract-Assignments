;; ============================================================================
;; COOPERATIVE SAVINGS (ROSCA) - CLARITY SMART CONTRACT
;; ============================================================================
;; This is a Rotating Savings and Credit Association AKA Adashi implemented on Stacks blockchain
;; Monthly deposits 
;; ============================================================================

;; ============================================================================
;; CONSTANTS - Error Codes
;; ============================================================================

(define-constant ERR_AUTH (err u300))
(define-constant ERR_NOT_YOUR_TURN (err u301))
(define-constant ERR_TRANSFER_FAILED (err u302))
(define-constant ERR_NO_BALANCE (err u303))
(define-constant ERR_EMPTY_NAME (err u304))
(define-constant ERR_MAX_MEMBERS (err u305))
(define-constant ERR_GROUP_NOT_FOUND (err u306))
(define-constant ERR_ALREADY_MEMBER (err u307))
(define-constant ERR_NOT_MEMBER (err u308))
(define-constant ERR_ALREADY_PAID (err u309))
(define-constant ERR_NOT_TIME_YET (err u310))
(define-constant ERR_GRACE_PERIOD_ENDED (err u311))
(define-constant ERR_INSUFFICIENT_CONTRIBUTIONS (err u312))
(define-constant ERR_INVALID_PAYOUT_POSITION (err u313))
(define-constant ERR_ALREADY_RECEIVED_PAYOUT (err u314))
(define-constant ERR_GROUP_COMPLETED (err u315))
(define-constant ERR_NO_DEPOSIT_ENTERED (err u316))

;; ============================================================================
;; CONSTANTS - Status Codes
;; ============================================================================

(define-constant STATUS_ACTIVE u1)
(define-constant STATUS_COMPLETED u2)
(define-constant STATUS_PAUSED u3)

;; Grace period (10 days = 1440 blocks)
(define-constant GRACE_PERIOD_BLOCKS u1440)

;; ============================================================================
;; DATA STRUCTURES
;; ============================================================================

;; Main group information
(define-map groups
  { group_id: (string-utf8 50) }
  {
    creator: principal,
    name: (string-utf8 100),
    description: (optional (string-utf8 256)),
    deposit_per_member: uint,
    cycle_duration_blocks: uint,
    max_members: uint,
    members_count: uint,
    current_cycle: uint,
    cycle_start_block: uint,
    status: uint,
    total_pool_balance: uint,
    created_at: uint
  }
)

;; Member information
(define-map group_members
  { 
    group_id: (string-utf8 50),
    member_address: principal
  }
  {
    member_name: (string-utf8 100),
    payout_position: uint,
    has_received_payout: bool,
    joined_at: uint
  }
)

;; Track contributions per member per cycle
(define-map contributions
  {
    group_id: (string-utf8 50),
    member_address: principal,
    cycle: uint
  }
  {
    amount: uint,
    paid_at_block: uint,
    is_paid: bool
  }
)


;; ============================================================================
;; HELPER FUNCTIONS for code reusability
;; ============================================================================

(define-private (is-creator (group_id (string-utf8 50)) (caller principal))
  (match (map-get? groups { group_id: group_id })
    group-data (is-eq caller (get creator group-data))
    false
  )
)

(define-private (is-member (group_id (string-utf8 50)) (caller principal))
  (is-some (map-get? group_members { group_id: group_id, member_address: caller }))
)

(define-private (has-paid-current-cycle (group_id (string-utf8 50)) (member principal) (cycle uint))
  (match (map-get? contributions { group_id: group_id, member_address: member, cycle: cycle })
    contribution-data (get is_paid contribution-data)
    false
  )
)

(define-private (get-current-cycle-deadline (group_id (string-utf8 50)))
  (match (map-get? groups { group_id: group_id })
    group-data 
      (+ 
        (get cycle_start_block group-data)
        (* (get current_cycle group-data) (get cycle_duration_blocks group-data))
      )
    u0
  )
)

(define-private (get-grace-period-deadline (group_id (string-utf8 50)))
  (+ (get-current-cycle-deadline group_id) GRACE_PERIOD_BLOCKS)
)



;; ============================================================================
;; PUBLIC FUNCTIONS
;; ============================================================================

;; Create a new cooperative savings group
(define-public (create-group
  (group_id (string-utf8 50))
  (name (string-utf8 100))
  (description (optional (string-utf8 256)))
  (deposit_per_member uint)
  (cycle_duration_blocks uint)
  (max_members uint)
)
  (let
    (
      (creator tx-sender)
    )
    ;; Validations
    (asserts! (> (len name) u0) ERR_EMPTY_NAME)
    (asserts! (is-none (map-get? groups { group_id: group_id })) ERR_GROUP_NOT_FOUND)
    (asserts! (> deposit_per_member u0) ERR_NO_DEPOSIT_ENTERED)
    (asserts! (> cycle_duration_blocks u0) ERR_NOT_TIME_YET)
    (asserts! (> max_members u1) ERR_MAX_MEMBERS)

    ;; Create group
    (map-set groups
      { group_id: group_id }
      {
        creator: creator,
        name: name,
        description: description,
        deposit_per_member: deposit_per_member,
        cycle_duration_blocks: cycle_duration_blocks,
        max_members: max_members,
        members_count: u0,
        current_cycle: u0,
        cycle_start_block: stacks-block-height,
        status: STATUS_ACTIVE,
        total_pool_balance: u0,
        created_at: stacks-block-height
      }
    )
    
    (ok true)
  )
)

;; Add member to group which alos determines thier payout position
(define-public (add-member
  (group_id (string-utf8 50))
  (member_address principal)
  (member_name (string-utf8 100))
  (payout_position uint)
)
  (match (map-get? groups { group_id: group_id }) 
    group-data
    (begin
      ;; Validations
      (asserts! (is-eq tx-sender (get creator group-data)) ERR_AUTH)
      (asserts! 
        (is-none (map-get? group_members { group_id: group_id, member_address: member_address }))
        ERR_ALREADY_MEMBER
      )
      (asserts! 
        (< (get members_count group-data) (get max_members group-data))
        ERR_MAX_MEMBERS
      )
      (asserts! 
        (and (> payout_position u0) (<= payout_position (get max_members group-data)))
        ERR_INVALID_PAYOUT_POSITION
      )

      ;; Add member
      (map-set group_members
        { group_id: group_id, member_address: member_address }
        {
          member_name: member_name,
          payout_position: payout_position,
          has_received_payout: false,
          joined_at: stacks-block-height
        }
      )

      ;; Update group member count
      (map-set groups
        { group_id: group_id }
        (merge group-data { members_count: (+ (get members_count group-data) u1) })
      )

      (ok true)
    )
    ERR_GROUP_NOT_FOUND
  )
)

;; Member deposits their contribution for current cycle
(define-public (deposit (group_id (string-utf8 50)))
  (match (map-get? groups { group_id: group_id })
    group-data
    (let
      (
        (current_cycle (get current_cycle group-data))
        (deposit_amount (get deposit_per_member group-data))
        (grace_deadline (get-grace-period-deadline group_id))
      )
      ;; Validations
      (asserts! (is-member group_id tx-sender) ERR_NOT_MEMBER)
      (asserts! (> current_cycle u0) ERR_NOT_TIME_YET)
      (asserts! (is-eq (get status group-data) STATUS_ACTIVE) ERR_GROUP_COMPLETED)
      (asserts! 
        (not (has-paid-current-cycle group_id tx-sender current_cycle))
        ERR_ALREADY_PAID
      )
      (asserts! (<= stacks-block-height grace_deadline) ERR_GRACE_PERIOD_ENDED)

      ;; Transfer STX to contract
      (try! (stx-transfer? deposit_amount tx-sender (as-contract tx-sender)))

      ;; Record contribution
      (map-set contributions
        { group_id: group_id, member_address: tx-sender, cycle: current_cycle }
        {
          amount: deposit_amount,
          paid_at_block: stacks-block-height,
          is_paid: true
        }
      )

      ;; Update pool balance
      (map-set groups
        { group_id: group_id }
        (merge group-data 
          { 
            total_pool_balance: (+ (get total_pool_balance group-data) deposit_amount)
          }
        )
      )

      (ok true)
    )
    ERR_GROUP_NOT_FOUND
  )
)


;; Member claims their payout when it's their turn
(define-public (claim-payout (group_id (string-utf8 50)))
  (match (map-get? groups { group_id: group_id })
    group-data
    (match (map-get? group_members { group_id: group_id, member_address: tx-sender })
      member-data
      (let
        (
          (current_cycle (get current_cycle group-data))
          (expected_pool (+ u1 (* (get members_count group-data) (get deposit_per_member group-data))))
          (payout_amount (* (get members_count group-data) (get deposit_per_member group-data)))
        )
        ;; Validations
        (asserts! (is-eq (get status group-data) STATUS_ACTIVE) ERR_GROUP_COMPLETED)
        (asserts! 
          (is-eq (get payout_position member-data) current_cycle)
          ERR_NOT_YOUR_TURN
        )
        (asserts! 
          (not (get has_received_payout member-data))
          ERR_ALREADY_RECEIVED_PAYOUT
        )
        (asserts! 
          (>= (get total_pool_balance group-data) payout_amount)
          ERR_INSUFFICIENT_CONTRIBUTIONS
        )

        ;; Transfer payout to member
        (try! 
          (as-contract (stx-transfer? payout_amount tx-sender (unwrap-panic (some tx-sender))))
        )

        ;; Mark member as paid
        (map-set group_members
          { group_id: group_id, member_address: tx-sender }
          (merge member-data { has_received_payout: true })
        )

        ;; Update group state
        (let
          (
            (new_balance (- (get total_pool_balance group-data) payout_amount))
            (next_cycle (+ current_cycle u1))
            (is_completed (> next_cycle (get max_members group-data)))
          )
          (map-set groups
            { group_id: group_id }
            (merge group-data
              {
                total_pool_balance: new_balance,
                current_cycle: (if is_completed current_cycle next_cycle),
                status: (if is_completed STATUS_COMPLETED STATUS_ACTIVE)
              }
            )
          )
        )

        (ok true)
      )
      ERR_NOT_MEMBER
    )
    ERR_GROUP_NOT_FOUND
  )
)


;; Creator manually marks a contribution as paid (for off-chain payments/disputes)
(define-public (creator-mark-paid
  (group_id (string-utf8 50))
  (member_address principal)
  (cycle uint)
)
  (match (map-get? groups { group_id: group_id })
    group-data
    (begin
      ;; Validations
      (asserts! (is-creator group_id tx-sender) ERR_AUTH)
      (asserts! (is-member group_id member_address) ERR_NOT_MEMBER)

      ;; Mark as paid
      (map-set contributions
        { group_id: group_id, member_address: member_address, cycle: cycle }
        {
          amount: (get deposit_per_member group-data),
          paid_at_block: stacks-block-height,
          is_paid: true
        }
      )

      (ok true)
    )
    ERR_GROUP_NOT_FOUND
  )
)

;; Creator pauses/unpauses group (for dispute resolution)
(define-public (creator-set-status
  (group_id (string-utf8 50))
  (new_status uint)
)
  (match (map-get? groups { group_id: group_id })
    group-data
    (begin
      ;; Validations
      (asserts! (is-creator group_id tx-sender) ERR_AUTH)

      ;; Update status
      (map-set groups
        { group_id: group_id }
        (merge group-data { status: new_status })
      )

      (ok true)
    )
    ERR_GROUP_NOT_FOUND
  )
)

;; Creator advances to next cycle manually (dispute resolution)
(define-public (creator-advance-cycle (group_id (string-utf8 50)))
  (match (map-get? groups { group_id: group_id })
    group-data
    (begin
      ;; Validations
      (asserts! (is-creator group_id tx-sender) ERR_AUTH)

      ;; Advance cycle
      (map-set groups
        { group_id: group_id }
        (merge group-data 
          { 
            current_cycle: (+ (get current_cycle group-data) u1),
            cycle_start_block: stacks-block-height
          }
        )
      )

      (ok true)
    )
    ERR_GROUP_NOT_FOUND
  )
)


;; ============================================================================
;; READ-ONLY FUNCTIONS
;; ============================================================================

(define-read-only (get-group (group_id (string-utf8 50)))
  (map-get? groups { group_id: group_id })
)

(define-read-only (get-member 
  (group_id (string-utf8 50))
  (member_address principal)
)
  (map-get? group_members { group_id: group_id, member_address: member_address })
)

(define-read-only (get-contribution
  (group_id (string-utf8 50))
  (member_address principal)
  (cycle uint)
)
  (map-get? contributions { group_id: group_id, member_address: member_address, cycle: cycle })
)

(define-read-only (check-payment-window (group_id (string-utf8 50)))
  (let
    (
      (cycle_deadline (get-current-cycle-deadline group_id))
      (grace_deadline (get-grace-period-deadline group_id))
    )
    {
      current_block: stacks-block-height,
      cycle_deadline: cycle_deadline,
      grace_deadline: grace_deadline,
      is_within_cycle: (<= stacks-block-height cycle_deadline),
      is_within_grace: (and 
        (> stacks-block-height cycle_deadline)
        (<= stacks-block-height grace_deadline)
      ),
      is_expired: (> stacks-block-height grace_deadline)
    }
  )
)

(define-read-only (get-cycle-contributions 
  (group_id (string-utf8 50))
  (cycle uint)
)
  (ok {
    cycle: cycle,
    note: "Use get-contribution for specific member-cycle pairs"
  })
)
