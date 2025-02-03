;; PulseVault - Fitness Data Storage Contract with DeFi Integration

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-unauthorized (err u101))
(define-constant err-invalid-data (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-cooldown-active (err u104))
(define-constant reward-amount u100) ;; Reward amount in tokens
(define-constant minimum-data-points u30) ;; Minimum daily entries for rewards
(define-constant reward-cooldown u86400) ;; 24 hour cooldown

;; Data structures
(define-map fitness-data 
  { user: principal, timestamp: uint } 
  {
    steps: uint,
    heart-rate: uint,
    calories: uint,
    device-id: (string-ascii 32),
    data-hash: (buff 32)
  }
)

(define-map data-access
  { owner: principal, viewer: principal }
  { can-view: bool }
)

(define-map user-stats
  { user: principal }
  {
    total-entries: uint,
    total-rewards: uint,
    last-reward-date: uint,
    current-streak: uint
  }
)

;; SIP-010 Token Interface
(define-trait ft-trait
  (
    (transfer (uint principal principal) (response bool uint))
    (get-balance (principal) (response uint uint))
  )
)

;; Storage functions
(define-public (store-fitness-data 
    (timestamp uint)
    (steps uint)
    (heart-rate uint)
    (calories uint)
    (device-id (string-ascii 32))
    (data-hash (buff 32)))
  (begin
    (asserts! (> timestamp u0) err-invalid-data)
    (asserts! (and (> steps u0) (<= steps u100000)) err-invalid-data)
    (asserts! (and (> heart-rate u30) (<= heart-rate u220)) err-invalid-data)
    (map-set fitness-data
      { user: tx-sender, timestamp: timestamp }
      {
        steps: steps,
        heart-rate: heart-rate,
        calories: calories,
        device-id: device-id,
        data-hash: data-hash
      }
    )
    (try! (update-user-stats tx-sender timestamp))
    (ok true)
  )
)

;; Stats and rewards
(define-private (update-user-stats (user principal) (timestamp uint))
  (let (
    (current-stats (default-to 
      { total-entries: u0, total-rewards: u0, last-reward-date: u0, current-streak: u0 }
      (map-get? user-stats { user: user }))
    )
    (current-entries (+ (get total-entries current-stats) u1))
    (new-streak (if (is-consecutive-day timestamp (get last-reward-date current-stats))
                 (+ (get current-streak current-stats) u1)
                 u1))
  )
    (begin
      (map-set user-stats
        { user: user }
        {
          total-entries: current-entries,
          total-rewards: (get total-rewards current-stats),
          last-reward-date: timestamp,
          current-streak: new-streak
        }
      )
      (if (check-reward-eligibility user timestamp current-stats)
        (distribute-rewards user)
        (ok true)
      )
    )
  )
)

(define-private (is-consecutive-day (current-time uint) (last-time uint))
  (and
    (> current-time last-time)
    (<= (- current-time last-time) reward-cooldown)
  )
)

(define-private (check-reward-eligibility 
  (user principal) 
  (timestamp uint)
  (stats {total-entries: uint, total-rewards: uint, last-reward-date: uint, current-streak: uint}))
  (and
    (>= (get total-entries stats) minimum-data-points)
    (> timestamp (+ (get last-reward-date stats) reward-cooldown))
  )
)

[... rest of contract remains unchanged ...]
