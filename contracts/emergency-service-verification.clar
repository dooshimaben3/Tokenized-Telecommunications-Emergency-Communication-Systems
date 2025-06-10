;; Emergency Service Verification Contract
;; Validates and manages emergency communication services

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_SERVICE_NOT_FOUND (err u101))
(define-constant ERR_INVALID_SERVICE (err u102))

;; Data structures
(define-map emergency-services
  { service-id: uint }
  {
    service-name: (string-ascii 50),
    service-type: (string-ascii 20),
    verified: bool,
    priority-level: uint,
    contact-info: (string-ascii 100),
    last-verified: uint
  }
)

(define-map service-operators
  { operator-id: principal }
  {
    operator-name: (string-ascii 50),
    authorized: bool,
    services-managed: (list 10 uint)
  }
)

(define-data-var next-service-id uint u1)

;; Public functions
(define-public (register-emergency-service
  (service-name (string-ascii 50))
  (service-type (string-ascii 20))
  (contact-info (string-ascii 100))
  (priority-level uint))
  (let ((service-id (var-get next-service-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set emergency-services
      { service-id: service-id }
      {
        service-name: service-name,
        service-type: service-type,
        verified: false,
        priority-level: priority-level,
        contact-info: contact-info,
        last-verified: block-height
      }
    )
    (var-set next-service-id (+ service-id u1))
    (ok service-id)
  )
)

(define-public (verify-service (service-id uint))
  (let ((service (unwrap! (map-get? emergency-services { service-id: service-id }) ERR_SERVICE_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set emergency-services
      { service-id: service-id }
      (merge service { verified: true, last-verified: block-height })
    )
    (ok true)
  )
)

(define-public (authorize-operator (operator principal) (operator-name (string-ascii 50)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set service-operators
      { operator-id: operator }
      {
        operator-name: operator-name,
        authorized: true,
        services-managed: (list)
      }
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-service-info (service-id uint))
  (map-get? emergency-services { service-id: service-id })
)

(define-read-only (is-service-verified (service-id uint))
  (match (map-get? emergency-services { service-id: service-id })
    service (get verified service)
    false
  )
)

(define-read-only (get-operator-info (operator principal))
  (map-get? service-operators { operator-id: operator })
)
