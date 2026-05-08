ARG VERSION=1.0.0

FROM python:3.12-slim

ARG VERSION
LABEL version="${VERSION}" \
      maintainer="ayalmauda-ai" \
      description="Seyoawe sawectl CLI"

WORKDIR /app

COPY cli/sawectl/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY cli/sawectl/ ./

ENTRYPOINT ["python3", "sawectl.py"]
