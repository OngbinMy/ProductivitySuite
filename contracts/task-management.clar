;; Task Manager Contract

;; Define data variables
(define-data-var task-counter uint u0)
(define-map tasks uint {
  title: (string-utf8 100),
  description: (string-utf8 500),
  status: (string-ascii 20),
  due-date: uint,
  created-by: principal,
  assigned-to: (optional principal)
})

;; Define constants for task status
(define-constant STATUS_TODO "todo")
(define-constant STATUS_IN_PROGRESS "in_progress")
(define-constant STATUS_COMPLETED "completed")

;; Create a new task
(define-public (create-task (title (string-utf8 100)) (description (string-utf8 500)) (due-date uint))
  (let ((task-id (var-get task-counter)))
    (map-set tasks task-id {
      title: title,
      description: description,
      status: STATUS_TODO,
      due-date: due-date,
      created-by: tx-sender,
      assigned-to: none
    })
    (var-set task-counter (+ task-id u1))
    (ok task-id)))

;; Update task status
(define-public (update-task-status (task-id uint) (new-status (string-ascii 20)))
  (match (map-get? tasks task-id)
    task (begin
      (asserts! (or (is-eq new-status STATUS_TODO)
                    (is-eq new-status STATUS_IN_PROGRESS)
                    (is-eq new-status STATUS_COMPLETED))
                (err u403))
      (map-set tasks task-id (merge task {status: new-status}))
      (ok true))
    (err u404)))

;; Assign task to a user
(define-public (assign-task (task-id uint) (assignee principal))
  (match (map-get? tasks task-id)
    task (begin
      (map-set tasks task-id (merge task {assigned-to: (some assignee)}))
      (ok true))
    (err u404)))

;; Get task details
(define-read-only (get-task (task-id uint))
  (map-get? tasks task-id))

;; Get tasks by status
(define-read-only (get-tasks-by-status (status (string-ascii 20)))
  (filter check-task-status (range (var-get task-counter))))

;; Get tasks by assignee
(define-read-only (get-tasks-by-assignee (assignee principal))
  (filter check-task-assignee (range (var-get task-counter))))

;; Helper function to check task status
(define-private (check-task-status (task-id uint))
  (match (get-task task-id)
    task (is-eq (get status task) STATUS_TODO)
    false))

;; Helper function to check task assignee
(define-private (check-task-assignee (task-id uint))
  (match (get-task task-id)
    task (is-eq (get assigned-to task) (some tx-sender))
    false))

;; Helper function to generate a range of numbers
(define-private (range (n uint))
  (map uint-to-uint (unwrap-panic (as-max-len? (list n) u100))))

;; Helper function for range
(define-private (uint-to-uint (n uint))
  (- n u1))

