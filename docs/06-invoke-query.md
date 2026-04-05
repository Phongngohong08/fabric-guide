# Bước 6: Giao dịch và Query Ledger

## Mục tiêu

Sau bước này bạn sẽ biết cách:
- Khởi tạo dữ liệu ban đầu trên ledger
- Ghi dữ liệu mới bằng `peer chaincode invoke`
- Đọc dữ liệu bằng `peer chaincode query`
- Kiểm tra block và transaction trên ledger

---

## Chuẩn bị biến môi trường

```bash
# FABRIC_CFG_PATH phải trỏ đến thư mục chứa core.yaml (cho peer CLI)
export FABRIC_CFG_PATH=$(pwd)/configs/node-config
BASE=$(pwd)/organizations

# Identity của Org1 Admin — dùng absolute paths
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${BASE}/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${BASE}/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

# TLS CA của orderer (dùng cho --cafile)
export ORDERER_CA=$(pwd)/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem

# TLS CA của cả hai peers (dùng cho --tlsRootCertFiles khi invoke)
export PEER0_ORG1_CA=${BASE}/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export PEER0_ORG2_CA=${BASE}/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
```

---

## 1. Khởi tạo ledger (InitLedger)

Chaincode `asset-transfer-basic` có function `InitLedger` tạo sẵn một số assets mẫu:

```bash
peer chaincode invoke \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls \
  --cafile "$ORDERER_CA" \
  -C mychannel \
  -n basic \
  --peerAddresses localhost:7051 \
  --tlsRootCertFiles "$PEER0_ORG1_CA" \
  --peerAddresses localhost:9051 \
  --tlsRootCertFiles "$PEER0_ORG2_CA" \
  -c '{"function":"InitLedger","Args":[]}'
```

**Giải thích flags:**
| Flag | Ý nghĩa |
|------|---------|
| `-o localhost:7050` | Địa chỉ orderer |
| `--ordererTLSHostnameOverride` | Override hostname khi verify TLS cert (vì kết nối qua `localhost` nhưng cert cấp cho `orderer.example.com`) |
| `-C mychannel` | Channel ID |
| `-n basic` | Tên chaincode |
| `--peerAddresses` | Peers để lấy endorsement (theo endorsement policy) |

**Kết quả mong đợi:**
```
2024-01-01 00:00:00.000 UTC [chaincodeCmd] chaincodeInvokeOrQuery -> INFO 001 Chaincode invoke successful. result: status:200
```

---

## 2. Query tất cả assets

```bash
peer chaincode query \
  -C mychannel \
  -n basic \
  -c '{"Args":["GetAllAssets"]}'
```

**Kết quả mong đợi (JSON array):**
```json
[
  {"ID":"asset1","color":"blue","size":5,"owner":"Tomoko","appraisedValue":300},
  {"ID":"asset2","color":"red","size":5,"owner":"Brad","appraisedValue":400},
  {"ID":"asset3","color":"green","size":10,"owner":"Jin Soo","appraisedValue":500},
  {"ID":"asset4","color":"yellow","size":10,"owner":"Max","appraisedValue":600},
  {"ID":"asset5","color":"black","size":15,"owner":"Adriana","appraisedValue":700},
  {"ID":"asset6","color":"white","size":15,"owner":"Michel","appraisedValue":800}
]
```

> **Invoke vs Query:**
> - `invoke`: Ghi vào ledger → cần endorsement từ peers → gửi qua orderer → tạo transaction
> - `query`: Chỉ đọc local state của peer → không tạo transaction → nhanh hơn

---

## 3. Tạo asset mới

```bash
peer chaincode invoke \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls \
  --cafile "$ORDERER_CA" \
  -C mychannel \
  -n basic \
  --peerAddresses localhost:7051 \
  --tlsRootCertFiles "$PEER0_ORG1_CA" \
  --peerAddresses localhost:9051 \
  --tlsRootCertFiles "$PEER0_ORG2_CA" \
  -c '{"function":"CreateAsset","Args":["asset7","purple","10","Alice","1200"]}'
```

**Args format:** `["assetID", "color", "size", "owner", "appraisedValue"]`

---

## 4. Query một asset cụ thể

```bash
peer chaincode query \
  -C mychannel \
  -n basic \
  -c '{"Args":["ReadAsset","asset7"]}'
```

**Kết quả:**
```json
{"ID":"asset7","color":"purple","size":10,"owner":"Alice","appraisedValue":1200}
```

---

## 5. Transfer asset (thay đổi owner)

```bash
peer chaincode invoke \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls \
  --cafile "$ORDERER_CA" \
  -C mychannel \
  -n basic \
  --peerAddresses localhost:7051 \
  --tlsRootCertFiles "$PEER0_ORG1_CA" \
  --peerAddresses localhost:9051 \
  --tlsRootCertFiles "$PEER0_ORG2_CA" \
  -c '{"function":"TransferAsset","Args":["asset7","Bob"]}'
```

Verify:
```bash
peer chaincode query -C mychannel -n basic -c '{"Args":["ReadAsset","asset7"]}'
# owner đã đổi thành "Bob"
```

---

## 6. Kiểm tra thông tin blockchain

### Xem block height của channel:

```bash
peer channel getinfo -c mychannel
```

**Output:**
```
Blockchain info: {"height":5,"currentBlockHash":"xxxxx","previousBlockHash":"yyyyy"}
```

`height: 5` nghĩa là có 5 blocks (block 0 là genesis block, block 1-4 là các transactions).

### Xem nội dung một block:

```bash
# Lấy block số 1 (block đầu tiên có transaction)
peer channel fetch 1 block1.pb \
  -c mychannel \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls \
  --cafile "$ORDERER_CA"

# Decode về JSON
configtxlator proto_decode \
  --input block1.pb \
  --type common.Block \
  --output block1.json

# Xem nội dung
cat block1.json | jq .
```

---

## 7. Xem logs chaincode

Khi chaincode được invoke lần đầu, Docker sẽ tạo container riêng:

```bash
# Xem danh sách containers (chaincode container có tên dạng dev-peer...)
docker ps | grep dev-peer

# Xem logs chaincode
docker logs dev-peer0.org1.example.com-basic_1.0-xxxx
```

---

## Tóm tắt luồng một invoke transaction

```
Client (peer CLI)
    │
    ├─ 1. Gửi proposal đến peer0.org1 và peer0.org2
    │
    ├─ 2. Mỗi peer:
    │       a. Kiểm tra identity và policy
    │       b. Simulate chaincode (không ghi vào ledger)
    │       c. Ký kết quả (read-write set)
    │       d. Trả về endorsement
    │
    ├─ 3. Client nhận đủ endorsements
    │
    ├─ 4. Client gửi transaction tới orderer
    │
    └─ 5. Orderer:
            a. Sắp xếp transactions (ordering)
            b. Đóng block
            c. Broadcast block tới tất cả peers
            └─ Peers validate và commit vào ledger
```

---

## Dọn dẹp sau khi xong

```bash
# Dừng và xóa tất cả containers + volumes + artifacts
docker compose -f configs/compose/compose-test-net.yaml down -v
docker rm -f $(docker ps -aq --filter "name=dev-peer") 2>/dev/null
docker rmi -f $(docker images -q "dev-peer*") 2>/dev/null
rm -rf organizations/ channel-artifacts/ basic.tar.gz
```

---

## Bước tiếp theo

Sau khi đã chạy thành công mạng cơ bản, có thể tiếp tục:

- **Thêm org mới**: Xem `fabric-samples/test-network/addOrg3/`
- **Dùng Fabric CA**: Thay cryptogen bằng CA server thực (`./network.sh up -ca`)
- **CouchDB**: State database mạnh hơn, hỗ trợ rich query (`./network.sh up -s couchdb`)
- **Viết chaincode**: Xem [Fabric Chaincode Tutorial](https://hyperledger-fabric.readthedocs.io/en/release-2.5/chaincode4ade.html)
- **Client SDK**: Kết nối từ ứng dụng Go/Node.js/Java
