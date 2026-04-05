# Bước 2: Tạo Certificates (cryptogen)

## Mục tiêu

Sau bước này bạn sẽ có:
- Thư mục `organizations/` chứa toàn bộ certificates và private keys
- Certificates cho Org1, Org2, và OrdererOrg

**Không cần** cài CA server — `cryptogen` tạo tất cả offline, chỉ dùng cho môi trường dev/test.

---

## 1. File cấu hình cryptogen

Cần 3 file cấu hình. Xem samples tại [`configs/cryptogen/`](../configs/cryptogen/).

### crypto-config-org1.yaml

```yaml
PeerOrgs:
  - Name: Org1
    Domain: org1.example.com
    EnableNodeOUs: true       # Phân biệt peer/client/admin bằng OU
    Template:
      Count: 1                # Tạo 1 peer (peer0)
      SANS:
        - localhost           # QUAN TRỌNG: cần để kết nối qua localhost khi test
    Users:
      Count: 1                # Tạo 1 user ngoài Admin
```

**Giải thích:**
- `Name`: Tên tổ chức, dùng trong MSP ID → `Org1MSP`
- `Domain`: Domain name, dùng làm hostname → `peer0.org1.example.com`
- `EnableNodeOUs: true`: Cho phép phân loại node theo OU (Organizational Unit). Khi bật, file `config.yaml` trong MSP sẽ map các role:
  - `peer` OU → peers
  - `client` OU → clients/users
  - `admin` OU → admins
- `Template.Count: 1`: Tạo peer0, peer1, ... (nếu Count > 1)
- `Template.SANS`: Subject Alternative Names trong TLS cert của peer. Cần có `localhost` để kết nối từ host machine qua `localhost:7051`. Nếu thiếu, sẽ gặp lỗi `x509: certificate is valid for peer0.org1.example.com, not localhost`.
- `Users.Count: 1`: Tạo thêm 1 user thường (User1). Admin luôn được tạo tự động.

### crypto-config-org2.yaml

Tương tự Org1, đổi `Name: Org2` và `Domain: org2.example.com`. Cũng cần `SANS: [localhost]` trong Template.

### crypto-config-orderer.yaml

```yaml
OrdererOrgs:
  - Name: Orderer
    Domain: example.com
    EnableNodeOUs: true
    Specs:
      - Hostname: orderer      # → orderer.example.com
        SANS:
          - localhost          # Cho phép kết nối qua localhost
```

**Giải thích:**
- `Specs` thay vì `Template`: Khai báo tường minh từng hostname
- `SANS`: Subject Alternative Names — cho phép TLS certificate chấp nhận kết nối qua các hostname/IP này

---

## 2. Chạy cryptogen

Cần thực hiện 3 lần, một lần cho mỗi file cấu hình:

```bash
# Tạo thư mục làm việc
mkdir -p organizations

# Sinh certs cho Org1
cryptogen generate \
  --config=configs/cryptogen/crypto-config-org1.yaml \
  --output=organizations

# Sinh certs cho Org2
cryptogen generate \
  --config=configs/cryptogen/crypto-config-org2.yaml \
  --output=organizations

# Sinh certs cho Orderer
cryptogen generate \
  --config=configs/cryptogen/crypto-config-orderer.yaml \
  --output=organizations
```

### Kiểm tra kết quả:

```bash
tree organizations/ -L 4
```

Phải thấy:

```
organizations/
├── ordererOrganizations/
│   └── example.com/
│       ├── ca/
│       ├── msp/
│       ├── orderers/
│       │   └── orderer.example.com/
│       ├── tlsca/
│       └── users/
└── peerOrganizations/
    ├── org1.example.com/
    │   ├── ca/
    │   ├── msp/
    │   ├── peers/
    │   │   └── peer0.org1.example.com/
    │   ├── tlsca/
    │   └── users/
    └── org2.example.com/
        └── ...
```

---

## 3. Hiểu cấu trúc certificate được tạo ra

Lấy `peer0.org1.example.com` làm ví dụ:

```
organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/
├── msp/
│   ├── admincerts/         (trống — dùng NodeOUs nên không cần)
│   ├── cacerts/
│   │   └── ca.org1.example.com-cert.pem   ← CA cert (public)
│   ├── config.yaml         ← Map role OU → peer/client/admin
│   ├── keystore/
│   │   └── *_sk            ← Private key của peer (BẢO MẬT)
│   ├── signcerts/
│   │   └── peer0.org1.example.com-cert.pem  ← Cert của peer (public)
│   └── tlscacerts/
│       └── tlsca.org1.example.com-cert.pem  ← TLS CA cert
└── tls/
    ├── ca.crt              ← TLS CA cert (để verify server)
    ├── server.crt          ← TLS server cert của peer
    └── server.key          ← TLS server private key (BẢO MẬT)
```

**Quy tắc dùng:**
- Thư mục `msp/` → dùng để xác minh **danh tính** trong Fabric protocol
- Thư mục `tls/` → dùng để mã hóa **kết nối mạng** (TLS/SSL)

---

## 4. Kiểm tra certificate

Xem thông tin một cert:

```bash
openssl x509 -in organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/server.crt -text -noout | head -30
```

Kiểm tra cert khớp với private key:

```bash
# Lấy modulus của cert và key, phải giống nhau
openssl x509 -noout -modulus -in organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/server.crt | openssl md5
openssl rsa -noout -modulus -in organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/server.key | openssl md5
```

---

## Lỗi thường gặp

### `command not found: cryptogen`

PATH chưa có `fabric-samples/bin`. Chạy:
```bash
export PATH=$PATH:/path/to/fabric-samples/bin
```

### `Error: failed to load config`

Kiểm tra đường dẫn file config và cú pháp YAML (indent phải là spaces, không phải tabs).

### Certs đã tồn tại

Nếu muốn tạo lại từ đầu:
```bash
rm -rf organizations/
```

---

**Tiếp theo:** [03-start-network.md](03-start-network.md)
