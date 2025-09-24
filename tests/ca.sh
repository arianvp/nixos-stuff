#!/bin/sh
openssl req -subj "/C=/ST=/L=/O=/CN=example.com" -new -nodes -x509 -days 9999 -keyout ca.key -out ca.crt
