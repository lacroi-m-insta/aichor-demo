FROM pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime

RUN mkdir -p /opt/app/src
WORKDIR /opt/app

COPY wheels/ wheels/
COPY requirements.txt .
RUN pip install --no-index --find-links=wheels/ -r requirements.txt

COPY src/main.py src/

RUN python3 -c "from torchvision import datasets; datasets.CIFAR100('./data', download=True)"