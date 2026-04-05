# Bước 0: Cài đặt môi trường

## Mục tiêu

Sau bước này bạn sẽ có:
- Docker và Docker Compose đang chạy
- Go đã cài
- Fabric binaries (`peer`, `orderer`, `cryptogen`, `configtxgen`, `osnadmin`) trong PATH
- Fabric Docker images đã pull về máy

---

## Yêu cầu: Clone repo này trước

Toàn bộ hướng dẫn sử dụng các file cấu hình có sẵn trong repo (`configs/`).
Clone repo về và `cd` vào — đây sẽ là **thư mục làm việc** cho mọi bước:

```bash
git clone <url-repo> fabric-guide
cd fabric-guide
```

> Từ đây trở đi, **mọi lệnh đều chạy từ thư mục `fabric-guide/`** trừ khi có ghi chú khác.
> Nếu mở terminal mới, hãy `cd fabric-guide` trước.

---

## 1. Kiểm tra Docker

```bash
docker version
docker compose version
```

Yêu cầu: Docker Engine >= 18.09, Docker Compose >= 1.29 (hoặc plugin v2).

Nếu chưa cài: https://docs.docker.com/engine/install/

Nếu gặp lỗi `permission denied`:
```bash
sudo usermod -aG docker $USER
newgrp docker
```

---

## 2. Kiểm tra / Cài Go

```bash
go version
# go version go1.21.x linux/amd64
```

Nếu chưa cài:
```bash
curl -sSL https://go.dev/dl/go1.21.13.linux-amd64.tar.gz -o /tmp/go.tar.gz
sudo tar -C /usr/local -xzf /tmp/go.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc
```

---

## 3. Tải Fabric binaries và Docker images

Chạy lệnh sau **từ bên trong thư mục `fabric-guide/`**:

```bash
curl -sSL https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh \
  | bash -s -- binary docker samples
```

Script tạo ra thư mục `fabric-samples/` ngay trong thư mục hiện tại:

```
fabric-samples/
├── bin/
│   ├── peer, orderer, cryptogen
│   ├── configtxgen, configtxlator
│   └── osnadmin, fabric-ca-client
├── config/
│   ├── core.yaml
│   └── orderer.yaml
└── asset-transfer-basic/    ← Chaincode mẫu dùng ở Bước 5
```

> `fabric-samples/` đã có trong `.gitignore` — sẽ không bị commit vào repo.

---

## 4. Thêm Fabric binaries vào PATH

Chạy từ thư mục `fabric-guide/`:

```bash
export PATH=$PATH:$(pwd)/fabric-samples/bin
```

Để không phải chạy lại mỗi lần mở terminal mới:
```bash
echo "export PATH=\$PATH:$(pwd)/fabric-samples/bin" >> ~/.bashrc
source ~/.bashrc
```

---

## 5. Kiểm tra tổng thể

```bash
peer version | head -2
cryptogen version | head -2
configtxgen --version | head -2
osnadmin version
go version

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

hyperledger/fabric-peer      latest
hyperledger/fabric-orderer   latest
hyperledger/fabric-ccenv     latest
hyperledger/fabric-baseos    latest
```

---

## Lỗi thường gặp

### `command not found: cryptogen` / `peer`

PATH chưa được set. Chạy lại từ thư mục `fabric-guide/`:
```bash
export PATH=$PATH:$(pwd)/fabric-samples/bin
```

### Script tải chậm hoặc fail

Tải thủ công tại: https://github.com/hyperledger/fabric/releases

---

**Tiếp theo:** [01-network-overview.md](01-network-overview.md)
