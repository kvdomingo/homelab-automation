FROM python:3.11 as build

ENV DEBIAN_FRONTEND noninteractive
ARG POETRY_VERSION=1.6.1

RUN pip install "poetry==$POETRY_VERSION" && \
    poetry config virtualenvs.create false && \
    poetry config installer.max-workers 4

WORKDIR /tmp

RUN poetry export --without-hashes --format requirements.txt > requirements.txt

FROM python:3.11 as prod

WORKDIR /tmp

COPY --from=build /tmp/requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

WORKDIR /app

COPY . .

CMD [ "./docker-entrypoint.sh" ]
