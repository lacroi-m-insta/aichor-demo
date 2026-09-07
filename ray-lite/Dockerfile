# Lightweight Ray image for minimal KubeRay runs.
#
# Ray is already installed in the base image, so there is no pip install step:
# the build is a single COPY layer and finishes in seconds.
FROM rayproject/ray:2.36.1-py39-cpu

WORKDIR /app

ENV TZ=Europe/Paris
ENV LANG=C.UTF-8 PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
ENV LOG_DURATION_SECONDS=5

COPY main.py .
