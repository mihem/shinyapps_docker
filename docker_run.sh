#!/bin/bash
docker run \
	--detach \
	--restart=always \
	-p 3838:3838 \
	mihem/shinyapps_3838:v3.0
