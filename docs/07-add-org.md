# Bước 7: Thêm Org3 vào mạng đang chạy

## Mục tiêu

Sau bước này bạn sẽ có:
- Org3 được thêm vào channel `mychannel`
- `peer0.org3` đã join channel và có đầy đủ ledger data
- Org3 có thể tham gia endorse transactions và truy vấn ledger

---

## Tổng quan

Thêm một org vào mạng **đang chạy** khác với khi tạo mạng ban đầu. Lý do: channel config
đã được commit lên orderer và có chữ ký của các org hiện tại. Để thay đổi config, cần:

```
1. Sinh certs cho Org3          (cryptogen)
2. Tạo org definition JSON      (configtxgen -printOrg)
3. Lấy config hiện tại          (peer channel fetch)
4. Thêm Org3 vào config         (jq)
5. Org1 ký config update        (peer channel signconfigtx)
6. Org2 gửi + ký config update  (peer channel update)
7. Khởi động peer0.org3         (docker compose)
8. Org3 join channel            (peer channel join)
9. Install + approve chaincode  (peer lifecycle)
```

Bước 5-6 là bắt buộc vì channel policy mặc định yêu cầu **majority admins** ký trước
khi config update được chấp nhận.

---

## Yêu cầu trước khi bắt đầu

- Đang đứng ở thư mục `fabric-guide/`
- Mạng cơ bản đang chạy (Bước 3)
- Channel `mychannel` đã tạo và peers đã join (Bước 4)
- `jq` đã cài:

```bash
jq --version
# Nếu chưa có: sudo apt-get install jq
```

---

## Bước 7.1: Sinh certificates cho Org3

```bash
cryptogen generate \
  --config=configs/cryptogen/crypto-config-org3.yaml \
  --output=organizations
```

Kiểm tra:
```bash
ls organizations/peerOrganizations/org3.example.com/
# ca  msp  peers  tlsca  users
```

---

## Bước 7.2: Tạo Org3 definition JSON

`configtxgen -printOrg` yêu cầu một **thư mục** chứa file tên `configtx.yaml` — không nhận tên file tuỳ ý.
File `configs/org3/configtx.yaml` định nghĩa MSP của Org3:

```bash
configtxgen \
  -printOrg Org3MSP \
  -configPath configs/org3 \
  > channel-artifacts/org3.json
```

Kiểm tra:
```bash
cat channel-artifacts/org3.json | jq 'keys'
# ["groups", "mod_policy", "policies", "values", "version"]
```

---

## Bước 7.3: Lấy config block hiện tại của channel

```bash
export FABRIC_CFG_PATH=$(pwd)/configs/node-config
BASE=$(pwd)/organizations

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${BASE}/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${BASE}/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

export ORDERER_CA=$(pwd)/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt

peer channel fetch config channel-artifacts/config_block.pb \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  -c mychannel \
  --tls \
  --cafile "$ORDERER_CA"
```

---

## Bước 7.4: Chuyển đổi và thêm Org3 vào config

Quá trình này gồm nhiều lệnh nhỏ. Chạy tuần tự từ thư mục `fabric-guide/`:

```bash
cd channel-artifacts

# Decode config block về JSON
configtxlator proto_decode \
  --input config_block.pb \
  --type common.Block \
  --output config_block.json

# Trích xuất phần config
jq .data.data[0].payload.data.config config_block.json > config.json

# Thêm Org3MSP vào Application.groups
jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups":{"Org3MSP":.[1]}}}}}' \
  config.json \
  org3.json \
  > modified_config.json

# Encode cả hai về protobuf
configtxlator proto_encode \
  --input config.json \
  --type common.Config \
  --output config.pb

configtxlator proto_encode \
  --input modified_config.json \
  --type common.Config \
  --output modified_config.pb

# Tính delta (chỉ phần thay đổi)
configtxlator compute_update \
  --channel_id mychannel \
  --original config.pb \
  --updated modified_config.pb \
  --output config_update.pb

# Wrap delta vào envelope để gửi lên channel
configtxlator proto_decode \
  --input config_update.pb \
  --type common.ConfigUpdate \
  --output config_update.json

echo '{"payload":{"header":{"channel_header":{"channel_id":"mychannel","type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' \
  | jq . > config_update_envelope.json

configtxlator proto_encode \
  --input config_update_envelope.json \
  --type common.Envelope \
  --output config_update_in_envelope.pb

cd ..
```

**Tại sao cần nhiều bước vậy?**
Fabric lưu channel config dưới dạng protobuf. Không thể edit trực tiếp —
phải decode → sửa JSON → encode lại → tính delta → gửi delta lên channel.

---

## Bước 7.5: Org1 ký config update

```bash
export FABRIC_CFG_PATH=$(pwd)/configs/node-config
BASE=$(pwd)/organizations

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${BASE}/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${BASE}/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer channel signconfigtx \
  -f channel-artifacts/config_update_in_envelope.pb
```

---

## Bước 7.6: Org2 gửi config update (kèm chữ ký của Org2)

Khi gọi `peer channel update`, peer tự động đính kèm chữ ký của org đang dùng.
Vì Org1 đã ký ở bước 7.5, lệnh này gửi update có đủ 2 chữ ký (Org1 + Org2):

```bash
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${BASE}/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${BASE}/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer channel update \
  -f channel-artifacts/config_update_in_envelope.pb \
  -c mychannel \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls \
  --cafile "$ORDERER_CA"
```

**Kết quả mong đợi:**
```
Successfully submitted channel update
```

Lúc này Org3 đã được ghi vào channel config. Peer0.org3 chưa tồn tại nhưng
channel đã "biết" về Org3.

---

## Bước 7.7: Khởi động peer0.org3

```bash
export DOCKER_SOCK=/var/run/docker.sock

docker compose -f configs/compose/compose-org3.yaml up -d
```

Kiểm tra:
```bash
docker ps --filter "name=peer0.org3" --format "table {{.Names}}\t{{.Status}}"
# peer0.org3.example.com   Up X seconds

curl -k https://localhost:11444/healthz
# {"status":"OK"}
```

---

## Bước 7.8: Org3 join channel

```bash
export FABRIC_CFG_PATH=$(pwd)/configs/node-config
BASE=$(pwd)/organizations

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org3MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${BASE}/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${BASE}/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051

peer channel join -b ./channel-artifacts/mychannel.block
```

Kiểm tra:
```bash
peer channel list
# mychannel
```

> Sau khi join, peer0.org3 sẽ tự đồng bộ toàn bộ lịch sử ledger từ các peers khác
> qua gossip protocol. Quá trình này diễn ra tự động, không cần làm gì thêm.

---

## Bước 7.9: Install chaincode lên peer0.org3

Org3 cần install cùng package đã dùng để deploy (đảm bảo package ID giống nhau):

```bash
export GOFLAGS="-buildvcs=false"

# Package lại nếu chưa có basic.tar.gz
peer lifecycle chaincode package basic.tar.gz \
  --path ./fabric-samples/asset-transfer-basic/chaincode-go \
  --lang golang \
  --label basic_1.0

# Install lên peer0.org3
peer lifecycle chaincode install basic.tar.gz

# Lấy package ID
export CC_PACKAGE_ID=$(peer lifecycle chaincode calculatepackageid basic.tar.gz)
echo $CC_PACKAGE_ID
```

---

## Bước 7.10: Org3 approve chaincode

Org3 cần approve chaincode definition với **cùng tham số** mà Org1/Org2 đã dùng khi commit:

```bash
export ORDERER_CA=$(pwd)/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt

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

**Kiểm tra:**
```bash
peer lifecycle chaincode querycommitted \
  --channelID mychannel \
  --name basic \
  --cafile "$ORDERER_CA"
```

> **Lưu ý:** Org3 approve nhưng không cần commit lại vì chaincode đã được committed
> với sequence 1. Org3 chỉ cần approve để có thể endorse transactions.

---

## Bước 7.11: Kiểm tra Org3 có thể query

```bash
peer chaincode query \
  -C mychannel \
  -n basic \
  -c '{"Args":["GetAllAssets"]}'
```

Phải thấy danh sách assets — Org3 đã đồng bộ ledger thành công.

---

## Endorsement policy sau khi thêm Org3

Chaincode hiện tại vẫn dùng policy mặc định (`MAJORITY Endorsement`). Với 3 org,
majority = 2/3. Nếu muốn Org3 **bắt buộc phải** endorse, cần update endorsement
policy bằng cách upgrade chaincode (tăng sequence):

```bash
# Ví dụ: yêu cầu cả 3 org endorse
peer lifecycle chaincode approveformyorg \
  --channelID mychannel \
  --name basic \
  --version 1.0 \
  --sequence 2 \
  --signature-policy "AND('Org1MSP.peer','Org2MSP.peer','Org3MSP.peer')" \
  ...

# Tương tự cho Org1 và Org2, sau đó commit với sequence 2
```

---

## Dọn dẹp Org3

```bash
docker compose -f configs/compose/compose-org3.yaml down -v
```

Để xóa luôn certs của Org3:
```bash
rm -rf organizations/peerOrganizations/org3.example.com
```

---

## Lỗi thường gặp

### `Error: got unexpected status: BAD_REQUEST`

Config update có lỗi hoặc không đủ chữ ký. Kiểm tra:
- Đã ký đủ số org theo channel policy chưa
- `--channel_id` trong `compute_update` có khớp với channel thật không

### `Error: proposal failed with status: 500`

Org3 chưa được thêm vào channel config, hoặc channel config update chưa được commit.
Kiểm tra bằng `peer channel getinfo -c mychannel` và so sánh block height.

### Ledger của peer0.org3 không đồng bộ

Peer mới join cần thời gian để sync qua gossip. Chờ 10-30 giây rồi query lại.

---

**Tiếp theo:** Xem thêm các chủ đề mở rộng trong `docs/` hoặc tham khảo [Fabric documentation](https://hyperledger-fabric.readthedocs.io).
