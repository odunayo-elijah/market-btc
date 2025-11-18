# 🟧 MarketBTC – Bitcoin-Native Decentralized Marketplace

### A fully decentralized commerce protocol built on **Stacks**, enabling seamless Bitcoin-settled transactions through smart contracts

---

## 📘 Overview

**MarketBTC** is a Clarity smart contract that powers a **Bitcoin-native decentralized marketplace** on the Stacks blockchain. It enables **trustless e-commerce**, **auctions**, and **reputation systems**—all secured by Bitcoin's finality and settlement assurances.

The protocol introduces a full marketplace lifecycle:

* Brand registration and verification
* Product listing for **direct sales** or **auctions**
* Automated escrow for bids and settlements
* Transparent platform fees
* On-chain customer reviews and ratings

All transactions are executed via **Stacks smart contracts**, with final settlement anchored to Bitcoin’s immutable security.

---

## 🧩 System Overview

```
                        ┌──────────────────────────┐
                        │      Marketplace UI      │
                        │ (Web, Wallet, or dApp)   │
                        └────────────┬─────────────┘
                                     │
                    User tx calls →  │  via Clarity
                                     ▼
                 ┌───────────────────────────────┐
                 │       MarketBTC Contract      │
                 │───────────────────────────────│
                 │  • Brand Registry             │
                 │  • Product Listings           │
                 │  • Auctions & Escrow          │
                 │  • Reviews & Ratings          │
                 │  • Fee Management             │
                 └────────────┬──────────────────┘
                              │
                              ▼
                  ┌──────────────────────┐
                  │    Stacks Blockchain │
                  │ (Anchored to Bitcoin)│
                  └──────────────────────┘
```

This architecture ensures:

* **Trustless execution** (no custodial intermediaries)
* **Bitcoin settlement** via the Stacks consensus layer
* **Transparent state** for all marketplace data
* **Composability** with other Stacks contracts and dApps

---

## ⚙️ Contract Architecture

### **Core Components**

| Component                 | Description                                                                                       |
| ------------------------- | ------------------------------------------------------------------------------------------------- |
| **Brands Map**            | Stores registered merchants with metadata (name, verification status, creation time).             |
| **Products Map**          | Tracks product listings for both direct sales and auctions, including metadata and status.        |
| **Auctions Map**          | Manages active auctions, bids, and end-block tracking for time-bound bidding.                     |
| **Reviews Map**           | Records customer feedback tied to `product-id` and `reviewer`, enabling decentralized reputation. |
| **Platform Fee Variable** | Defines marketplace fee percentage (default: `2.5%`).                                             |
| **Product Counter**       | Sequential counter ensuring unique product IDs.                                                   |

---

### **Functional Breakdown**

#### 🏷️ Brand Management

* `register-brand(name)`
  Registers a new merchant with brand metadata.
* `verify-brand(brand)`
  Contract-owner–only function to verify a registered brand.

#### 🛒 Direct Sales

* `list-product(name, description, price)`
  Creates a new product listing under the sender’s brand.
* `purchase-product(product-id)`
  Handles product purchase, automatically splitting platform fees and transferring ownership.

#### 🔨 Auctions

* `create-auction(name, description, min-price, duration)`
  Starts a new auction with minimum bid and duration.
* `place-bid(product-id, bid-amount)`
  Places a bid, auto-refunding the previous bidder.
* `end-auction(product-id)`
  Ends the auction, transferring funds to the brand and finalizing product sale.

#### ⭐ Reviews

* `add-review(product-id, rating, comment)`
  Allows verified buyers to leave ratings and comments, stored immutably on-chain.

#### 🔍 Read-Only Views

* `get-product(product-id)`
* `get-brand(brand)`
* `get-auction(product-id)`
* `get-review(product-id, reviewer)`

These functions allow dApps and frontends to query on-chain data efficiently.

---

## 🔄 Data Flow (High-Level)

1. **Brand Registration**

   * User registers → brand stored in `Brands` map.
   * Optional verification by contract owner.

2. **Product Listing**

   * Registered brand lists item → `Products` map updated.
   * Product set as available for purchase or auction.

3. **Sale / Auction**

   * Buyer initiates purchase or bid → STX transferred via contract.
   * Platform fee split between contract owner and merchant.
   * Product availability toggled off once settled.

4. **Review Submission**

   * Buyer leaves on-chain review tied to `product-id`.
   * Future customers can query reviews via `get-review`.

---

## 🧠 Key Design Decisions

* **Bitcoin Settlement via Stacks:**
  All state changes are confirmed on Stacks but anchored to Bitcoin blocks, ensuring economic finality.

* **Non-Custodial Escrow:**
  STX never held by external wallets — all flows handled via Clarity contract logic.

* **Composable & Extensible:**
  Contract designed modularly — can integrate with Stacks-based NFT stores, identity protocols, or DAO governance modules.

* **Transparent Fees:**
  Marketplace fee set globally via `platform-fee` variable (default: 2.5%).

---

## 🧪 Example Workflow

1. **Merchant registers brand:**

   ```clarity
   (contract-call? .marketbtc register-brand "Bitcoin Coffee Co.")
   ```

2. **Admin verifies brand:**

   ```clarity
   (contract-call? .marketbtc verify-brand tx-sender)
   ```

3. **Merchant lists product:**

   ```clarity
   (contract-call? .marketbtc list-product "BTC Mug" "Stacked ceramic mug" u1500000)
   ```

4. **Customer purchases product:**

   ```clarity
   (contract-call? .marketbtc purchase-product u1)
   ```

5. **Customer leaves review:**

   ```clarity
   (contract-call? .marketbtc add-review u1 u5 "Excellent quality, fast delivery!")
   ```

---

## 🔐 Security Notes

* **Permissioned Verification:** Only the contract owner can verify brands.
* **Escrow Safety:** Bids are auto-refunded on overbid.
* **Error Handling:** All major execution paths include robust assertions and typed error codes.
* **Immutable Records:** Reviews and listings are publicly readable and tamper-proof.

---

## 🧭 Future Extensions

* **Integration with sBTC for native Bitcoin payments**
* **On-chain dispute resolution DAO**
* **Dynamic fee adjustment via governance**
* **Cross-brand promotion or affiliate incentives**

---

## 📄 License

This project is open-sourced under the **MIT License**.
See `LICENSE` file for details.

---

## 🧑‍💻 Contributing

Pull requests, issue reports, and architectural discussions are welcome.
Please ensure your Clarity code is formatted and passes `clarinet check` before submission.
