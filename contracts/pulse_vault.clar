;; PulseVault - Fitness Data Storage Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-unauthorized (err u101))
(define-constant err-invalid-data (err u102))

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

;; Storage functions
(define-public (store-fitness-data 
    (timestamp uint)
    (steps uint)
    (heart-rate uint)
    (calories uint)
    (device-id (string-ascii 32))
    (data-hash (buff 32)))
  (ok (map-set fitness-data
    { user: tx-sender, timestamp: timestamp }
    {
      steps: steps,
      heart-rate: heart-rate,
      calories: calories,
      device-id: device-id,
      data-hash: data-hash
    }
  ))
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
      ;; Note: This is a simplified version. In practice, you'd need off-chain
      ;; indexing to efficiently calculate averages
      (ok true)
      err-unauthorized
    )
  )
)