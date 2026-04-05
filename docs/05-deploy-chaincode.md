# Bước 5: Deploy Chaincode

## Mục tiêu

Sau bước này bạn sẽ có:
- Chaincode đã được package thành `.tar.gz`
- Chaincode đã được install trên `peer0.org1` và `peer0.org2`
- Cả hai org đã approve chaincode definition
- Chaincode definition đã được commit lên channel — sẵn sàng nhận transactions

---

## Tổng quan Fabric Chaincode Lifecycle

Fabric 2.x dùng **decentralized chaincode lifecycle** — cần sự đồng thuận của nhiều tổ chức:

```
1. Package    → Đóng gói chaincode thành .tar.gz
               (làm 1 lần, dùng chung cho mọi peer)

2. Install    → Cài package lên từng peer
               (làm riêng cho peer0.org1 VÀ peer0.org2)

3. Approve    → Mỗi org phê duyệt definition
               (Org1 approve + Org2 approve)

4. Commit     → Sau khi đủ số org approve, commit lên channel
               (làm 1 lần)
```

**Tại sao cần approve từ nhiều org?**

Tránh tình trạng một org tự ý thay đổi logic chaincode mà không được các bên khác đồng ý. Số lượng org cần approve được định nghĩa bởi **lifecycle policy** (mặc định: majority).

---

## Chuẩn bị chaincode

Trong ví dụ này dùng chaincode `asset-transfer-basic` từ fabric-samples (Go):

```
fabric-samples/asset-transfer-basic/chaincode-go/
├── go.mod
├── go.sum
└── chaincode/
    └── smartcontract.go    ← Logic: CreateAsset, ReadAsset, TransferAsset, ...
```

Hoặc bạn có thể dùng chaincode của mình. Các ngôn ngữ hỗ trợ: `golang`, `node`, `java`.

---

## Bước 5.1: Package Chaincode

> **Yêu cầu:** Go phải được cài và có trong PATH. Xem [docs/00-prerequisites.md](00-prerequisites.md).

```bash
export FABRIC_CFG_PATH=$(pwd)/configs/node-config
export GOFLAGS="-buildvcs=false"   # Cần với Go 1.18+ khi thư mục không có .git

peer lifecycle chaincode package basic.tar.gz \
  --path ../fabric-samples/asset-transfer-basic/chaincode-go \
  --lang golang \
  --label basic_1.0
```

> **Tại sao cần GOFLAGS?** Go 1.18+ mặc định cố gắng nhúng thông tin VCS (git) vào binary. Khi thư mục chaincode không nằm trong git repo (hoặc không có quyền đọc `.git`), lệnh build sẽ fail với lỗi `error obtaining VCS status`. Flag `-buildvcs=false` tắt tính năng này.

**Giải thích flags:**
- `--path`: Thư mục chứa source code chaincode
- `--lang golang`: Ngôn ngữ lập trình (golang | node | java)
- `--label basic_1.0`: Nhãn định danh, format thường là `<name>_<version>`

**Kiểm tra:**
```bash
ls -la basic.tar.gz
# Thấy file .tar.gz khoảng vài trăm KB
```

**Xem nội dung package:**
```bash
tar tzf basic.tar.gz
# metadata.json       ← chứa label và type
# code.tar.gz         ← source code đã được nén
```

---

## Bước 5.2: Install lên Peer0.Org1

```bash
export FABRIC_CFG_PATH=$(pwd)/configs/node-config
BASE=$(pwd)/organizations

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${BASE}/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${BASE}/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer lifecycle chaincode install basic.tar.gz
```

**Kết quả mong đợi:**
```
Chaincode code package identifier: basic_1.0:xxxxxxxx...
```

**Lưu Package ID:**
```bash
peer lifecycle chaincode queryinstalled

# Output:
# Installed chaincodes on peer:
# Package ID: basic_1.0:7d55..., Label: basic_1.0

# Gán vào biến môi trường
export CC_PACKAGE_ID=basic_1.0:7d55...
```

---

## Bước 5.3: Install lên Peer0.Org2

```bash
# (BASE và FABRIC_CFG_PATH đã set từ bước trên)
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${BASE}/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${BASE}/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer lifecycle chaincode install basic.tar.gz
```

> **Lưu ý:** Package ID phải giống nhau trên cả hai peers (vì cùng một file .tar.gz).

---

## Bước 5.4: Approve từ Org1

```bash
# (BASE và FABRIC_CFG_PATH đã set từ bước trên)
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${BASE}/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${BASE}/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051
export ORDERER_CA=$(pwd)/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem

peer lifecycle chaincode approveformyorg \
  --channelID mychannel \
  --name basic \
  --version 1.0 \
  --package-id $CC_PACKAGE_ID \
  --sequence 1 \
  -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
  --tls \
  --cafile "$ORDERER_CA"
```

> **Tại sao cần `-o localhost:7050 --ordererTLSHostnameOverride`?**
> Khi chạy local, peer không thể resolve hostname `orderer.example.com` từ channel config. Cần chỉ định địa chỉ orderer tường minh. `--ordererTLSHostnameOverride` để TLS verify đúng vì cert được cấp cho `orderer.example.com` nhưng kết nối qua `localhost`.

**Giải thích flags:**
| Flag | Ý nghĩa |
|------|---------|
| `--name basic` | Tên chaincode trên channel (có thể khác label) |
| `--version 1.0` | Version của chaincode definition |
| `--package-id` | Liên kết definition với package đã install |
| `--sequence 1` | Số thứ tự lần deploy (tăng lên khi update) |

**Kết quả mong đợi:**
```
Successfully endorsed proposal to approve chaincode
```

---

## Bước 5.5: Approve từ Org2

```bash
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${BASE}/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${BASE}/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer lifecycle chaincode approveformyorg \
  --channelID mychannel \
  --name basic \
  --version 1.0 \
  --package-id $CC_PACKAGE_ID \
  --sequence 1 \
  -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
  --tls \
  --cafile "$ORDERER_CA"
```

---

## Bước 5.6: Kiểm tra commit readiness

Trước khi commit, kiểm tra đã đủ số tổ chức approve chưa (set lại env cho Org1 trước):

```bash
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${BASE}/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${BASE}/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer lifecycle chaincode checkcommitreadiness \
  --channelID mychannel \
  --name basic \
  --version 1.0 \
  --sequence 1 \
  --tls \
  --cafile "$ORDERER_CA" \
  --output json
```

**Kết quả mong đợi:**
```json
{
  "approvals": {
    "Org1MSP": true,
    "Org2MSP": true
  }
}
```

Nếu một org vẫn `false` → chưa approve hoặc approve với tham số khác.

---

## Bước 5.7: Commit chaincode definition

```bash
# Dùng identity Org1 để commit
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${BASE}/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${BASE}/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

PEER0_ORG1_CA=${BASE}/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
PEER0_ORG2_CA=${BASE}/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt

peer lifecycle chaincode commit \
  --channelID mychannel \
  --name basic \
  --version 1.0 \
  --sequence 1 \
  -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
  --tls \
  --cafile "$ORDERER_CA" \
  --peerAddresses localhost:7051 \
  --tlsRootCertFiles "$PEER0_ORG1_CA" \
  --peerAddresses localhost:9051 \
  --tlsRootCertFiles "$PEER0_ORG2_CA"
```

**Giải thích `--peerAddresses`:**
- Commit cần endorsements từ các peers theo endorsement policy
- Phải chỉ định ít nhất 1 peer từ mỗi org tham gia
- `--tlsRootCertFiles`: TLS CA cert tương ứng với mỗi peer

**Kết quả mong đợi:**
```
Chaincode definition committed on channel 'mychannel'
```

---

## Bước 5.8: Kiểm tra chaincode đã committed

```bash
peer lifecycle chaincode querycommitted \
  --channelID mychannel \
  --name basic \
  --cafile "$ORDERER_CA"
```

**Kết quả mong đợi:**
```
Committed chaincode definition for chaincode 'basic' on channel 'mychannel':
Version: 1.0, Sequence: 1, Endorsement Plugin: escc, Validation Plugin: vscc,
Approvals: [Org1MSP: true, Org2MSP: true]
```

---

## Update chaincode

Khi cần thay đổi logic chaincode:

1. Sửa code
2. Package lại với label mới: `basic_2.0`
3. Install trên các peers
4. Approve với `--version 2.0 --sequence 2`
5. Commit với `--version 2.0 --sequence 2`

> `--sequence` tăng lên 1 mỗi lần update (không thể giảm).

---

## Lỗi thường gặp

### `chaincode definition not agreed to by this org`

Các tham số trong approve không khớp giữa các org. Kiểm tra `--version` và `--sequence` phải giống nhau.

### `Error: failed to send transaction`

Không kết nối được tới orderer. Kiểm tra `$ORDERER_CA` và orderer có đang chạy không.

### `Error: could not assemble transaction: ProposalResponsePayloads do not match`

Hai peers trả về kết quả khác nhau khi simulate. Thường do code chaincode không deterministic (dùng random, time, ...).

---

**Tiếp theo:** [06-invoke-query.md](06-invoke-query.md)
