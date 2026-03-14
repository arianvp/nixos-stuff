#!/usr/bin/env bash

sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrlock  /var/lib/systemd/pcrlock.json 
