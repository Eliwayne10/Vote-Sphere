;; SPDX-License-Identifier: UNLICENSED

;; #[allow(unchecked_data)]

;; ------------------------------------------------------------
;; VoteSphere DAO
;; On-chain tokenless (membership) voting system
;; - Admin manages members and proposals
;; - Members get 1 vote per proposal
;; - Voting windows enforced by block-height
;; - Prevents double-voting
;; --------------------------------------------------------------------

;; Contract version / metadata (comment only)
;; Version: 1.0
;; Author: Generated for user

;; ----------------------------
;; State & Data Definitions
;; ----------------------------

;; Admin (set at deploy time to the deploying principal)
(define-data-var admin principal tx-sender)

;; Members map: { member: principal } -> { is-member: bool }
(define-map members
  { member: principal }
  { is-member: bool }
)

;; Proposal counter
(define-data-var proposal-count uint u0)

;; Proposal structure:
;; id -> {
;;   creator: principal,
;;   title: (string-ascii 80),
;;   description: (string-ascii 280),
;;   votes-for: uint,
;;   votes-against: uint,
;;   start-block: uint,
;;   end-block: uint,
;;   open: bool
;; }
(define-map proposals
  { id: uint }
  {
    creator: principal,
    title: (string-ascii 80),
    description: (string-ascii 280),
    votes-for: uint,
    votes-against: uint,
    start-block: uint,
    end-block: uint,
    open: bool
  }
)

;; Tracks if a voter has voted on a proposal:
;; { proposal-id, voter } -> { voted: bool }
(define-map has-voted
  { proposal-id: uint, voter: principal }
  { voted: bool }
)

;; ----------------------------
;; Events
;; ----------------------------
;; Events are emitted by printing a tuple that includes an "event" string field
;; Example usage: (print { event: "member-added", admin: tx-sender, member: user })

;; ----------------------------
;; PRIVATE HELPERS
;; ----------------------------

(define-private (assert-admin)
  (if (is-eq tx-sender (var-get admin))
    (ok true)
    (err "ERR_UNAUTHORIZED"))
)

(define-private (is-member? (addr principal))
  (match (map-get? members { member: addr })
    m (get is-member m)
    false)
)

(define-private (proposal-exists? (pid uint))
  (is-some (map-get? proposals { id: pid }))
)

;; ----------------------------
;; ADMIN FUNCTIONS
;; ----------------------------

;; Change admin (only current admin)
(define-public (change-admin (new-admin principal))
  (begin
    (try! (assert-admin))
    (let ((old (var-get admin)))
      (var-set admin new-admin)
      (print { event: "admin-changed", old-admin: old, new-admin: new-admin })
      (ok new-admin)
    )
  )
)

;; Add a member (only admin)
(define-public (add-member (user principal))
  (begin
    (try! (assert-admin))
    (map-set members { member: user } { is-member: true })
    (print { event: "member-added", admin: tx-sender, member: user })
    (ok user)
  )
)

;; Remove a member (only admin)
(define-public (remove-member (user principal))
  (begin
    (try! (assert-admin))
    (map-set members { member: user } { is-member: false })
    (print { event: "member-removed", admin: tx-sender, member: user })
    (ok user)
  )
)

;; start-block and end-block are absolute block-height values
(define-public (create-proposal
                (title (string-ascii 80))
                (description (string-ascii 280))
                (start-block uint)
                (end-block uint))
  (begin
    (try! (assert-admin))

    ;; Validate blocks
    (asserts! (<= burn-block-height end-block) (err "ERR_END_BEFORE_NOW"))
    (asserts! (< start-block end-block) (err "ERR_INVALID_WINDOW"))

    (let ((new-id (+ (var-get proposal-count) u1)))
      (var-set proposal-count new-id)
      (map-set proposals { id: new-id }
        {
          creator: tx-sender,
          title: title,
          description: description,
          votes-for: u0,
          votes-against: u0,
          start-block: start-block,
          end-block: end-block,
          open: true
        })
      (print { event: "proposal-created", id: new-id, creator: tx-sender, title: title, start-block: start-block, end-block: end-block })
      (ok new-id)
    )
  )
)

;; Close a proposal early (only admin)
(define-public (close-proposal (proposal-id uint))
  (begin
    (try! (assert-admin))
    (match (map-get? proposals { id: proposal-id })
      p
      (let ((is-open (get open p)))
        (asserts! is-open (err "ERR_ALREADY_CLOSED"))
        (map-set proposals { id: proposal-id }
          {
            creator: (get creator p),
            title: (get title p),
            description: (get description p),
            votes-for: (get votes-for p),
            votes-against: (get votes-against p),
            start-block: (get start-block p),
            end-block: (get end-block p),
            open: false
          })
        (print { event: "proposal-closed", proposal-id: proposal-id, closed-by: tx-sender })
        (ok "proposal-closed")
      )
      (err "ERR_PROPOSAL_NOT_FOUND")
    )
  )
)

;; ----------------------------
;; PUBLIC / MEMBER FUNCTIONS
;; ----------------------------

;; Cast a vote: support = true -> for, false -> against
(define-public (cast-vote (proposal-id uint) (support bool))
  (begin
    ;; membership check
    (try! (match (map-get? members { member: tx-sender })
      m (if (get is-member m) (ok true) (err "ERR_NOT_MEMBER"))
      (err "ERR_NOT_MEMBER")
    ))

    ;; proposal exists?
    (match (map-get? proposals { id: proposal-id })
      p
      (let (
            (open? (get open p))
            (start (get start-block p))
            (end (get end-block p))
            (now burn-block-height)
           )
        ;; ensure proposal open and within voting window
        (asserts! open? (err "ERR_PROPOSAL_CLOSED"))
        (asserts! (>= now start) (err "ERR_VOTING_NOT_STARTED"))
        (asserts! (<= now end) (err "ERR_VOTING_ENDED"))

        ;; prevent double-voting
        (asserts! (is-none (map-get? has-voted { proposal-id: proposal-id, voter: tx-sender })) (err "ERR_ALREADY_VOTED"))

        ;; mark voted
        (map-set has-voted { proposal-id: proposal-id, voter: tx-sender } { voted: true })

        ;; update counts
        (if support
            (map-set proposals { id: proposal-id }
              {
                creator: (get creator p),
                title: (get title p),
                description: (get description p),
                votes-for: (+ (get votes-for p) u1),
                votes-against: (get votes-against p),
                start-block: start,
                end-block: end,
                open: open?
              })
            (map-set proposals { id: proposal-id }
              {
                creator: (get creator p),
                title: (get title p),
                description: (get description p),
                votes-for: (get votes-for p),
                votes-against: (+ (get votes-against p) u1),
                start-block: start,
                end-block: end,
                open: open?
              }))
        (print { event: "vote-cast", proposal-id: proposal-id, voter: tx-sender, support: support })
        (ok "vote-recorded")
      )
      (err "ERR_PROPOSAL_NOT_FOUND")
    )
  )
)

;; ----------------------------
;; READ-ONLY HELPERS
;; ----------------------------

;; Get proposal by id (returns optional tuple)
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { id: proposal-id })
)

;; Get proposal count
(define-read-only (get-proposal-count)
  (ok (var-get proposal-count))
)

;; Check if an address is a member
(define-read-only (check-member (addr principal))
  (match (map-get? members { member: addr })
    m (ok (get is-member m))
    (ok false)
  )
)

;; Check if a voter has voted on a proposal
(define-read-only (has-voted-on (proposal-id uint) (voter principal))
  (match (map-get? has-voted { proposal-id: proposal-id, voter: voter })
    r (ok (get voted r))
    (ok false)
  )
)

;; Quick result summary for a proposal: returns tuple if exists
(define-read-only (proposal-result (proposal-id uint))
  (match (map-get? proposals { id: proposal-id })
    p
    (ok (tuple (title (get title p))
               (description (get description p))
               (votes-for (get votes-for p))
               (votes-against (get votes-against p))
               (start-block (get start-block p))
               (end-block (get end-block p))
               (open (get open p))))
    (err "ERR_PROPOSAL_NOT_FOUND")
  )
)
