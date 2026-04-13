# Bước 8 (nâng cao): 3 máy ảo Ubuntu (VMware) — SSH từ máy ngoài

## Mục tiêu

Giữ **cùng topology** với các bước trước (1 orderer, `peer0.org1`, `peer0.org2`, channel `mychannel`), nhưng:

- Mỗi node chạy trên **một máy ảo Ubuntu** (VMware),
- Bạn **SSH từ máy ngoài** vào từng VM,
- Mở **ba cửa sổ terminal**, mỗi terminal một phiên SSH — tiện để `docker compose up`, xem log, gõ lệnh trên đúng máy.

```
  Máy ngoài (PC)                    Mạng VMware / LAN
  ┌─────────────┐
  │ Terminal 1  │──ssh──► VM Ubuntu: Orderer   (orderer.example.com)
  │ Terminal 2  │──ssh──► VM Ubuntu: Org1 peer (peer0.org1.example.com)
  │ Terminal 3  │──ssh──► VM Ubuntu: Org2 peer (peer0.org2.example.com)
  └─────────────┘
```

---

## 1. Chuẩn bị VMware và mạng

### 1.1. Ba máy ảo Ubuntu

- Cài **Ubuntu Server** hoặc Desktop (20.04/22.04 đều được), bật **OpenSSH Server** để SSH vào được.
- Trên **mỗi VM** cài Docker và các bước trong [00-prerequisites.md](00-prerequisites.md) (trừ phần chỉ dành cho “một máy duy nhất” nếu có).

### 1.2. Cho ba VM “thấy” nhau (ping được)

- **Bridged (cầu nối)** thường dễ nhất: mỗi VM lấy IP cùng dải với router LAN (ví dụ `192.168.1.x`), ping được lẫn nhau và thường ping được cả máy ngoài.
- **Host-only** hoặc **NAT tùy chỉnh** cũng được, miễn **ba IP cố định hoặc dễ nhớ** và **ba VM cùng segment** có thể mở port tới nhau.

Ghi lại **ba IP**, ví dụ:

| VM        | Vai trò   | IP ví dụ      |
|-----------|-----------|---------------|
| `fabric-orderer` | Orderer   | `192.168.56.10` |
| `fabric-org1`    | peer0.org1 | `192.168.56.11` |
| `fabric-org2`    | peer0.org2 | `192.168.56.12` |

(Dùng IP thật của bạn thay cho bảng trên.)

### 1.3. SSH từ máy ngoài

Trên **máy ngoài** (Windows, macOS, Linux đều được), mở ba terminal và kết nối kiểu:

```bash
ssh <user>@<IP_ORDERER>   # Terminal 1 — VM orderer
ssh <user>@<IP_ORG1>      # Terminal 2 — VM Org1
ssh <user>@<IP_ORG2>      # Terminal 3 — VM Org2
```

Gợi ý: trong `~/.ssh/config` (Linux/macOS) hoặc `C:\Users\...\/.ssh/config` (Windows, OpenSSH) có thể đặt alias cho gọn:

```text
Host fabric-orderer
  HostName <IP_ORDERER>
  User ubuntu

Host fabric-org1
  HostName <IP_ORG1>
  User ubuntu

Host fabric-org2
  HostName <IP_ORG2>
  User ubuntu
```

Sau đó: `ssh fabric-orderer`, `ssh fabric-org1`, `ssh fabric-org2`.

**Máy ngoài không bắt buộc** phải có `/etc/hosts` cho Fabric nếu bạn **chỉ dùng IP để SSH** và **mọi lệnh `peer` / `osnadmin` / `configtxgen` đều chạy bên trong các VM** (khuyến nghị cho bài lab này).

### 1.4. Ví dụ lệnh cho đúng 3 máy của bạn

Giả sử bạn có 3 máy và IP như sau:

| Server | Vai trò | IP |
|---|---|---|
| `orderer-server` | Orderer | `192.168.0.103` |
| `org1-server` | peer0.org1 | `192.168.0.101` |
| `org2-server` | peer0.org2 | `192.168.0.102` |

Mở 3 terminal trên máy ngoài:

```bash
ssh <user>@192.168.0.103   # Terminal 1 — orderer-server
ssh <user>@192.168.0.101   # Terminal 2 — org1-server
ssh <user>@192.168.0.102   # Terminal 3 — org2-server
```

---

## 2. `/etc/hosts` trên cả ba Ubuntu

Các container Fabric dùng tên `orderer.example.com`, `peer0.org1.example.com`, `peer0.org2.example.com` trong cấu hình và khi **các node nói chuyện với nhau** (gossip, orderer, commit nhiều peer). Vì vậy **trên cả ba máy ảo Ubuntu** cần cùng một bản ánh xạ tên → IP.

Sửa file với quyền root trên **mỗi** VM:

```bash
sudo nano /etc/hosts
```

Thêm (thay IP bằng IP thật của bạn):

```text
192.168.0.103  orderer.example.com
192.168.0.101  peer0.org1.example.com
192.168.0.102  peer0.org2.example.com
```

Lưu file. Kiểm tra trên VM Org1:

```bash
ping -c 2 orderer.example.com
ping -c 2 peer0.org2.example.com
```

Nếu bạn sau này chạy `peer` CLI **trên máy ngoài** (ví dụ WSL), máy đó cũng cần bản `/etc/hosts` tương tự (hoặc DNS nội bộ).

---

## 3. TLS (cert) và IP trong SANS

Cert do `cryptogen` tạo có **Subject Alternative Names (SANS)**. Repo mặc định đã có `localhost` trong SANS — nhờ đó bạn có thể gọi `osnadmin` tới `localhost:7053` và `peer channel join` tới `localhost:7051` / `localhost:9051` **trên đúng VM** (xem mục 6).

Để **các peer/orderer kết nối TLS với nhau bằng tên `*.example.com`**, cần `/etc/hosts` như mục 2. Nếu bạn muốn **chỉ dùng IP** khi gõ lệnh (ít gọn hơn), hãy thêm IP từng VM vào `SANS` trong `crypto-config-*.yaml` trước khi sinh cert (chi tiết đã nêu ở phiên bản trước của tài liệu này; với lab VMware + `/etc/hosts`, thường **không cần** thêm SAN IP).

Với triển khai “thực tế hơn”, mỗi org nên **tự sinh** crypto material của mình (vẫn dùng `cryptogen` cho lab) và **không chia sẻ private key**. Thứ được trao đổi giữa các VM/org là **public certificates (CA/TLS-CA)** và **channel artifacts** (block/update), không phải `keystore`.

Trong lab đơn giản, bạn vẫn có thể sinh cert **một lần** (trên một VM hoặc trên máy ngoài có WSL), rồi copy đúng phần cần thiết — xem [02-generate-crypto.md](02-generate-crypto.md).

---

## 4. Đồng bộ repo và `organizations/` lên từng VM

Trên **cả ba VM** nên có cùng repo `fabric-guide` (git clone hoặc `scp`/`rsync`).

### 4.1. Tối thiểu để chạy node (không chia sẻ private key)

| VM Orderer | VM Org1 | VM Org2 |
|------------|---------|---------|
| Toàn bộ `organizations/ordererOrganizations/example.com/` | Toàn bộ `organizations/peerOrganizations/org1.example.com/` | Toàn bộ `organizations/peerOrganizations/org2.example.com/` |
| `configs/compose/compose-orderer-only.yaml`, `configs/node-config/` nếu cần | `compose-peer-org1-only.yaml`, `configs/node-config/` | `compose-peer-org2-only.yaml`, `configs/node-config/` |

Gợi ý thêm để “đúng chất multi-org”:

- **Private thứ cần giữ local**: `keystore/` và các khóa riêng của user/admin của từng org (nằm trong cây `users/.../msp/keystore` và `peers/.../msp/keystore`, `orderers/.../msp/keystore`, `*/tls/server.key`). Không nên copy chéo giữa các org.
- **Public thứ có thể chia sẻ** (để bên khác tin cậy/kết nối TLS):
  - **Orderer TLS-CA cert**: `organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem`
  - **Peer TLS-CA cert** của từng org (để client/CLI ở VM khác có thể gọi tới peer qua TLS): ví dụ `organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem`, tương tự cho org2
  - (Nếu bạn tách CA & TLS-CA rõ ràng) các root CA cert trong `*/msp/cacerts/` cũng là public.

### 4.2. (Tuỳ chọn) Đường tắt lab: copy “full `organizations/`”
Nếu bạn muốn thao tác nhanh theo kiểu “một VM làm CLI” và không quan tâm việc private key bị tập trung, bạn có thể copy nguyên thư mục `organizations/` lên một VM (thường VM orderer). Cách này tiện cho lab nhưng **không hay** trong triển khai thật.

### 4.3. Ví dụ lệnh “thực tế hơn” theo IP của bạn (không share private key)

Giả sử:

- `org1-server`: `192.168.0.101`
- `org2-server`: `192.168.0.102`
- `orderer-server`: `192.168.0.103`

Và bạn SSH bằng user `<user>`, repo ở `~/fabric-guide`.

**Bước A — mỗi server tự sinh phần crypto của mình (cryptogen).**

- Trên `orderer-server`:

```bash
cd ~/fabric-guide
rm -rf organizations/ordererOrganizations
cryptogen generate --config=./configs/cryptogen/crypto-config-orderer.yaml --output=./organizations
```

- Trên `org1-server`:

```bash
cd ~/fabric-guide
rm -rf organizations/peerOrganizations/org1.example.com
cryptogen generate --config=./configs/cryptogen/crypto-config-org1.yaml --output=./organizations
```

- Trên `org2-server`:

```bash
cd ~/fabric-guide
rm -rf organizations/peerOrganizations/org2.example.com
cryptogen generate --config=./configs/cryptogen/crypto-config-org2.yaml --output=./organizations
```

**Bước B — Org1/Org2 chỉ gửi “MSP public” sang orderer-server để chạy `configtxgen`.**

- Trên `org1-server`:

```bash
scp -r ~/fabric-guide/organizations/peerOrganizations/org1.example.com/msp \
  <user>@192.168.0.103:~/fabric-guide/organizations/peerOrganizations/org1.example.com/
```

- Trên `org2-server`:

```bash
scp -r ~/fabric-guide/organizations/peerOrganizations/org2.example.com/msp \
  <user>@192.168.0.103:~/fabric-guide/organizations/peerOrganizations/org2.example.com/
```

**Bước C — (tuỳ chọn) orderer-server gửi orderer TLS-CA cert (public) cho 2 org** để các bước sau (deploy/commit) nếu cần gọi TLS tới `orderer.example.com:7050` từ VM org:

- Trên `org1-server` và `org2-server` (tạo chỗ để nhận file):

```bash
mkdir -p ~/fabric-guide/channel-artifacts
```

- Trên `orderer-server`:

```bash
scp ~/fabric-guide/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem \
  <user>@192.168.0.101:~/fabric-guide/channel-artifacts/orderer-tlsca.pem

scp ~/fabric-guide/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem \
  <user>@192.168.0.102:~/fabric-guide/channel-artifacts/orderer-tlsca.pem
```

---

## 5. Ba terminal SSH: khởi động Docker Compose

Làm việc trong thư mục gốc project trên **mỗi** VM (ví dụ `~/fabric-guide`). Thứ tự: orderer trước, sau đó hai peer (song song cũng được).

**Terminal 1 — SSH vào VM orderer**

```bash
cd ~/fabric-guide
docker compose -f configs/compose/compose-orderer-only.yaml up -d
docker ps
```

**Terminal 2 — SSH vào VM Org1**

```bash
cd ~/fabric-guide
docker compose -f configs/compose/compose-peer-org1-only.yaml up -d
docker ps
```

**Terminal 3 — SSH vào VM Org2**

```bash
cd ~/fabric-guide
docker compose -f configs/compose/compose-peer-org2-only.yaml up -d
docker ps
```

Kiểm tra liên mạng (trên bất kỳ VM nào, sau khi đã sửa `/etc/hosts`):

```bash
nc -zv orderer.example.com 7050
nc -zv peer0.org1.example.com 7051
nc -zv peer0.org2.example.com 9051
```

(Cài `netcat` nếu chưa có: `sudo apt install netcat-openbsd`.)

---

## 6. Tạo channel và join — hai cách làm (khuyến nghị: không tập trung private key)

Bạn vẫn có thể chỉ dùng **ba** terminal nếu phân chia lệnh như sau.

- **Cách A (khuyến nghị, “thực tế hơn”)**: VM nào chỉ dùng identity của org đó; trao đổi qua lại bằng cách copy **channel artifacts** và (khi cần gọi TLS) copy **TLS-CA cert (public)**.
- **Cách B (đường tắt lab)**: một VM giữ “full `organizations/`” để chạy hết lệnh. Nhanh nhưng gom private key.

### 6.1. Sinh `mychannel.block` và `osnadmin` (nên làm trên VM orderer)

Trên **VM orderer**, cần thư mục `channel-artifacts/`, `fabric-samples/bin` trong `PATH` (xem [00-prerequisites.md](00-prerequisites.md)), và đủ thông tin org trong `configs/configtx` để chạy `configtxgen`.

- Nếu bạn đang theo **Cách A**: “đủ thông tin org” nghĩa là VM orderer có **MSP public** của các org tham gia channel (cacerts/tlscacerts + cấu trúc MSP), không nhất thiết phải có private key admin của org khác.
- Nếu theo **Cách B**: bạn có thể dùng “full `organizations/`” cho nhanh.

Trong repo này, `configtxgen` thường đọc `MSPDir` trỏ vào cây `organizations/.../msp`. Vì vậy với **Cách A**, cách đơn giản là:

- Trên VM orderer, giữ đầy đủ `organizations/ordererOrganizations/example.com/` (local, có private key của orderer)
- Từ Org1/Org2, chỉ copy **MSP folder public** sang VM orderer (không cần `users/.../msp/keystore`):
  - `organizations/peerOrganizations/org1.example.com/msp/`
  - `organizations/peerOrganizations/org2.example.com/msp/`

```bash
cd ~/fabric-guide
mkdir -p channel-artifacts
export FABRIC_CFG_PATH=$(pwd)/configs/configtx
export PATH=$PATH:$(pwd)/fabric-samples/bin

configtxgen -profile ChannelUsingRaft \
  -outputBlock ./channel-artifacts/mychannel.block \
  -channelID mychannel

export ORDERER_CA=$(pwd)/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem
export ORDERER_ADMIN_TLS_SIGN_CERT=$(pwd)/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
export ORDERER_ADMIN_TLS_PRIVATE_KEY=$(pwd)/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key

osnadmin channel join \
  --channelID mychannel \
  --config-block ./channel-artifacts/mychannel.block \
  -o localhost:7053 \
  --ca-file "$ORDERER_CA" \
  --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" \
  --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY"
```

### 6.2. Copy `mychannel.block` sang hai VM peer

Từ **máy ngoài** (PowerShell có `scp`) hoặc từ VM orderer:

```bash
scp ~/fabric-guide/channel-artifacts/mychannel.block <user>@<IP_VM_Org1>:~/fabric-guide/channel-artifacts/
scp ~/fabric-guide/channel-artifacts/mychannel.block <user>@<IP_VM_Org2>:~/fabric-guide/channel-artifacts/
```

(Tạo `channel-artifacts` trên VM peer trước nếu chưa có: `mkdir -p ~/fabric-guide/channel-artifacts`.)

### 6.3. Join — dùng đúng **Terminal 2** và **Terminal 3** (localhost)

Cert trong repo có SAN `localhost`, nên trên **đúng VM** có thể nối tới peer qua `localhost`.

**Terminal 2 — VM Org1**

```bash
cd ~/fabric-guide
export FABRIC_CFG_PATH=$(pwd)/configs/node-config
export PATH=$PATH:$(pwd)/fabric-samples/bin
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=Org1MSP
export CORE_PEER_TLS_ROOTCERT_FILE=$(pwd)/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$(pwd)/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer channel join -b ./channel-artifacts/mychannel.block
```

**Terminal 3 — VM Org2**

```bash
cd ~/fabric-guide
export FABRIC_CFG_PATH=$(pwd)/configs/node-config
export PATH=$PATH:$(pwd)/fabric-samples/bin
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=Org2MSP
export CORE_PEER_TLS_ROOTCERT_FILE=$(pwd)/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$(pwd)/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer channel join -b ./channel-artifacts/mychannel.block
```

### 6.4. Deploy chaincode (cần chỉ tới orderer + cả hai peer)

Làm theo [05-deploy-chaincode.md](05-deploy-chaincode.md), nhưng thay `localhost:7050` bằng **`orderer.example.com:7050`** (hoặc IP orderer nếu đã thêm SAN IP), và `--peerAddresses` dùng **`peer0.org1.example.com:7051`** và **`peer0.org2.example.com:9051`** — các tên này phải resolve được **trên máy đang chạy lệnh** (VM đó cần `/etc/hosts` như mục 2).

Gợi ý theo **Cách A (khuyến nghị)**:

- `package`: làm ở bất kỳ đâu, rồi copy gói `.tar.gz` sang VM Org1 và VM Org2
- `install`: chạy trên **VM Org1** và **VM Org2** (mỗi org tự cài lên peer của mình)
- `approve`: chạy trên **VM Org1** và **VM Org2** (mỗi org tự approve bằng Admin của mình)
- `commit`: chạy trên **một** VM bất kỳ (thường VM Org1), chỉ cần identity của org đó + có thể gọi TLS tới orderer/peers (tức là hostname resolve được và có các `--tlsRootCertFiles` phù hợp). Không cần mang private key org khác sang.

---

## 7. File Compose trong repo

| File | VM |
|------|-----|
| [configs/compose/compose-orderer-only.yaml](../configs/compose/compose-orderer-only.yaml) | Chỉ orderer |
| [configs/compose/compose-peer-org1-only.yaml](../configs/compose/compose-peer-org1-only.yaml) | Chỉ `peer0.org1` |
| [configs/compose/compose-peer-org2-only.yaml](../configs/compose/compose-peer-org2-only.yaml) | Chỉ `peer0.org2` |

Mạng một máy (cả ba container trên một host) vẫn dùng [compose-test-net.yaml](../configs/compose/compose-test-net.yaml).

---

## 8. Checklist nhanh

- [ ] VMware: ba Ubuntu cùng mạng, ping được nhau  
- [ ] Cả ba VM: cùng một nội dung `/etc/hosts` cho ba hostname Fabric  
- [ ] Ba terminal SSH: mỗi terminal một VM  
- [ ] `docker compose` đúng file trên từng VM  
- [ ] `configtxgen` + `osnadmin` trên VM có full `organizations/`  
- [ ] `mychannel.block` đã có trên hai VM peer trước khi `peer channel join`  
- [ ] Firewall Ubuntu (`ufw`) nếu bật thì mở đủ port orderer / peer  

---

**Quay lại tổng quan:** [01-network-overview.md](01-network-overview.md)
