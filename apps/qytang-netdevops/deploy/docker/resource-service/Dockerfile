FROM harbor.qytk8s.com/library/python:3.12-slim

WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY . /app

ENV PYTHONPATH=/app

EXPOSE 8002

CMD ["uvicorn", "backend.resource_service.main:app", "--host", "0.0.0.0", "--port", "8002"]
