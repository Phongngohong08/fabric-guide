# Fabric Guide — Hướng dẫn chạy mạng Hyperledger Fabric

Dự án này hướng dẫn từng bước cách khởi chạy một mạng Hyperledger Fabric cơ bản từ đầu.

## Bắt đầu

```bash
git clone <url-repo-này> fabric-guide
cd fabric-guide
```

Từ đây, **toàn bộ hướng dẫn đều chạy trong thư mục `fabric-guide/`** này.

---

## Kiến trúc mạng

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

---

## Cấu trúc thư mục

```
fabric-guide/                        ← Thư mục làm việc (repo này)
│
├── docs/                            ← Tài liệu từng bước (đọc theo thứ tự)
├── configs/                         ← File cấu hình (có sẵn trong repo)
│   ├── cryptogen/                   ← crypto-config-*.yaml (bao gồm org3)
│   ├── configtx/                    ← configtx.yaml (genesis block)
│   ├── org3/                        ← configtx.yaml riêng cho Org3 (dùng với -printOrg)
│   ├── compose/                     ← Docker Compose files (bao gồm compose-org3.yaml)
│   └── node-config/                 ← core.yaml, orderer.yaml
├── scripts/
│   └── network.sh                   ← Script tiện ích (tùy chọn)
│
│   ── Tạo ra trong quá trình làm theo hướng dẫn ──
│
├── fabric-samples/                  ← Tải về ở Bước 0 (không commit)
│   ├── bin/                         ← cryptogen, configtxgen, peer, osnadmin, ...
│   └── asset-transfer-basic/        ← Chaincode mẫu
├── organizations/                   ← Sinh ra ở Bước 2 (không commit)
└── channel-artifacts/               ← Sinh ra ở Bước 4 (không commit)
```

---

## Thứ tự đọc tài liệu

| Bước | File | Nội dung |
|------|------|----------|
| 0 | [docs/00-prerequisites.md](docs/00-prerequisites.md) | Cài Docker, Go, tải Fabric binaries |
| 1 | [docs/01-network-overview.md](docs/01-network-overview.md) | Tổng quan kiến trúc mạng |
| 2 | [docs/02-generate-crypto.md](docs/02-generate-crypto.md) | Sinh certificates bằng cryptogen |
| 3 | [docs/03-start-network.md](docs/03-start-network.md) | Khởi động containers |
| 4 | [docs/04-create-channel.md](docs/04-create-channel.md) | Tạo channel và join peers |
| 5 | [docs/05-deploy-chaincode.md](docs/05-deploy-chaincode.md) | Deploy chaincode |
| 6 | [docs/06-invoke-query.md](docs/06-invoke-query.md) | Giao dịch và query ledger |
| 7 | [docs/07-add-org.md](docs/07-add-org.md) | Thêm Org3 vào mạng đang chạy |
| 8 | [docs/08-multi-vm-deployment.md](docs/08-multi-vm-deployment.md) | Triển khai 2 peer + 1 orderer trên 3 máy ảo (cùng LAN) |

---

## Triển khai đa máy (3 VM)

Kịch bản gợi ý: **ba máy ảo Ubuntu trên VMware**, SSH từ máy ngoài, mở **ba terminal** (mỗi terminal một phiên SSH), cấu hình `/etc/hosts` trên cả ba Ubuntu. Chi tiết và thứ tự lệnh: [docs/08-multi-vm-deployment.md](docs/08-multi-vm-deployment.md) — kèm file Compose tách sẵn trong `configs/compose/` (`compose-orderer-only.yaml`, `compose-peer-org1-only.yaml`, `compose-peer-org2-only.yaml`).

---

## Quick Start (chạy nhanh bằng script)

Nếu chỉ muốn xem kết quả, dùng `network.sh` để chạy toàn bộ pipeline tự động:

```bash
# Set PATH trước
export PATH=$PATH:$(pwd)/fabric-samples/bin

# Chạy toàn bộ: sinh certs → start network → tạo channel → deploy chaincode → test
./scripts/network.sh all
```

Để hiểu từng bước đang làm gì, đọc từ [docs/00-prerequisites.md](docs/00-prerequisites.md).

---

## Dọn dẹp

```bash
./scripts/network.sh down
```
