import os
from datetime import timedelta
from http import HTTPStatus

import requests
from dotenv import load_dotenv
from flask import Flask, Response, redirect
from flask_caching import Cache

load_dotenv()

NASA_APOD_API_KEY = os.environ.get("NASA_APOD_API_KEY")

if NASA_APOD_API_KEY is None:
    raise EnvironmentError("env NASA_APOD_API_KEY not found")

cache = Cache(config={"CACHE_TYPE": "SimpleCache"})

app = Flask(__name__)
cache.init_app(app)


@app.route("/health")
def health():
    return Response("ok", content_type="text/plain")


@app.route("/")
@cache.cached(timeout=int(timedelta(hours=6).total_seconds()))
def index():
    res = requests.get(
        "https://api.nasa.gov/planetary/apod", params={"api_key": NASA_APOD_API_KEY}
    )
    if not res.ok:
        return Response(res.json(), status=HTTPStatus.FAILED_DEPENDENCY)

    data = res.json()
    url = data["hdurl"]
    return redirect(url)


if __name__ == "__main__":
    app.run()
