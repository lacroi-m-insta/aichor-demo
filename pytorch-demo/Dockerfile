FROM pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime

RUN mkdir -p /opt/app/src
WORKDIR /opt/app

COPY wheels/ wheels/
COPY requirements.txt .
RUN pip install --no-index --find-links=wheels/ -r requirements.txt

COPY src/main.py src/
COPY data/ data/
RUN cat data/cifar-100-python.tar.gz.part* > data/cifar-100-python.tar.gz && \
    tar -xzf data/cifar-100-python.tar.gz -C data/ && \
    rm data/cifar-100-python.tar.gz.part* data/cifar-100-python.tar.gz