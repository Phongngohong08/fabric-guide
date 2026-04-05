# Bước 0: Cài đặt môi trường

## Mục tiêu

Sau bước này bạn sẽ có:
- Docker và Docker Compose đang chạy
- Go đã cài
- Fabric binaries (`peer`, `orderer`, `cryptogen`, `configtxgen`) trong PATH
- Fabric Docker images đã pull về máy
- Thư mục làm việc đã sẵn sàng để chạy các bước tiếp theo

---

## 1. Tạo thư mục làm việc

Chọn một thư mục để làm nơi chứa toàn bộ project. Ví dụ:

```bash
mkdir ~/fabric-network
cd ~/fabric-network
```

> Từ đây trở đi, **mọi lệnh đều chạy từ thư mục này** trừ khi có ghi chú khác.
> Nếu mở terminal mới, hãy `cd` về thư mục này trước.

---

## 2. Kiểm tra yêu cầu hệ thống

### Docker

```bash
docker version
docker compose version
```

Yêu cầu:
- Docker Engine >= 18.09
- Docker Compose >= 1.29 (hoặc Docker Compose plugin v2)

Nếu chưa cài: https://docs.docker.com/engine/install/

Nếu gặp lỗi `permission denied` khi chạy Docker:
```bash
sudo usermod -aG docker $USER
newgrp docker
```

### Git và curl

```bash
git --version
curl --version
```

---

## 3. Cài Go

```bash
curl -sSL https://go.dev/dl/go1.21.13.linux-amd64.tar.gz -o /tmp/go.tar.gz
sudo tar -C /usr/local -xzf /tmp/go.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc
go version
# go version go1.21.13 linux/amd64
```

---

## 4. Tải Fabric binaries và Docker images

Chạy lệnh này **từ bên trong thư mục làm việc** (bước 1):

```bash
curl -sSL https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh \
  | bash -s -- binary docker samples
```

| Tham số | Tác dụng |
|---------|----------|
| `binary` | Tải Fabric binaries vào `fabric-samples/bin/` |
| `docker` | Pull Docker images của Fabric |
| `samples` | Clone repo `fabric-samples` từ GitHub |

Script sẽ tạo ra thư mục `fabric-samples/` ngay trong thư mục hiện tại:

```
fabric-samples/
├── bin/
│   ├── peer              ← CLI tương tác với peer
│   ├── orderer           ← Binary chạy orderer node
│   ├── cryptogen         ← Sinh certificates
│   ├── configtxgen       ← Sinh genesis block và channel tx
│   ├── configtxlator     ← Convert config format
│   ├── osnadmin          ← Quản lý channel trên orderer
│   └── fabric-ca-client  ← Fabric CA client
├── config/
│   ├── core.yaml         ← Config mặc định cho peer
│   └── orderer.yaml      ← Config mặc định cho orderer
└── asset-transfer-basic/ ← Chaincode mẫu dùng ở Bước 5
```

---

## 5. Thêm Fabric binaries vào PATH

Chạy lệnh này **từ thư mục làm việc** để set PATH cho session hiện tại:

```bash
export PATH=$PATH:$(pwd)/fabric-samples/bin
export FABRIC_CFG_PATH=$(pwd)/fabric-samples/config
```

Để không phải chạy lại mỗi lần mở terminal mới, lưu đường dẫn tuyệt đối vào `~/.bashrc`:

```bash
echo "export PATH=\$PATH:$(pwd)/fabric-samples/bin" >> ~/.bashrc
echo "export FABRIC_CFG_PATH=$(pwd)/fabric-samples/config" >> ~/.bashrc
```

> `FABRIC_CFG_PATH` ở đây là giá trị mặc định. Các bước sau sẽ override biến này
> tùy từng lệnh (xem Bước 2 và Bước 4).

---

## 6. Sao chép configs vào project

Fabric binaries cần `core.yaml` và `orderer.yaml` khi chạy. Copy từ `fabric-samples`:

```bash
mkdir -p configs/node-config
cp fabric-samples/config/core.yaml configs/node-config/
cp fabric-samples/config/orderer.yaml configs/node-config/
```

> Nếu bạn đang dùng repo `fabric-guide` đã clone sẵn, thư mục `configs/` đã có đầy đủ
> file config — bỏ qua bước này.

---

## 7. Kiểm tra tổng thể

```bash
# Binaries có trong PATH
peer version | head -3
cryptogen version | head -3
configtxgen --version | head -3
go version

# Docker đang chạy
docker info | grep "Server Version"

# Images đã có
docker images | grep hyperledger | awk '{print $1, $2}'
```

Output mẫu:

```
peer:
 Version: 2.5.x

cryptogen:
 Version: 2.5.x

configtxgen:
 Version: 2.5.x

go version go1.21.13 linux/amd64

Server Version: 24.x.x

hyperledger/fabric-peer      latest
hyperledger/fabric-orderer   latest
hyperledger/fabric-ccenv     latest
hyperledger/fabric-baseos    latest
hyperledger/fabric-ca        latest
```

---

## Lỗi thường gặp

### `command not found: cryptogen` / `command not found: peer`

PATH chưa được set. Chạy lại từ thư mục làm việc:
```bash
export PATH=$PATH:$(pwd)/fabric-samples/bin
```
Hoặc mở terminal mới sau khi đã lưu vào `~/.bashrc`.

### Script tải chậm hoặc fail

Tải thủ công từ: https://github.com/hyperledger/fabric/releases

---

**Tiếp theo:** [01-network-overview.md](01-network-overview.md)
