# 💸 FlowLend - Effortless. Secure. Profitable.

A streamlined peer-to-peer lending platform built on Stacks blockchain that connects borrowers and lenders for seamless STX loans with collateral protection.

## 📋 Overview

FlowLend simplifies P2P lending by enabling direct loans between users with automated interest calculations, collateral management, and built-in liquidation protection. Experience effortless lending that flows naturally.

## ✨ Key Features

### 🏦 Direct P2P Lending
- Create flexible lending offers with custom terms
- Request loans that match your needs
- Automated interest calculation based on time
- Built-in collateral requirements for security

### 🛡️ Collateral Protection
- 120% minimum collateral ratio
- Automatic liquidation for expired loans
- Secure collateral token system
- Risk management through over-collateralization

### 📊 Smart Contract Automation
- Automated repayment calculations
- Interest accrual based on actual loan duration
- Platform fee collection (1%)
- Real-time loan status tracking

### 🎯 User-Friendly Experience
- Simple loan request process
- Clear repayment amounts
- Reputation scoring system
- Comprehensive user statistics

## 🏗️ Architecture

### Core Components
```clarity
loans           -> Individual loan records
lending-offers  -> Available lending opportunities
user-stats      -> User lending history and reputation
```

### Token System
- **STX**: Primary lending asset
- **Collateral Tokens**: Secure loan backing
- **Automated Fees**: 1% platform fee on loans

## 🚀 Getting Started

### For Lenders

1. **Create Lending Offer**: Set your terms and availability
   ```clarity
   (create-lending-offer max-amount interest-rate max-duration min-collateral-ratio)
   ```

2. **Wait for Borrowers**: Your offer becomes available to borrowers
3. **Earn Interest**: Collect repayments with interest automatically

### For Borrowers

1. **Find Lending Offers**: Browse available loan opportunities
   ```clarity
   (get-lending-offer offer-id)
   ```

2. **Request Loan**: Submit loan request with collateral
   ```clarity
   (request-loan offer-id loan-amount duration-blocks collateral-amount)
   ```

3. **Repay On Time**: Pay back principal + interest to retrieve collateral
   ```clarity
   (repay-loan loan-id)
   ```

## 📈 Example Scenarios

### Standard Lending Flow
```
1. Lender creates offer: 100 STX, 10% APR, 30 days, 120% collateral
2. Borrower requests: 50 STX for 15 days with 60 collateral tokens
3. Loan executes: Borrower gets 50 STX, collateral locked
4. Repayment: ~51.03 STX (principal + interest + 1% platform fee)
5. Success: Borrower gets collateral back, lender earns interest
```

### Liquidation Scenario
```
1. Borrower takes 50 STX loan with 60 collateral tokens
2. Loan expires without repayment
3. Anyone can call liquidate-loan()
4. Lender receives the 60 collateral tokens as compensation
```

## ⚙️ Configuration

### Loan Parameters
- **Minimum Loan**: 1 STX
- **Maximum Duration**: ~10 days (1,440 blocks)
- **Collateral Requirement**: 120% minimum ratio
- **Platform Fee**: 1% of loan amount

### Interest Calculation
- **Time-based**: Interest calculated on actual loan duration
- **Flexible Rates**: Lenders set their own interest rates
- **No Compounding**: Simple interest model for clarity

## 🔒 Security Features

### Risk Management
- Over-collateralization protects lenders
- Time limits prevent indefinite loans
- Automated liquidation for expired loans
- Platform fee covers operational costs

### Access Control
- Borrowers can only repay their own loans
- Lenders control their own offers
- Admin functions for platform management

### Error Handling
```clarity
ERR-NOT-AUTHORIZED (u200)         -> Insufficient permissions
ERR-LOAN-NOT-FOUND (u201)         -> Invalid loan/offer ID
ERR-LOAN-ACTIVE (u202)            -> Operation not allowed on active loan
ERR-LOAN-EXPIRED (u203)           -> Loan past due date
ERR-INSUFFICIENT-AMOUNT (u204)    -> Invalid amount parameters
ERR-LOAN-NOT-ACTIVE (u205)        -> Loan not in active state
ERR-ALREADY-REPAID (u206)         -> Loan already paid back
ERR-INSUFFICIENT-COLLATERAL (u207) -> Not enough collateral provided
```

## 📊 Analytics & Metrics

### Platform Statistics
- Total loans issued and repaid
- Platform revenue from fees
- Active loan count
- Overall lending volume

### User Metrics
- Individual lending/borrowing history
- Reputation scores based on successful repayments
- Active loan tracking
- Total volume per user

### Loan Details
- Real-time repayment calculations
- Loan status tracking (active, repaid, expired)
- Interest accrual monitoring
- Collateral ratio tracking

## 🛠️ Development

### Prerequisites
- Clarinet CLI tool
- Stacks blockchain access
- STX tokens for lending
- Collateral tokens for borrowing

### Local Testing
```bash
# Validate contract
clarinet check

# Run comprehensive tests
clarinet test

# Deploy to testnet
clarinet deploy --testnet
```

### Integration Examples
```clarity
;; Create a lending offer
(contract-call? .flowlend create-lending-offer u100000000 u1000 u720 u12000)

;; Request a loan
(contract-call? .flowlend request-loan u1 u50000000 u360 u60000000)

;; Check repayment amount
(contract-call? .flowlend calculate-repayment-amount u1)

;; Repay loan
(contract-call? .flowlend repay-loan u1)
```

## 🎯 Use Cases

### Individual Lending
- Earn passive income through interest
- Help community members with short-term needs
- Build lending reputation over time

### Short-term Borrowing
- Access quick liquidity without selling assets
- Maintain token positions while accessing cash
- Build credit history through timely repayments

### DeFi Integration
- Plugin for larger DeFi ecosystems
- Collateral management for trading platforms
- Credit scoring for other financial products

## 📋 Deployment Checklist

- [ ] Contract passes all validation tests
- [ ] Collateral tokens minted and distributed
- [ ] Platform fee collection configured
- [ ] Admin controls properly secured
- [ ] User documentation complete
- [ ] Frontend integration tested

## 🤝 Contributing

We welcome contributions to improve FlowLend:
- Bug reports and feature requests
- Code optimizations and security improvements
- Documentation updates and examples
- Testing and quality assurance

---

**⚠️ Disclaimer**: FlowLend is experimental lending software. Understand the risks of P2P lending and ensure proper collateral management before participating.
