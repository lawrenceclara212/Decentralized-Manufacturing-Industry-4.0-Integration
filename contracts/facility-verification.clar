;; Facility Verification Contract
;; Validates and manages smart factory certifications

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_FACILITY_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_VERIFIED (err u102))
(define-constant ERR_INVALID_CERTIFICATION (err u103))

;; Data structures
(define-map facilities
  { facility-id: uint }
  {
    owner: principal,
    name: (string-ascii 100),
    location: (string-ascii 100),
    certification-level: uint,
    verified: bool,
    verification-date: uint,
    expiry-date: uint
  }
)

(define-map certifications
  { cert-id: uint }
  {
    name: (string-ascii 50),
    requirements: (string-ascii 200),
    validity-period: uint,
    active: bool
  }
)

(define-data-var facility-counter uint u0)
(define-data-var cert-counter uint u0)

;; Register a new facility
(define-public (register-facility (name (string-ascii 100)) (location (string-ascii 100)))
  (let ((facility-id (+ (var-get facility-counter) u1)))
    (map-set facilities
      { facility-id: facility-id }
      {
        owner: tx-sender,
        name: name,
        location: location,
        certification-level: u0,
        verified: false,
        verification-date: u0,
        expiry-date: u0
      }
    )
    (var-set facility-counter facility-id)
    (ok facility-id)
  )
)

;; Verify a facility
(define-public (verify-facility (facility-id uint) (cert-level uint))
  (let ((facility (unwrap! (map-get? facilities { facility-id: facility-id }) ERR_FACILITY_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (get verified facility)) ERR_ALREADY_VERIFIED)
    (map-set facilities
      { facility-id: facility-id }
      (merge facility {
        certification-level: cert-level,
        verified: true,
        verification-date: block-height,
        expiry-date: (+ block-height u52560) ;; ~1 year
      })
    )
    (ok true)
  )
)

;; Get facility details
(define-read-only (get-facility (facility-id uint))
  (map-get? facilities { facility-id: facility-id })
)

;; Check if facility is verified
(define-read-only (is-facility-verified (facility-id uint))
  (match (map-get? facilities { facility-id: facility-id })
    facility (and (get verified facility) (> (get expiry-date facility) block-height))
    false
  )
)

;; Add certification type
(define-public (add-certification (name (string-ascii 50)) (requirements (string-ascii 200)) (validity-period uint))
  (let ((cert-id (+ (var-get cert-counter) u1)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set certifications
      { cert-id: cert-id }
      {
        name: name,
        requirements: requirements,
        validity-period: validity-period,
        active: true
      }
    )
    (var-set cert-counter cert-id)
    (ok cert-id)
  )
)
