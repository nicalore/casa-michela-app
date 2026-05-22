FROM python:3.13-slim

WORKDIR /app

COPY pyproject.toml ./

RUN pip install uv && \
    uv pip install --system .

COPY . .

EXPOSE 8000

CMD ["uv", "run", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
