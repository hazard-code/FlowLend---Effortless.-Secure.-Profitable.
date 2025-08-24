;; FlowLend - Effortless. Secure. Profitable.
;; A streamlined P2P lending platform for seamless STX loans
;; Features: Direct lending, automated interest, collateral protection

;; ===================================
;; CONSTANTS AND ERROR CODES
;; ===================================

(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-LOAN-NOT-FOUND (err u201))
(define-constant ERR-LOAN-ACTIVE (err u202))
(define-constant ERR-LOAN-EXPIRED (err u203))
(define-constant ERR-INSUFFICIENT-AMOUNT (err u204))
(define-constant ERR-LOAN-NOT-ACTIVE (err u205))
(define-constant ERR-ALREADY-REPAID (err u206))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u207))

;; Contract constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MIN-LOAN-AMOUNT u1000000) ;; 1 STX minimum
(define-constant MAX-LOAN-DURATION u1440) ;; ~10 days max
(define-constant LIQUIDATION-THRESHOLD u12000) ;; 120% collateral requirement
(define-constant PLATFORM-FEE u100) ;; 1% platform fee

;; ===================================
;; DATA VARIABLES
;; ===================================

(define-data-var platform-active bool true)
(define-data-var loan-counter uint u0)
(define-data-var total-loans-issued uint u0)
(define-data-var total-loans-repaid uint u0)
(define-data-var platform-revenue uint u0)

;; ===================================
;; TOKEN DEFINITIONS
;; ===================================

;; Collateral tokens
(define-fungible-token collateral-token)

;; ===================================
;; DATA MAPS
;; ===================================

;; Loan records
(define-map loans
  uint
  {
    borrower: principal,
    lender: principal,
    loan-amount: uint,
    interest-rate: uint,
    duration-blocks: uint,
    collateral-amount: uint,
    start-block: uint,
    end-block: uint,
    repaid: bool,
    active: bool
  }
)

;; User lending statistics  
(define-map user-stats
  principal
  {
    loans-borrowed: uint,
    loans-lent: uint,
    total-borrowed: uint,
    total-lent: uint,
    active-loans: uint,
    reputation-score: uint
  }
)

;; Available lending offers
(define-map lending-offers
  uint
  {
    lender: principal,
    max-amount: uint,
    interest-rate: uint,
    max-duration: uint,
    min-collateral-ratio: uint,
    active: bool
  }
)

;; ===================================
;; PRIVATE HELPER FUNCTIONS
;; ===================================

(define-private (is-contract-owner (user principal))
  (is-eq user CONTRACT-OWNER)
)

(define-private (calculate-interest (principal-amount uint) (rate uint) (blocks uint))
  (let (
    (annual-interest (/ (* principal-amount rate) u10000))
    (blocks-per-year u52560)
  )
    (/ (* annual-interest blocks) blocks-per-year)
  )
)

(define-private (calculate-platform-fee (amount uint))
  (/ (* amount PLATFORM-FEE) u10000)
)

(define-private (is-loan-expired (loan-id uint))
  (match (map-get? loans loan-id)
    loan-data
    (>= burn-block-height (get end-block loan-data))
    false
  )
)

(define-private (calculate-collateral-ratio (collateral uint) (loan-amount uint))
  (if (> loan-amount u0)
    (/ (* collateral u10000) loan-amount)
    u0
  )
)

;; ===================================
;; READ-ONLY FUNCTIONS
;; ===================================

(define-read-only (get-platform-info)
  {
    active: (var-get platform-active),
    total-loans: (var-get loan-counter),
    loans-issued: (var-get total-loans-issued),
    loans-repaid: (var-get total-loans-repaid),
    platform-revenue: (var-get platform-revenue)
  }
)

(define-read-only (get-loan (loan-id uint))
  (map-get? loans loan-id)
)

(define-read-only (get-user-stats (user principal))
  (map-get? user-stats user)
)

(define-read-only (get-lending-offer (offer-id uint))
  (map-get? lending-offers offer-id)
)

(define-read-only (calculate-repayment-amount (loan-id uint))
  (match (map-get? loans loan-id)
    loan-data
    (let (
      (blocks-elapsed (- burn-block-height (get start-block loan-data)))
      (interest (calculate-interest (get loan-amount loan-data) (get interest-rate loan-data) blocks-elapsed))
      (platform-fee (calculate-platform-fee (get loan-amount loan-data)))
    )
      (some (+ (get loan-amount loan-data) interest platform-fee))
    )
    none
  )
)

(define-read-only (get-loan-status (loan-id uint))
  (match (map-get? loans loan-id)
    loan-data
    (if (get repaid loan-data)
      (some "repaid")
      (if (is-loan-expired loan-id)
        (some "expired")
        (if (get active loan-data)
          (some "active")
          (some "inactive")
        )
      )
    )
    none
  )
)

;; ===================================
;; ADMIN FUNCTIONS
;; ===================================

(define-public (toggle-platform (active bool))
  (begin
    (asserts! (is-contract-owner tx-sender) ERR-NOT-AUTHORIZED)
    (var-set platform-active active)
    (print { action: "platform-toggled", active: active })
    (ok true)
  )
)

(define-public (withdraw-platform-fees (amount uint))
  (begin
    (asserts! (is-contract-owner tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (<= amount (var-get platform-revenue)) ERR-INSUFFICIENT-AMOUNT)
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (var-set platform-revenue (- (var-get platform-revenue) amount))
    (print { action: "fees-withdrawn", amount: amount })
    (ok true)
  )
)

(define-public (mint-collateral (amount uint) (recipient principal))
  (begin
    (asserts! (is-contract-owner tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INSUFFICIENT-AMOUNT)
    (try! (ft-mint? collateral-token amount recipient))
    (print { action: "collateral-minted", amount: amount, recipient: recipient })
    (ok true)
  )
)

;; ===================================
;; LENDING OFFER FUNCTIONS
;; ===================================

(define-public (create-lending-offer 
  (max-amount uint) 
  (interest-rate uint) 
  (max-duration uint)
  (min-collateral-ratio uint)
)
  (let (
    (offer-id (+ (var-get loan-counter) u1))
  )
    (asserts! (var-get platform-active) ERR-NOT-AUTHORIZED)
    (asserts! (> max-amount u0) ERR-INSUFFICIENT-AMOUNT)
    (asserts! (<= max-duration MAX-LOAN-DURATION) ERR-INSUFFICIENT-AMOUNT)
    (asserts! (>= min-collateral-ratio LIQUIDATION-THRESHOLD) ERR-INSUFFICIENT-COLLATERAL)
    
    ;; Create lending offer
    (map-set lending-offers offer-id {
      lender: tx-sender,
      max-amount: max-amount,
      interest-rate: interest-rate,
      max-duration: max-duration,
      min-collateral-ratio: min-collateral-ratio,
      active: true
    })
    
    (print { action: "lending-offer-created", offer-id: offer-id, lender: tx-sender, max-amount: max-amount })
    (ok offer-id)
  )
)

(define-public (cancel-lending-offer (offer-id uint))
  (let (
    (offer-data (unwrap! (map-get? lending-offers offer-id) ERR-LOAN-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get lender offer-data)) ERR-NOT-AUTHORIZED)
    (asserts! (get active offer-data) ERR-LOAN-NOT-ACTIVE)
    
    (map-set lending-offers offer-id (merge offer-data { active: false }))
    (print { action: "lending-offer-cancelled", offer-id: offer-id })
    (ok true)
  )
)

;; ===================================
;; LOAN FUNCTIONS
;; ===================================

(define-public (request-loan 
  (offer-id uint)
  (loan-amount uint)
  (duration-blocks uint)
  (collateral-amount uint)
)
  (let (
    (loan-id (+ (var-get loan-counter) u1))
    (offer-data (unwrap! (map-get? lending-offers offer-id) ERR-LOAN-NOT-FOUND))
    (end-block (+ burn-block-height duration-blocks))
    (collateral-ratio (calculate-collateral-ratio collateral-amount loan-amount))
    (borrower-stats (default-to { loans-borrowed: u0, loans-lent: u0, total-borrowed: u0, total-lent: u0, active-loans: u0, reputation-score: u0 }
                                (map-get? user-stats tx-sender)))
    (lender-stats (default-to { loans-borrowed: u0, loans-lent: u0, total-borrowed: u0, total-lent: u0, active-loans: u0, reputation-score: u0 }
                              (map-get? user-stats (get lender offer-data))))
  )
    (asserts! (var-get platform-active) ERR-NOT-AUTHORIZED)
    (asserts! (get active offer-data) ERR-LOAN-NOT-ACTIVE)
    (asserts! (>= loan-amount MIN-LOAN-AMOUNT) ERR-INSUFFICIENT-AMOUNT)
    (asserts! (<= loan-amount (get max-amount offer-data)) ERR-INSUFFICIENT-AMOUNT)
    (asserts! (<= duration-blocks (get max-duration offer-data)) ERR-INSUFFICIENT-AMOUNT)
    (asserts! (>= collateral-ratio (get min-collateral-ratio offer-data)) ERR-INSUFFICIENT-COLLATERAL)
    
    ;; Transfer collateral to contract
    (try! (ft-transfer? collateral-token collateral-amount tx-sender (as-contract tx-sender)))
    
    ;; Transfer loan amount from lender to borrower  
    (try! (stx-transfer? loan-amount (get lender offer-data) tx-sender))
    
    ;; Create loan record
    (map-set loans loan-id {
      borrower: tx-sender,
      lender: (get lender offer-data),
      loan-amount: loan-amount,
      interest-rate: (get interest-rate offer-data),
      duration-blocks: duration-blocks,
      collateral-amount: collateral-amount,
      start-block: burn-block-height,
      end-block: end-block,
      repaid: false,
      active: true
    })
    
    ;; Update user statistics
    (map-set user-stats tx-sender (merge borrower-stats {
      loans-borrowed: (+ (get loans-borrowed borrower-stats) u1),
      total-borrowed: (+ (get total-borrowed borrower-stats) loan-amount),
      active-loans: (+ (get active-loans borrower-stats) u1)
    }))
    
    (map-set user-stats (get lender offer-data) (merge lender-stats {
      loans-lent: (+ (get loans-lent lender-stats) u1),
      total-lent: (+ (get total-lent lender-stats) loan-amount),
      active-loans: (+ (get active-loans lender-stats) u1)
    }))
    
    ;; Update global stats
    (var-set loan-counter loan-id)
    (var-set total-loans-issued (+ (var-get total-loans-issued) u1))
    
    (print { action: "loan-created", loan-id: loan-id, borrower: tx-sender, lender: (get lender offer-data), amount: loan-amount })
    (ok loan-id)
  )
)

(define-public (repay-loan (loan-id uint))
  (let (
    (loan-data (unwrap! (map-get? loans loan-id) ERR-LOAN-NOT-FOUND))
    (repayment-amount (unwrap! (calculate-repayment-amount loan-id) ERR-LOAN-NOT-FOUND))
    (platform-fee (calculate-platform-fee (get loan-amount loan-data)))
    (lender-payment (- repayment-amount platform-fee))
    (borrower-stats (default-to { loans-borrowed: u0, loans-lent: u0, total-borrowed: u0, total-lent: u0, active-loans: u0, reputation-score: u0 }
                                (map-get? user-stats tx-sender)))
    (lender-stats (default-to { loans-borrowed: u0, loans-lent: u0, total-borrowed: u0, total-lent: u0, active-loans: u0, reputation-score: u0 }
                              (map-get? user-stats (get lender loan-data))))
  )
    (asserts! (var-get platform-active) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq tx-sender (get borrower loan-data)) ERR-NOT-AUTHORIZED)
    (asserts! (get active loan-data) ERR-LOAN-NOT-ACTIVE)
    (asserts! (not (get repaid loan-data)) ERR-ALREADY-REPAID)
    
    ;; Transfer repayment to lender
    (try! (stx-transfer? lender-payment tx-sender (get lender loan-data)))
    
    ;; Transfer platform fee
    (try! (stx-transfer? platform-fee tx-sender (as-contract tx-sender)))
    
    ;; Return collateral to borrower
    (try! (as-contract (ft-transfer? collateral-token (get collateral-amount loan-data) tx-sender tx-sender)))
    
    ;; Mark loan as repaid
    (map-set loans loan-id (merge loan-data { repaid: true, active: false }))
    
    ;; Update user statistics
    (map-set user-stats tx-sender (merge borrower-stats {
      active-loans: (- (get active-loans borrower-stats) u1),
      reputation-score: (+ (get reputation-score borrower-stats) u1)
    }))
    
    (map-set user-stats (get lender loan-data) (merge lender-stats {
      active-loans: (- (get active-loans lender-stats) u1),
      reputation-score: (+ (get reputation-score lender-stats) u1)
    }))
    
    ;; Update global stats
    (var-set total-loans-repaid (+ (var-get total-loans-repaid) u1))
    (var-set platform-revenue (+ (var-get platform-revenue) platform-fee))
    
    (print { action: "loan-repaid", loan-id: loan-id, borrower: tx-sender, amount: repayment-amount })
    (ok repayment-amount)
  )
)

(define-public (liquidate-loan (loan-id uint))
  (let (
    (loan-data (unwrap! (map-get? loans loan-id) ERR-LOAN-NOT-FOUND))
  )
    (asserts! (var-get platform-active) ERR-NOT-AUTHORIZED)
    (asserts! (get active loan-data) ERR-LOAN-NOT-ACTIVE)
    (asserts! (not (get repaid loan-data)) ERR-ALREADY-REPAID)
    (asserts! (is-loan-expired loan-id) ERR-LOAN-ACTIVE)
    
    ;; Transfer collateral to lender
    (try! (as-contract (ft-transfer? collateral-token (get collateral-amount loan-data) tx-sender (get lender loan-data))))
    
    ;; Mark loan as inactive
    (map-set loans loan-id (merge loan-data { active: false }))
    
    (print { action: "loan-liquidated", loan-id: loan-id, liquidator: tx-sender })
    (ok true)
  )
)

;; ===================================
;; INITIALIZATION
;; ===================================

(begin
  (print { action: "flowlend-initialized", owner: CONTRACT-OWNER })
)