# 使用Ubuntu 22.04 LTS作为基础镜像
FROM ubuntu:latest

# 设置维护者信息
LABEL maintainer="your-email@example.com"
LABEL description="AstrBot与Lagrange.OneBot基于Ubuntu 22.04的Docker镜像，使用Supervisor管理进程"

# 设置环境变量，避免在安装过程中出现交互式提示
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# 设置工作目录
WORKDIR /app

# 更新包列表并安装基础依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    ca-certificates \
    curl \
    wget \
    git \
    && add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get update

# 安装Python 3.11和其他系统依赖
RUN apt-get install -y --no-install-recommends \
    python3.11 \
    python3.11-dev \
    python3.11-venv \
    python3.11-distutils \
    nodejs \
    npm \
    gcc \
    build-essential \
    libffi-dev \
    libssl-dev \
    bash \
    supervisor \
    tar \
    gzip \
    libicu-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 设置Python 3.11为默认Python版本
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1 \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1

# 安装pip for Python 3.11（使用ensurepip模块）
RUN python3.11 -m ensurepip --upgrade || \
    (curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11 - --force-reinstall)

# 升级pip
RUN python3.11 -m pip install --upgrade pip

# 从GitHub克隆AstrBot项目代码直接到/app目录
RUN git clone https://github.com/AstrBotDevs/AstrBot.git . \
    || (git init && \
        git remote add origin https://github.com/AstrBotDevs/AstrBot.git && \
        git fetch origin && \
        git checkout -b main origin/main)

# 安装Python包管理工具uv
RUN python -m pip install --upgrade pip \
    && python -m pip install uv

# 安装AstrBot的Python依赖
RUN uv pip install -r requirements.txt --no-cache-dir --system

# 安装AstrBot额外的Python包
RUN uv pip install socksio uv pyffmpeg pilk --no-cache-dir --system

# 释出ffmpeg并配置
RUN python -c "from pyffmpeg import FFmpeg; ff = FFmpeg();"

# 添加ffmpeg到PATH环境变量
ENV PATH="${PATH}:/root/.pyffmpeg/bin"
RUN echo 'export PATH=$PATH:/root/.pyffmpeg/bin' >> ~/.bashrc

# 下载并解压Lagrange.OneBot
RUN mkdir -p /tmp/lagrange && \
    cd /tmp/lagrange && \
    wget https://github.com/LagrangeDev/Lagrange.Core/releases/download/nightly/Lagrange.OneBot_linux-x64_net9.0_SelfContained.tar.gz && \
    tar -xzf Lagrange.OneBot_linux-x64_net9.0_SelfContained.tar.gz && \
    # 将实际的可执行文件及其依赖复制到/app目录
    cp -r /tmp/lagrange/Lagrange.OneBot/bin/Release/net9.0/linux-x64/publish/* /app/ && \
    # 设置执行权限
    chmod +x /app/Lagrange.OneBot && \
    # 清理临时文件
    rm -rf /tmp/lagrange

# 创建Lagrange配置目录
RUN mkdir -p /app/lagrange_config

# 创建supervisor日志目录
RUN mkdir -p /var/log/supervisor

# 复制supervisor配置文件（如果存在本地配置文件）
# 注意：这个文件需要在构建Docker镜像的目录中存在
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# 暴露端口
# AstrBot端口
EXPOSE 6185
EXPOSE 6186

# 设置默认shell
SHELL ["/bin/bash", "-c"]

# 使用supervisor启动和管理所有进程
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]