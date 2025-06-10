;; Backup Coordination Contract
;; Coordinates emergency communication backups

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_BACKUP_NOT_FOUND (err u401))
(define-constant ERR_INVALID_STATUS (err u402))

;; Backup status constants
(define-constant BACKUP_READY u1)
(define-constant BACKUP_ACTIVE u2)
(define-constant BACKUP_FAILED u3)
(define-constant BACKUP_MAINTENANCE u4)

;; Data structures
(define-map backup-systems
  { backup-id: uint }
  {
    system-name: (string-ascii 50),
    backup-type: (string-ascii 20),
    primary-system: uint,
    status: uint,
    capacity: uint,
    last-tested: uint,
    activation-time: uint
  }
)

(define-map failover-plans
  { plan-id: uint }
  {
    primary-service: uint,
    backup-sequence: (list 5 uint),
    auto-failover: bool,
    recovery-time-objective: uint,
    recovery-point-objective: uint
  }
)

(define-map backup-logs
  { log-id: uint }
  {
    backup-id: uint,
    event-type: (string-ascii 20),
    timestamp: uint,
    success: bool,
    details: (string-ascii 100)
  }
)

(define-data-var next-backup-id uint u1)
(define-data-var next-plan-id uint u1)
(define-data-var next-log-id uint u1)

;; Public functions
(define-public (register-backup-system
  (system-name (string-ascii 50))
  (backup-type (string-ascii 20))
  (primary-system uint)
  (capacity uint))
  (let ((backup-id (var-get next-backup-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set backup-systems
      { backup-id: backup-id }
      {
        system-name: system-name,
        backup-type: backup-type,
        primary-system: primary-system,
        status: BACKUP_READY,
        capacity: capacity,
        last-tested: block-height,
        activation-time: u0
      }
    )
    (var-set next-backup-id (+ backup-id u1))
    (ok backup-id)
  )
)

(define-public (activate-backup (backup-id uint))
  (let ((backup (unwrap! (map-get? backup-systems { backup-id: backup-id }) ERR_BACKUP_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set backup-systems
      { backup-id: backup-id }
      (merge backup {
        status: BACKUP_ACTIVE,
        activation-time: block-height
      })
    )
    (unwrap-panic (log-backup-event backup-id "ACTIVATION" true "Backup system activated"))
    (ok true)
  )
)

(define-public (create-failover-plan
  (primary-service uint)
  (backup-sequence (list 5 uint))
  (auto-failover bool)
  (rto uint)
  (rpo uint))
  (let ((plan-id (var-get next-plan-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set failover-plans
      { plan-id: plan-id }
      {
        primary-service: primary-service,
        backup-sequence: backup-sequence,
        auto-failover: auto-failover,
        recovery-time-objective: rto,
        recovery-point-objective: rpo
      }
    )
    (var-set next-plan-id (+ plan-id u1))
    (ok plan-id)
  )
)

(define-private (log-backup-event
  (backup-id uint)
  (event-type (string-ascii 20))
  (success bool)
  (details (string-ascii 100)))
  (let ((log-id (var-get next-log-id)))
    (map-set backup-logs
      { log-id: log-id }
      {
        backup-id: backup-id,
        event-type: event-type,
        timestamp: block-height,
        success: success,
        details: details
      }
    )
    (var-set next-log-id (+ log-id u1))
    (ok log-id)
  )
)

;; Read-only functions
(define-read-only (get-backup-system (backup-id uint))
  (map-get? backup-systems { backup-id: backup-id })
)

(define-read-only (get-failover-plan (plan-id uint))
  (map-get? failover-plans { plan-id: plan-id })
)

(define-read-only (get-backup-log (log-id uint))
  (map-get? backup-logs { log-id: log-id })
)
