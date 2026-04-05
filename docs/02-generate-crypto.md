# Bước 2: Tạo Certificates (cryptogen)

## Mục tiêu

Sau bước này bạn sẽ có:
- Thư mục `organizations/` chứa toàn bộ certificates và private keys
- Certificates cho Org1, Org2, và OrdererOrg

**Không cần** cài CA server — `cryptogen` tạo tất cả offline, chỉ dùng cho môi trường dev/test.

---

## Yêu cầu trước khi bắt đầu

- Đang đứng ở thư mục làm việc (nơi chứa `fabric-samples/` và `configs/`)
- `cryptogen` đã có trong PATH (Bước 0)

```bash
# Kiểm tra
which cryptogen
```

---

## 1. File cấu hình cryptogen

Các file cấu hình nằm tại `configs/cryptogen/`. Nội dung mỗi file:

### `crypto-config-org1.yaml`

```yaml
PeerOrgs:
  - Name: Org1
    Domain: org1.example.com
    EnableNodeOUs: true       # Phân biệt peer/client/admin bằng OU
    Template:
      Count: 1                # Tạo 1 peer (peer0)
      SANS:
        - localhost           # Cho phép kết nối qua localhost khi test
    Users:
      Count: 1                # Tạo 1 user ngoài Admin
```

**Giải thích:**
- `Name`: Tên tổ chức, dùng trong MSP ID → `Org1MSP`
- `Domain`: Domain name, dùng làm hostname → `peer0.org1.example.com`
- `EnableNodeOUs: true`: Phân loại node theo OU. Khi bật, MSP sẽ phân biệt:
  - `peer` OU → peers
  - `client` OU → clients/users
  - `admin` OU → admins
- `Template.SANS`: Subject Alternative Names trong TLS cert. Cần có `localhost` để kết nối từ host machine qua `localhost:7051`. Nếu thiếu sẽ gặp lỗi `x509: certificate is valid for peer0.org1.example.com, not localhost`.

### `crypto-config-org2.yaml`

Tương tự Org1, đổi `Name: Org2` và `Domain: org2.example.com`.

### `crypto-config-orderer.yaml`

```yaml
OrdererOrgs:
  - Name: Orderer
    Domain: example.com
    EnableNodeOUs: true
    Specs:
      - Hostname: orderer      # → orderer.example.com
        SANS:
          - localhost
```

Dùng `Specs` thay vì `Template` để khai báo tường minh từng hostname.

---

## 2. Chạy cryptogen

Từ thư mục làm việc:

```bash
mkdir -p organizations

cryptogen generate \
  --config=configs/cryptogen/crypto-config-org1.yaml \
  --output=organizations

cryptogen generate \
  --config=configs/cryptogen/crypto-config-org2.yaml \
  --output=organizations

cryptogen generate \
  --config=configs/cryptogen/crypto-config-orderer.yaml \
  --output=organizations
```

### Kiểm tra kết quả:

```bash
ls organizations/
# ordererOrganizations  peerOrganizations

ls organizations/peerOrganizations/
# org1.example.com  org2.example.com

ls organizations/ordererOrganizations/
# example.com
```

---

## 3. Cấu trúc certificate được tạo ra

Lấy `peer0.org1.example.com` làm ví dụ:

```
organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/
├── msp/
│   ├── cacerts/
│   │   └── ca.org1.example.com-cert.pem    ← CA cert (public)
│   ├── config.yaml                         ← Map role OU → peer/client/admin
│   ├── keystore/
│   │   └── *_sk                            ← Private key của peer (BẢO MẬT)
│   ├── signcerts/
│   │   └── peer0.org1.example.com-cert.pem ← Cert của peer (public)
│   └── tlscacerts/
│       └── tlsca.org1.example.com-cert.pem ← TLS CA cert
└── tls/
    ├── ca.crt      ← TLS CA cert (để verify server)
    ├── server.crt  ← TLS server cert của peer
    └── server.key  ← TLS server private key (BẢO MẬT)
```

**Quy tắc dùng:**
- `msp/` → xác minh **danh tính** trong Fabric protocol
- `tls/` → mã hóa **kết nối mạng** (TLS/SSL)

---

## Lỗi thường gặp

### `command not found: cryptogen`

Chạy lại từ thư mục làm việc:
```bash
export PATH=$PATH:$(pwd)/fabric-samples/bin
```

### `Error: failed to load config`

Kiểm tra đường dẫn file config. Indent trong YAML phải dùng spaces, không dùng tabs.

### Muốn tạo lại certs từ đầu

```bash
rm -rf organizations/
```
Sau đó chạy lại các lệnh `cryptogen generate` ở trên.

---

**Tiếp theo:** [03-start-network.md](03-start-network.md)
