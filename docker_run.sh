#!/bin/bash
# DEPRECATED: use docker compose instead.
#
#   docker compose up -d          # start / restart
#   docker compose down           # stop and remove container
#   docker compose pull && docker compose up -d  # pull new image and restart
#
# This file is kept for reference only.

docker run \
	--detach \
	--name shinyapps_v14 \
	--restart=unless-stopped \
	-p 3838:3838 \
	mihem/shinyapps_3838:v14.0
