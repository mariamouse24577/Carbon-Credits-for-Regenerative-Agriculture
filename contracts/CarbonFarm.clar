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
(define-constant ERR_INVALID_RATING (err u112))
(define-constant ERR_FARM_ALREADY_RATED (err u113))

(define-data-var total-farms uint u0)
(define-data-var total-credits-issued uint u0)
(define-data-var carbon-price uint u1000000)

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

(define-map farm-ratings
  {farm: principal, rater: principal}
  {
    rating: uint,
    comment: (string-ascii 50),
    rating-date: uint
  }
)

(define-map farm-reputation-summary
  {farm: principal}
  {
    total-ratings: uint,
    average-rating: uint,
    last-rating-date: uint
  }
)

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

(define-public (rate-farm (farm principal) (rating uint) (comment (string-ascii 50)))
  (let
    ((farm-exists (map-get? farms farm))
     (existing-rating (map-get? farm-ratings {farm: farm, rater: tx-sender}))
     (current-summary (map-get? farm-reputation-summary {farm: farm})))
    (if (not (is-some farm-exists))
      ERR_FARM_NOT_FOUND
      (if (is-some existing-rating)
        ERR_FARM_ALREADY_RATED
        (if (or (< rating u1) (> rating u5))
          ERR_INVALID_RATING
          (let
            ((total (if (is-some current-summary) (+ (get total-ratings (unwrap-panic current-summary)) u1) u1))
             (prev-avg (if (is-some current-summary) (get average-rating (unwrap-panic current-summary)) u0))
             (new-avg (/ (+ (* prev-avg (- total u1)) rating) total)))
            (begin
              (map-set farm-ratings
                {farm: farm, rater: tx-sender}
                {
                  rating: rating,
                  comment: comment,
                  rating-date: stacks-block-height
                }
              )
              (map-set farm-reputation-summary
                {farm: farm}
                {
                  total-ratings: total,
                  average-rating: new-avg,
                  last-rating-date: stacks-block-height
                }
              )
              (ok true)
            )
          )
        )
      )
    )
  )
)

(define-read-only (get-farm-rating (farm principal) (rater principal))
  (map-get? farm-ratings {farm: farm, rater: rater})
)

(define-read-only (get-farm-reputation-summary (farm principal))
  (map-get? farm-reputation-summary {farm: farm})
)

(define-read-only (get-farm-average-rating (farm principal))
  (let
    ((summary (map-get? farm-reputation-summary {farm: farm})))
    (ok (if (is-some summary) (get average-rating (unwrap-panic summary)) u0))
  )
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
