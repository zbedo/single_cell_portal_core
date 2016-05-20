#!/usr/bin/env bash

gcloud compute ssh single-cell-google --project broad-kdux-dev --zone us-central1-a --ssh-flag="-L" --ssh-flag="80:localhost:80" --ssh-flag="-L" --ssh-flag="443:localhost:443"