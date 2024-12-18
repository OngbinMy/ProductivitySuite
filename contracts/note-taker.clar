;; Note-Taking Contract

;; Define data variables
(define-data-var note-counter uint u0)
(define-map notes uint {
    title: (string-utf8 100),
    content: (string-utf8 10000),
    created-at: uint,
    updated-at: uint,
    owner: principal,
    tags: (list 10 (string-utf8 50)),
    is-encrypted: bool,
    shared-with: (list 10 principal)
})

;; Define a map to track notes by owner
(define-map owner-notes principal (list 100 uint))

;; Create a new note
(define-public (create-note (title (string-utf8 100)) (content (string-utf8 10000)) (tags (list 10 (string-utf8 50))) (is-encrypted bool))
    (let ((note-id (var-get note-counter)))
        (map-set notes note-id {
            title: title,
            content: content,
            created-at: block-height,
            updated-at: block-height,
            owner: tx-sender,
            tags: tags,
            is-encrypted: is-encrypted,
            shared-with: (list)
        })
        (var-set note-counter (+ note-id u1))
        (map-set owner-notes tx-sender
            (unwrap-panic (as-max-len?
                (append (default-to (list) (map-get? owner-notes tx-sender)) note-id)
                u100)))
        (ok note-id)))

;; Update an existing note
(define-public (update-note (note-id uint) (title (string-utf8 100)) (content (string-utf8 10000)) (tags (list 10 (string-utf8 50))))
    (match (map-get? notes note-id)
        note (begin
            (asserts! (is-eq (get owner note) tx-sender) (err u403))
            (map-set notes note-id (merge note {
                title: title,
                content: content,
                updated-at: block-height,
                tags: tags
            }))
            (ok true))
        (err u404)))

;; Get note details
(define-read-only (get-note (note-id uint))
    (match (map-get? notes note-id)
        note (if (or (is-eq (get owner note) tx-sender)
                     (is-some (index-of (get shared-with note) tx-sender)))
                (ok note)
                (err u403))
        (err u404)))

;; Share a note with another user
(define-public (share-note (note-id uint) (user principal))
    (match (map-get? notes note-id)
        note (begin
            (asserts! (is-eq (get owner note) tx-sender) (err u403))
            (asserts! (is-none (index-of (get shared-with note) user)) (err u400))
            (map-set notes note-id (merge note {
                shared-with: (unwrap-panic (as-max-len? (append (get shared-with note) user) u10))
            }))
            (ok true))
        (err u404)))

;; Get notes by owner
(define-read-only (get-notes-by-owner (owner principal))
    (default-to (list) (map-get? owner-notes owner)))

;; Helper function to check if a note has a specific tag
(define-private (note-has-tag (note-id uint) (tag (string-utf8 50)))
    (match (map-get? notes note-id)
        note (and (or (is-eq (get owner note) tx-sender)
                      (is-some (index-of (get shared-with note) tx-sender)))
                  (is-some (index-of (get tags note) tag)))
        false))


