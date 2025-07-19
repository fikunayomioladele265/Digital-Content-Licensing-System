;; Expiration Management Contract
;; Handles license renewal and termination

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-LICENSE-NOT-FOUND (err u501))
(define-constant ERR-INVALID-INPUT (err u502))
(define-constant ERR-LICENSE-EXPIRED (err u503))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u504))

;; License Types
(define-constant LICENSE-TEMPORARY u1)
(define-constant LICENSE-SUBSCRIPTION u2)
(define-constant LICENSE-PERPETUAL u3)

;; Data Variables
(define-data-var next-license-id uint u1)
(define-data-var renewal-grace-period uint u144) ;; ~1 day in blocks

;; Data Maps
(define-map license-registry
  { license-id: uint }
  {
    content-id: uint,
    licensee: principal,
    licensor: principal,
    license-type: uint,
    start-height: uint,
    end-height: uint,
    renewal-fee: uint,
    auto-renewal: bool,
    is-active: bool,
    renewal-count: uint,
    last-renewed: uint
  }
)

(define-map content-licenses
  { content-id: uint }
  { license-ids: (list 100 uint) }
)

(define-map expiring-licenses
  { expiry-height: uint }
  { license-ids: (list 50 uint) }
)

(define-map renewal-notifications
  { license-id: uint }
  {
    notification-sent: bool,
    notification-height: uint,
    reminder-count: uint
  }
)

;; Public Functions

;; Create new license
(define-public (create-license
  (content-id uint)
  (licensee principal)
  (license-type uint)
  (duration uint)
  (renewal-fee uint)
  (auto-renewal bool))
  (let
    (
      (license-id (var-get next-license-id))
      (licensor tx-sender)
      (start-height block-height)
      (end-height (if (is-eq license-type LICENSE-PERPETUAL)
                     u999999999 ;; Very large number for perpetual licenses
                     (+ block-height duration)))
    )
    ;; Validate inputs
    (asserts! (> content-id u0) ERR-INVALID-INPUT)
    (asserts! (>= license-type LICENSE-TEMPORARY) ERR-INVALID-INPUT)
    (asserts! (<= license-type LICENSE-PERPETUAL) ERR-INVALID-INPUT)
    (asserts! (> duration u0) ERR-INVALID-INPUT)

    ;; Create license
    (map-set license-registry
      { license-id: license-id }
      {
        content-id: content-id,
        licensee: licensee,
        licensor: licensor,
        license-type: license-type,
        start-height: start-height,
        end-height: end-height,
        renewal-fee: renewal-fee,
        auto-renewal: auto-renewal,
        is-active: true,
        renewal-count: u0,
        last-renewed: start-height
      }
    )

    ;; Update content licenses list
    (let
      (
        (current-licenses (default-to (list) (get license-ids (map-get? content-licenses { content-id: content-id }))))
      )
      (map-set content-licenses
        { content-id: content-id }
        { license-ids: (unwrap! (as-max-len? (append current-licenses license-id) u100) ERR-INVALID-INPUT) }
      )
    )

    ;; Add to expiring licenses if not perpetual
    (if (not (is-eq license-type LICENSE-PERPETUAL))
      (let
        (
          (current-expiring (default-to (list) (get license-ids (map-get? expiring-licenses { expiry-height: end-height }))))
        )
        (map-set expiring-licenses
          { expiry-height: end-height }
          { license-ids: (unwrap! (as-max-len? (append current-expiring license-id) u50) ERR-INVALID-INPUT) }
        )
      )
      true
    )

    ;; Increment next license ID
    (var-set next-license-id (+ license-id u1))

    (ok license-id)
  )
)

;; Renew license
(define-public (renew-license (license-id uint) (duration uint))
  (let
    (
      (license-data (unwrap! (map-get? license-registry { license-id: license-id }) ERR-LICENSE-NOT-FOUND))
      (renewal-fee (get renewal-fee license-data))
      (current-end (get end-height license-data))
      (new-end-height (+ current-end duration))
    )
    ;; Check authorization
    (asserts! (is-eq tx-sender (get licensee license-data)) ERR-NOT-AUTHORIZED)

    ;; Check if license is renewable (not perpetual)
    (asserts! (not (is-eq (get license-type license-data) LICENSE-PERPETUAL)) ERR-INVALID-INPUT)

    ;; Check if within grace period for expired licenses
    (if (> block-height current-end)
      (asserts! (<= (- block-height current-end) (var-get renewal-grace-period)) ERR-LICENSE-EXPIRED)
      true
    )

    ;; Process payment if renewal fee is required
    (if (> renewal-fee u0)
      (try! (stx-transfer? renewal-fee tx-sender (get licensor license-data)))
      true
    )

    ;; Update license
    (map-set license-registry
      { license-id: license-id }
      (merge license-data {
        end-height: new-end-height,
        is-active: true,
        renewal-count: (+ (get renewal-count license-data) u1),
        last-renewed: block-height
      })
    )

    ;; Update expiring licenses
    (let
      (
        (current-expiring (default-to (list) (get license-ids (map-get? expiring-licenses { expiry-height: new-end-height }))))
      )
      (map-set expiring-licenses
        { expiry-height: new-end-height }
        { license-ids: (unwrap! (as-max-len? (append current-expiring license-id) u50) ERR-INVALID-INPUT) }
      )
    )

    (ok true)
  )
)

;; Auto-renew license (can be called by anyone for auto-renewal licenses)
(define-public (auto-renew-license (license-id uint))
  (let
    (
      (license-data (unwrap! (map-get? license-registry { license-id: license-id }) ERR-LICENSE-NOT-FOUND))
      (renewal-fee (get renewal-fee license-data))
      (licensee (get licensee license-data))
      (licensor (get licensor license-data))
    )
    ;; Check if auto-renewal is enabled
    (asserts! (get auto-renewal license-data) ERR-NOT-AUTHORIZED)

    ;; Check if license has expired or is about to expire
    (asserts! (<= (get end-height license-data) (+ block-height u144)) ERR-INVALID-INPUT) ;; Within 1 day

    ;; Process automatic renewal (simplified - in production, use escrow or pre-authorized payments)
    ;; For now, we'll extend by the original duration
    (let
      (
        (original-duration (- (get end-height license-data) (get start-height license-data)))
        (new-end-height (+ (get end-height license-data) original-duration))
      )
      (map-set license-registry
        { license-id: license-id }
        (merge license-data {
          end-height: new-end-height,
          is-active: true,
          renewal-count: (+ (get renewal-count license-data) u1),
          last-renewed: block-height
        })
      )
    )

    (ok true)
  )
)

;; Terminate license
(define-public (terminate-license (license-id uint))
  (let
    (
      (license-data (unwrap! (map-get? license-registry { license-id: license-id }) ERR-LICENSE-NOT-FOUND))
    )
    ;; Only licensor or licensee can terminate
    (asserts! (or (is-eq tx-sender (get licensor license-data)) (is-eq tx-sender (get licensee license-data))) ERR-NOT-AUTHORIZED)

    ;; Deactivate license
    (map-set license-registry
      { license-id: license-id }
      (merge license-data { is-active: false })
    )

    (ok true)
  )
)

;; Send renewal notification
(define-public (send-renewal-notification (license-id uint))
  (let
    (
      (license-data (unwrap! (map-get? license-registry { license-id: license-id }) ERR-LICENSE-NOT-FOUND))
      (notification-data (default-to { notification-sent: false, notification-height: u0, reminder-count: u0 }
                                     (map-get? renewal-notifications { license-id: license-id })))
    )
    ;; Check if license is approaching expiration (within 7 days)
    (asserts! (<= (get end-height license-data) (+ block-height u1008)) ERR-INVALID-INPUT) ;; ~7 days

    ;; Update notification record
    (map-set renewal-notifications
      { license-id: license-id }
      {
        notification-sent: true,
        notification-height: block-height,
        reminder-count: (+ (get reminder-count notification-data) u1)
      }
    )

    (ok true)
  )
)

;; Read-only Functions

;; Get license details
(define-read-only (get-license-details (license-id uint))
  (map-get? license-registry { license-id: license-id })
)

;; Check if license is active and valid
(define-read-only (is-license-valid (license-id uint))
  (match (map-get? license-registry { license-id: license-id })
    license-data
      (and
        (get is-active license-data)
        (or
          (is-eq (get license-type license-data) LICENSE-PERPETUAL)
          (<= block-height (get end-height license-data))
        )
      )
    false
  )
)

;; Get content licenses
(define-read-only (get-content-licenses (content-id uint))
  (get license-ids (map-get? content-licenses { content-id: content-id }))
)

;; Get expiring licenses for a specific height
(define-read-only (get-expiring-licenses (expiry-height uint))
  (get license-ids (map-get? expiring-licenses { expiry-height: expiry-height }))
)

;; Get licenses expiring soon (within next 7 days)
(define-read-only (get-licenses-expiring-soon)
  (let
    (
      (target-height (+ block-height u1008)) ;; ~7 days
    )
    ;; This is simplified - in production, you'd iterate through a range
    (get license-ids (map-get? expiring-licenses { expiry-height: target-height }))
  )
)

;; Get renewal notification status
(define-read-only (get-renewal-notification (license-id uint))
  (map-get? renewal-notifications { license-id: license-id })
)

;; Get grace period
(define-read-only (get-grace-period)
  (var-get renewal-grace-period)
)

;; Check if license needs renewal
(define-read-only (needs-renewal (license-id uint))
  (match (map-get? license-registry { license-id: license-id })
    license-data
      (and
        (get is-active license-data)
        (not (is-eq (get license-type license-data) LICENSE-PERPETUAL))
        (<= (get end-height license-data) (+ block-height u1008)) ;; Within 7 days
      )
    false
  )
)
