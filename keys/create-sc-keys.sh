#!/bin/sh

# for automation like agents
sc_auth create-ctk-identity -l $(hostname -s)-unverified -k p-256-ne

# for humans
sc_auth create-ctk-identity -l $(hostname -s) -k p-256-ne -t bio

ssh-keygen -K -N ""
