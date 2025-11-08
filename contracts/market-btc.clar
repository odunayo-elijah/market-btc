;; Title: MarketBTC - Bitcoin-Native Decentralized Marketplace
;;
;; Summary:
;; A fully decentralized marketplace built on Stacks with seamless Bitcoin settlement,
;; supporting direct sales, auctions, brand verification, and customer reviews.
;;
;; Description:
;; This contract enables a trustless commerce ecosystem where merchants can register brands,
;; list products for direct sale or auction, and build reputation through customer reviews.
;; All transactions settle with Bitcoin's security through the Stacks protocol, with
;; transparent platform fees and automated escrow functionality for auctions.

;; Constants 
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-brand-owner (err u101))
(define-constant err-invalid-price (err u102))
(define-constant err-listing-not-found (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-auction-ended (err u105))
(define-constant err-bid-too-low (err u106))
(define-constant err-no-active-auction (err u107))
(define-constant err-invalid-duration (err u108))
(define-constant err-invalid-rating (err u109))
(define-constant err-invalid-input (err u110))

;; Data Variables
(define-data-var platform-fee uint u25) ;; 2.5% fee

;; Data Maps
(define-map Brands principal 
  {
    name: (string-ascii 50),
    verified: bool,
    created-at: uint
  }
)

(define-map Products uint 
  {
    brand: principal,
    name: (string-ascii 100),
    description: (string-ascii 500),
    price: uint,
    available: bool,
    created-at: uint,
    is-auction: bool
  }
)

(define-map Auctions uint
  {
    end-block: uint,
    min-price: uint,
    highest-bid: uint,
    highest-bidder: (optional principal),
    is-active: bool
  }
)

(define-map Reviews {product-id: uint, reviewer: principal}
  {
    rating: uint,
    comment: (string-ascii 200),
    timestamp: uint
  }
)

;; Product ID counter
(define-data-var product-counter uint u0)

;; Brand Management Functions

;; Register a new brand
(define-public (register-brand (name (string-ascii 50)))
  (begin
    (asserts! (> (len name) u0) err-invalid-input)
    (let
      ((brand-data {
        name: name,
        verified: false,
        created-at: stacks-block-height
      }))
      (ok (map-set Brands tx-sender brand-data))
    )
  )
)

;; Verify a brand (owner only)
;; Note: 'brand' parameter is validated by checking existence in Brands map
;; and function is restricted to contract owner only
(define-public (verify-brand (brand principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (let
      ((brand-data (unwrap! (map-get? Brands brand) err-not-brand-owner)))
      (ok (map-set Brands brand 
        (merge brand-data {verified: true})))
    )
  )
)

;; Direct Sale Functions

;; List a new product
(define-public (list-product 
    (name (string-ascii 100))
    (description (string-ascii 500))
    (price uint)
  )
  (let
    ((brand (unwrap! (map-get? Brands tx-sender) err-not-brand-owner))
     (product-id (+ (var-get product-counter) u1)))
    
    (asserts! (> (len name) u0) err-invalid-input)
    (asserts! (> (len description) u0) err-invalid-input)
    (asserts! (> price u0) err-invalid-price)
    (var-set product-counter product-id)
    (ok (map-set Products product-id {
      brand: tx-sender,
      name: name,
      description: description,
      price: price,
      available: true,
      created-at: stacks-block-height,
      is-auction: false
    }))
  )
)

;; Purchase a product
(define-public (purchase-product (product-id uint))
  (let
    ((product (unwrap! (map-get? Products product-id) err-listing-not-found))
     (price (get price product))
     (brand (get brand product))
     (fee (/ (* price (var-get platform-fee)) u1000)))
    
    (asserts! (get available product) err-listing-not-found)
    (asserts! (not (get is-auction product)) err-listing-not-found)
    
    (try! (stx-transfer? fee tx-sender contract-owner))
    (try! (stx-transfer? (- price fee) tx-sender brand))
    (ok (map-set Products product-id 
      (merge product {available: false})))
  )
)

;; Auction Functions

;; Create auction for a product
(define-public (create-auction
    (name (string-ascii 100))
    (description (string-ascii 500))
    (min-price uint)
    (duration uint)
  )
  (let
    ((brand (unwrap! (map-get? Brands tx-sender) err-not-brand-owner))
     (product-id (+ (var-get product-counter) u1))
     (end-block (+ stacks-block-height duration)))
    
    (asserts! (> (len name) u0) err-invalid-input)
    (asserts! (> (len description) u0) err-invalid-input)
    (asserts! (>= duration u10) err-invalid-duration)
    (asserts! (> min-price u0) err-invalid-price)

    (var-set product-counter product-id)
    (map-set Products product-id {
      brand: tx-sender,
      name: name,
      description: description,
      price: min-price,
      available: true,
      created-at: stacks-block-height,
      is-auction: true
    })
    (ok (map-set Auctions product-id {
      end-block: end-block,
      min-price: min-price,
      highest-bid: u0,
      highest-bidder: none,
      is-active: true
    }))
  )
)

;; Place bid on auction
(define-public (place-bid (product-id uint) (bid-amount uint))
  (let
    ((product (unwrap! (map-get? Products product-id) err-listing-not-found))
     (auction (unwrap! (map-get? Auctions product-id) err-no-active-auction)))
    
    (asserts! (get is-active auction) err-auction-ended)
    (asserts! (<= stacks-block-height (get end-block auction)) err-auction-ended)
    (asserts! (>= bid-amount (get min-price auction)) err-bid-too-low)
    (asserts! (> bid-amount (get highest-bid auction)) err-bid-too-low)
    
    ;; Return funds to previous bidder if exists
    (match (get highest-bidder auction)
      prev-bidder (try! (as-contract (stx-transfer? (get highest-bid auction) tx-sender prev-bidder)))
      true)
    
    ;; Accept new bid
    (try! (stx-transfer? bid-amount tx-sender (as-contract tx-sender)))
    (ok (map-set Auctions product-id
      (merge auction {
        highest-bid: bid-amount,
        highest-bidder: (some tx-sender)
      })))
  )
)

;; End auction
(define-public (end-auction (product-id uint))
  (let
    ((product (unwrap! (map-get? Products product-id) err-listing-not-found))
     (auction (unwrap! (map-get? Auctions product-id) err-no-active-auction))
     (brand (get brand product)))
    
    (asserts! (get is-active auction) err-auction-ended)
    (asserts! (> stacks-block-height (get end-block auction)) err-auction-ended)
    
    (match (get highest-bidder auction)
      winner (let ((bid-amount (get highest-bid auction))
                   (fee (/ (* bid-amount (var-get platform-fee)) u1000)))
          ;; Transfer funds from contract
          (try! (as-contract (stx-transfer? fee tx-sender contract-owner)))
          (try! (as-contract (stx-transfer? (- bid-amount fee) tx-sender brand)))
          ;; Update product status
          (map-set Products product-id 
            (merge product {available: false}))
          ;; Close auction
          (map-set Auctions product-id
            (merge auction {is-active: false}))
          (ok true))
      err-no-active-auction)
  )
)

;; Review System

;; Add a review
(define-public (add-review 
    (product-id uint)
    (rating uint)
    (comment (string-ascii 200)))
  (let
    ((product (unwrap! (map-get? Products product-id) err-listing-not-found)))
    (asserts! (<= rating u5) err-invalid-rating)
    (asserts! (> rating u0) err-invalid-rating)
    (asserts! (> (len comment) u0) err-invalid-input)
    (ok (map-set Reviews 
      {product-id: product-id, reviewer: tx-sender}
      {
        rating: rating,
        comment: comment,
        timestamp: stacks-block-height
      }))
  )
)

;; Read-only Functions

(define-read-only (get-product (product-id uint))
  (ok (map-get? Products product-id))
)

(define-read-only (get-brand (brand principal))
  (ok (map-get? Brands brand))
)

(define-read-only (get-review (product-id uint) (reviewer principal))
  (ok (map-get? Reviews {product-id: product-id, reviewer: reviewer}))
)

(define-read-only (get-auction (product-id uint))
  (ok (map-get? Auctions product-id))
)