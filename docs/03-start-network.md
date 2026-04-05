# Bước 3: Khởi động mạng (Docker Compose)

## Mục tiêu

Sau bước này bạn sẽ có:
- 3 containers đang chạy: `orderer.example.com`, `peer0.org1.example.com`, `peer0.org2.example.com`
- Mỗi node đã được cấu hình TLS và MSP
- Các node đã kết nối với nhau trong Docker network `fabric_test`

---

## Yêu cầu trước khi bắt đầu

- Đang đứng ở thư mục làm việc
- Bước 2 đã hoàn thành — thư mục `organizations/` phải tồn tại:

```bash
ls organizations/peerOrganizations/ organizations/ordererOrganizations/
```

---

## 1. Docker Compose file

File `configs/compose/compose-test-net.yaml` định nghĩa 3 services: `orderer.example.com`, `peer0.org1.example.com`, `peer0.org2.example.com`.

Tất cả đều dùng **relative paths** khi mount volumes — vì vậy lệnh `docker compose` phải chạy từ thư mục làm việc.

### Orderer service (tóm tắt)

```yaml
services:
  orderer.example.com:
    image: hyperledger/fabric-orderer:latest
    environment:
      - ORDERER_GENERAL_LOCALMSPID=OrdererMSP
      - ORDERER_GENERAL_TLS_ENABLED=true
      - ORDERER_GENERAL_BOOTSTRAPMETHOD=none
      - ORDERER_CHANNELPARTICIPATION_ENABLED=true  # Dùng channel participation API (Fabric 2.3+)
      - ORDERER_ADMIN_LISTENADDRESS=0.0.0.0:7053   # Admin API để tạo channel
    volumes:
      - ./organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp:/var/hyperledger/orderer/msp
      - ./organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls:/var/hyperledger/orderer/tls
    ports:
      - 7050:7050   # Orderer endpoint
      - 7053:7053   # Admin API (dùng osnadmin)
      - 9443:9443   # Operations/metrics
```

**Điểm quan trọng:**
- `ORDERER_GENERAL_BOOTSTRAPMETHOD=none` + `ORDERER_CHANNELPARTICIPATION_ENABLED=true`: Dùng cách tạo channel mới từ Fabric 2.3+, không cần system channel.
- `ORDERER_ADMIN_LISTENADDRESS=0.0.0.0:7053`: Port để `osnadmin channel join` gửi genesis block khi tạo channel.

### Peer service (tóm tắt)

```yaml
  peer0.org1.example.com:
    image: hyperledger/fabric-peer:latest
    environment:
      - CORE_PEER_ID=peer0.org1.example.com
      - CORE_PEER_LOCALMSPID=Org1MSP
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer0.org1.example.com:7051
    volumes:
      - ./organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/msp:/etc/hyperledger/fabric/msp
      - ./organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls:/etc/hyperledger/fabric/tls
      - /var/run/docker.sock:/host/var/run/docker.sock  # Peer tạo chaincode container
    ports:
      - 7051:7051   # Peer endpoint
      - 9444:9444   # Operations/metrics
```

**Điểm quan trọng:**
- `/var/run/docker.sock`: Cho phép peer container tạo chaincode container khi deploy.

---

## 2. Khởi động mạng

Từ thư mục làm việc:

```bash
export DOCKER_SOCK=/var/run/docker.sock

docker compose -f configs/compose/compose-test-net.yaml up -d
```

> Bạn có thể thấy warning `the attribute 'version' is obsolete` — đây là warning bình thường từ Docker Compose v2, không ảnh hưởng đến hoạt động.

---

## 3. Kiểm tra kết quả

### Containers đang chạy:

```bash
docker ps
```

Phải thấy 3 containers:

```
NAMES                    STATUS         PORTS
orderer.example.com      Up X seconds   0.0.0.0:7050->7050/tcp, 0.0.0.0:7053->7053/tcp
peer0.org1.example.com   Up X seconds   0.0.0.0:7051->7051/tcp
peer0.org2.example.com   Up X seconds   0.0.0.0:9051->9051/tcp
```

### Kiểm tra health:

```bash
curl -k https://localhost:9443/healthz   # Orderer
curl -k https://localhost:9444/healthz   # peer0.org1
curl -k https://localhost:9445/healthz   # peer0.org2
# Output mỗi cái: {"status":"OK"}
```

### Theo dõi logs nếu cần debug:

```bash
docker logs -f orderer.example.com
docker logs -f peer0.org1.example.com
```

---

## 4. Cổng mạng tóm tắt

| Container | Port | Mục đích |
|-----------|------|----------|
| orderer.example.com | 7050 | Nhận transactions từ clients |
| orderer.example.com | 7053 | Admin API (osnadmin) |
| orderer.example.com | 9443 | Operations (health, metrics) |
| peer0.org1.example.com | 7051 | Nhận requests từ clients |
| peer0.org1.example.com | 9444 | Operations |
| peer0.org2.example.com | 9051 | Nhận requests từ clients |
| peer0.org2.example.com | 9445 | Operations |

---

## 5. Dừng và dọn dẹp

```bash
# Dừng containers (giữ data)
docker compose -f configs/compose/compose-test-net.yaml stop

# Dừng và xóa containers + networks (giữ volumes)
docker compose -f configs/compose/compose-test-net.yaml down

# Dừng và xóa tất cả kể cả volumes (xóa sạch data) ← DÙNG CÁI NÀY KHI MUỐN RESET
docker compose -f configs/compose/compose-test-net.yaml down -v
```

> **Quan trọng:** Khi muốn chạy lại từ đầu (regenerate certs mới), **phải** dùng `down -v`
> để xóa Docker named volumes. Nếu chỉ dùng `down`, containers bị xóa nhưng volumes vẫn còn —
> lần start tiếp theo orderer sẽ dùng state cũ từ volume, xung đột với certs mới và gây lỗi TLS.

---

## Lỗi thường gặp

### Container khởi động rồi tự tắt

Xem logs để biết nguyên nhân:
```bash
docker logs orderer.example.com
```

Nguyên nhân phổ biến:
- Cert file không tìm thấy → đường dẫn mount sai hoặc chưa chạy Bước 2
- MSP directory không hợp lệ → chạy lại cryptogen

### Port đã bị dùng

```bash
lsof -i :7050
# Tắt process đang dùng port đó hoặc thay đổi port trong compose file
```

### `Error: no such file or directory` khi mount volumes

Lệnh `docker compose` phải chạy từ thư mục làm việc (nơi có thư mục `organizations/`).

---

**Tiếp theo:** [04-create-channel.md](04-create-channel.md)
