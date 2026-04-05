# Bước 0: Cài đặt môi trường

## Mục tiêu

Sau bước này bạn sẽ có:
- Docker và Docker Compose đang chạy
- Fabric binaries (`peer`, `orderer`, `cryptogen`, `configtxgen`) trong PATH
- Fabric Docker images đã pull về máy
- Thư mục `fabric-samples/` chứa mã nguồn tham khảo

---

## 1. Kiểm tra yêu cầu hệ thống

### Docker

```bash
docker version
docker compose version
```

Yêu cầu:
- Docker Engine >= 18.09
- Docker Compose >= 1.29 (hoặc Docker Compose plugin v2)

Nếu chưa cài: https://docs.docker.com/engine/install/

### Git

```bash
git --version
```

### curl

```bash
curl --version
```

---

## 2. Tải Fabric binaries và Docker images

Chạy lệnh sau tại thư mục bạn muốn cài (ví dụ `~/projects`):

```bash
curl -sSL https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh | bash -s -- binary docker samples
```

### Giải thích các tham số:

| Tham số | Tác dụng |
|---------|----------|
| `binary` | Tải Fabric binaries về thư mục `bin/` |
| `docker` | Pull Docker images của Fabric |
| `samples` | Clone repo `fabric-samples` từ GitHub |

### Script này làm gì:

```
1. Clone https://github.com/hyperledger/fabric-samples.git
2. Tải archive binaries từ GitHub releases:
   - Fabric v2.5.x  → giải nén vào fabric-samples/bin/ và fabric-samples/config/
   - Fabric CA v1.5.x → giải nén vào fabric-samples/bin/
3. Pull Docker images:
   - hyperledger/fabric-peer
   - hyperledger/fabric-orderer
   - hyperledger/fabric-ccenv
   - hyperledger/fabric-baseos
   - hyperledger/fabric-ca
```

### Kết quả sau khi chạy:

```
fabric-samples/
├── bin/
│   ├── peer              ← CLI tương tác với peer
│   ├── orderer           ← Binary chạy orderer node
│   ├── cryptogen         ← Sinh certificates
│   ├── configtxgen       ← Sinh genesis block và channel tx
│   ├── configtxlator     ← Convert config format
│   ├── discover          ← Service discovery tool
│   └── fabric-ca-client  ← Fabric CA client
├── config/
│   ├── core.yaml         ← Config mặc định cho peer
│   ├── orderer.yaml      ← Config mặc định cho orderer
│   └── configtx.yaml     ← Config mẫu cho channel
└── test-network/         ← Mạng test để tham khảo
```

---

## 3. Thêm binaries vào PATH

```bash
# Thêm vào ~/.bashrc hoặc ~/.zshrc
export PATH=$PATH:$(pwd)/fabric-samples/bin
export FABRIC_CFG_PATH=$(pwd)/fabric-samples/config
```

Sau đó reload:

```bash
source ~/.bashrc
```

### Kiểm tra:

```bash
peer version
# Output mẫu:
# peer:
#  Version: 2.5.x
#  Commit SHA: ...

cryptogen version
# Output mẫu:
# cryptogen:
#  Version: 2.5.x

configtxgen --version
# Output mẫu:
# configtxgen:
#  Version: 2.5.x
```

---

## 4. Kiểm tra Docker images

```bash
docker images | grep hyperledger
```

Phải thấy các images:

```
hyperledger/fabric-peer      latest    ...
hyperledger/fabric-orderer   latest    ...
hyperledger/fabric-ccenv     latest    ...
hyperledger/fabric-baseos    latest    ...
hyperledger/fabric-ca        latest    ...
```

---

## Kiểm tra tổng thể

Chạy lệnh sau để xác nhận mọi thứ đã sẵn sàng:

```bash
# Binaries có trong PATH
which peer && peer version | head -2
which cryptogen && cryptogen version | head -2
which configtxgen && configtxgen --version | head -2

# Docker đang chạy
docker info | grep "Server Version"

# Images đã có
docker images | grep hyperledger | awk '{print $1, $2}'
```

---

## Lỗi thường gặp

### `permission denied` khi chạy Docker

```bash
sudo usermod -aG docker $USER
newgrp docker
```

### Script tải chậm hoặc fail

Tải thủ công từ: https://github.com/hyperledger/fabric/releases

### `command not found: peer`

PATH chưa được cập nhật. Chạy lại `source ~/.bashrc` hoặc mở terminal mới.

---

**Tiếp theo:** [01-network-overview.md](01-network-overview.md)
