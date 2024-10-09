#!/usr/bin/env bash
set -e

source local.env

echo "Cleanup existing services"
for c in cnb-app-container $SERVICE_NAME-service;do
 echo "Stopping $c"
 if docker container stop $c;then
   echo "Removing $c"
  docker container rm -f $c
  fi
done

source ./setup-prerequisite.sh
./run-tests.sh
