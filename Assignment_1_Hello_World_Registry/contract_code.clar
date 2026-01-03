;; Hello World Registry Contract
;; Users can store and retrieve personalized greeting messages

;; Data Maps
;; TODO: Define a map to store messages with principal as key
;; Hint: (define-map map-name {key-type} {value-type})

;; Data Maps
(define-map messages principal (string-utf8 500))

;; Error Constants
(define-constant ERR-EMPTY-MESSAGE (err u100))
(define-constant ERR-MESSAGE-NOT-FOUND (err u101))

;; Public Functions

;; Set or update a greeting message for the caller
(define-public (set-message (message (string-utf8 500)))
    (begin
        ;; Validation: Check message is not empty
        (asserts! (> (len message) u0) ERR-EMPTY-MESSAGE)

        ;; Store the message with tx-sender as key
        (map-set messages tx-sender message)

        (ok true)
    )
)

;; Delete the caller's message
(define-public (delete-message)
    (begin
        ;; Delete the message for tx-sender
        (map-delete messages tx-sender)

        (ok true)
    )
)

;; Read-only Functions

;; Get message for a specific principal
(define-read-only (get-message (user principal))
    ;; Retrieve and return the message for the given user
    (map-get? messages user)
)

;; Get the caller's own message
(define-read-only (get-my-message)
    ;; Call get-message with tx-sender
    (get-message tx-sender)
)