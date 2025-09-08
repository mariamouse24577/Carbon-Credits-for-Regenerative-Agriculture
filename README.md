# 🌱 CarbonFarm - Carbon Credits for Regenerative Agriculture

A decentralized protocol for tokenizing and trading carbon credits earned through regenerative farming practices on the Stacks blockchain.

## 🎯 Overview

CarbonFarm enables farmers to earn tradeable carbon credits by implementing verified regenerative agriculture practices. The smart contract manages farm registration, verification, credit issuance, and carbon offset trading.

## ✨ Features

- 🚜 **Farm Registration**: Register farms with location, size, and regenerative practices
- ✅ **Verification System**: Authorized verifiers can validate farming practices and award credits
- 🪙 **Carbon Credits**: Fungible token representing verified carbon sequestration
- 💰 **Credit Trading**: Direct peer-to-peer transfer of carbon credits
- 🛒 **Carbon Offsets**: Purchase and retire carbon credits for offsetting emissions
- 📊 **Transparent Tracking**: All transactions and verifications recorded on-chain

## 🌾 Supported Regenerative Practices

- Cover crops
- No-till farming
- Rotational grazing
- Composting
- Agroforestry

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for mainnet/testnet deployment

### Installation

1. Clone the repository
2. Run tests: `clarinet test`
3. Check contract: `clarinet check`
4. Deploy: `clarinet deploy`

## 📋 Usage

### For Farmers

#### 1. Register Your Farm
```clarity
(contract-call? .CarbonFarm register-farm 
  "Green Valley Farm"
  "Iowa, USA" 
  u500 
  (list "cover-crops" "no-till"))
```

#### 2. Get Verified
Wait for an authorized verifier to validate your practices and award credits.

#### 3. Trade Credits
```clarity
(contract-call? .CarbonFarm transfer-credits u100 'SP2RECIPIENT...)
```

### For Verifiers

#### Verify a Farm
```clarity
(contract-call? .CarbonFarm verify-farm 
  'SPFARM... 
  u250 
  "cover-crops")
```

### For Carbon Credit Buyers

#### Purchase Offsets
```clarity
(contract-call? .CarbonFarm purchase-offset u50 'SPFARM...)
```

#### Retire Credits
```clarity
(contract-call? .CarbonFarm retire-offset u1)
```

## 📖 Contract Functions

### Public Functions

| Function | Description |
|----------|-------------|
| `register-farm` | Register a new farm with practices |
| `add-verifier` | Add authorized verifier (owner only) |
| `verify-farm` | Verify farm practices and award credits |
| `transfer-credits` | Transfer credits between accounts |
| `purchase-offset` | Buy carbon credits from a farm |
| `retire-offset` | Permanently retire carbon credits |
| `update-carbon-price` | Update credit price (owner only) |

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-farm-info` | Get farm registration details |
| `get-carbon-balance` | Get account's carbon credit balance |
| `get-total-supply` | Get total carbon credits in circulation |
| `get-carbon-price` | Get current price per credit |
| `get-verification-info` | Get farm verification history |
| `get-offset-info` | Get carbon offset details |

## 💳 Token Economics

- **Carbon Credit Symbol**: `carbon-credit`
- **Initial Price**: 1,000,000 microSTX per credit
- **Supply**: Uncapped, based on verified carbon sequestration
- **Burning**: Credits are burned when retired as offsets

## 🔐 Security Features

- Owner-only functions for verifier management
- Authorization checks for farm verification
- Balance validation for transfers and purchases
- Permanent retirement of offset credits

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Farmers       │    │   Verifiers     │    │   Buyers        │
│                 │    │                 │    │                 │
│ • Register      │    │ • Verify farms  │    │ • Purchase      │
│ • Earn credits  │    │ • Award credits │    │ • Retire credits│
│ • Trade credits │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │  CarbonFarm     │
                    │  Smart Contract │
                    │                 │
                    │ • Farm registry │
                    │ • Credit tokens │
                    │ • Verification  │
                    │ • Trading       │
                    └─────────────────┘
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 🌍 Impact

By using CarbonFarm, farmers are incentivized to adopt regenerative practices that:
- Sequester atmospheric carbon
- Improve soil health
- Enhance biodiversity
- Create sustainable income streams
- Combat climate change

---

*Built with 💚 for a sustainable future*
