# ====================================================================================
# Stage 1: Build the .NET application
# ====================================================================================
FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:9.0-bookworm-slim AS build-dotnet

WORKDIR /root/build

ARG TARGETARCH

# Install git and clone the Lagrange.Core repository
RUN apt-get update && apt-get install -y git && \
    git clone --depth=1 https://github.com/LagrangeDev/Lagrange.Core.git c && \
    rm -rf /var/lib/apt/lists/*

# Publish the .NET application
RUN dotnet publish -p:DebugType="none" -a $TARGETARCH -f "net9.0" \
    -o /root/out c/Lagrange.OneBot


# ====================================================================================
# Stage 2: Final image with Python virtual environment
# ====================================================================================
FROM python:3.11-slim

# Install system dependencies including .NET runtime
RUN apt-get update && \
    apt-get install -y wget apt-transport-https gnupg ca-certificates git && \
    wget https://packages.microsoft.com/config/debian/11/packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y dotnet-runtime-9.0 supervisor gosu gcc build-essential python3-dev libffi-dev libssl-dev && \
    rm -rf /var/lib/apt/lists/*

# Set up the application directory
WORKDIR /app

# Copy the built .NET application and entrypoint script from the build stage
COPY --from=build-dotnet /root/out /app/bin
COPY --from=build-dotnet /root/build/c/Lagrange.OneBot/Resources/docker-entrypoint.sh /app/bin/docker-entrypoint.sh
RUN chmod +x /app/bin/docker-entrypoint.sh

# Clone the Python application repository
RUN git clone --depth=1 https://github.com/AstrBotDevs/AstrBot.git python && \
    chown -R 1000:1000 python

# --- Python Virtual Environment Setup ---
# 1. Create a virtual environment
RUN python -m venv /app/venv

# 2. Install Python dependencies into the virtual environment
#    We use the pip from the venv to ensure packages are installed in the correct location.
RUN /app/venv/bin/pip install --upgrade pip && \
    /app/venv/bin/pip install -r python/requirements.txt --no-cache-dir && \
    /app/venv/bin/pip install socksio wechatpy cryptography --no-cache-dir

# Expose ports
EXPOSE 6185
EXPOSE 6186

# --- Supervisor Configuration ---
# Configure supervisor to run both .NET and Python applications
# The Python command now points to the python executable inside the virtual environment.
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
    echo "command=/app/venv/bin/python /app/python/main.py" >> /etc/supervisord.conf && \
    echo "directory=/app/python" >> /etc/supervisord.conf && \
    echo "autostart=true" >> /etc/supervisord.conf && \
    echo "autorestart=true" >> /etc/supervisord.conf && \
    echo "stdout_logfile=/dev/stdout" >> /etc/supervisord.conf && \
    echo "stdout_logfile_maxbytes=0" >> /etc/supervisord.conf && \
    echo "stderr_logfile=/dev/stderr" >> /etc/supervisord.conf && \
    echo "stderr_logfile_maxbytes=0" >> /etc/supervisord.conf

# Set the command to run supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]