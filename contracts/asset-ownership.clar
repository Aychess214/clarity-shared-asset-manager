;; Define data structures
(define-map assets
    { asset-id: uint }
    {
        name: (string-ascii 64),
        total-shares: uint,
        available-shares: uint,
        price-per-share: uint
    }
)

(define-map ownership
    { asset-id: uint, owner: principal }
    { shares: uint }
)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-asset-exists (err u101))
(define-constant err-asset-not-found (err u102))
(define-constant err-insufficient-shares (err u103))
(define-constant err-insufficient-funds (err u104))

;; Data vars
(define-data-var last-asset-id uint u0)

;; Private functions
(define-private (increase-asset-id)
    (let
        ((current (var-get last-asset-id)))
        (var-set last-asset-id (+ current u1))
        (var-get last-asset-id)
    )
)

;; Public functions
(define-public (create-asset (name (string-ascii 64)) (total-shares uint) (price-per-share uint))
    (let
        ((asset-id (increase-asset-id)))
        (if (is-eq tx-sender contract-owner)
            (begin
                (map-insert assets
                    { asset-id: asset-id }
                    {
                        name: name,
                        total-shares: total-shares,
                        available-shares: total-shares,
                        price-per-share: price-per-share
                    }
                )
                (ok asset-id)
            )
            err-owner-only
        )
    )
)

(define-public (buy-shares (asset-id uint) (shares uint))
    (let
        (
            (asset (unwrap! (map-get? assets { asset-id: asset-id }) err-asset-not-found))
            (total-cost (* shares (get price-per-share asset)))
            (current-ownership (default-to { shares: u0 }
                (map-get? ownership { asset-id: asset-id, owner: tx-sender })))
        )
        (asserts! (<= shares (get available-shares asset)) err-insufficient-shares)
        (begin
            (try! (stx-transfer? total-cost tx-sender contract-owner))
            (map-set assets
                { asset-id: asset-id }
                (merge asset { available-shares: (- (get available-shares asset) shares) })
            )
            (map-set ownership
                { asset-id: asset-id, owner: tx-sender }
                { shares: (+ shares (get shares current-ownership)) }
            )
            (ok true)
        )
    )
)

(define-public (transfer-shares (asset-id uint) (shares uint) (recipient principal))
    (let
        (
            (current-ownership (unwrap! (map-get? ownership
                { asset-id: asset-id, owner: tx-sender }) err-insufficient-shares))
            (recipient-ownership (default-to { shares: u0 }
                (map-get? ownership { asset-id: asset-id, owner: recipient })))
        )
        (asserts! (>= (get shares current-ownership) shares) err-insufficient-shares)
        (begin
            (map-set ownership
                { asset-id: asset-id, owner: tx-sender }
                { shares: (- (get shares current-ownership) shares) }
            )
            (map-set ownership
                { asset-id: asset-id, owner: recipient }
                { shares: (+ shares (get shares recipient-ownership)) }
            )
            (ok true)
        )
    )
)

;; Read only functions
(define-read-only (get-asset-info (asset-id uint))
    (ok (map-get? assets { asset-id: asset-id }))
)

(define-read-only (get-shares (asset-id uint) (owner principal))
    (ok (map-get? ownership { asset-id: asset-id, owner: owner }))
)
