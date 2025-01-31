;; PulseVault - Fitness Data Storage Contract with DeFi Integration

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-unauthorized (err u101))
(define-constant err-invalid-data (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant reward-amount u100) ;; Reward amount in tokens
(define-constant minimum-data-points u30) ;; Minimum daily entries for rewards

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
    last-reward-date: uint
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
      { total-entries: u0, total-rewards: u0, last-reward-date: u0 }
      (map-get? user-stats { user: user })
    ))
    (current-entries (+ (get total-entries current-stats) u1))
  )
    (begin
      (map-set user-stats
        { user: user }
        {
          total-entries: current-entries,
          total-rewards: (get total-rewards current-stats),
          last-reward-date: (get last-reward-date current-stats)
        }
      )
      (if (check-reward-eligibility user timestamp current-stats)
        (distribute-rewards user)
        (ok true)
      )
    )
  )
)

(define-private (check-reward-eligibility 
  (user principal) 
  (timestamp uint)
  (stats {total-entries: uint, total-rewards: uint, last-reward-date: uint}))
  (and
    (>= (get total-entries stats) minimum-data-points)
    (> timestamp (+ (get last-reward-date stats) u86400))
  )
)

(define-public (distribute-rewards (user principal))
  (let ((token-contract (contract-call? .fitness-token)))
    (begin
      (try! (contract-call? token-contract transfer reward-amount tx-sender user))
      (map-set user-stats
        { user: user }
        {
          total-entries: u0, ;; Reset entries
          total-rewards: (+ (get total-rewards (unwrap-panic (get-user-stats user))) reward-amount),
          last-reward-date: block-height
        }
      )
      (ok true)
    )
  )
)

;; Access control
(define-public (grant-access (viewer principal))
  (ok (map-set data-access
    { owner: tx-sender, viewer: viewer }
    { can-view: true }
  ))
)

(define-public (revoke-access (viewer principal))
  (ok (map-set data-access
    { owner: tx-sender, viewer: viewer }
    { can-view: false }
  ))
)

;; Read functions
(define-read-only (can-view-data (owner principal) (viewer principal))
  (default-to 
    false
    (get can-view (map-get? data-access { owner: owner, viewer: viewer }))
  )
)

(define-read-only (get-fitness-data (user principal) (timestamp uint))
  (let ((viewer tx-sender))
    (if (or 
      (is-eq user viewer)
      (can-view-data user viewer)
    )
      (ok (map-get? fitness-data { user: user, timestamp: timestamp }))
      err-unauthorized
    )
  )
)

(define-read-only (get-user-stats (user principal))
  (ok (map-get? user-stats { user: user }))
)

;; Data analysis functions  
(define-read-only (get-daily-average 
    (user principal)
    (start-time uint)
    (end-time uint))
  (let ((viewer tx-sender))
    (if (or 
      (is-eq user viewer)
      (can-view-data user viewer)
    )
      (ok true)
      err-unauthorized
    )
  )
)
