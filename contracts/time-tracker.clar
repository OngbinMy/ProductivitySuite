;; Time-Tracking Contract

;; Define data variables
(define-data-var session-counter uint u0)
(define-map sessions uint {
  start-time: uint,
  end-time: (optional uint),
  description: (string-utf8 500),
  owner: principal,
  tags: (list 10 (string-utf8 50))
})

;; Define a map to track sessions by user
(define-map user-sessions principal (list 100 uint))

;; Start a new time tracking session
(define-public (start-session (description (string-utf8 500)) (tags (list 10 (string-utf8 50))))
  (let ((session-id (var-get session-counter)))
    (map-set sessions session-id {
      start-time: block-height,
      end-time: none,
      description: description,
      owner: tx-sender,
      tags: tags
    })
    (var-set session-counter (+ session-id u1))
    (map-set user-sessions tx-sender 
      (unwrap-panic (as-max-len? 
        (append (default-to (list) (map-get? user-sessions tx-sender)) session-id) 
        u100)))
    (ok session-id)))

;; End an ongoing time tracking session
(define-public (end-session (session-id uint))
  (match (map-get? sessions session-id)
    session (begin
      (asserts! (is-eq (get owner session) tx-sender) (err u403))
      (asserts! (is-none (get end-time session)) (err u400))
      (map-set sessions session-id (merge session {
        end-time: (some block-height)
      }))
      (ok true))
    (err u404)))

;; Update session details
(define-public (update-session (session-id uint) (description (string-utf8 500)) (tags (list 10 (string-utf8 50))))
  (match (map-get? sessions session-id)
    session (begin
      (asserts! (is-eq (get owner session) tx-sender) (err u403))
      (map-set sessions session-id (merge session {
        description: description,
        tags: tags
      }))
      (ok true))
    (err u404)))

;; Get session details
(define-read-only (get-session (session-id uint))
  (match (map-get? sessions session-id)
    session (if (is-eq (get owner session) tx-sender)
                (ok session)
                (err u403))
    (err u404)))

;; Get sessions by user
(define-read-only (get-sessions-by-user (user principal))
  (default-to (list) (map-get? user-sessions user)))

;; Helper function to check if a session has a specific tag
(define-private (session-has-tag (session-id uint) (tag (string-utf8 50)))
  (match (map-get? sessions session-id)
    session (and (is-eq (get owner session) tx-sender)
                 (is-some (index-of (get tags session) tag)))
    false))