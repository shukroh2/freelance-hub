;; freelance-hub.clar
;; A decentralized freelance job marketplace with escrow and reputation system.

(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_ASSIGNED (err u102))
(define-constant ERR_ALREADY_COMPLETED (err u103))
(define-constant ERR_NO_FUNDS (err u104))
(define-constant ERR_NOT_ASSIGNED (err u105))

;; === DATA STRUCTURES ===

;; Job listings
(define-map jobs
  { id: uint }
  {
    client: principal,
    freelancer: (optional principal),
    title: (string-ascii 64),
    description: (string-ascii 256),
    price: uint,
    status: (string-ascii 16)
  }
)

;; Reputation scores
(define-map reputation
  { user: principal }
  { score: uint })

;; === VARIABLES ===
(define-data-var total-jobs uint u0)
(define-data-var admin principal tx-sender)

;; === ADMIN ===
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok new-admin)
  )
)

;; === JOB CREATION ===

(define-public (create-job (title (string-ascii 64)) (description (string-ascii 256)) (price uint))
  (let ((job-id (+ u1 (var-get total-jobs))))
    (begin
      (asserts! (> price u0) ERR_NO_FUNDS)
      (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
      (map-set jobs { id: job-id }
        {
          client: tx-sender,
          freelancer: none,
          title: title,
          description: description,
          price: price,
          status: "open"
        })
      (var-set total-jobs job-id)
      (ok job-id)
    )
  )
)

;; === APPLY FOR JOB ===

(define-public (apply-for-job (job-id uint))
  (let ((job (map-get? jobs { id: job-id })))
    (match job
      job-data
      (if (is-eq (get status job-data) "open")
          (begin
            (map-set jobs { id: job-id }
              (merge job-data
                {
                  freelancer: (some tx-sender),
                  status: "assigned"
                }))
            (ok "Job assigned to you")
          )
          ERR_ALREADY_ASSIGNED
      )
      ERR_NOT_FOUND
    )
  )
)

;; === SUBMIT WORK ===

(define-public (submit-work (job-id uint))
  (let ((job (map-get? jobs { id: job-id })))
    (match job
      job-data
      (if (and (is-some (get freelancer job-data)) (is-eq (get status job-data) "assigned"))
          (if (is-eq (unwrap! (get freelancer job-data) ERR_NOT_ASSIGNED) tx-sender)
              (begin
                (map-set jobs { id: job-id } (merge job-data { status: "submitted" }))
                (ok "Work submitted")
              )
              ERR_UNAUTHORIZED
          )
          ERR_NOT_ASSIGNED
      )
      ERR_NOT_FOUND
    )
  )
)

;; === CLIENT APPROVES WORK ===

(define-public (approve-work (job-id uint))
  (let ((job (map-get? jobs { id: job-id })))
    (match job
      job-data
      (if (and (is-eq (get client job-data) tx-sender)
               (is-eq (get status job-data) "submitted"))
          (let ((freelancer (unwrap! (get freelancer job-data) ERR_NOT_ASSIGNED)))
            (try! (stx-transfer? (get price job-data) (as-contract tx-sender) freelancer))
            (map-set jobs { id: job-id } (merge job-data { status: "completed" }))
            (begin
              (increment-reputation freelancer u10)
              (increment-reputation tx-sender u5)
              (ok "Payment released")
            )
          )
          ERR_UNAUTHORIZED
      )
      ERR_NOT_FOUND
    )
  )
)

;; === DISPUTE / REFUND ===

(define-public (refund-client (job-id uint))
  (let ((job (map-get? jobs { id: job-id })))
    (match job
      job-data
      (if (and (is-eq (get client job-data) tx-sender)
               (not (is-eq (get status job-data) "completed")))
          (begin
            (try! (stx-transfer? (get price job-data) (as-contract tx-sender) tx-sender))
            (map-set jobs { id: job-id } (merge job-data { status: "cancelled" }))
            (ok "Refund processed")
          )
          ERR_UNAUTHORIZED
      )
      ERR_NOT_FOUND
    )
  )
)

;; === INTERNAL REPUTATION HELPER ===

(define-private (increment-reputation (user principal) (points uint))
  (let ((current (default-to u0 (get score (map-get? reputation { user: user })))))
    (map-set reputation { user: user } { score: (+ current points) })
  )
)

;; === READ-ONLY FUNCTIONS ===

(define-read-only (get-job (job-id uint))
  (map-get? jobs { id: job-id })
)

(define-read-only (get-reputation (user principal))
  (ok (default-to u0 (get score (map-get? reputation { user: user }))))
)

(define-read-only (get-total-jobs)
  (ok (var-get total-jobs))
)
