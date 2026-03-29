#!/bin/bash
docker run \
	--detach \
	--name shinyapps_v14 \
	--restart=unless-stopped \
	-p 3838:3838 \
	mihem/shinyapps_3838:v14.0
