;; IoT Device Management Contract
;; Manages connected manufacturing equipment

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_DEVICE_NOT_FOUND (err u201))
(define-constant ERR_DEVICE_OFFLINE (err u202))
(define-constant ERR_INVALID_STATUS (err u203))

;; Device status constants
(define-constant STATUS_OFFLINE u0)
(define-constant STATUS_ONLINE u1)
(define-constant STATUS_MAINTENANCE u2)
(define-constant STATUS_ERROR u3)

;; Data structures
(define-map devices
  { device-id: uint }
  {
    facility-id: uint,
    device-type: (string-ascii 50),
    manufacturer: (string-ascii 50),
    model: (string-ascii 50),
    status: uint,
    last-heartbeat: uint,
    maintenance-due: uint,
    owner: principal
  }
)

(define-map device-metrics
  { device-id: uint, timestamp: uint }
  {
    temperature: uint,
    pressure: uint,
    vibration: uint,
    power-consumption: uint,
    efficiency: uint
  }
)

(define-data-var device-counter uint u0)

;; Register a new IoT device
(define-public (register-device
  (facility-id uint)
  (device-type (string-ascii 50))
  (manufacturer (string-ascii 50))
  (model (string-ascii 50))
)
  (let ((device-id (+ (var-get device-counter) u1)))
    (map-set devices
      { device-id: device-id }
      {
        facility-id: facility-id,
        device-type: device-type,
        manufacturer: manufacturer,
        model: model,
        status: STATUS_OFFLINE,
        last-heartbeat: block-height,
        maintenance-due: (+ block-height u8760), ;; ~2 months
        owner: tx-sender
      }
    )
    (var-set device-counter device-id)
    (ok device-id)
  )
)

;; Update device status
(define-public (update-device-status (device-id uint) (new-status uint))
  (let ((device (unwrap! (map-get? devices { device-id: device-id }) ERR_DEVICE_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner device)) ERR_UNAUTHORIZED)
    (asserts! (<= new-status u3) ERR_INVALID_STATUS)
    (map-set devices
      { device-id: device-id }
      (merge device {
        status: new-status,
        last-heartbeat: block-height
      })
    )
    (ok true)
  )
)

;; Record device metrics
(define-public (record-metrics
  (device-id uint)
  (temperature uint)
  (pressure uint)
  (vibration uint)
  (power-consumption uint)
  (efficiency uint)
)
  (let ((device (unwrap! (map-get? devices { device-id: device-id }) ERR_DEVICE_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner device)) ERR_UNAUTHORIZED)
    (map-set device-metrics
      { device-id: device-id, timestamp: block-height }
      {
        temperature: temperature,
        pressure: pressure,
        vibration: vibration,
        power-consumption: power-consumption,
        efficiency: efficiency
      }
    )
    (ok true)
  )
)

;; Get device details
(define-read-only (get-device (device-id uint))
  (map-get? devices { device-id: device-id })
)

;; Get device metrics
(define-read-only (get-device-metrics (device-id uint) (timestamp uint))
  (map-get? device-metrics { device-id: device-id, timestamp: timestamp })
)

;; Check if device is online
(define-read-only (is-device-online (device-id uint))
  (match (map-get? devices { device-id: device-id })
    device (and
      (is-eq (get status device) STATUS_ONLINE)
      (> (+ (get last-heartbeat device) u144) block-height) ;; Within last day
    )
    false
  )
)

;; Schedule maintenance
(define-public (schedule-maintenance (device-id uint) (maintenance-date uint))
  (let ((device (unwrap! (map-get? devices { device-id: device-id }) ERR_DEVICE_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner device)) ERR_UNAUTHORIZED)
    (map-set devices
      { device-id: device-id }
      (merge device { maintenance-due: maintenance-date })
    )
    (ok true)
  )
)
