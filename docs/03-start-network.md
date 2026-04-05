# Bước 3: Khởi động mạng (Docker Compose)

## Mục tiêu

Sau bước này bạn sẽ có:
- 3 containers đang chạy: `orderer.example.com`, `peer0.org1.example.com`, `peer0.org2.example.com`
- Mỗi node đã được cấu hình TLS và MSP
- Các node đã kết nối với nhau trong Docker network `fabric_test`

---

## 1. Yêu cầu trước khi bắt đầu

Bước 2 đã tạo xong, thư mục `organizations/` phải tồn tại:

```bash
ls organizations/peerOrganizations/ organizations/ordererOrganizations/
```

---

## 2. File Docker Compose

Xem file đầy đủ tại [`configs/compose/compose-test-net.yaml`](../configs/compose/compose-test-net.yaml).

### Orderer service

```yaml
services:
  orderer.example.com:
    image: hyperledger/fabric-orderer:latest
    environment:
      - ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_LISTENPORT=7050
      - ORDERER_GENERAL_LOCALMSPID=OrdererMSP
      - ORDERER_GENERAL_LOCALMSPDIR=/var/hyperledger/orderer/msp

      # TLS
      - ORDERER_GENERAL_TLS_ENABLED=true
      - ORDERER_GENERAL_TLS_PRIVATEKEY=/var/hyperledger/orderer/tls/server.key
      - ORDERER_GENERAL_TLS_CERTIFICATE=/var/hyperledger/orderer/tls/server.crt
      - ORDERER_GENERAL_TLS_ROOTCAS=[/var/hyperledger/orderer/tls/ca.crt]

      # Raft consensus
      - ORDERER_GENERAL_BOOTSTRAPMETHOD=none
      - ORDERER_CHANNELPARTICIPATION_ENABLED=true
      - ORDERER_ADMIN_TLS_ENABLED=true
      - ORDERER_ADMIN_LISTENADDRESS=0.0.0.0:7053

    volumes:
      # Mount MSP và TLS certs từ bước 2
      - ./organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp:/var/hyperledger/orderer/msp
      - ./organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls:/var/hyperledger/orderer/tls
      # Lưu data orderer
      - orderer.example.com:/var/hyperledger/production/orderer

    ports:
      - 7050:7050   # Orderer endpoint
      - 7053:7053   # Admin API (dùng để tạo channel)
      - 9443:9443   # Operations/metrics
    networks:
      - fabric_test
```

**Điểm quan trọng:**
- `ORDERER_GENERAL_BOOTSTRAPMETHOD=none` + `ORDERER_CHANNELPARTICIPATION_ENABLED=true`: Dùng **channel participation API** (cách mới từ Fabric 2.3+), không dùng system channel nữa
- `ORDERER_ADMIN_LISTENADDRESS=0.0.0.0:7053`: Port để gọi `osnadmin channel join` khi tạo channel

### Peer service (Org1)

```yaml
  peer0.org1.example.com:
    image: hyperledger/fabric-peer:latest
    environment:
      - CORE_PEER_ID=peer0.org1.example.com
      - CORE_PEER_ADDRESS=peer0.org1.example.com:7051
      - CORE_PEER_LISTENADDRESS=0.0.0.0:7051
      - CORE_PEER_LOCALMSPID=Org1MSP
      - CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/msp

      # TLS
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt

      # Gossip protocol (peer-to-peer communication)
      - CORE_PEER_GOSSIP_USELEADERELECTION=true
      - CORE_PEER_GOSSIP_ORGLEADER=false
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer0.org1.example.com:7051
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer0.org1.example.com:7051

      # Chaincode
      - CORE_PEER_CHAINCODEADDRESS=peer0.org1.example.com:7052
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:7052

    volumes:
      - ./organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/msp:/etc/hyperledger/fabric/msp
      - ./organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls:/etc/hyperledger/fabric/tls
      # Cho phép peer tạo Docker containers cho chaincode
      - /var/run/docker.sock:/host/var/run/docker.sock
      # Lưu data peer
      - peer0.org1.example.com:/var/hyperledger/production

    ports:
      - 7051:7051   # Peer endpoint
      - 9444:9444   # Operations/metrics
    networks:
      - fabric_test
```

**Điểm quan trọng:**
- `/var/run/docker.sock:/host/var/run/docker.sock`: Cho phép peer container tạo chaincode container khi deploy
- `CORE_PEER_GOSSIP_BOOTSTRAP`: Peer sẽ kết nối với địa chỉ này khi khởi động để khám phá network

---

## 3. Khởi động mạng

```bash
# Đặt biến môi trường
export DOCKER_SOCK=/var/run/docker.sock

# Khởi động tất cả containers
docker compose -f configs/compose/compose-test-net.yaml up -d
```

### Theo dõi logs:

```bash
# Xem logs của orderer
docker logs -f orderer.example.com

# Xem logs của peer Org1
docker logs -f peer0.org1.example.com

# Xem logs của peer Org2
docker logs -f peer0.org2.example.com
```

---

## 4. Kiểm tra kết quả

### Containers đang chạy:

```bash
docker ps
```

Phải thấy:

```
CONTAINER ID   IMAGE                               COMMAND             STATUS         PORTS
xxxxxxxxxxxx   hyperledger/fabric-orderer:latest   "orderer"           Up X seconds   0.0.0.0:7050->7050/tcp, 0.0.0.0:7053->7053/tcp
xxxxxxxxxxxx   hyperledger/fabric-peer:latest      "peer node start"   Up X seconds   0.0.0.0:7051->7051/tcp
xxxxxxxxxxxx   hyperledger/fabric-peer:latest      "peer node start"   Up X seconds   0.0.0.0:9051->9051/tcp
```

### Kiểm tra health orderer:

```bash
curl -k https://localhost:9443/healthz
# Output: {"status":"OK"}
```

### Kiểm tra health peer Org1:

```bash
curl -k https://localhost:9444/healthz
# Output: {"status":"OK"}
```

---

## 5. Cổng mạng tóm tắt

| Container | Port | Mục đích |
|-----------|------|----------|
| orderer.example.com | 7050 | Nhận transactions từ clients |
| orderer.example.com | 7053 | Admin API (osnadmin) |
| orderer.example.com | 9443 | Operations (health, metrics) |
| peer0.org1.example.com | 7051 | Nhận requests từ clients |
| peer0.org1.example.com | 7052 | Chaincode communication |
| peer0.org1.example.com | 9444 | Operations |
| peer0.org2.example.com | 9051 | Nhận requests từ clients |
| peer0.org2.example.com | 9052 | Chaincode communication |
| peer0.org2.example.com | 9445 | Operations |

---

## 6. Dừng và dọn dẹp

```bash
# Dừng containers (giữ data)
docker compose -f configs/compose/compose-test-net.yaml stop

# Dừng và xóa containers + networks (giữ volumes)
docker compose -f configs/compose/compose-test-net.yaml down

# Dừng và xóa tất cả kể cả volumes (xóa sạch data)
docker compose -f configs/compose/compose-test-net.yaml down -v
```

---

## Lỗi thường gặp

### `Error: no such file or directory` khi mount volumes

Kiểm tra đường dẫn trong `volumes:` section có đúng với cấu trúc `organizations/` chưa.

### Container khởi động rồi tự tắt

Xem logs để biết lỗi:
```bash
docker logs orderer.example.com
```

Lỗi phổ biến:
- Cert file không tìm thấy → đường dẫn mount sai
- MSP directory không hợp lệ → chạy lại cryptogen

### Port đã bị dùng

```bash
# Kiểm tra cổng 7050 có đang dùng không
lsof -i :7050
```

---

**Tiếp theo:** [04-create-channel.md](04-create-channel.md)
