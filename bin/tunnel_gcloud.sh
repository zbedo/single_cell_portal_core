#!/usr/bin/env bash

sudo gcloud compute ssh singlecell-production --project broad-singlecellportal --zone us-central1-a --ssh-flag="-L" --ssh-flag="443:localhost:443"