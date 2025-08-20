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

;; private functions

(define-private (is-valid-institution (institution principal))
    (match (map-get? institutions { institution-address: institution })
        institution-data (get verified institution-data)
        false
    )
)
