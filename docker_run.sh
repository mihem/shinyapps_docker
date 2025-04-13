#!/bin/bash
docker run \
	--detach \
	--restart=unless-stopped \
	-p 3838:3838 \
	mihem/shinyapps_3838:v5.0
