# Lightweight image shared by the jax, jobset, pytorch and xgboost operators.
#
# These operators only need the container to start, print and exit 0 — none of
# the frameworks are imported — so there is no pip install step and the build
# is a single COPY layer on top of a ~50MB base.
FROM python:3.11-slim

WORKDIR /app

ENV TZ=Europe/Paris
ENV LANG=C.UTF-8 PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
ENV LOG_DURATION_SECONDS=5

COPY main.py .
