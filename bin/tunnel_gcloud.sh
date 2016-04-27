#!/usr/bin/env bash

gcloud compute ssh kdux-google --project broad-kdux-dev --zone us-central1-a --ssh-flag="-L" --ssh-flag="80:localhost:80" --ssh-flag="-L" --ssh-flag="443:localhost:443" --ssh-flag="-L" --ssh-flag="27017:localhost:27017"