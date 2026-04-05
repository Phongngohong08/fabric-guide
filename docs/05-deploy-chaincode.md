# Bước 5: Deploy Chaincode

## Mục tiêu

Sau bước này bạn sẽ có:
- Chaincode đã được package thành `basic.tar.gz`
- Chaincode đã được install trên `peer0.org1` và `peer0.org2`
- Cả hai org đã approve chaincode definition
- Chaincode definition đã được commit lên channel — sẵn sàng nhận transactions

---

## Yêu cầu trước khi bắt đầu

- Đang đứng ở thư mục làm việc
- Bước 4 đã hoàn thành — channel `mychannel` đang hoạt động
- Thư mục `fabric-samples/asset-transfer-basic/chaincode-go/` tồn tại:

```bash
ls fabric-samples/asset-transfer-basic/chaincode-go/
# go.mod  go.sum  chaincode/
```

---

## Tổng quan Fabric Chaincode Lifecycle

Fabric 2.x dùng **decentralized chaincode lifecycle** — cần sự đồng thuận của nhiều tổ chức:

```
1. Package   → Đóng gói chaincode thành .tar.gz (làm 1 lần)
2. Install   → Cài package lên từng peer (riêng cho mỗi peer)
3. Approve   → Mỗi org phê duyệt definition (Org1 và Org2)
4. Commit    → Sau khi đủ số org approve, commit lên channel (làm 1 lần)
```

Tại sao cần approve từ nhiều org? Để tránh một org tự ý thay đổi logic chaincode mà không được các bên khác đồng ý.

---

## Chuẩn bị biến môi trường dùng chung

Chạy khối này một lần, các bước sau sẽ dùng lại:

```bash
export FABRIC_CFG_PATH=$(pwd)/configs/node-config
BASE=$(pwd)/organizations
export ORDERER_CA=${BASE}/../organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem
export ORDERER_CA=$(pwd)/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem
export PEER0_ORG1_CA=$(pwd)/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export PEER0_ORG2_CA=$(pwd)/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
```

---

## Bước 5.1: Package Chaincode

```bash
export GOFLAGS="-buildvcs=false"   # Cần với Go 1.18+ khi thư mục không có .git

peer lifecycle chaincode package basic.tar.gz \
  --path ./fabric-samples/asset-transfer-basic/chaincode-go \
  --lang golang \
  --label basic_1.0
```

> **Tại sao cần `GOFLAGS`?** Go 1.18+ cố nhúng thông tin VCS vào binary. Khi thư mục chaincode
> không nằm trong git repo (hoặc không có quyền đọc `.git`), build sẽ fail với lỗi
> `error obtaining VCS status`. Flag này tắt tính năng đó.

**Kiểm tra:**
```bash
ls -lh basic.tar.gz
tar tzf basic.tar.gz
# metadata.json   ← chứa label và type
# code.tar.gz     ← source code đã nén
```

---

## Bước 5.2: Install lên Peer0.Org1

```bash
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${BASE}/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${BASE}/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer lifecycle chaincode install basic.tar.gz
```

**Lấy Package ID** (dùng ở các bước sau):

```bash
peer lifecycle chaincode queryinstalled
# Package ID: basic_1.0:xxxxxxxx..., Label: basic_1.0

export CC_PACKAGE_ID=$(peer lifecycle chaincode calculatepackageid basic.tar.gz)
echo $CC_PACKAGE_ID
```

---

## Bước 5.3: Install lên Peer0.Org2

```bash
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${BASE}/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${BASE}/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer lifecycle chaincode install basic.tar.gz
```

> Package ID phải giống nhau trên cả hai peers vì cùng một file `.tar.gz`.

---

## Bước 5.4: Approve từ Org1

```bash
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${BASE}/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${BASE}/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

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

> **Tại sao cần `--ordererTLSHostnameOverride`?**
> TLS cert của orderer được cấp cho hostname `orderer.example.com`, nhưng khi chạy local ta kết nối
> qua `localhost:7050`. Flag này báo cho peer biết verify TLS theo hostname `orderer.example.com`
> dù đang kết nối qua `localhost`.

| Flag | Ý nghĩa |
|------|---------|
| `--name basic` | Tên chaincode trên channel |
| `--version 1.0` | Version của definition |
| `--package-id` | Liên kết definition với package đã install |
| `--sequence 1` | Số thứ tự lần deploy — tăng lên khi update |

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

Nếu một org vẫn `false` → chưa approve hoặc approve với tham số khác (version, sequence không khớp).

---

## Bước 5.7: Commit chaincode definition

```bash
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${BASE}/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${BASE}/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

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

> `--peerAddresses` chỉ định peers để lấy endorsement khi commit.
> Cần ít nhất 1 peer từ mỗi org.

**Kiểm tra:**
```bash
peer lifecycle chaincode querycommitted \
  --channelID mychannel \
  --name basic \
  --cafile "$ORDERER_CA"

# Output:
# Committed chaincode definition for chaincode 'basic' on channel 'mychannel':
# Version: 1.0, Sequence: 1, Approvals: [Org1MSP: true, Org2MSP: true]
```

---

## Update chaincode

Khi cần thay đổi logic chaincode:

1. Sửa code
2. Package lại: `--label basic_2.0`
3. Install trên các peers
4. Approve với `--version 2.0 --sequence 2`
5. Commit với `--version 2.0 --sequence 2`

> `--sequence` tăng lên 1 mỗi lần update, không thể giảm.

---

## Lỗi thường gặp

### `chaincode definition not agreed to by this org`

Tham số approve không khớp giữa các org. Kiểm tra `--version` và `--sequence` phải giống nhau.

### `Error: failed to send transaction`

Không kết nối được tới orderer. Kiểm tra `$ORDERER_CA` và orderer đang chạy.

### `Error: could not assemble transaction: ProposalResponsePayloads do not match`

Hai peers trả về kết quả khác nhau khi simulate. Thường do chaincode dùng random, time, hoặc các giá trị không deterministic.

---

**Tiếp theo:** [06-invoke-query.md](06-invoke-query.md)
