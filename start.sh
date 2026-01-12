#!/bin/sh

# ============================================================
# 配置区域
# ============================================================
# Rclone 配置
export RCLONE_CONFIG_REMOTE_TYPE="s3"
export RCLONE_CONFIG_REMOTE_PROVIDER="Cloudflare"
export RCLONE_CONFIG_REMOTE_ACCESS_KEY_ID="75e72cddecc51b32deab13873c967000"
export RCLONE_CONFIG_REMOTE_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
export RCLONE_CONFIG_REMOTE_ENDPOINT="https://6e84f688bfe062834470070a2d946be5.r2.cloudflarestorage.com"

# 路径定义
REMOTE_PATH="remote:hf--backups/n8n"
# 直接写死路径，排除变量拼接带来的换行符问题
LIVE_DB_PATH="/home/node/.n8n/database.sqlite"
TEMP_BACKUP_DIR="/tmp/n8n_backup"
TEMP_BACKUP_PATH="$TEMP_BACKUP_DIR/database.sqlite"

mkdir -p $TEMP_BACKUP_DIR

# ============================================================
# 调试函数：打印环境信息
# ============================================================
debug_info() {
    echo "================ DEBUG INFO ================"
    echo "Current User: $(whoami)"
    echo "Checking directory: /home/node/.n8n/"
    if [ -d "/home/node/.n8n/" ]; then
        echo "Directory exists. Contents:"
        ls -la /home/node/.n8n/
    else
        echo "ERROR: Directory /home/node/.n8n/ DOES NOT EXIST!"
        echo "Searching for database.sqlite in entire /home/node/:"
        find /home/node/ -name "database.sqlite"
    fi
    echo "Target DB Path: [$LIVE_DB_PATH]"
    if [ -f "$LIVE_DB_PATH" ]; then
        echo "CHECK RESULT: File found!"
    else
        echo "CHECK RESULT: File NOT found!"
    fi
    echo "============================================"
}

# ============================================================
# 备份函数
# ============================================================
perform_backup() {
    echo "[$(date)] Starting backup process..."
    
    # 每次备份前运行一次调试检查
    debug_info

    if [ -f "$LIVE_DB_PATH" ]; then
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
rclone copy "$REMOTE_PATH/database.sqlite" /home/node/.n8n/

if [ -f "$LIVE_DB_PATH" ]; then
    echo "Data restored from R2."
else
    echo "No remote backup found. Starting fresh."
fi

echo "Starting n8n..."
n8n start &
N8N_PID=$!
echo "n8n started with PID $N8N_PID"

# 循环备份 (为了调试，暂时改为 10 分钟一次，避免您等太久)
while kill -0 $N8N_PID >/dev/null 2>&1; do
    sleep 300 & 
    wait $!
    perform_backup
done
