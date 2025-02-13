FROM python:3.8-slim

RUN pip install tensorboardX boto3

WORKDIR /app
COPY ./src ./src
COPY main.py .


RUN --mount=type=cache,target=/root/.cache/uv \
    echo "CACHE TEST $(date)" > /root/.cache/uv/test.txt && \
    cat /root/.cache/uv/test.txt
 
RUN --mount=type=cache,target=/root/.cache/uv \
    cat /root/.cache/uv/test.txt
