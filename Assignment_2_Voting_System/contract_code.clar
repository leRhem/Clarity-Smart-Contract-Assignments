;; Simple Voting System Contract
;; Create proposals and vote on them (one vote per user per proposal)

;; Data Variables
(define-data-var proposal-count uint u0)
;; Storage
(define-data-var counter-name uint u0)

;; Data Maps
;; TODO: Define map for proposal details
;; Should store: title, description, yes-votes, no-votes, end-height, creator
(define-map proposals 
    uint
    {
        title: (string-utf8 100),
        description: (string-utf8 500),
        yes-votes: uint,
        no-votes: uint,
        end-height: uint,
        creator: principal
    }
)

;; TODO: Define map to track if a user has voted on a proposal
(define-map votes {proposal-id: uint, voter: principal} bool)

;; Error Constants
(define-constant ERR-NOT-FOUND (err u200))
(define-constant ERR-VOTING-CLOSED (err u201))
(define-constant ERR-ALREADY-VOTED (err u202))
(define-constant ERR-INVALID-PROPOSAL (err u203))

;; Public Functions

;; Create a new proposal
(define-public (create-proposal 
    (title (string-utf8 100))
    (description (string-utf8 500))
    (duration uint))
    (let
        (
            (proposal-id (+ (var-get proposal-count) u1))
            ;; Calculated end-height (current block-height + duration)
            (end-height (+ stacks-block-height duration))
        )
        ;; Stored the proposal data in the proposals map
        (map-set proposals
            proposal-id
            {
                title: title,
                description: description,
                yes-votes: u0,
                no-votes: u0,
                end-height: end-height,
                creator: tx-sender          
            }
        )
        
        (var-set proposal-count proposal-id)
        (ok proposal-id)
    )
)

;; Vote on a proposal
;; @param proposal-id: the proposal to vote on
;; @param vote-for: true for yes, false for no
;; @returns (ok true) on success
(define-public (vote (proposal-id uint) (vote-for bool))
    (let
        (
            ;; Get the proposal data
            (proposal (unwrap! (map-get? proposals proposal-id) ERR-NOT-FOUND))
            (end-height (get end-height proposal))
            (current-yes (get yes-votes proposal))
            (current-no (get no-votes proposal))
        )

        ;; CHECK 1: If the voting is still open
        (asserts! (< stacks-block-height end-height) ERR-VOTING-CLOSED)

        ;; CHECK 2: Has this person already voted?
        (asserts! (is-none (has-voted proposal-id tx-sender)) ERR-ALREADY-VOTED)

        ;; Record their vote, if they haven't voted yet
        (map-set votes {proposal-id: proposal-id, voter: tx-sender} true)
        
        ;; Updated the vote counts in the proposal
        (map-set proposals 
            proposal-id
            (merge proposal 
                {
                    yes-votes: (if vote-for (+ current-yes u1) current-yes), 
                    no-votes: (if vote-for current-no (+ current-no u1))
                }
            )
        )
        
        (ok true)
    )
)

;; Read-only Functions

;; Get proposal details
;; @param proposal-id: the proposal to look up
;; @returns proposal data or none
(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals proposal-id)
)

;; Check if a user has voted on a proposal
;; @param proposal-id: the proposal to check
;; @param user: the user to check
;; @returns true if voted, false otherwise
(define-read-only (has-voted (proposal-id uint) (user principal))
    (map-get? votes {proposal-id: proposal-id, voter: user})
)

;; Get vote totals for a proposal
;; @param proposal-id: the proposal to check
;; @returns {yes-votes: uint, no-votes: uint}
(define-read-only (get-vote-totals (proposal-id uint))
    (match (map-get? proposals proposal-id)
        proposal {
            yes-votes: (get yes-votes proposal),
            no-votes: (get no-votes proposal)
        }
        {yes-votes: u0, no-votes: u0}
    )
)