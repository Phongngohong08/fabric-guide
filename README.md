# Fabric Guide — Hướng dẫn chạy mạng Hyperledger Fabric

Dự án này hướng dẫn từng bước cách khởi chạy một mạng Hyperledger Fabric cơ bản, dựa trên [test-network](https://github.com/hyperledger/fabric-samples/tree/main/test-network) chính thức.

## Mục tiêu

Sau khi đọc xong tài liệu này, bạn có thể:
- Hiểu các thành phần của một mạng Fabric
- Tạo được certificate cho các tổ chức
- Khởi động được mạng gồm 1 orderer và 2 peer
- Tạo channel và join peers vào channel
- Deploy và gọi chaincode

## Kiến trúc mạng cơ bản

```
                    ┌─────────────────────┐
                    │  Orderer (Raft)      │
                    │  orderer.example.com │
                    │  Port: 7050          │
                    └──────────┬──────────┘
                               │
              ┌────────────────┴────────────────┐
              │                                 │
   ┌──────────┴─────────┐           ┌──────────┴──────────┐
   │  Org1               │           │  Org2               │
   │  peer0.org1         │           │  peer0.org2         │
   │  Port: 7051         │           │  Port: 9051         │
   └─────────────────────┘           └─────────────────────┘
```

## Cấu trúc thư mục

```
fabric-guide/
├── README.md                    # File này
├── docs/                        # Tài liệu từng bước
│   ├── 00-prerequisites.md      # Bước 0: Cài đặt môi trường
│   ├── 01-network-overview.md   # Bước 1: Tổng quan các thành phần
│   ├── 02-generate-crypto.md    # Bước 2: Tạo certificates
│   ├── 03-start-network.md      # Bước 3: Khởi động mạng
│   ├── 04-create-channel.md     # Bước 4: Tạo channel
│   ├── 05-deploy-chaincode.md   # Bước 5: Deploy chaincode
│   └── 06-invoke-query.md       # Bước 6: Giao dịch & Query
├── configs/                     # File cấu hình mẫu
│   ├── cryptogen/               # Cấu hình sinh certificate
│   ├── configtx/                # Cấu hình channel & orderer
│   └── compose/                 # Docker Compose files
└── scripts/                     # Scripts tiện ích
```

## Thứ tự đọc tài liệu

| Bước | File | Mục đích |
|------|------|----------|
| 0 | [docs/00-prerequisites.md](docs/00-prerequisites.md) | Cài đặt tools: Docker, Fabric binaries |
| 1 | [docs/01-network-overview.md](docs/01-network-overview.md) | Hiểu các thành phần mạng Fabric |
| 2 | [docs/02-generate-crypto.md](docs/02-generate-crypto.md) | Sinh certificates bằng cryptogen |
| 3 | [docs/03-start-network.md](docs/03-start-network.md) | Chạy containers bằng Docker Compose |
| 4 | [docs/04-create-channel.md](docs/04-create-channel.md) | Tạo channel và join peers |
| 5 | [docs/05-deploy-chaincode.md](docs/05-deploy-chaincode.md) | Cài và commit chaincode |
| 6 | [docs/06-invoke-query.md](docs/06-invoke-query.md) | Gửi transaction và query ledger |

## Quick Start (dùng test-network có sẵn)

Nếu chỉ muốn chạy nhanh để xem kết quả, dùng network.sh của fabric-samples:

```bash
# 1. Tải fabric-samples và binaries
curl -sSL https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh | bash -s -- binary docker samples

# 2. Vào thư mục test-network
cd fabric-samples/test-network

# 3. Khởi động mạng + tạo channel + deploy chaincode
./network.sh up createChannel -c mychannel
./network.sh deployCC -ccn basic -ccp ../asset-transfer-basic/chaincode-go -ccl go

# 4. Dọn dẹp
./network.sh down
```

Để hiểu từng bước đang làm gì — đọc từ [docs/00-prerequisites.md](docs/00-prerequisites.md).
