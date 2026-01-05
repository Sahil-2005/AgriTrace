# 🌾 AgriTrace User Flow Guide

> Simple guide to how different users interact with AgriTrace

---

## 👥 Who Uses AgriTrace?

```mermaid
flowchart LR
    F[🌾 Farmer] --> D[🚚 Distributor] --> R[🏪 Retailer] --> C[👤 Consumer]
```

| User | What They Do |
|------|--------------|
| **Farmer** | Grows crops, registers batches, sells to distributors |
| **Distributor** | Buys from farmers, sells to retailers |
| **Retailer** | Buys from distributors, sells to consumers |
| **Consumer** | Scans QR code to verify product authenticity |

---

## 📱 Two Ways to Register

### Option 1: Phone Call (No Internet Needed)

```mermaid
flowchart LR
    A[📞 Farmer gets call] --> B[🗣️ Tells crop details] --> C[👨‍💼 Admin reviews] --> D[✅ Batch registered]
```

**How it works:**
1. AI calls the farmer in their local language
2. Farmer shares crop details over the phone
3. Admin reviews and approves
4. Farmer gets SMS confirmation

### Option 2: Website (With Internet)

```mermaid
flowchart LR
    A[🌐 Login to website] --> B[🦊 Connect wallet] --> C[📝 Fill form] --> D[✅ Batch registered]
```

**How it works:**
1. Create account & login
2. Connect MetaMask wallet
3. Fill batch details form
4. Sign transaction & done!

---

## 🌾 Farmer Journey

```mermaid
flowchart TD
    A[Register Batch] --> B[Get Certificate]
    B --> C[Listed on Marketplace]
    C --> D[Distributor Buys]
    D --> E[💰 Receive Payment]
```

**What farmers can do:**
- ✅ Register new crop batches
- ✅ Get blockchain certificates
- ✅ Sell to distributors
- ✅ Track all sales

---

## 🚚 Distributor Journey

```mermaid
flowchart TD
    A[Browse Farmer Products] --> B[Purchase Batch]
    B --> C[Add to Inventory]
    C --> D[List for Retailers]
    D --> E[💰 Earn Profit]
```

**What distributors can do:**
- ✅ Buy directly from farmers
- ✅ Manage inventory
- ✅ Set prices for retailers
- ✅ Track purchases & sales

---

## 🏪 Retailer Journey

```mermaid
flowchart TD
    A[Browse Distributor Products] --> B[Purchase Batch]
    B --> C[Add to Store]
    C --> D[Generate QR Codes]
    D --> E[Sell to Customers]
```

**What retailers can do:**
- ✅ Buy from distributors
- ✅ Generate product QR codes
- ✅ Prove product authenticity
- ✅ Build customer trust

---

## 🔍 QR Code Verification

```mermaid
flowchart LR
    A[📱 Scan QR] --> B[🔍 View Details] --> C[✅ Verified!]
```

**What consumers see:**
- 🌾 Farm origin & farmer name
- 📦 Crop type & quality grade
- 📅 Harvest date
- 🔗 Complete supply chain history

---

## 👨‍💼 Admin Helper Desk

```mermaid
flowchart LR
    A[📞 Voice calls arrive] --> B[👀 Review data] --> C{Approve?}
    C -->|Yes| D[✅ Register on blockchain]
    C -->|No| E[📞 Schedule callback]
```

**Admin responsibilities:**
- Review voice registrations
- Verify farmer data
- Approve or reject submissions
- Ensure data quality

---

## 🔄 Complete Product Journey

```mermaid
flowchart LR
    subgraph Farm
        A[🌱 Harvest]
    end
    subgraph Market
        B[🚚 Distribute] --> C[🏪 Retail]
    end
    subgraph Consumer
        D[📱 Verify]
    end
    A --> B
    C --> D
```

**The flow:**
1. **Farmer** harvests & registers crop
2. **Distributor** buys & transports
3. **Retailer** sells to public
4. **Consumer** scans QR to verify

---

## 🔑 Key Features

| Feature | Benefit |
|---------|---------|
| 📱 **QR Codes** | Instant product verification |
| ⛓️ **Blockchain** | Tamper-proof records |
| 📞 **Voice Registration** | No internet required for farmers |
| 📄 **Certificates** | Downloadable proof of origin |

---

## ❓ Quick FAQ

**Q: Do I need internet to register crops?**  
A: No! Farmers can register via phone call.

**Q: How do I verify a product?**  
A: Just scan the QR code on the product.

**Q: Is the data secure?**  
A: Yes, all records are stored on blockchain.

**Q: What wallet do I need?**  
A: MetaMask (free browser extension).

---

*AgriTrace - Transparency from Farm to Fork 🌾*
