;; PulseVault - Fitness Data Storage Contract with DeFi Integration

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-unauthorized (err u101))
(define-constant err-invalid-data (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-cooldown-active (err u104))
(define-constant err-rate-limit (err u105))
(define-constant reward-amount u100)
(define-constant minimum-data-points u30)
(define-constant reward-cooldown u86400)
(define-constant rate-limit-window u3600) ;; 1 hour window

;; Data structures
(define-map fitness-data 
  { user: principal, timestamp: uint } 
  {
    steps: uint,
    heart-rate: uint,
    calories: uint,
    device-id: (string-ascii 32),
    data-hash: (buff 32),
    version: uint
  }
)

(define-map submission-rates
  { user: principal }
  { last-submission: uint, count: uint }
)

;; Read-only functions
(define-read-only (get-user-stats (user principal))
  (default-to
    { total-entries: u0, total-rewards: u0, last-reward-date: u0, current-streak: u0 }
    (map-get? user-stats { user: user })
  )
)

(define-read-only (get-daily-aggregate (user principal) (day-start uint))
  (let (
    (day-end (+ day-start u86400))
    (entries (get-entries-in-range user day-start day-end))
  )
    (ok {
      avg-heart-rate: (calculate-average entries),
      total-steps: (sum-steps entries),
      total-calories: (sum-calories entries)
    })
  )
)

;; Enhanced validation
(define-private (validate-fitness-data
  (timestamp uint)
  (steps uint)
  (heart-rate uint)
  (calories uint))
  (begin
    (asserts! (< timestamp (get-block-time)) err-invalid-data)
    (asserts! (and (> steps u0) (<= steps u100000)) err-invalid-data)
    (asserts! (and (> heart-rate u30) (<= heart-rate u220)) err-invalid-data)
    (asserts! (and (> calories u0) (<= calories u10000)) err-invalid-data)
    (ok true)
  )
)

;; Rate limiting
(define-private (check-rate-limit (user principal))
  (let (
    (current-time (get-block-time))
    (rate-data (default-to
      { last-submission: u0, count: u0 }
      (map-get? submission-rates { user: user })))
  )
    (if (> (- current-time (get last-submission rate-data)) rate-limit-window)
      (begin
        (map-set submission-rates
          { user: user }
          { last-submission: current-time, count: u1 }
        )
        (ok true)
      )
      (if (< (get count rate-data) u10)
        (begin
          (map-set submission-rates
            { user: user }
            { last-submission: (get last-submission rate-data),
              count: (+ (get count rate-data) u1) }
          )
          (ok true)
        )
        err-rate-limit
      )
    )
  )
)

[... rest of existing contract functions ...]
