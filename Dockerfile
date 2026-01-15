# 基於您提供的基礎鏡像
ARG BASE_IMAGE=nvidia/cuda:12.6.3-cudnn-runtime-ubuntu24.04
FROM ${BASE_IMAGE} AS base

# --- 基礎環境設定 (維持不變) ---
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:${PATH}"

# 安裝必要工具 (git, wget, python 等)
RUN apt-get update && apt-get install -y python3.12 python3.12-venv git wget libgl1 libglib2.0-0 ffmpeg && \
    ln -sf /usr/bin/python3.12 /usr/bin/python && \
    wget -qO- https://astral.sh/uv/install.sh | sh && \
    ln -s /root/.local/bin/uv /usr/local/bin/uv && \
    uv venv /opt/venv

# 安裝 ComfyUI 核心
RUN uv pip install comfy-cli pip setuptools wheel && \
    /usr/bin/yes | comfy --workspace /comfyui install --nvidia

# --- 插件處理：僅安裝「核心必需」或「體積小」的插件 ---
WORKDIR /comfyui/custom_nodes
RUN git clone https://github.com/zhangp365/ComfyUI-utils-nodes.git && \
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git && \
    uv pip install -r ComfyUI-Impact-Pack/requirements.txt && \
    git clone https://github.com/rgthree/rgthree-comfy.git && \
    uv pip install -r rgthree-comfy/requirements.txt

# --- 網路磁碟關鍵設定 ---
WORKDIR /comfyui

# 複製設定檔，讓 ComfyUI 知道去 /runpod-volume 找模型
ADD src/extra_model_paths.yaml ./

# 安裝 RunPod Handler 依賴
RUN uv pip install runpod requests websocket-client
# 確保使用絕對路徑進行複製
ADD src/start.sh /start.sh
ADD handler.py /handler.py

# 執行賦予權限時，同樣指向根目錄下的絕對路徑
RUN chmod +x /start.sh

# --- 修改啟動指令 ---
# 功能：自動連結網路磁碟中的自定義節點，然後執行啟動腳本
CMD ["sh", "-c", "ln -sf /runpod-volume/comfyui/custom_nodes/* /comfyui/custom_nodes/ && /start.sh"]

# 注意：移除原本的 Stage 2 (downloader) 和 Stage 3 (final)
# 這樣鏡像會變得非常輕量，只包含程式碼，不包含模型檔案。