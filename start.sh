#!/bin/sh

# ================= 配置区域 =================
# Rclone (Secret Key 建议从 Hugging Face 环境变量读取)
export RCLONE_CONFIG_REMOTE_TYPE="s3"
export RCLONE_CONFIG_REMOTE_PROVIDER="Cloudflare"
export RCLONE_CONFIG_REMOTE_ACCESS_KEY_ID="75e72cddecc51b32deab13873c967000"
export RCLONE_CONFIG_REMOTE_ENDPOINT="https://6e84f688bfe062834470070a2d946be5.r2.cloudflarestorage.com"
export RCLONE_CONFIG_REMOTE_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"

# 路径定义
DB_PATH="/home/node/.n8n/database.sqlite"
REMOTE_URL="remote:hf--backups/n8n/database.sqlite"
TEMP_BACKUP="/tmp/database.sqlite"

# ================= 核心函数 =================
run_backup() {
    if [ -f "$DB_PATH" ]; then
        echo "[$(date)] Backing up..."
        # 使用 sqlite3 生成快照以防止数据库锁死
        sqlite3 "$DB_PATH" ".backup '$TEMP_BACKUP'" && \
        rclone copyto "$TEMP_BACKUP" "$REMOTE_URL" && \
        echo "[$(date)] Backup success."
    else
        echo "[$(date)] Database not ready."
    fi
}

# 信号捕获：容器停止时执行最后一次备份
trap 'echo "Stopping..."; run_backup; kill -TERM $PID; wait $PID; exit 0' SIGTERM SIGINT

# ================= 主流程 =================
# 1. 尝试从远程恢复数据
echo "Restoring data..."
rclone copyto "$REMOTE_URL" "$DB_PATH" 2>/dev/null

# 2. 启动 n8n
echo "Starting n8n..."
n8n start &
PID=$!

# 3. 循环备份 (每 1 小时)
while kill -0 $PID >/dev/null 2>&1; do
    sleep 300 & wait $!
    run_backup
done
