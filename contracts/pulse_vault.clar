;; PulseVault - Fitness Data Storage Contract with DeFi Integration

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-unauthorized (err u101))
(define-constant err-invalid-data (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-cooldown-active (err u104))
(define-constant err-rate-limit (err u105))
(define-constant err-invalid-streak (err u106))
(define-constant reward-amount u100)
(define-constant minimum-data-points u30)
(define-constant reward-cooldown u86400)
(define-constant rate-limit-window u3600)

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

(define-map user-stats
  { user: principal }
  {
    total-entries: uint,
    total-rewards: uint,
    last-reward-date: uint,
    current-streak: uint,
    last-submission-date: uint
  }
)

(define-map daily-aggregates
  { user: principal, date: uint }
  {
    avg-heart-rate: uint,
    total-steps: uint,
    total-calories: uint,
    submissions: uint
  }
)

(define-map submission-rates
  { user: principal }
  { last-submission: uint, count: uint }
)

;; Enhanced read-only functions
(define-read-only (get-user-stats (user principal))
  (default-to
    { total-entries: u0, total-rewards: u0, last-reward-date: u0, current-streak: u0, last-submission-date: u0 }
    (map-get? user-stats { user: user })
  )
)

(define-read-only (get-daily-aggregate (user principal) (date uint))
  (default-to
    { avg-heart-rate: u0, total-steps: u0, total-calories: u0, submissions: u0 }
    (map-get? daily-aggregates { user: user, date: date })
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

;; Streak tracking
(define-private (update-streak (user principal) (timestamp uint))
  (let (
    (stats (get-user-stats user))
    (last-date (get last-submission-date stats))
    (current-date (/ timestamp u86400))
    (prev-date (/ last-date u86400))
  )
    (if (is-eq last-date u0)
      (map-set user-stats
        { user: user }
        (merge stats { current-streak: u1, last-submission-date: timestamp })
      )
      (if (is-eq (- current-date prev-date) u1)
        (map-set user-stats
          { user: user }
          (merge stats {
            current-streak: (+ (get current-streak stats) u1),
            last-submission-date: timestamp
          })
        )
        (map-set user-stats
          { user: user }
          (merge stats { current-streak: u1, last-submission-date: timestamp })
        )
      )
    )
  )
)

;; Update daily aggregate
(define-private (update-daily-aggregate
  (user principal)
  (timestamp uint)
  (steps uint)
  (heart-rate uint)
  (calories uint))
  (let (
    (date (/ timestamp u86400))
    (current-agg (get-daily-aggregate user date))
    (submission-count (+ (get submissions current-agg) u1))
  )
    (map-set daily-aggregates
      { user: user, date: date }
      {
        avg-heart-rate: (/ (+ (* (get avg-heart-rate current-agg) 
                                (get submissions current-agg))
                             heart-rate)
                          submission-count),
        total-steps: (+ (get total-steps current-agg) steps),
        total-calories: (+ (get total-calories current-agg) calories),
        submissions: submission-count
      }
    )
  )
)

;; Public functions remain unchanged
[... existing public functions ...]
