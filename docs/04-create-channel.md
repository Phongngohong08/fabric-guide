# Bước 4: Tạo Channel

## Mục tiêu

Sau bước này bạn sẽ có:
- Channel `mychannel` tồn tại trên orderer
- `peer0.org1` và `peer0.org2` đã join vào channel
- Anchor peer của mỗi org đã được set (cần cho gossip cross-org)

---

## 1. Chuẩn bị: configtx.yaml

File [`configs/configtx/configtx.yaml`](../configs/configtx/configtx.yaml) định nghĩa:
- Các tổ chức tham gia (MSP của từng org)
- Cấu hình orderer (Raft, batch size, ...)
- Cấu hình channel (policies, capabilities)
- **Profiles**: Template để sinh genesis block

### Cấu trúc quan trọng trong configtx.yaml:

```yaml
Organizations:
  - &OrdererOrg
    Name: OrdererOrg
    ID: OrdererMSP
    MSPDir: ../organizations/ordererOrganizations/example.com/msp
    # Policies cho phép ai làm gì với OrdererOrg

  - &Org1
    Name: Org1MSP
    ID: Org1MSP
    MSPDir: ../organizations/peerOrganizations/org1.example.com/msp
    AnchorPeers:
      - Host: peer0.org1.example.com
        Port: 7051

  - &Org2
    Name: Org2MSP
    ID: Org2MSP
    MSPDir: ../organizations/peerOrganizations/org2.example.com/msp
    AnchorPeers:
      - Host: peer0.org2.example.com
        Port: 9051

Orderer:
  OrdererType: etcdraft
  Addresses:
    - orderer.example.com:7050
  BatchTimeout: 2s
  BatchSize:
    MaxMessageCount: 10
    AbsoluteMaxBytes: 99 MB
    PreferredMaxBytes: 512 KB
  EtcdRaft:
    Consenters:
      - Host: orderer.example.com
        Port: 7050
        ClientTLSCert: ../organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
        ServerTLSCert: ../organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt

Profiles:
  ChannelUsingRaft:              # Tên profile, dùng khi gọi configtxgen
    Orderer:
      <<: *OrdererDefaults
      Organizations:
        - *OrdererOrg
    Application:
      <<: *ApplicationDefaults
      Organizations:
        - *Org1
        - *Org2
```

**Giải thích Raft Consenters:**
- `ClientTLSCert` và `ServerTLSCert`: TLS cert của orderer node — dùng để verify trong Raft cluster
- Mỗi orderer node trong cluster phải được liệt kê ở đây

---

## 2. Sinh Genesis Block cho channel

**Genesis block** là block đầu tiên của channel, chứa toàn bộ cấu hình ban đầu.

```bash
# Set FABRIC_CFG_PATH để configtxgen tìm thấy configtx.yaml
export FABRIC_CFG_PATH=./configs/configtx

mkdir -p channel-artifacts

configtxgen \
  -profile ChannelUsingRaft \
  -outputBlock ./channel-artifacts/mychannel.block \
  -channelID mychannel
```

**Giải thích flags:**
- `-profile ChannelUsingRaft`: Dùng profile này trong configtx.yaml
- `-outputBlock`: Đường dẫn lưu genesis block
- `-channelID mychannel`: Tên channel (lowercase, không có ký tự đặc biệt)

**Kiểm tra:**
```bash
ls -la channel-artifacts/mychannel.block
# Phải thấy file khoảng vài KB
```

---

## 3. Tạo channel trên Orderer (osnadmin)

Dùng `osnadmin` để gửi genesis block lên orderer qua Admin API (port 7053):

```bash
export ORDERER_CA=./organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem
export ORDERER_ADMIN_TLS_SIGN_CERT=./organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
export ORDERER_ADMIN_TLS_PRIVATE_KEY=./organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key

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

**Kiểm tra danh sách channels trên orderer:**
```bash
osnadmin channel list \
  -o localhost:7053 \
  --ca-file "$ORDERER_CA" \
  --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" \
  --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY"
```

---

## 4. Join Peer0.Org1 vào channel

Mỗi lần gọi lệnh `peer`, cần set environment variables xác định đang dùng identity của peer nào:

```bash
# Set env cho Org1
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=./organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=./organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

# Join channel
peer channel join -b ./channel-artifacts/mychannel.block
```

**Kết quả mong đợi:**
```
Successfully submitted proposal to join channel
```

**Kiểm tra:**
```bash
peer channel list
# Output: mychannel
```

---

## 5. Join Peer0.Org2 vào channel

```bash
# Set env cho Org2
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=./organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=./organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

# Join channel
peer channel join -b ./channel-artifacts/mychannel.block
```

---

## 6. Set Anchor Peers

Anchor peer là peer "đại diện" của mỗi org, được dùng để gossip với peers từ org khác.

### Tại sao cần Anchor Peer?

Gossip protocol trong Fabric hoạt động theo 2 tầng:
1. **Intra-org**: Peers trong cùng org tự tìm nhau qua bootstrap
2. **Cross-org**: Peers chỉ biết nhau qua Anchor Peer

Nếu không set anchor peer, các peer từ org khác nhau sẽ không gossip được với nhau.

### Set anchor peer cho Org1:

```bash
# Lấy config block hiện tại của channel
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=./organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=./organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer channel fetch config channel-artifacts/config_block.pb \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  -c mychannel \
  --tls \
  --cafile "$ORDERER_CA"

# Decode config block
cd channel-artifacts

configtxlator proto_decode \
  --input config_block.pb \
  --type common.Block \
  --output config_block.json

# Trích xuất phần config
jq .data.data[0].payload.data.config config_block.json > config.json

# Thêm anchor peer cho Org1
jq '.channel_group.groups.Application.groups.Org1MSP.values += {
  "AnchorPeers": {
    "mod_policy": "Admins",
    "value": {
      "anchor_peers": [{"host": "peer0.org1.example.com", "port": 7051}]
    },
    "version": "0"
  }
}' config.json > modified_config.json

# Encode cả hai về protobuf
configtxlator proto_encode --input config.json --type common.Config --output config.pb
configtxlator proto_encode --input modified_config.json --type common.Config --output modified_config.pb

# Tính delta (chỉ gửi phần thay đổi)
configtxlator compute_update \
  --channel_id mychannel \
  --original config.pb \
  --updated modified_config.pb \
  --output config_update.pb

# Wrap delta vào envelope
configtxlator proto_decode --input config_update.pb --type common.ConfigUpdate --output config_update.json
echo '{"payload":{"header":{"channel_header":{"channel_id":"mychannel","type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' | jq . > config_update_envelope.json
configtxlator proto_encode --input config_update_envelope.json --type common.Envelope --output config_update_in_envelope.pb

cd ..

# Gửi update transaction
peer channel update \
  -f channel-artifacts/config_update_in_envelope.pb \
  -c mychannel \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls \
  --cafile "$ORDERER_CA"
```

Lặp lại tương tự cho Org2 (thay `Org1MSP` → `Org2MSP`, port `7051` → `9051`).

> **Lưu ý:** Quy trình set anchor peer khá dài. Trong thực tế, script `createChannel.sh` của test-network tự động làm tất cả các bước này.

---

## 7. Kiểm tra tổng thể

```bash
# Kiểm tra peer0.org1 đã join channel
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=./organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=./organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer channel getinfo -c mychannel
# Output: Blockchain info: {"height":1,"currentBlockHash":"...","previousBlockHash":""}
```

---

**Tiếp theo:** [05-deploy-chaincode.md](05-deploy-chaincode.md)
