FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /workspace

# Basic system dependencies
RUN apt-get update && apt-get install -y \
    git \
    openssh-client \
    python3.12 \
    python3.12-venv \
    python3-pip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Clone and pin the upstream repositories used by Prototype V1
RUN mkdir -p /workspace/repos /workspace/tools && \
    git clone https://github.com/Xiangyu-Hu/SPHinXsys.git /workspace/repos/SPHinXsys && \
    git -C /workspace/repos/SPHinXsys checkout \
        5dec24e4731e5ad8e45cc7f7191cda19871f410f && \
    git clone https://github.com/Xiangyu-Hu/SPHinXsim.git /workspace/repos/SPHinXsim && \
    git -C /workspace/repos/SPHinXsim checkout \
        90375915a25d6f16ea6c496264171f15df14b007


# Trust the project workspace and pinned read-only upstream repositories
RUN git config --system --add safe.directory /workspace && \
    git config --system --add safe.directory /workspace/repos/SPHinXsys && \
    git config --system --add safe.directory /workspace/repos/SPHinXsim


# Clone and pin treesitter-chunker
RUN git clone \
        https://github.com/Consiliency/treesitter-chunker.git \
        /workspace/tools/treesitter-chunker && \
    git -C /workspace/tools/treesitter-chunker checkout \
        fb70922076c773d1865176329a03f67ff893fd90

# Create the isolated Python environment
RUN python3.12 -m venv /opt/sphinxsistant-venv && \
    /opt/sphinxsistant-venv/bin/python -m pip install --upgrade pip && \
    /opt/sphinxsistant-venv/bin/python -m pip install \
        -e /workspace/tools/treesitter-chunker && \
    /opt/sphinxsistant-venv/bin/python -m pip install \
        openai==3.15.0 \
        gradio==6.27.0 \
        markdown-it-py==4.2.0

ENV PATH="/opt/sphinxsistant-venv/bin:${PATH}"

# Copy the assistant project itself
COPY . /workspace

# Verify the essential Python dependencies during image build
RUN python -c \
    "import chunker, gradio, openai; print('SPHinXsistant environment ready')"

CMD ["python", "apps/gradio_app_v1.py"]
