#!/usr/bin/env bash

rake RAILS_ENV=test db:reset
rake RAILS_ENV=test test
exit