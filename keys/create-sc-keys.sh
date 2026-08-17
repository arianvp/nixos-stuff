#!/bin/sh

# for automation like agents
sc_auth create-ctk-identity -l $USER@$(hostname -s) -k p-256-ne

# for humans
sc_auth create-ctk-identity -l $USER@$(hostname -s)-bio -k p-256-ne -t bio
