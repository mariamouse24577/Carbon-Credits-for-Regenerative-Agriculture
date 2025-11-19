;; title: CarbonFarm
;; version: 1.0.0
;; summary: A protocol for tokenizing and trading carbon credits earned through regenerative farming practices
;; description: Smart contract for managing carbon credits from regenerative agriculture

(define-fungible-token carbon-credit)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_CREDITS (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_FARM_EXISTS (err u103))
(define-constant ERR_FARM_NOT_FOUND (err u104))
(define-constant ERR_INVALID_PRACTICE (err u105))
(define-constant ERR_ALREADY_VERIFIED (err u106))
(define-constant ERR_NOT_VERIFIED (err u107))
(define-constant ERR_TRANSFER_FAILED (err u108))
(define-constant ERR_PERIOD_NOT_ACTIVE (err u109))
(define-constant ERR_EMPTY_BATCH (err u110))
(define-constant ERR_BATCH_TOO_LARGE (err u111))

(define-data-var total-farms uint u0)
(define-data-var total-credits-issued uint u0)
(define-data-var carbon-price uint u1000000)
(define-data-var current-period-id uint u1)
(define-data-var current-period-start uint u0)
(define-data-var current-period-end uint u0)

(define-map farms principal 
  {
    name: (string-ascii 50),
    location: (string-ascii 100),
    size-acres: uint,
    practices: (list 10 (string-ascii 30)),
    verified: bool,
    credits-earned: uint,
    last-verification: uint
  }
)

(define-map farm-verifications 
  {farm: principal, verifier: principal}
  {
    verification-date: uint,
    credits-awarded: uint,
    practice-verified: (string-ascii 30)
  }
)

(define-map carbon-offsets
  {buyer: principal, offset-id: uint}
  {
    amount: uint,
    farm: principal,
    offset-date: uint,
    retired: bool
  }
)

(define-map authorized-verifiers principal bool)

(define-map farm-performance principal
  {
    total-verifications: uint,
    current-streak: uint,
    max-streak: uint,
    average-credits: uint,
    last-verified: uint,
    period-id: uint,
    performance-score: uint
  }
)

(define-map verification-periods uint
  {
    period-start: uint,
    period-end: uint,
    farms-verified: uint,
    total-credits: uint
  }
)

(define-map period-farm-credits {period-id: uint, farm: principal}
  {
    credits-earned: uint,
    verification-count: uint
  }
)

(define-map batch-verifications {batch-id: uint, farm: principal}
  {
    credits-awarded: uint,
    batch-date: uint,
    verifier: principal
  }
)

(define-data-var next-batch-id uint u1)
(define-data-var next-offset-id uint u1)

(define-public (register-farm 
  (name (string-ascii 50))
  (location (string-ascii 100))
  (size-acres uint)
  (practices (list 10 (string-ascii 30)))
)
  (let
    ((existing-farm (map-get? farms tx-sender)))
    (if (is-some existing-farm)
      ERR_FARM_EXISTS
      (begin
        (map-set farms tx-sender {
          name: name,
          location: location,
          size-acres: size-acres,
          practices: practices,
          verified: false,
          credits-earned: u0,
          last-verification: u0
        })
        (var-set total-farms (+ (var-get total-farms) u1))
        (ok true)
      )
    )
  )
)

(define-public (add-verifier (verifier principal))
  (if (is-eq tx-sender CONTRACT_OWNER)
    (begin
      (map-set authorized-verifiers verifier true)
      (ok true)
    )
    ERR_UNAUTHORIZED
  )
)

(define-public (remove-verifier (verifier principal))
  (if (is-eq tx-sender CONTRACT_OWNER)
    (begin
      (map-delete authorized-verifiers verifier)
      (ok true)
    )
    ERR_UNAUTHORIZED
  )
)

(define-public (start-verification-period (period-duration uint))
  (if (is-eq tx-sender CONTRACT_OWNER)
    (let ((period-id (var-get current-period-id))
          (start-block stacks-block-height))
      (begin
        (map-set verification-periods period-id {
          period-start: start-block,
          period-end: (+ start-block period-duration),
          farms-verified: u0,
          total-credits: u0
        })
        (var-set current-period-id (+ period-id u1))
        (var-set current-period-start start-block)
        (var-set current-period-end (+ start-block period-duration))
        (ok period-id)
      )
    )
    ERR_UNAUTHORIZED
  )
)

(define-public (verify-farm
  (farm principal)
  (credits-to-award uint)
  (practice (string-ascii 30))
)
  (let
    ((farm-data (map-get? farms farm))
     (is-authorized (default-to false (map-get? authorized-verifiers tx-sender))))
    (if (and is-authorized (is-some farm-data))
      (let ((farm-info (unwrap-panic farm-data)))
        (if (> credits-to-award u0)
          (begin
            (map-set farms farm 
              (merge farm-info {
                verified: true,
                credits-earned: (+ (get credits-earned farm-info) credits-to-award),
                last-verification: stacks-block-height
              })
            )
            (map-set farm-verifications 
              {farm: farm, verifier: tx-sender}
              {
                verification-date: stacks-block-height,
                credits-awarded: credits-to-award,
                practice-verified: practice
              }
            )
            (try! (ft-mint? carbon-credit credits-to-award farm))
            (var-set total-credits-issued (+ (var-get total-credits-issued) credits-to-award))
            (ok credits-to-award)
          )
          ERR_INVALID_AMOUNT
        )
      )
      ERR_UNAUTHORIZED
    )
  )
)

(define-public (batch-verify-farms 
  (farms-list (list 50 principal))
  (credits-list (list 50 uint))
)
  (let
    ((batch-id (var-get next-batch-id))
     (is-authed (default-to false (map-get? authorized-verifiers tx-sender))))
    (if is-authed
      (if (is-eq (len farms-list) (len credits-list))
        (if (> (len farms-list) u0)
          (if (< (len farms-list) u51)
            (begin
              (var-set next-batch-id (+ batch-id u1))
              (ok batch-id)
            )
            ERR_BATCH_TOO_LARGE
          )
          ERR_EMPTY_BATCH
        )
        ERR_INVALID_AMOUNT
      )
      ERR_UNAUTHORIZED
    )
  )
)

(define-public (transfer-credits (amount uint) (recipient principal))
  (if (> amount u0)
    (begin
      (try! (ft-transfer? carbon-credit amount tx-sender recipient))
      (ok true)
    )
    ERR_INVALID_AMOUNT
  )
)

(define-public (purchase-offset 
  (amount uint)
  (from-farm principal)
)
  (let
    ((farm-data (map-get? farms from-farm))
     (farm-balance (ft-get-balance carbon-credit from-farm))
     (offset-id (var-get next-offset-id)))
    (if (and (is-some farm-data) (>= farm-balance amount) (> amount u0))
      (let ((payment-amount (* amount (var-get carbon-price))))
        (try! (stx-transfer? payment-amount tx-sender from-farm))
        (try! (ft-transfer? carbon-credit amount from-farm tx-sender))
        (map-set carbon-offsets 
          {buyer: tx-sender, offset-id: offset-id}
          {
            amount: amount,
            farm: from-farm,
            offset-date: stacks-block-height,
            retired: false
          }
        )
        (var-set next-offset-id (+ offset-id u1))
        (ok offset-id)
      )
      ERR_INSUFFICIENT_CREDITS
    )
  )
)

(define-public (retire-offset (offset-id uint))
  (let
    ((offset-data (map-get? carbon-offsets {buyer: tx-sender, offset-id: offset-id})))
    (if (is-some offset-data)
      (let ((offset-info (unwrap-panic offset-data)))
        (if (not (get retired offset-info))
          (begin
            (try! (ft-burn? carbon-credit (get amount offset-info) tx-sender))
            (map-set carbon-offsets 
              {buyer: tx-sender, offset-id: offset-id}
              (merge offset-info {retired: true})
            )
            (ok true)
          )
          (ok false)
        )
      )
      ERR_FARM_NOT_FOUND
    )
  )
)

(define-public (update-carbon-price (new-price uint))
  (if (is-eq tx-sender CONTRACT_OWNER)
    (begin
      (var-set carbon-price new-price)
      (ok true)
    )
    ERR_UNAUTHORIZED
  )
)

(define-public (calculate-farm-performance (farm principal))
  (let
    ((existing-perf (map-get? farm-performance farm))
     (farm-data (map-get? farms farm))
     (current-period (var-get current-period-id)))
    (if (is-some farm-data)
      (let ((farm-info (unwrap-panic farm-data))
            (perf-data (default-to 
              {total-verifications: u0, current-streak: u0, max-streak: u0, average-credits: u0, last-verified: u0, period-id: u0, performance-score: u0}
              existing-perf)))
        (let ((new-streak (if (is-eq (get period-id perf-data) current-period) (get current-streak perf-data) u1))
              (max-streak (if (> new-streak (get max-streak perf-data)) new-streak (get max-streak perf-data)))
              (avg-credits (if (> (get total-verifications perf-data) u0) 
                (/ (get credits-earned farm-info) (+ (get total-verifications perf-data) u1))
                (get credits-earned farm-info))))
          (begin
            (map-set farm-performance farm {
              total-verifications: (+ (get total-verifications perf-data) u1),
              current-streak: (+ new-streak u1),
              max-streak: max-streak,
              average-credits: avg-credits,
              last-verified: stacks-block-height,
              period-id: current-period,
              performance-score: (* avg-credits max-streak)
            })
            (ok true)
          )
        )
      )
      ERR_FARM_NOT_FOUND
    )
  )
)

(define-read-only (get-farm-info (farm principal))
  (map-get? farms farm)
)

(define-read-only (get-carbon-balance (account principal))
  (ok (ft-get-balance carbon-credit account))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply carbon-credit))
)

(define-read-only (get-carbon-price)
  (ok (var-get carbon-price))
)

(define-read-only (get-total-farms)
  (ok (var-get total-farms))
)

(define-read-only (get-total-credits-issued)
  (ok (var-get total-credits-issued))
)

(define-read-only (get-verification-info (farm principal) (verifier principal))
  (map-get? farm-verifications {farm: farm, verifier: verifier})
)

(define-read-only (get-offset-info (buyer principal) (offset-id uint))
  (map-get? carbon-offsets {buyer: buyer, offset-id: offset-id})
)

(define-read-only (is-authorized-verifier (verifier principal))
  (default-to false (map-get? authorized-verifiers verifier))
)

(define-read-only (get-contract-owner)
  (ok CONTRACT_OWNER)
)

(define-read-only (get-farm-performance (farm principal))
  (map-get? farm-performance farm)
)

(define-read-only (get-verification-streak (farm principal))
  (let ((perf-data (map-get? farm-performance farm)))
    (if (is-some perf-data)
      (ok (get current-streak (unwrap-panic perf-data)))
      (ok u0)
    )
  )
)

(define-read-only (get-period-performance (period-id uint))
  (map-get? verification-periods period-id)
)

(define-private (is-valid-practice (practice (string-ascii 30)))
  (or 
    (is-eq practice "cover-crops")
    (or 
      (is-eq practice "no-till")
      (or
        (is-eq practice "rotational-grazing")
        (or
          (is-eq practice "composting")
          (is-eq practice "agroforestry")
        )
      )
    )
  )
)
