#!/bin/sh

# ============================================================
# 配置区域
# ============================================================
# Rclone 配置 (自动读取环境变量)
export RCLONE_CONFIG_REMOTE_TYPE="s3"
export RCLONE_CONFIG_REMOTE_PROVIDER="Cloudflare"
export RCLONE_CONFIG_REMOTE_ACCESS_KEY_ID="75e72cddecc51b32deab13873c967000"
export RCLONE_CONFIG_REMOTE_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
export RCLONE_CONFIG_REMOTE_ENDPOINT="https://6e84f688bfe062834470070a2d946be5.r2.cloudflarestorage.com"

# 路径定义
REMOTE_PATH="remote:hf--backups/n8n"
DB_FILE="database.sqlite"
LIVE_DB_PATH="/home/node/.n8n/$DB_FILE"
TEMP_BACKUP_DIR="/tmp/n8n_backup"
TEMP_BACKUP_PATH="$TEMP_BACKUP_DIR/$DB_FILE"

mkdir -p $TEMP_BACKUP_DIR

# ============================================================
# 函数定义
# ============================================================
perform_backup() {
    echo "[$(date)] Starting backup process..."
    if [ -f "$LIVE_DB_PATH" ]; then
        # 使用 sqlite3 生成安全快照
        sqlite3 "$LIVE_DB_PATH" ".backup '$TEMP_BACKUP_PATH'"
        if [ $? -eq 0 ]; then
            echo "[$(date)] SQLite snapshot created."
            rclone copy "$TEMP_BACKUP_PATH" "$REMOTE_PATH"
            echo "[$(date)] Upload to R2 completed."
        else
            echo "[$(date)] ERROR: Failed to create snapshot."
        fi
    else
        echo "[$(date)] Database not found, skipping backup."
    fi
}

cleanup() {
    echo "!!! Received termination signal. Performing final backup..."
    perform_backup
    echo "Stopping n8n..."
    kill -TERM "$N8N_PID" 2>/dev/null
    wait "$N8N_PID"
    exit 0
}

# ============================================================
# 主流程
# ============================================================
trap cleanup SIGTERM SIGINT

echo "Checking for remote backup..."
rclone copy "$REMOTE_PATH/$DB_FILE" /home/node/.n8n/

if [ -f "$LIVE_DB_PATH" ]; then
    echo "Data restored from R2."
else
    echo "No remote backup found. Starting fresh."
fi

echo "Starting n8n..."

# ------------------------------------------------------------
# 关键修改：直接使用 n8n 命令
# ------------------------------------------------------------
n8n start &
N8N_PID=$!

echo "n8n started with PID $N8N_PID"

# 循环备份 (每 1 小时)
while kill -0 $N8N_PID >/dev/null 2>&1; do
    sleep 3600 &
    wait $!
    perform_backup
done
