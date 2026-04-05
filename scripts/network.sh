#!/bin/bash
# network.sh — Script tiện ích để quản lý mạng Fabric
#
# Dùng:
#   ./scripts/network.sh up              # Tạo certs + khởi động containers
#   ./scripts/network.sh channel         # Tạo channel và join peers
#   ./scripts/network.sh deploy          # Deploy chaincode asset-transfer-basic
#   ./scripts/network.sh down            # Dừng và dọn dẹp tất cả
#   ./scripts/network.sh status          # Xem trạng thái containers

set -e

# ============================================================
# Cấu hình
# ============================================================
CHANNEL_NAME="mychannel"
CHAINCODE_NAME="basic"
CHAINCODE_VERSION="1.0"
CHAINCODE_SEQUENCE="1"

# Đường dẫn (tương đối với thư mục gốc project)
COMPOSE_FILE="./configs/compose/compose-test-net.yaml"
CONFIGTX_DIR="./configs/configtx"
CRYPTOGEN_DIR="./configs/cryptogen"
ORGANIZATIONS_DIR="./organizations"
CHANNEL_ARTIFACTS_DIR="./channel-artifacts"

# Binaries (cần có trong PATH hoặc chỉ định đường dẫn)
# Nếu dùng fabric-samples: export PATH=$PATH:/path/to/fabric-samples/bin
PEER_BIN="peer"
ORDERER_BIN="orderer"
CRYPTOGEN_BIN="cryptogen"
CONFIGTXGEN_BIN="configtxgen"
OSNADMIN_BIN="osnadmin"

# ============================================================
# Helper functions
# ============================================================

log() {
    echo ""
    echo "============================================================"
    echo "  $1"
    echo "============================================================"
}

check_prereqs() {
    log "Kiểm tra prerequisites"
    for cmd in $PEER_BIN $CRYPTOGEN_BIN $CONFIGTXGEN_BIN $OSNADMIN_BIN docker; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "ERROR: '$cmd' không tìm thấy trong PATH"
            echo "Chạy bước 0: docs/00-prerequisites.md"
            exit 1
        fi
    done
    echo "OK: Tất cả binaries đã sẵn sàng"
    docker info > /dev/null 2>&1 || { echo "ERROR: Docker không chạy"; exit 1; }
    echo "OK: Docker đang chạy"
}

set_org1_env() {
    # Dùng absolute paths — peer resolve relative paths từ FABRIC_CFG_PATH, không phải PWD
    local BASE
    BASE=$(pwd)/organizations
    export FABRIC_CFG_PATH=$(pwd)/configs/node-config
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE="${BASE}/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt"
    export CORE_PEER_MSPCONFIGPATH="${BASE}/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp"
    export CORE_PEER_ADDRESS=localhost:7051
}

set_org2_env() {
    local BASE
    BASE=$(pwd)/organizations
    export FABRIC_CFG_PATH=$(pwd)/configs/node-config
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID="Org2MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE="${BASE}/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt"
    export CORE_PEER_MSPCONFIGPATH="${BASE}/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp"
    export CORE_PEER_ADDRESS=localhost:9051
}

# ============================================================
# Bước 2: Sinh certificates
# ============================================================
generate_crypto() {
    log "Sinh certificates (cryptogen)"

    if [ -d "$ORGANIZATIONS_DIR" ]; then
        echo "Thư mục $ORGANIZATIONS_DIR đã tồn tại. Bỏ qua."
        return
    fi

    $CRYPTOGEN_BIN generate --config="${CRYPTOGEN_DIR}/crypto-config-org1.yaml" --output="$ORGANIZATIONS_DIR"
    echo "✓ Đã tạo certs cho Org1"

    $CRYPTOGEN_BIN generate --config="${CRYPTOGEN_DIR}/crypto-config-org2.yaml" --output="$ORGANIZATIONS_DIR"
    echo "✓ Đã tạo certs cho Org2"

    $CRYPTOGEN_BIN generate --config="${CRYPTOGEN_DIR}/crypto-config-orderer.yaml" --output="$ORGANIZATIONS_DIR"
    echo "✓ Đã tạo certs cho Orderer"
}

# ============================================================
# Bước 3: Khởi động containers
# ============================================================
start_network() {
    log "Khởi động containers (Docker Compose)"

    export DOCKER_SOCK=/var/run/docker.sock
    docker compose -f "$COMPOSE_FILE" up -d

    echo ""
    echo "Đang chờ containers khởi động..."
    sleep 3

    echo ""
    docker ps --filter "label=service=hyperledger-fabric" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# ============================================================
# Bước 4: Tạo channel
# ============================================================
create_channel() {
    log "Tạo channel: $CHANNEL_NAME"

    mkdir -p "$CHANNEL_ARTIFACTS_DIR"

    # Sinh genesis block (cần FABRIC_CFG_PATH trỏ đến configtx.yaml)
    echo "[1/4] Sinh genesis block..."
    export FABRIC_CFG_PATH=$(pwd)/configs/configtx
    $CONFIGTXGEN_BIN \
        -profile ChannelUsingRaft \
        -outputBlock "${CHANNEL_ARTIFACTS_DIR}/${CHANNEL_NAME}.block" \
        -channelID "$CHANNEL_NAME"
    echo "✓ Genesis block: ${CHANNEL_ARTIFACTS_DIR}/${CHANNEL_NAME}.block"

    # Biến TLS cho orderer admin API (absolute paths)
    export ORDERER_CA=$(pwd)/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem
    export ORDERER_ADMIN_TLS_SIGN_CERT=$(pwd)/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
    export ORDERER_ADMIN_TLS_PRIVATE_KEY=$(pwd)/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key

    # Tạo channel trên orderer
    echo "[2/4] Tạo channel trên orderer..."
    $OSNADMIN_BIN channel join \
        --channelID "$CHANNEL_NAME" \
        --config-block "${CHANNEL_ARTIFACTS_DIR}/${CHANNEL_NAME}.block" \
        -o localhost:7053 \
        --ca-file "$ORDERER_CA" \
        --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" \
        --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY"
    echo "✓ Channel đã được tạo trên orderer"

    # Join peer0.org1
    echo "[3/4] Join peer0.org1 vào channel..."
    set_org1_env
    $PEER_BIN channel join -b "${CHANNEL_ARTIFACTS_DIR}/${CHANNEL_NAME}.block"
    echo "✓ peer0.org1 đã join channel"

    # Join peer0.org2
    echo "[4/4] Join peer0.org2 vào channel..."
    set_org2_env
    $PEER_BIN channel join -b "${CHANNEL_ARTIFACTS_DIR}/${CHANNEL_NAME}.block"
    echo "✓ peer0.org2 đã join channel"

    echo ""
    echo "Channel '$CHANNEL_NAME' đã sẵn sàng!"
    echo "Kiểm tra: peer channel getinfo -c $CHANNEL_NAME"
}

# ============================================================
# Bước 5: Deploy chaincode
# ============================================================
deploy_chaincode() {
    log "Deploy chaincode: $CHAINCODE_NAME v$CHAINCODE_VERSION"

    # Đường dẫn đến chaincode (cần fabric-samples)
    CC_SRC_PATH="../fabric-samples/asset-transfer-basic/chaincode-go"
    if [ ! -d "$CC_SRC_PATH" ]; then
        echo "ERROR: Không tìm thấy chaincode tại $CC_SRC_PATH"
        echo "Cần clone fabric-samples trước (docs/00-prerequisites.md)"
        exit 1
    fi

    export ORDERER_CA=$(pwd)/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem
    export PEER0_ORG1_CA=$(pwd)/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export PEER0_ORG2_CA=$(pwd)/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt

    # Package (GOFLAGS cần thiết với Go 1.18+ khi không có .git)
    echo "[1/5] Package chaincode..."
    export GOFLAGS="-buildvcs=false"
    $PEER_BIN lifecycle chaincode package ${CHAINCODE_NAME}.tar.gz \
        --path "$CC_SRC_PATH" \
        --lang golang \
        --label ${CHAINCODE_NAME}_${CHAINCODE_VERSION}
    echo "✓ Package: ${CHAINCODE_NAME}.tar.gz"

    # Lấy package ID
    set_org1_env
    CC_PACKAGE_ID=$($PEER_BIN lifecycle chaincode calculatepackageid ${CHAINCODE_NAME}.tar.gz)
    echo "✓ Package ID: $CC_PACKAGE_ID"

    # Install trên peer0.org1
    echo "[2/5] Install trên peer0.org1..."
    set_org1_env
    $PEER_BIN lifecycle chaincode install ${CHAINCODE_NAME}.tar.gz
    echo "✓ Installed trên peer0.org1"

    # Install trên peer0.org2
    echo "      Install trên peer0.org2..."
    set_org2_env
    $PEER_BIN lifecycle chaincode install ${CHAINCODE_NAME}.tar.gz
    echo "✓ Installed trên peer0.org2"

    # Approve từ Org1
    echo "[3/5] Org1 approve chaincode definition..."
    set_org1_env
    $PEER_BIN lifecycle chaincode approveformyorg \
        --channelID "$CHANNEL_NAME" \
        --name "$CHAINCODE_NAME" \
        --version "$CHAINCODE_VERSION" \
        --package-id "$CC_PACKAGE_ID" \
        --sequence "$CHAINCODE_SEQUENCE" \
        -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
        --tls \
        --cafile "$ORDERER_CA"
    echo "✓ Org1 đã approve"

    # Approve từ Org2
    echo "      Org2 approve chaincode definition..."
    set_org2_env
    $PEER_BIN lifecycle chaincode approveformyorg \
        --channelID "$CHANNEL_NAME" \
        --name "$CHAINCODE_NAME" \
        --version "$CHAINCODE_VERSION" \
        --package-id "$CC_PACKAGE_ID" \
        --sequence "$CHAINCODE_SEQUENCE" \
        -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
        --tls \
        --cafile "$ORDERER_CA"
    echo "✓ Org2 đã approve"

    # Kiểm tra readiness
    echo "[4/5] Kiểm tra commit readiness..."
    set_org1_env
    $PEER_BIN lifecycle chaincode checkcommitreadiness \
        --channelID "$CHANNEL_NAME" \
        --name "$CHAINCODE_NAME" \
        --version "$CHAINCODE_VERSION" \
        --sequence "$CHAINCODE_SEQUENCE" \
        --tls \
        --cafile "$ORDERER_CA" \
        --output json

    # Commit
    echo "[5/5] Commit chaincode definition..."
    set_org1_env
    $PEER_BIN lifecycle chaincode commit \
        --channelID "$CHANNEL_NAME" \
        --name "$CHAINCODE_NAME" \
        --version "$CHAINCODE_VERSION" \
        --sequence "$CHAINCODE_SEQUENCE" \
        -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
        --tls \
        --cafile "$ORDERER_CA" \
        --peerAddresses localhost:7051 \
        --tlsRootCertFiles "$PEER0_ORG1_CA" \
        --peerAddresses localhost:9051 \
        --tlsRootCertFiles "$PEER0_ORG2_CA"
    echo "✓ Chaincode đã được commit"

    echo ""
    echo "Chaincode '$CHAINCODE_NAME' đã sẵn sàng!"
    echo "Kiểm tra: peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name $CHAINCODE_NAME"
}

# ============================================================
# Bước 6: Test chaincode
# ============================================================
test_chaincode() {
    log "Test chaincode"

    local ORDERER_CA=$(pwd)/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem
    local PEER0_ORG1_CA=$(pwd)/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    local PEER0_ORG2_CA=$(pwd)/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt

    set_org1_env

    # InitLedger
    echo "Khởi tạo ledger (InitLedger)..."
    $PEER_BIN chaincode invoke \
        -o localhost:7050 \
        --ordererTLSHostnameOverride orderer.example.com \
        --tls --cafile "$ORDERER_CA" \
        -C "$CHANNEL_NAME" -n "$CHAINCODE_NAME" \
        --peerAddresses localhost:7051 --tlsRootCertFiles "$PEER0_ORG1_CA" \
        --peerAddresses localhost:9051 --tlsRootCertFiles "$PEER0_ORG2_CA" \
        -c '{"function":"InitLedger","Args":[]}'

    sleep 2

    # Query
    echo ""
    echo "Query tất cả assets:"
    $PEER_BIN chaincode query \
        -C "$CHANNEL_NAME" -n "$CHAINCODE_NAME" \
        -c '{"Args":["GetAllAssets"]}' | jq .
}

# ============================================================
# Dọn dẹp
# ============================================================
network_down() {
    log "Dừng mạng và dọn dẹp"

    docker compose -f "$COMPOSE_FILE" down -v 2>/dev/null || true
    docker rm -f $(docker ps -aq --filter "name=dev-peer") 2>/dev/null || true
    docker rmi -f $(docker images -q "dev-peer*") 2>/dev/null || true

    rm -rf "$ORGANIZATIONS_DIR" "$CHANNEL_ARTIFACTS_DIR" *.tar.gz 2>/dev/null || true

    echo "✓ Đã dọn dẹp xong"
}

# ============================================================
# Trạng thái
# ============================================================
network_status() {
    echo ""
    echo "=== Containers đang chạy ==="
    docker ps --filter "label=service=hyperledger-fabric" \
        --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "(không có container nào)"
}

# ============================================================
# Main
# ============================================================
MODE=$1

case $MODE in
    up)
        check_prereqs
        generate_crypto
        start_network
        ;;
    channel)
        create_channel
        ;;
    deploy)
        deploy_chaincode
        ;;
    test)
        test_chaincode
        ;;
    down)
        network_down
        ;;
    status)
        network_status
        ;;
    all)
        # Chạy toàn bộ pipeline
        check_prereqs
        generate_crypto
        start_network
        sleep 5
        create_channel
        sleep 3
        deploy_chaincode
        sleep 3
        test_chaincode
        ;;
    *)
        echo "Dùng: $0 {up|channel|deploy|test|down|status|all}"
        echo ""
        echo "  up      - Sinh certs và khởi động containers"
        echo "  channel - Tạo channel mychannel và join peers"
        echo "  deploy  - Deploy chaincode basic (cần fabric-samples)"
        echo "  test    - InitLedger và query assets"
        echo "  down    - Dừng tất cả và xóa sạch"
        echo "  status  - Xem trạng thái containers"
        echo "  all     - Chạy toàn bộ pipeline (up + channel + deploy + test)"
        exit 1
        ;;
esac
