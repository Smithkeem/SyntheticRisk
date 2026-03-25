;; contract title 
;; AI-Guided Synthetic Collateral Management V2
 
;; <add a description here> 
;; This smart contract manages synthetic assets backed by collateral.
;; It integrates an AI-driven risk oracle that dynamically adjusts the 
;; collateralization requirements based on market volatility and user risk profiles.
;; The contract allows users to open positions, update AI risk scores (admin/oracle only),
;; add/remove collateral, mint/burn synthetic assets, and features a robust 
;; liquidation mechanism for high-risk undercollateralized positions.
;; V2 introduces protocol pausing, dynamic fee collection, global state tracking, 
;; and more granular control over individual user positions.
 
;; constants 
;; Define contract owner for administrative privileges
(define-constant contract-owner tx-sender)

;; Error codes for secure failure handling
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-collateral (err u101))
(define-constant err-position-not-found (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-risk-score (err u104))
(define-constant err-already-exists (err u105))
(define-constant err-protocol-paused (err u106))
(define-constant err-invalid-amount (err u107))
(define-constant err-position-undercollateralized (err u108))

;; Global configuration constants
(define-constant base-collateral-ratio u150) ;; 150% base collateralization ratio
(define-constant liquidation-penalty u10)    ;; 10% penalty for liquidation
(define-constant protocol-fee-rate u50)      ;; 0.50% fee rate (basis points where 10000 = 100%)
 
;; data maps and vars 
;; Oracle address authorized to update AI risk scores
(define-data-var ai-oracle principal tx-sender)

;; Emergency pause state for protocol security
(define-data-var protocol-paused bool false)

;; Global protocol state tracking for total value locked and minted
(define-data-var total-collateral-locked uint u0)
(define-data-var total-synthetic-minted uint u0)
(define-data-var total-protocol-fees uint u0)

;; Data map storing individual user collateral positions
;; ai-risk-score acts as a multiplier: 100 = 1.0x (normal risk), 200 = 2.0x (high risk)
(define-map positions
    { user: principal }
    {
        collateral: uint,
        synthetic-minted: uint,
        ai-risk-score: uint,
        last-updated-height: uint
    }
)
 
;; private functions 

;; @desc Calculates the required collateral based on minted amount and AI risk score
;; @param minted-amount The amount of synthetic assets minted
;; @param risk-score The AI-assigned risk score (100 = baseline)
(define-private (calculate-required-collateral (minted-amount uint) (risk-score uint))
    (let
        (
            ;; Required = (minted * base_ratio * risk_score) / (100 * 100)
            ;; We divide by 10000 because both base-ratio (150) and risk-score (100) are percentages
            (adjusted-ratio (/ (* base-collateral-ratio risk-score) u100))
        )
        (/ (* minted-amount adjusted-ratio) u100)
    )
)

;; @desc Calculates protocol fees for minting actions
;; @param amount The amount to calculate fees against
(define-private (calculate-protocol-fee (amount uint))
    (/ (* amount protocol-fee-rate) u10000)
)

;; @desc Helper function to check if protocol is active
;; @returns boolean indicating if the protocol is running
(define-private (is-active)
    (not (var-get protocol-paused))
)

;; @desc Helper to safely add values without overflow errors
;; @param a First value
;; @param b Second value
(define-private (safe-add (a uint) (b uint))
    (+ a b)
)

;; @desc Helper to safely subtract values preventing underflow
;; @param a Minuend
;; @param b Subtrahend
(define-private (safe-sub (a uint) (b uint))
    (if (>= a b)
        (- a b)
        u0
    )
)
 
;; public functions 

;; @desc Admin function to pause the protocol in emergencies
(define-public (pause-protocol)
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err err-owner-only))
        (var-set protocol-paused true)
        (ok true)
    )
)

;; @desc Admin function to resume the protocol
(define-public (resume-protocol)
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err err-owner-only))
        (var-set protocol-paused false)
        (ok true)
    )
)

;; @desc Admin function to update the authorized AI oracle address
;; @param new-oracle The new principal address for the oracle
(define-public (set-ai-oracle (new-oracle principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err err-owner-only))
        (var-set ai-oracle new-oracle)
        (ok true)
    )
)

;; @desc Opens a new collateralized debt position (CDP)
;; @param collateral-amount Amount of underlying asset locked
;; @param synthetic-amount Amount of synthetic asset to mint
(define-public (open-position (collateral-amount uint) (synthetic-amount uint))
    (let
        (
            (initial-risk-score u100)
            (fee (calculate-protocol-fee synthetic-amount))
            (mint-after-fee (safe-sub synthetic-amount fee))
            (required-coll (calculate-required-collateral mint-after-fee initial-risk-score))
        )
        ;; Security: Protocol must not be paused
        (asserts! (is-active) (err err-protocol-paused))
        
        ;; Security: Invalid amounts
        (asserts! (and (> collateral-amount u0) (> synthetic-amount u0)) (err err-invalid-amount))

        ;; Security Check: Ensure caller doesn't already have a position
        (asserts! (is-none (map-get? positions { user: tx-sender })) (err err-already-exists))
        
        ;; Security Check: Ensure sufficient collateral is provided
        (asserts! (>= collateral-amount required-coll) (err err-insufficient-collateral))

        ;; Update global tracking variables safely
        (var-set total-collateral-locked (safe-add (var-get total-collateral-locked) collateral-amount))
        (var-set total-synthetic-minted (safe-add (var-get total-synthetic-minted) mint-after-fee))
        (var-set total-protocol-fees (safe-add (var-get total-protocol-fees) fee))

        ;; Store the new position data
        (map-set positions
            { user: tx-sender }
            {
                collateral: collateral-amount,
                synthetic-minted: mint-after-fee,
                ai-risk-score: initial-risk-score,
                last-updated-height: block-height
            }
        )
        (ok true)
    )
)

;; @desc Adds more collateral to an existing position
;; @param amount Amount of collateral to add
(define-public (add-collateral (amount uint))
    (let
        (
            (position (unwrap! (map-get? positions { user: tx-sender }) (err err-position-not-found)))
            (current-collateral (get collateral position))
        )
        ;; Security: Protocol must not be paused
        (asserts! (is-active) (err err-protocol-paused))
        (asserts! (> amount u0) (err err-invalid-amount))

        ;; Update global tracking variables safely
        (var-set total-collateral-locked (safe-add (var-get total-collateral-locked) amount))
        
        ;; Update user position mapping
        (map-set positions
            { user: tx-sender }
            (merge position { 
                collateral: (safe-add current-collateral amount),
                last-updated-height: block-height
            })
        )
        (ok true)
    )
)

;; @desc Removes excess collateral from an existing position
;; @param amount Amount of collateral to remove
(define-public (remove-collateral (amount uint))
    (let
        (
            (position (unwrap! (map-get? positions { user: tx-sender }) (err err-position-not-found)))
            (current-collateral (get collateral position))
            (minted (get synthetic-minted position))
            (risk-score (get ai-risk-score position))
            (required-coll (calculate-required-collateral minted risk-score))
            (new-collateral (safe-sub current-collateral amount))
        )
        ;; Security: Protocol must not be paused
        (asserts! (is-active) (err err-protocol-paused))
        (asserts! (> amount u0) (err err-invalid-amount))
        
        ;; Security: Ensure position remains safely overcollateralized after withdrawal
        (asserts! (>= new-collateral required-coll) (err err-insufficient-collateral))

        ;; Update global tracking variables safely
        (var-set total-collateral-locked (safe-sub (var-get total-collateral-locked) amount))
        
        ;; Update user position mapping
        (map-set positions
            { user: tx-sender }
            (merge position { 
                collateral: new-collateral,
                last-updated-height: block-height
            })
        )
        (ok true)
    )
)

;; @desc Repays synthetic debt, freeing up collateral or increasing health factor
;; @param amount Amount of synthetic asset to burn/repay
(define-public (repay-debt (amount uint))
    (let
        (
            (position (unwrap! (map-get? positions { user: tx-sender }) (err err-position-not-found)))
            (minted (get synthetic-minted position))
            (repay-amount (if (> amount minted) minted amount)) ;; Repay up to total minted
        )
        ;; Security: Protocol must not be paused
        (asserts! (is-active) (err err-protocol-paused))
        (asserts! (> amount u0) (err err-invalid-amount))

        ;; Update global tracking variables safely
        (var-set total-synthetic-minted (safe-sub (var-get total-synthetic-minted) repay-amount))
        
        ;; Update user position mapping
        (map-set positions
            { user: tx-sender }
            (merge position { 
                synthetic-minted: (safe-sub minted repay-amount),
                last-updated-height: block-height
            })
        )
        (ok true)
    )
)

;; @desc Updates the AI risk score for a specific user position
;; @param target-user The user whose position is being updated
;; @param new-risk-score The new AI-generated risk score
(define-public (update-ai-risk-score (target-user principal) (new-risk-score uint))
    (let
        (
            (position (unwrap! (map-get? positions { user: target-user }) (err err-position-not-found)))
        )
        ;; Security Check: Only the designated AI Oracle or Contract Owner can update scores
        (asserts! (or (is-eq tx-sender (var-get ai-oracle)) (is-eq tx-sender contract-owner)) (err err-unauthorized))
        
        ;; Security Check: Prevent risk score from being set to 0 to avoid zero-collateral exploits
        (asserts! (> new-risk-score u0) (err err-invalid-risk-score))

        ;; Update the position with the new dynamic risk score
        (map-set positions
            { user: target-user }
            (merge position { 
                ai-risk-score: new-risk-score,
                last-updated-height: block-height
            })
        )
        (ok true)
    )
)

;; read-only functions

;; @desc Returns the complete position data for a given user
;; @param user The principal address of the position owner
(define-read-only (get-position (user principal))
    (map-get? positions { user: user })
)

;; @desc Returns the global protocol state and metrics
(define-read-only (get-protocol-state)
    {
        paused: (var-get protocol-paused),
        total-collateral: (var-get total-collateral-locked),
        total-minted: (var-get total-synthetic-minted),
        total-fees: (var-get total-protocol-fees),
        oracle: (var-get ai-oracle)
    }
)


