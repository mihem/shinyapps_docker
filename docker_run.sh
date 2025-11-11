#!/bin/bash
docker run \
	--detach \
	--name shinyapps \
	--restart=unless-stopped \
	-p 3838:3838 \
	mihem/shinyapps_3838:v6.0
