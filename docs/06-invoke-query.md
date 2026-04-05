# Bước 6: Giao dịch và Query Ledger

## Mục tiêu

Sau bước này bạn sẽ biết cách:
- Khởi tạo dữ liệu ban đầu trên ledger
- Ghi dữ liệu mới bằng `peer chaincode invoke`
- Đọc dữ liệu bằng `peer chaincode query`

---

## Yêu cầu trước khi bắt đầu

- Đang đứng ở thư mục làm việc
- Bước 5 đã hoàn thành — chaincode `basic` đã được commit lên channel

---

## Chuẩn bị biến môi trường

```bash
export FABRIC_CFG_PATH=$(pwd)/configs/node-config
BASE=$(pwd)/organizations

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${BASE}/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${BASE}/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

export ORDERER_CA=$(pwd)/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem
export PEER0_ORG1_CA=${BASE}/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export PEER0_ORG2_CA=${BASE}/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
```

---

## Invoke vs Query

| | `invoke` | `query` |
|-|----------|---------|
| Mục đích | Ghi vào ledger | Chỉ đọc state của peer |
| Cần endorsement | Có (từ nhiều peers) | Không |
| Gửi qua orderer | Có | Không |
| Tạo transaction | Có | Không |
| Tốc độ | Chậm hơn | Nhanh hơn |

---

## 1. Khởi tạo ledger (InitLedger)

Chaincode `asset-transfer-basic` có function `InitLedger` tạo sẵn 6 assets mẫu:

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

**Kết quả mong đợi:**
```
Chaincode invoke successful. result: status:200
```

---

## 2. Query tất cả assets

```bash
peer chaincode query \
  -C mychannel \
  -n basic \
  -c '{"Args":["GetAllAssets"]}'
```

**Kết quả:**
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

---

## 3. Tạo asset mới

```bash
peer chaincode invoke \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile "$ORDERER_CA" \
  -C mychannel -n basic \
  --peerAddresses localhost:7051 --tlsRootCertFiles "$PEER0_ORG1_CA" \
  --peerAddresses localhost:9051 --tlsRootCertFiles "$PEER0_ORG2_CA" \
  -c '{"function":"CreateAsset","Args":["asset7","purple","10","Alice","1200"]}'
```

Format Args: `["assetID", "color", "size", "owner", "appraisedValue"]`

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
  --tls --cafile "$ORDERER_CA" \
  -C mychannel -n basic \
  --peerAddresses localhost:7051 --tlsRootCertFiles "$PEER0_ORG1_CA" \
  --peerAddresses localhost:9051 --tlsRootCertFiles "$PEER0_ORG2_CA" \
  -c '{"function":"TransferAsset","Args":["asset7","Bob"]}'
```

Verify:
```bash
peer chaincode query -C mychannel -n basic -c '{"Args":["ReadAsset","asset7"]}'
# "owner":"Bob"
```

---

## 6. Xem thông tin blockchain

```bash
peer channel getinfo -c mychannel
# Blockchain info: {"height":5,"currentBlockHash":"...","previousBlockHash":"..."}
```

`height: 5` nghĩa là có 5 blocks (block 0 là genesis block, block 1-4 là các transactions).

---

## 7. Xem logs chaincode

Khi invoke lần đầu, peer tạo Docker container riêng cho chaincode:

```bash
docker ps | grep dev-peer
# dev-peer0.org1.example.com-basic_1.0-xxxxx

docker logs dev-peer0.org1.example.com-basic_1.0-xxxxx
```

---

## Dọn dẹp sau khi xong

```bash
docker compose -f configs/compose/compose-test-net.yaml down -v
docker rm -f $(docker ps -aq --filter "name=dev-peer") 2>/dev/null || true
docker rmi -f $(docker images -q "dev-peer*") 2>/dev/null || true
rm -rf organizations/ channel-artifacts/ basic.tar.gz
```

---

## Bước tiếp theo

| Chủ đề | Tài liệu |
|--------|----------|
| Thêm Org3 vào mạng đang chạy | [07-add-org.md](07-add-org.md) |
| Viết chaincode | https://hyperledger-fabric.readthedocs.io/en/release-2.5/chaincode4ade.html |
| Dùng Fabric CA thay cryptogen | https://hyperledger-fabric-ca.readthedocs.io |
| CouchDB (rich query) | https://hyperledger-fabric.readthedocs.io/en/release-2.5/couchdb_tutorial.html |
| Client SDK (Go/Node.js/Java) | https://hyperledger-fabric.readthedocs.io/en/release-2.5/sdk_chaincode.html |
