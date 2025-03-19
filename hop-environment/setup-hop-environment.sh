#!/bin/bash
/opt/hop/hop-conf.sh \
     --environment-create \
     --environment="Development" \
     --environment-project="Samples"  \
     --environment-purpose=Development \
     --environment-config-files=/home/ubuntu/dev.json
