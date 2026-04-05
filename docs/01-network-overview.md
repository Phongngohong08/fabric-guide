# Bước 1: Tổng quan các thành phần mạng Fabric

## Mục tiêu

Hiểu được:
- Mạng Fabric gồm những loại node nào
- Mỗi node cần những file gì để chạy
- Luồng dữ liệu đi qua mạng như thế nào

---

## 1. Các thành phần chính

### Peer

Peer là node lưu trữ ledger và chạy chaincode.

```
Mỗi Peer cần:
├── MSP (identity)          ← Certificates xác định danh tính
├── Ledger                  ← Blockchain data (LevelDB hoặc CouchDB)
├── Chaincode containers    ← Docker container chạy business logic
└── TLS certificates        ← Mã hóa kết nối mạng
```

Trong mạng test này:
- `peer0.org1.example.com` — peer của tổ chức Org1, port `7051`
- `peer0.org2.example.com` — peer của tổ chức Org2, port `9051`

### Orderer

Orderer là node sắp xếp thứ tự transactions và đóng block.

```
Orderer cần:
├── MSP (identity)
├── Raft consensus data     ← Lưu trạng thái Raft
├── Channel ledger          ← Lưu config và blocks của channel
└── TLS certificates
```

Trong mạng test này:
- `orderer.example.com` — chạy Raft consensus, port `7050`

### Channel

Channel là một subnet giao tiếp riêng giữa các peers. Mỗi channel có ledger độc lập.

```
Channel "mychannel":
├── Genesis block           ← Block đầu tiên định nghĩa cấu hình channel
├── Ledger                  ← Lưu tất cả transactions của channel
└── Chaincode definitions   ← Danh sách chaincode được phép chạy
```

### Chaincode (Smart Contract)

Chaincode là business logic chạy trên peer, xử lý read/write vào ledger.

---

## 2. Tổ chức (Organization) và MSP

Fabric dùng **MSP (Membership Service Provider)** để quản lý danh tính.

Mỗi tổ chức có:
- **CA (Certificate Authority)**: ký và phát certificates
- **MSP**: tập hợp certificates định nghĩa thành viên của tổ chức
- **Admin cert**: certificate của người quản trị tổ chức

Mạng test có 3 tổ chức:

| Tổ chức | MSP ID | Vai trò |
|---------|--------|---------|
| Org1 | `Org1MSP` | Sở hữu peer0.org1 |
| Org2 | `Org2MSP` | Sở hữu peer0.org2 |
| OrdererOrg | `OrdererMSP` | Sở hữu orderer |

---

## 3. Cấu trúc file certificates (sau khi chạy cryptogen)

```
organizations/
├── peerOrganizations/
│   ├── org1.example.com/
│   │   ├── ca/                         ← CA certificate và key của Org1
│   │   ├── msp/                        ← MSP của Org1 (dùng khi định nghĩa channel)
│   │   │   ├── admincerts/
│   │   │   ├── cacerts/
│   │   │   └── tlscacerts/
│   │   ├── peers/
│   │   │   └── peer0.org1.example.com/
│   │   │       ├── msp/                ← Identity của peer0.org1
│   │   │       └── tls/                ← TLS certs của peer0.org1
│   │   └── users/
│   │       └── Admin@org1.example.com/
│   │           └── msp/                ← Identity của Admin Org1
│   └── org2.example.com/               ← Tương tự Org1
└── ordererOrganizations/
    └── example.com/
        ├── msp/                        ← MSP của OrdererOrg
        ├── orderers/
        │   └── orderer.example.com/
        │       ├── msp/                ← Identity của orderer
        │       └── tls/                ← TLS certs của orderer
        └── users/
            └── Admin@example.com/
```

---

## 4. Luồng khởi động mạng

```
Bước 2: Tạo certificates
    cryptogen generate → organizations/ (chứa certs và keys)

Bước 3: Khởi động network
    Docker Compose → chạy containers:
                     orderer.example.com
                     peer0.org1.example.com
                     peer0.org2.example.com

Bước 4: Tạo channel
    configtxgen → mychannel.block (genesis block của channel)
    osnadmin    → tạo channel trên orderer
    peer        → join peer0.org1 vào channel
    peer        → join peer0.org2 vào channel

Bước 5: Deploy chaincode
    peer lifecycle chaincode package  → .tar.gz
    peer lifecycle chaincode install  → cài lên peer0.org1 và peer0.org2
    peer lifecycle chaincode approve  → Org1 và Org2 phê duyệt
    peer lifecycle chaincode commit   → commit definition lên channel

Bước 6: Giao dịch
    peer chaincode invoke → ghi vào ledger
    peer chaincode query  → đọc từ ledger
```

---

## 5. Luồng xử lý một transaction

```
Client
  │
  ├─► peer0.org1 (Simulate & Endorse)
  ├─► peer0.org2 (Simulate & Endorse)
  │
  │   [Nhận endorsements]
  │
  └─► Orderer (Order & Create Block)
          │
          └─► Broadcast block tới tất cả peers
                  │
                  ├─► peer0.org1 (Validate & Commit)
                  └─► peer0.org2 (Validate & Commit)
```

1. **Propose**: Client gửi proposal đến các peers được chỉ định bởi endorsement policy
2. **Endorse**: Mỗi peer simulate transaction, ký kết quả và trả về
3. **Order**: Client gửi endorsed transaction lên Orderer
4. **Deliver**: Orderer đóng block, gửi xuống tất cả peers
5. **Commit**: Mỗi peer validate và ghi block vào ledger

---

## 6. Files cần chuẩn bị

| File | Dùng để làm gì | Tạo ở bước |
|------|----------------|-----------|
| `crypto-config-org1.yaml` | Định nghĩa certs cần tạo cho Org1 | 2 |
| `crypto-config-org2.yaml` | Định nghĩa certs cần tạo cho Org2 | 2 |
| `crypto-config-orderer.yaml` | Định nghĩa certs cần tạo cho Orderer | 2 |
| `configtx.yaml` | Định nghĩa cấu hình channel và orderer | 4 |
| `compose-test-net.yaml` | Docker Compose để chạy containers | 3 |

---

**Tiếp theo:** [02-generate-crypto.md](02-generate-crypto.md)
