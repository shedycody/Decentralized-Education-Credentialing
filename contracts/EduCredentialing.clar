;; title: EduCredentialing
;; version: 1.0.0
;; summary: Decentralized education credentialing system using NFTs
;; description: Allows institutions to issue verifiable academic credentials as NFTs



;; token definitions
(define-non-fungible-token credential uint)

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-not-authorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-credential (err u104))
(define-constant err-expired-credential (err u105))
(define-constant err-institution-not-registered (err u106))

;; data vars
(define-data-var last-credential-id uint u0)
(define-data-var total-institutions uint u0)
(define-data-var rankings-updated-block uint u0)

;; data maps
(define-map institutions
    { institution-address: principal }
    {
        name: (string-ascii 100),
        description: (string-ascii 255),
        verified: bool,
        registration-block: uint
    }
)

(define-map credentials
    { credential-id: uint }
    {
        recipient: principal,
        institution: principal,
        credential-type: (string-ascii 50),
        field-of-study: (string-ascii 100),
        degree-level: (string-ascii 50),
        issue-date: uint,
        expiry-date: (optional uint),
        ipfs-hash: (string-ascii 100),
        verified: bool
    }
)

(define-map institution-credentials
    { institution: principal, credential-count: uint }
    { credential-id: uint }
)

(define-map recipient-credentials
    { recipient: principal, index: uint }
    { credential-id: uint }
)

(define-map credential-recipients-count
    { recipient: principal }
    { count: uint }
)

(define-map institution-metrics
    { institution: principal }
    {
        total-issued: uint,
        total-revoked: uint,
        total-validity-duration: uint,
        registration-block: uint,
        reputation-score: uint,
        last-activity-block: uint
    }
)

(define-map institution-rankings
    { rank: uint }
    { institution: principal }
)

(define-map credential-allowlist
    { recipient: principal, authorized: principal }
    { allowed: bool }
)

;; public functions

(define-public (register-institution (name (string-ascii 100)) (description (string-ascii 255)))
    (let
        (
            (caller tx-sender)
            (current-block stacks-block-height)
        )
        (asserts! (is-none (map-get? institutions { institution-address: caller })) err-already-exists)
        (map-set institutions
            { institution-address: caller }
            {
                name: name,
                description: description,
                verified: false,
                registration-block: current-block
            }
        )
        (map-set institution-metrics
            { institution: caller }
            {
                total-issued: u0,
                total-revoked: u0,
                total-validity-duration: u0,
                registration-block: current-block,
                reputation-score: u1000,
                last-activity-block: current-block
            }
        )
        (var-set total-institutions (+ (var-get total-institutions) u1))
        (ok caller)
    )
)

(define-public (verify-institution (institution principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-some (map-get? institutions { institution-address: institution })) err-not-found)
        (map-set institutions
            { institution-address: institution }
            (merge (unwrap-panic (map-get? institutions { institution-address: institution }))
                { verified: true })
        )
        (ok true)
    )
)

(define-public (issue-credential 
    (recipient principal)
    (credential-type (string-ascii 50))
    (field-of-study (string-ascii 100))
    (degree-level (string-ascii 50))
    (expiry-date (optional uint))
    (ipfs-hash (string-ascii 100))
)
    (let
        (
            (caller tx-sender)
            (new-credential-id (+ (var-get last-credential-id) u1))
            (current-block stacks-block-height)
            (institution-data (map-get? institutions { institution-address: caller }))
            (recipient-count (default-to u0 (get count (map-get? credential-recipients-count { recipient: recipient }))))
        )
        (asserts! (is-some institution-data) err-institution-not-registered)
        (asserts! (get verified (unwrap-panic institution-data)) err-not-authorized)
        (asserts! (> (len credential-type) u0) err-invalid-credential)
        (asserts! (> (len field-of-study) u0) err-invalid-credential)
        (asserts! (> (len degree-level) u0) err-invalid-credential)
        
        (try! (nft-mint? credential new-credential-id recipient))
        
        (map-set credentials
            { credential-id: new-credential-id }
            {
                recipient: recipient,
                institution: caller,
                credential-type: credential-type,
                field-of-study: field-of-study,
                degree-level: degree-level,
                issue-date: current-block,
                expiry-date: expiry-date,
                ipfs-hash: ipfs-hash,
                verified: true
            }
        )
        
        (map-set recipient-credentials
            { recipient: recipient, index: recipient-count }
            { credential-id: new-credential-id }
        )
        
        (map-set credential-recipients-count
            { recipient: recipient }
            { count: (+ recipient-count u1) }
        )
        
        (var-set last-credential-id new-credential-id)
        (unwrap-panic (update-institution-metrics-on-issue caller expiry-date))
        (ok new-credential-id)
    )
)

(define-public (revoke-credential (credential-id uint))
    (let
        (
            (credential-data (map-get? credentials { credential-id: credential-id }))
        )
        (asserts! (is-some credential-data) err-not-found)
        (asserts! (is-eq tx-sender (get institution (unwrap-panic credential-data))) err-not-authorized)
        
        (map-set credentials
            { credential-id: credential-id }
            (merge (unwrap-panic credential-data) { verified: false })
        )
        (unwrap-panic (update-institution-metrics-on-revoke (get institution (unwrap-panic credential-data))))
        (ok true)
    )
)

(define-public (transfer (id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) err-not-authorized)
        (asserts! (is-some (nft-get-owner? credential id)) err-not-found)
        (nft-transfer? credential id sender recipient)
    )
)

;; read only functions

(define-read-only (get-last-token-id)
    (ok (var-get last-credential-id))
)

(define-read-only (get-token-uri (id uint))
    (match (map-get? credentials { credential-id: id })
        credential-data (ok (some (get ipfs-hash credential-data)))
        (ok none)
    )
)

(define-read-only (get-owner (id uint))
    (ok (nft-get-owner? credential id))
)

(define-read-only (get-credential (credential-id uint))
    (map-get? credentials { credential-id: credential-id })
)

(define-read-only (get-institution-info (institution principal))
    (map-get? institutions { institution-address: institution })
)

(define-read-only (verify-credential (credential-id uint))
    (match (map-get? credentials { credential-id: credential-id })
        credential-data 
        (let
            (
                (is-verified (get verified credential-data))
                (expiry (get expiry-date credential-data))
                (current-block stacks-block-height)
            )
            (match expiry
                expiry-block (ok (and is-verified (< current-block expiry-block)))
                (ok is-verified)
            )
        )
        (ok false)
    )
)

(define-read-only (is-credential-valid (credential-id uint))
    (match (map-get? credentials { credential-id: credential-id })
        credential-data
        (let
            (
                (expiry (get expiry-date credential-data))
                (current-block stacks-block-height)
                (is-verified (get verified credential-data))
            )
            (and 
                is-verified
                (match expiry
                    expiry-block (< current-block expiry-block)
                    true
                )
            )
        )
        false
    )
)

(define-read-only (get-recipient-credential-count (recipient principal))
    (default-to u0 (get count (map-get? credential-recipients-count { recipient: recipient })))
)

(define-read-only (get-recipient-credential (recipient principal) (index uint))
    (map-get? recipient-credentials { recipient: recipient, index: index })
)

(define-read-only (get-total-institutions)
    (var-get total-institutions)
)

(define-read-only (get-total-credentials)
    (var-get last-credential-id)
)

(define-read-only (is-institution-verified (institution principal))
    (match (map-get? institutions { institution-address: institution })
        institution-data (get verified institution-data)
        false
    )
)

(define-read-only (get-institution-metrics (institution principal))
    (map-get? institution-metrics { institution: institution })
)

(define-read-only (get-institution-reputation (institution principal))
    (match (map-get? institution-metrics { institution: institution })
        metrics-data (get reputation-score metrics-data)
        u0
    )
)

(define-read-only (get-institution-success-rate (institution principal))
    (match (map-get? institution-metrics { institution: institution })
        metrics-data 
        (let
            (
                (total-issued (get total-issued metrics-data))
                (total-revoked (get total-revoked metrics-data))
            )
            (if (> total-issued u0)
                (/ (* (- total-issued total-revoked) u10000) total-issued)
                u10000
            )
        )
        u0
    )
)

(define-read-only (get-institution-avg-validity (institution principal))
    (match (map-get? institution-metrics { institution: institution })
        metrics-data
        (let
            (
                (total-issued (get total-issued metrics-data))
                (total-validity (get total-validity-duration metrics-data))
            )
            (if (> total-issued u0)
                (/ total-validity total-issued)
                u0
            )
        )
        u0
    )
)

(define-read-only (compare-institutions (institution-a principal) (institution-b principal))
    (let
        (
            (rep-a (get-institution-reputation institution-a))
            (rep-b (get-institution-reputation institution-b))
        )
        (if (> rep-a rep-b)
            institution-a
            institution-b
        )
    )
)

(define-read-only (get-top-institutions-by-reputation (limit uint))
    (let
        (
            (max-limit (if (< limit u20) limit u20))
        )
        (fold get-higher-reputation-institution
            (list 
                u1 u2 u3 u4 u5 u6 u7 u8 u9 u10
                u11 u12 u13 u14 u15 u16 u17 u18 u19 u20
            )
            (list)
        )
    )
)

(define-read-only (get-institution-rank (institution principal))
    (let
        (
            (institution-rep (get-institution-reputation institution))
            (better-count (fold count-better-institutions
                (list 
                    u1 u2 u3 u4 u5 u6 u7 u8 u9 u10
                    u11 u12 u13 u14 u15 u16 u17 u18 u19 u20
                )
                { target-rep: institution-rep, count: u0 }
            ))
        )
        (+ (get count better-count) u1)
    )
)

(define-public (add-to-allowlist (authorized principal))
    (ok (map-set credential-allowlist
        { recipient: tx-sender, authorized: authorized }
        { allowed: true }
    ))
)

(define-public (remove-from-allowlist (authorized principal))
    (ok (map-delete credential-allowlist
        { recipient: tx-sender, authorized: authorized }
    ))
)

(define-public (transfer-credential-authorized (credential-id uint) (from principal) (to principal))
    (let
        (
            (is-allowed (default-to false (get allowed (map-get? credential-allowlist { recipient: from, authorized: tx-sender }))))
        )
        (asserts! is-allowed (err u403))
        (asserts! (is-some (map-get? credentials { credential-id: credential-id })) (err u404))
        (ok (map-set credentials
            { credential-id: credential-id }
            (merge (unwrap-panic (map-get? credentials { credential-id: credential-id }))
                { recipient: to }
            )
        ))
    )
)

(define-read-only (is-on-allowlist (recipient principal) (authorized principal))
    (default-to false (get allowed (map-get? credential-allowlist { recipient: recipient, authorized: authorized })))
)

;; private functions

(define-private (is-valid-institution (institution principal))
    (match (map-get? institutions { institution-address: institution })
        institution-data (get verified institution-data)
        false
    )
)

(define-private (update-institution-metrics-on-issue (institution principal) (expiry-date (optional uint)))
    (let
        (
            (current-metrics (default-to 
                {
                    total-issued: u0,
                    total-revoked: u0,
                    total-validity-duration: u0,
                    registration-block: stacks-block-height,
                    reputation-score: u1000,
                    last-activity-block: stacks-block-height
                }
                (map-get? institution-metrics { institution: institution })
            ))
            (validity-duration (match expiry-date
                exp-block (if (> exp-block stacks-block-height) (- exp-block stacks-block-height) u0)
                u31536000
            ))
        )
        (map-set institution-metrics
            { institution: institution }
            (merge current-metrics
                {
                    total-issued: (+ (get total-issued current-metrics) u1),
                    total-validity-duration: (+ (get total-validity-duration current-metrics) validity-duration),
                    last-activity-block: stacks-block-height
                }
            )
        )
        (calculate-and-update-reputation institution)
    )
)

(define-private (update-institution-metrics-on-revoke (institution principal))
    (let
        (
            (current-metrics (default-to 
                {
                    total-issued: u0,
                    total-revoked: u0,
                    total-validity-duration: u0,
                    registration-block: stacks-block-height,
                    reputation-score: u1000,
                    last-activity-block: stacks-block-height
                }
                (map-get? institution-metrics { institution: institution })
            ))
        )
        (map-set institution-metrics
            { institution: institution }
            (merge current-metrics
                {
                    total-revoked: (+ (get total-revoked current-metrics) u1),
                    last-activity-block: stacks-block-height
                }
            )
        )
        (calculate-and-update-reputation institution)
    )
)

(define-private (calculate-and-update-reputation (institution principal))
    (let
        (
            (metrics (unwrap-panic (map-get? institution-metrics { institution: institution })))
            (total-issued (get total-issued metrics))
            (total-revoked (get total-revoked metrics))
            (avg-validity (if (> total-issued u0) 
                (/ (get total-validity-duration metrics) total-issued) 
                u0))
            (registration-age (- stacks-block-height (get registration-block metrics)))
            (success-rate (if (> total-issued u0) 
                (/ (* (- total-issued total-revoked) u10000) total-issued) 
                u10000))
            (validity-score (if (< (/ avg-validity u1000) u5000) (/ avg-validity u1000) u5000))
            (longevity-score (if (< (/ registration-age u100) u2500) (/ registration-age u100) u2500))
            (reputation-score (/ (+ (* success-rate u5) (* validity-score u3) (* longevity-score u2)) u10))
        )
        (map-set institution-metrics
            { institution: institution }
            (merge metrics { reputation-score: reputation-score })
        )
        (ok reputation-score)
    )
)

(define-private (get-higher-reputation-institution (index uint) (acc (list 20 principal)))
    (let
        (
            (institution-addr (map-get? institution-rankings { rank: index }))
        )
        (match institution-addr
            addr-data
            (let
                (
                    (institution (get institution addr-data))
                )
                (if (is-institution-verified institution)
                    (unwrap-panic (as-max-len? (append acc institution) u20))
                    acc
                )
            )
            acc
        )
    )
)

(define-private (count-better-institutions (index uint) (acc { target-rep: uint, count: uint }))
    (let
        (
            (institution-addr (map-get? institution-rankings { rank: index }))
            (target-rep (get target-rep acc))
            (current-count (get count acc))
        )
        (match institution-addr
            addr-data
            (let
                (
                    (institution (get institution addr-data))
                    (institution-rep (get-institution-reputation institution))
                )
                (if (> institution-rep target-rep)
                    { target-rep: target-rep, count: (+ current-count u1) }
                    acc
                )
            )
            acc
        )
    )
)
