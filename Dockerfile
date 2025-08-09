###############################
# 第一阶段：构建 .NET 程序（Lagrange.Core）
###############################
FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:9.0-bookworm-slim AS build-dotnet

WORKDIR /root/build

# 如果需要针对目标架构编译，可使用 ARG TARGETARCH
ARG TARGETARCH

# 安装 git 并拉取 Lagrange.Core 最新源码
RUN apt-get update && apt-get install -y git && \
    git clone --depth=1 https://github.com/LagrangeDev/Lagrange.Core.git c && \
    rm -rf /var/lib/apt/lists/*

# 发布 Lagrange.OneBot 项目到 /root/out 目录
RUN dotnet publish -p:DebugType="none" -a $TARGETARCH -f "net9.0" \
    -o /root/out c/Lagrange.OneBot


###############################
# 第二阶段：构建最终镜像（合并 .NET 与 Python 环境）
###############################
FROM python:3.11-slim

# 安装所需工具、Microsoft 的 apt 源、.NET 运行时、supervisor 以及构建 Python 所需依赖
RUN apt-get update && \
    apt-get install -y wget apt-transport-https gnupg ca-certificates git && \
    wget https://packages.microsoft.com/config/debian/11/packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y dotnet-runtime-9.0 supervisor gosu gcc build-essential python3-dev libffi-dev libssl-dev && \
    rm -rf /var/lib/apt/lists/*

###############################
# 复制 .NET 应用文件
###############################
WORKDIR /app
COPY --from=build-dotnet /root/out /app/bin
COPY --from=build-dotnet /root/build/c/Lagrange.OneBot/Resources/docker-entrypoint.sh /app/bin/docker-entrypoint.sh
RUN chmod +x /app/bin/docker-entrypoint.sh

###############################
# 安装 Python 应用（AstrBot）
###############################
WORKDIR /app

# 拉取 AstrBot 最新源码
RUN git clone --depth=1 https://github.com/AstrBotDevs/AstrBot.git python && \
    chown -R 1000:1000 python

# 安装 Python 依赖
RUN python -m pip install --upgrade pip && \
    pip install -r python/requirements.txt --no-cache-dir && \
    pip install socksio wechatpy cryptography --no-cache-dir

###############################
# 暴露端口
###############################
EXPOSE 6185
EXPOSE 6186

###############################
# 添加 supervisord 配置文件
###############################
RUN echo "[supervisord]" > /etc/supervisord.conf && \
    echo "nodaemon=true" >> /etc/supervisord.conf && \
    echo "logfile=/dev/stdout" >> /etc/supervisord.conf && \
    echo "logfile_maxbytes=0" >> /etc/supervisord.conf && \
    echo "loglevel=info" >> /etc/supervisord.conf && \
    echo "" >> /etc/supervisord.conf && \
    echo "[program:dotnet]" >> /etc/supervisord.conf && \
    echo "command=/app/bin/docker-entrypoint.sh" >> /etc/supervisord.conf && \
    echo "autostart=true" >> /etc/supervisord.conf && \
    echo "autorestart=true" >> /etc/supervisord.conf && \
    echo "stdout_logfile=/dev/stdout" >> /etc/supervisord.conf && \
    echo "stdout_logfile_maxbytes=0" >> /etc/supervisord.conf && \
    echo "stderr_logfile=/dev/stderr" >> /etc/supervisord.conf && \
    echo "stderr_logfile_maxbytes=0" >> /etc/supervisord.conf && \
    echo "" >> /etc/supervisord.conf && \
    echo "[program:python]" >> /etc/supervisord.conf && \
    echo "command=python /app/python/main.py" >> /etc/supervisord.conf && \
    echo "directory=/app/python" >> /etc/supervisord.conf && \
    echo "autostart=true" >> /etc/supervisord.conf && \
    echo "autorestart=true" >> /etc/supervisord.conf && \
    echo "stdout_logfile=/dev/stdout" >> /etc/supervisord.conf && \
    echo "stdout_logfile_maxbytes=0" >> /etc/supervisord.conf && \
    echo "stderr_logfile=/dev/stderr" >> /etc/supervisord.conf && \
    echo "stderr_logfile_maxbytes=0" >> /etc/supervisord.conf

###############################
# 启动 supervisord 作为容器入口
###############################
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
