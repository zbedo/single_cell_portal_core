#!/bin/bash

source config/secrets/.source_env.bash

thin start --ssl --ssl-key-file config/local_ssl/localhost.key --ssl-cert-file config/local_ssl/localhost.crt  --ssl-disable-verify
