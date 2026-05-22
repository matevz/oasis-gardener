ARG PYTHON_VERSION=3.14
ARG OASIS_CLI_VERSION=0.19.0

FROM python:${PYTHON_VERSION}-slim-trixie AS base

FROM base AS builder

ARG OASIS_CLI_VERSION
ARG TARGETARCH

COPY --from=ghcr.io/astral-sh/uv:0.11.15 /uv /usr/local/bin/uv

ENV UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    UV_PROJECT_ENVIRONMENT=/app/.venv \
    UV_PYTHON_DOWNLOADS=never

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && case "${TARGETARCH:-amd64}" in \
         amd64) OASIS_ARCH=amd64 ;; \
         arm64) OASIS_ARCH=arm64 ;; \
         *) echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
       esac \
    && curl -fsSL "https://github.com/oasisprotocol/cli/releases/download/v${OASIS_CLI_VERSION}/oasis_cli_${OASIS_CLI_VERSION}_linux_${OASIS_ARCH}.tar.gz" \
         | tar -xz -C /tmp \
    && install -D -m 0755 "/tmp/oasis_cli_${OASIS_CLI_VERSION}_linux_${OASIS_ARCH}/oasis" /out/oasis

COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --no-dev --frozen --no-install-project

FROM base AS runtime

RUN useradd --system --no-create-home appuser

ENV PYTHONUNBUFFERED=1 \
    PATH="/app/.venv/bin:${PATH}" \
    HOME=/tmp

WORKDIR /app

COPY --from=builder /out/oasis /usr/local/bin/oasis
COPY --from=builder /app/.venv /app/.venv
COPY main.py ./

USER appuser

CMD ["python", "main.py"]
