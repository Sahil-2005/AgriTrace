# 🔧 AgriTrace System Architecture

> Technical documentation for developers and system architects

---

## 📁 Project Structure

```
src/
├── components/       # Reusable UI components
├── contexts/         # React Context providers
│   ├── AuthContext.tsx      # Supabase JWT auth
│   └── Web3Context.tsx      # MetaMask wallet
├── contracts/        # Blockchain configuration
│   └── config.ts            # Contract address, ABI
├── hooks/            # Custom React hooks
│   └── useContract.ts       # Smart contract interactions
├── pages/            # Route components
├── services/         # External API integrations
│   ├── voicegenieService.ts         # VoiceGenie API
│   ├── geminiService.ts             # Google Gemini AI
│   └── voicegenieBatchRegistration.ts
├── utils/            # Utility functions
│   ├── singleStepGroupManager.ts    # Pinata IPFS upload
│   ├── blockchainTransactionManager.ts
│   └── transactionManager.ts
└── integrations/     # Supabase client
```

---

## 🔐 Hybrid Authentication Model

AgriTrace uses a **dual authentication system**:

```mermaid
flowchart LR
    subgraph Web["Web Auth (Supabase)"]
        A[User Login] --> B[JWT Token]
        B --> C[Session Management]
        C --> D[Database Access]
    end
    
    subgraph Blockchain["Blockchain Auth (MetaMask)"]
        E[Connect Wallet] --> F[Sign Transaction]
        F --> G[Smart Contract Call]
        G --> H[On-chain Record]
    end
    
    D -.->|"Links via wallet_address"| H
```

### Supabase Auth (Web Session)
- **Purpose**: User identity, session management, database access
- **Token**: JWT stored in browser
- **Roles**: `farmer` | `distributor` | `retailer` | `admin` | `helper` | `driver`

### MetaMask Auth (Blockchain)
- **Purpose**: Sign transactions, interact with smart contract
- **Network**: Sepolia Testnet (Chain ID: `11155111`)
- **Contract**: `0xf8e81D47203A594245E36C48e151709F0C19fBe8`

---

## 🗄️ Database Schema

```mermaid
erDiagram
    PROFILES ||--o{ BATCHES : creates
    PROFILES ||--o{ TRANSACTIONS : participates
    BATCHES ||--o| MARKETPLACE : listed_on
    BATCHES ||--o{ TRANSACTIONS : involves

    PROFILES {
        uuid id PK
        uuid user_id FK
        string full_name
        string email
        enum user_type
        string wallet_address
        string farm_location
    }

    BATCHES {
        uuid id PK
        uuid farmer_id FK
        string crop_type
        string variety
        float harvest_quantity
        float price_per_kg
        string ipfs_hash
        string blockchain_id
        enum status
        uuid current_owner FK
    }

    MARKETPLACE {
        uuid id PK
        uuid batch_id FK
        uuid current_seller_id FK
        float price
        float quantity
        enum status
    }

    TRANSACTIONS {
        uuid id PK
        uuid batch_id FK
        string type
        uuid from_user FK
        uuid to_user FK
        float quantity
        float price
        string ipfs_hash
        timestamp created_at
    }
```

### Key Fields
| Table | Key Fields | Purpose |
|-------|-----------|---------|
| `profiles` | `wallet_address`, `user_type` | Links Web2 identity to Web3 wallet |
| `batches` | `ipfs_hash`, `blockchain_id` | Connects off-chain to on-chain data |
| `transactions` | `type`, `ipfs_hash` | Records supply chain events |

---

## 🔄 Batch Lifecycle

The complete flow from farmer registration to blockchain record:

```mermaid
flowchart TB
    subgraph Input["1️⃣ Data Input"]
        A[Farmer Phone Call] --> B[VoiceGenie API]
        C[Web Form] --> D[Direct Input]
    end

    subgraph Process["2️⃣ Data Processing"]
        B --> E[Gemini AI Extraction]
        E --> F{Admin Review}
        D --> F
        F -->|Approved| G[Generate PDF Certificate]
    end

    subgraph Storage["3️⃣ Decentralized Storage"]
        G --> H[Upload to Pinata IPFS]
        H --> I[Return IPFS Hash]
    end

    subgraph Blockchain["4️⃣ Blockchain Record"]
        I --> J[Create Batch Input]
        J --> K[Sign with MetaMask]
        K --> L[Smart Contract: registerBatch]
        L --> M[Return Transaction Hash]
    end

    subgraph Database["5️⃣ Database Sync"]
        M --> N[Save to Supabase]
        N --> O[Add to Marketplace]
    end
```

---

## 📞 VoiceGenie Integration

```mermaid
sequenceDiagram
    participant F as Farmer
    participant VG as VoiceGenie API
    participant AI as Gemini AI
    participant HD as Helper Desk
    
    F->>VG: Phone Call
    VG->>VG: Record & Transcribe
    VG->>AI: Send Transcript
    AI->>AI: Extract JSON Data
    AI->>HD: Return Structured Data
    HD->>HD: Admin Reviews
    Note right of HD: cropType, variety,<br/>quantity, dates,<br/>price, grading
```

### Extracted Data Structure
```typescript
{
  cropType: string,      // "Rice", "Wheat"
  variety: string,       // "Basmati", "HMT"
  harvestQuantity: number,
  sowingDate: string,
  harvestDate: string,
  pricePerKg: number,
  grading: string,       // "A", "B", "C"
  certification: string  // "Organic", "Standard"
}
```

---

## ⛓️ Smart Contract

**Contract**: `AgriTrace.sol` on Sepolia Testnet

### Key Functions

```solidity
// Register new batch
function registerBatch(BatchInput calldata input) external

// Transfer ownership
function transferBatch(uint256 batchId, address to) external

// Record purchase
function recordPurchase(
    uint256 batchId,
    address from,
    address to,
    uint256 quantity,
    uint256 price
) external
```

### Events Emitted
| Event | Parameters | Purpose |
|-------|-----------|---------|
| `BatchRegistered` | batchId, farmer, crop, ipfsHash, price | New batch created |
| `BatchOwnershipTransferred` | batchId, from, to | Ownership change |
| `PurchaseRecorded` | batchId, from, to, quantity, price | Transaction logged |

---

## 📦 IPFS Storage (Pinata)

```mermaid
flowchart LR
    A[Harvest Certificate PDF] --> B[Pinata API]
    B --> C[Create Group]
    C --> D[Upload to Group]
    D --> E[Return CID/Hash]
    E --> F[Store in batch.ipfs_hash]
```

### Storage Details
- **Gateway**: `https://gateway.pinata.cloud/ipfs/`
- **File Format**: PDF Certificate
- **Naming**: `{farmer}_{crop}_{variety}_{timestamp}`

---

## 🔗 Data Flow Summary

```mermaid
flowchart LR
    subgraph External["External Services"]
        VG[VoiceGenie]
        AI[Gemini AI]
        IPFS[Pinata IPFS]
    end

    subgraph App["AgriTrace App"]
        FE[React Frontend]
        CTX[Contexts]
    end

    subgraph Storage["Data Storage"]
        DB[(Supabase)]
        BC[Ethereum]
    end

    VG --> AI
    AI --> FE
    FE --> CTX
    CTX --> DB
    CTX --> IPFS
    CTX --> BC
    IPFS -.->|hash| BC
    BC -.->|blockchain_id| DB
```

---

## 🛠️ Tech Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Frontend** | React + TypeScript | UI Components |
| **Styling** | Tailwind CSS + shadcn/ui | Design System |
| **Auth** | Supabase Auth | JWT Sessions |
| **Database** | Supabase (PostgreSQL) | Relational Data |
| **Blockchain** | Ethereum (Sepolia) | Immutable Records |
| **Smart Contract** | Solidity 0.8.20 | On-chain Logic |
| **Web3** | ethers.js v6 | Blockchain Interaction |
| **IPFS** | Pinata | Decentralized Storage |
| **AI** | Google Gemini | Data Extraction |
| **Voice** | VoiceGenie | Phone Registrations |

---

## 🔧 Key Services

### `voicegenieBatchRegistration.ts`
Orchestrates the complete batch registration:
1. Get/Create farmer profile
2. Generate certificate → Upload to Pinata
3. Register on blockchain
4. Save to database
5. Add to marketplace

### `singleStepGroupManager.ts`
Manages Pinata IPFS uploads:
- Creates file groups per batch
- Generates PDF certificates
- Returns IPFS hash (CID)

### `blockchainTransactionManager.ts`
Handles blockchain interactions:
- Records harvest transactions
- Records purchase transactions
- Manages signer state

---

*Last updated: AgriTrace v1.0*
