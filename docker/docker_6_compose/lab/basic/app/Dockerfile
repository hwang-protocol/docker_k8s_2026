FROM python:3.12-alpine

WORKDIR /app

RUN addgroup -S appgroup && adduser -S -G appgroup -u 10001 appuser

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY app.py /app/app.py

CMD ["python", "/app/app.py"]
