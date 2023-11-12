#!/bin/sh

exec gunicorn --config gunicorn.conf.py --bind 0.0.0.0:5000
