# Bước 4: Tạo Channel

## Mục tiêu

Sau bước này bạn sẽ có:
- Channel `mychannel` tồn tại trên orderer
- `peer0.org1` và `peer0.org2` đã join vào channel

---

## Yêu cầu trước khi bắt đầu

- Đang đứng ở thư mục làm việc
- Bước 3 đã hoàn thành — 3 containers đang chạy:

```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

---

## Lưu ý quan trọng về FABRIC_CFG_PATH

`FABRIC_CFG_PATH` phải trỏ đúng thư mục tùy theo lệnh đang dùng:

| Lệnh | FABRIC_CFG_PATH cần trỏ tới |
|------|-----------------------------|
| `configtxgen` | `configs/configtx/` (chứa `configtx.yaml`) |
| `peer` | `configs/node-config/` (chứa `core.yaml`) |

**Nhớ set lại trước mỗi nhóm lệnh** — đây là nguyên nhân phổ biến gây lỗi ở bước này.

---

## 1. Sinh Genesis Block cho channel

Genesis block là block đầu tiên của channel, chứa toàn bộ cấu hình ban đầu (danh sách orgs, cấu hình orderer, policies, ...).

```bash
# Set FABRIC_CFG_PATH cho configtxgen
export FABRIC_CFG_PATH=$(pwd)/configs/configtx

mkdir -p channel-artifacts

configtxgen \
  -profile ChannelUsingRaft \
  -outputBlock ./channel-artifacts/mychannel.block \
  -channelID mychannel
```

**Kiểm tra:**
```bash
ls -lh channel-artifacts/mychannel.block
# Phải thấy file khoảng vài KB
```

---

## 2. Tạo channel trên Orderer (osnadmin)

Gửi genesis block lên orderer qua Admin API (port 7053). Lưu ý dùng **absolute paths** cho cert files:

```bash
# --ca-file: TLS CA của orderer node (KHÔNG dùng tlsca/)
export ORDERER_CA=$(pwd)/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
# --client-cert/key: TLS client cert của Admin user (KHÔNG dùng server.crt/key)
export ORDERER_ADMIN_TLS_SIGN_CERT=$(pwd)/organizations/ordererOrganizations/example.com/users/Admin@example.com/tls/client.crt
export ORDERER_ADMIN_TLS_PRIVATE_KEY=$(pwd)/organizations/ordererOrganizations/example.com/users/Admin@example.com/tls/client.key

osnadmin channel join \
  --channelID mychannel \
  --config-block ./channel-artifacts/mychannel.block \
  -o localhost:7053 \
  --ca-file "$ORDERER_CA" \
  --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" \
  --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY"
```

**Kết quả mong đợi:**
```json
{
  "name": "mychannel",
  "url": "/participation/v1/channels/mychannel",
  "consensusRelation": "consenter",
  "status": "active",
  "height": 1
}
```

---

## 3. Join Peer0.Org1 vào channel

Set biến môi trường xác định đang dùng identity của peer nào, rồi chạy `peer channel join`.

> **Tại sao phải dùng absolute paths cho cert files?**
> `peer` CLI resolve relative paths từ `FABRIC_CFG_PATH`, không phải từ thư mục làm việc.
> Nếu dùng `./organizations/...` sẽ gặp lỗi `path does not exist`.
> Dùng `$(pwd)/organizations/...` để luôn đúng.

```bash
# Set FABRIC_CFG_PATH cho peer
export FABRIC_CFG_PATH=$(pwd)/configs/node-config
BASE=$(pwd)/organizations

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${BASE}/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${BASE}/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer channel join -b ./channel-artifacts/mychannel.block
```

**Kết quả mong đợi:**
```
Successfully submitted proposal to join channel
```

**Kiểm tra:**
```bash
peer channel list
# mychannel
```

---

## 4. Join Peer0.Org2 vào channel

```bash
# FABRIC_CFG_PATH và BASE đã set từ bước trên — chỉ cần đổi org

export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${BASE}/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${BASE}/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer channel join -b ./channel-artifacts/mychannel.block
```

---

## 5. Kiểm tra tổng thể

```bash
# Set lại env cho Org1 để kiểm tra
export FABRIC_CFG_PATH=$(pwd)/configs/node-config
BASE=$(pwd)/organizations

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${BASE}/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${BASE}/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer channel getinfo -c mychannel
# Output: Blockchain info: {"height":1,"currentBlockHash":"...","previousBlockHash":""}
```

---

## Lỗi thường gặp

### `Error: proposal failed (err: bad proposal response ...)`

Thường do `FABRIC_CFG_PATH` trỏ sai. Kiểm tra:
```bash
echo $FABRIC_CFG_PATH
# Phải là .../configs/node-config
ls $FABRIC_CFG_PATH
# Phải thấy core.yaml
```

### `Error: failed to create deliver client: orderer client failed to connect`

Peer chưa join channel hoặc orderer chưa có channel. Đảm bảo đã chạy bước 2 (osnadmin) trước bước 3.

### `context deadline exceeded`

Containers chưa kịp khởi động. Chờ thêm vài giây rồi thử lại.

---

**Tiếp theo:** [05-deploy-chaincode.md](05-deploy-chaincode.md)
