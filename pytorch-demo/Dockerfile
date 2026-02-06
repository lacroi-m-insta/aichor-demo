FROM pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime

RUN mkdir -p /opt/app/src
WORKDIR /opt/app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY src/main.py src/