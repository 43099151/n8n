# 使用基础镜像
FROM node:22-bookworm-slim

USER root

# 1. 安装系统工具
# 新增: git (用于npm安装依赖), chromium (用于puppeteer运行)
RUN apt-get update && \
    apt-get install -y rclone sqlite3 ca-certificates git chromium && \
    rm -rf /var/lib/apt/lists/*

# 2. 配置 Puppeteer 环境变量
# 跳过 Puppeteer 自带的 Chromium 下载，直接使用系统安装的 Chromium，减小体积并确保兼容性
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

# 3. 安装 n8n
RUN npm install -g n8n --omit=dev && \
    npm cache clean --force

# 4. 权限设置
# 提前创建 .n8n 目录并赋予 node 用户权限
RUN mkdir -p /home/node/.n8n && \
    chown -R node:node /home/node/.n8n

# 5. 复制启动脚本
COPY start.sh /start.sh
RUN sed -i 's/\r$//' /start.sh && chmod +x /start.sh

# ==========================================
# 6. 集成自定义插件 (切换到 node 用户操作)
# ==========================================
USER node

# 进入 n8n 配置目录并安装插件
# 这样 n8n 启动时会自动识别这些位于 ~/.n8n/node_modules 下的插件
RUN cd /home/node/.n8n && \
    npm install n8n-nodes-puppeteer n8n-nodes-cheerio

# 7. 环境变量设置
ENV DB_TYPE=sqlite
ENV N8N_PORT=7860
ENV N8N_USER_FOLDER=/home/node/

CMD ["/start.sh"]
