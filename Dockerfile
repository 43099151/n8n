FROM node:22-bookworm-slim

USER root

# 1. 安装系统工具
RUN apt-get update && \
    apt-get install -y rclone sqlite3 ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# 2. 安装 n8n
RUN npm install -g n8n

# 3. 权限设置
RUN mkdir -p /home/node/.n8n && \
    chown -R node:node /home/node/.n8n

# 4. 复制脚本
COPY start.sh /start.sh
RUN sed -i 's/\r$//' /start.sh && chmod +x /start.sh

USER node

ENV DB_TYPE=sqlite
ENV N8N_PORT=7860
ENV N8N_USER_FOLDER=/home/node/.n8n

CMD ["/start.sh"]
