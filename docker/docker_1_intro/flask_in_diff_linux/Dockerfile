FROM python:3.7-alpine
ENV FLASK_APP=app.py
ENV FLASK_RUN_HOST=0.0.0.0
WORKDIR /
RUN pip3 install -i https://mirrors.aliyun.com/pypi/simple/ flask
COPY app.py app.py
CMD ["flask", "run", "--port", "8080"]