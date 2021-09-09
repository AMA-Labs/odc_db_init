SHELL:=/bin/bash
compose_file = build/docker/docker-compose.yml
# --compatibility since we are using `docker stack deploy` for resource limits.
docker_compose = docker-compose --compatibility --project-directory build/docker -f ${compose_file}

# Make the environment variables of the environment available here.
export $(cat build/docker/.env)

ODC_VER?=1.8.3

## Indexer ##
INDEXER_BASE_IMG_REPO?=jcrattzama/odc_manual_indexer
INDEXER_BASE_IMG_VER?=
INDEXER_BASE_IMG?=${INDEXER_BASE_IMG_REPO}:odc${ODC_VER}${INDEXER_BASE_IMG_VER}
export INDEXER_BASE_IMG
## End Indexer ##

## Database ##
export ODC_DB_HOSTNAME=odc_db
export ODC_DB_DATABASE=datacube
export ODC_DB_USER=dc_user
export ODC_DB_PASSWORD=localuser1234
export ODC_DB_PORT=5432
## End Database ##

## Output ##
OUT_IMG_REPO?=jcrattzama/manual_indexer_init
export OUT_IMG_REPO
## End Output ##

init:
	docker swarm init

up:
	$(docker_compose) up -d --build

down:
	$(docker_compose) down --remove-orphans

restart: down up

ssh:
	$(docker_compose) exec indexer bash

ps:
	$(docker_compose) ps

db-init:
# 	Create directory to hold data.
	$(docker_compose) exec -T indexer conda run -n odc bash -c \
	  "mkdir -p /Datacube"
#	Initialize the ODC system.
	$(docker_compose) exec -T indexer conda run -n odc bash -c \
	  "datacube system init"

# data-copy:	
# 	docker cp data docker_indexer_1:/Datacube/data
# 	$(docker_compose) exec -T indexer conda run -n odc bash -c \
# 	  "mv /Datacube/data /Datacube/tmp"

## Indexing ##

### Indexing Env Vars ###
PROD_DEF_DIR = prod_defs
IDX_SCR_DIR = index_scripts
# Landsat
LANDSAT_PROD_DEFS_DIR = ${PROD_DEF_DIR}/Landsat
LANDSAT_IDX_SCR_DIR = ${IDX_SCR_DIR}/Landsat
LANDSAT_C1_PROD_DEFS_DIR = ${LANDSAT_PROD_DEFS_DIR}/collection_1
LANDSAT_C1_IDX_SCR_DIR = ${LANDSAT_IDX_SCR_DIR}/collection_1
LANDSAT_C2_PROD_DEFS_DIR = ${LANDSAT_PROD_DEFS_DIR}/collection_2
LANDSAT_C2_IDX_SCR_DIR = ${LANDSAT_IDX_SCR_DIR}/collection_2
## Landsat 5
LS5_C2_PROD_DEF_PATH = ${LANDSAT_C2_PROD_DEFS_DIR}/ls5_l2_c2.yaml
LS5_C2_IDX_SCR_BASE_CMD = \
	python3 ${LANDSAT_C2_IDX_SCR_DIR}/ls5_l2_c2.py \
	   usgs-landsat -p collection02/level-2/standard/tm --suffix=MTL.xml
## Landsat 7
### usgs-landsat S3 bucket
LS7_C2_PROD_DEF_PATH = ${LANDSAT_C2_PROD_DEFS_DIR}/ls7_l2_c2.yaml
LS7_C2_IDX_SCR_BASE_CMD = \
	python3 ${LANDSAT_C2_IDX_SCR_DIR}/ls7_l2_c2.py \
	   usgs-landsat -p collection02/level-2/standard/etm --suffix=MTL.xml
### Landsat 7 Google Earth Engine
LS7_C1_T1_GEE_PROD_DEF_PATH = ${LANDSAT_C1_PROD_DEFS_DIR}/ls7_l2_c1_t1_google.yaml
LS7_C1_T1_GEE_PROD_NAME = ls7_l2_c1_t1_google
LS7_C1_T2_GEE_PROD_DEF_PATH = ${LANDSAT_C1_PROD_DEFS_DIR}/ls7_l2_c1_t2_google.yaml
LS7_C1_T2_GEE_PROD_NAME = ls7_l2_c1_t2_google
## Landsat 8
LS8_C2_PROD_DEF_PATH = ${LANDSAT_C2_PROD_DEFS_DIR}/ls8_l2_c2.yaml
LS8_C2_IDX_SCR_BASE_CMD = \
	python3 ${LANDSAT_C2_IDX_SCR_DIR}/ls8_l2_c2.py \
	   usgs-landsat -p collection02/level-2/standard/oli-tirs --suffix=MTL.xml
### Landsat 8 Google Earth Engine
LS8_C1_T1_GEE_PROD_DEF_PATH = ${LANDSAT_C1_PROD_DEFS_DIR}/ls8_l2_c1_t1_google.yaml
LS8_C1_T1_GEE_PROD_NAME = ls8_l2_c1_t1_google
LS8_C1_T2_GEE_PROD_DEF_PATH = ${LANDSAT_C1_PROD_DEFS_DIR}/ls8_l2_c1_t2_google.yaml
LS8_C1_T2_GEE_PROD_NAME = ls8_l2_c1_t2_google
# Sentinel-1
S1_PROD_DEFS_DIR = ${PROD_DEF_DIR}/Sentinel-1
## Sentinel-1 GRD Google Earth Engine
S1_GRD_GEE_PROD_DEF_PATH = ${S1_PROD_DEFS_DIR}/s1_grd_google.yaml
# Mavic Mini
WEBODM_MAVICMINI_PROD_DEFS_DIR = ${PROD_DEF_DIR}/WebODM_MavicMini
## WebODM_MavicMini_RGBA
WEBODM_MAVICMINI_RGBA_PROD_DEF_PATH = ${WEBODM_MAVICMINI_PROD_DEFS_DIR}/WebODM_MavicMini_RGBA.yaml
### End Indexing Env Vars ###

### Indexing Areas ###
COLORADO_EXTENTS_STD_IDX_SCR_FMT = --lat1=37 --lat2=41 --lon1=-109.1 --lon2=-102
TEXAS_EXTENTS_STD_IDX_SCR_FMT = --lat1=25.6 --lat2=36.6 --lon1=-106.75 --lon2=-93.4
VIRGINIA_EXTENTS_STD_IDX_SCR_FMT = --lat1=36.5 --lat2=39.5 --lon1=-83.75 --lon2=-75.0
VIRGINIA_EXTENTS_GEE_FMT = --latitude '(36.5, 39.5)' --longitude '(-83.75, -75.0)'
US_EXTENTS_STD_IDX_SCR_FMT = --lat1=24 --lat2=50 --lon1=-127 --lon2=-66
### End Indexing Areas ###

### Indexing Commands (1 area each - EXTENTS is lat1,lat2,lon1,lon2) ###
# Index all Landsat C2 L2 data (5/7/8) on the *usgs-landsat* S3 bucket
# for the selected area ("extents").
# INDEX_LANDSAT_C2_L2_ALL = \
#  datacube product add ${LS5_C2_PROD_DEF_PATH}; \
#  nohup ${LS5_C2_IDX_SCR_BASE_CMD} $${EXTENTS} &> ls5_l2_c2_ind.txt & \
#  datacube product add ${LS7_C2_PROD_DEF_PATH}; \
#  nohup ${LS7_C2_IDX_SCR_BASE_CMD} $${EXTENTS} &> ls7_l2_c2_ind.txt & \
#  datacube product add ${LS8_C2_PROD_DEF_PATH}; \
#  nohup ${LS8_C2_IDX_SCR_BASE_CMD} $${EXTENTS} &> ls8_l2_c2_ind.txt &
### End Indexing Commands ###

### Indexing Targets ###
db-index-drone-paper:
#### Index Local Data ####
# 	Add products from the indexer.
	$(docker_compose) exec -T indexer conda run -n odc bash -c \
	  "datacube product add ${WEBODM_MAVICMINI_RGBA_PROD_DEF_PATH}"
# 	Copy the data into its final directory for indexing.
	$(docker_compose) exec -T indexer conda run -n odc bash -c \
	  "mkdir -p /Datacube/data/prod_defs; \
	   cp /Datacube/tmp/prod_defs/ls8_l2_c2_colorado_springs.yaml \
	      /Datacube/data/prod_defs; \
	   mkdir -p /Datacube/data/tiles; \
	   cp -r /Datacube/tmp/tiles/ls8_l2_c2_colorado_springs \
	      /Datacube/data/tiles/ls8_l2_c2_colorado_springs; \
	   cp -r /Datacube/tmp/tiles/WebODM_MavicMini_RGBA \
	      /Datacube/data/tiles/WebODM_MavicMini_RGBA; \
	   rm -rf /Datacube/tmp \
	  "
# 	Add products from this repository.
	$(docker_compose) exec -T indexer conda run -n odc bash -c \
	  "datacube product add /Datacube/data/prod_defs/**"
# 	Index the local data.
## 	Landsat 8 Colorado Springs
## 	MavicMini Colorado Springs
	$(docker_compose) exec -T indexer conda run -n odc bash -c \
	  "datacube dataset add /Datacube/data/tiles/ls8_l2_c2_colorado_springs/LC08_L2SP_033033_20210425_20210501_02_T1/metadata.json; \
	   python3 ${IDX_SCR_DIR}/drone_indexer.py /Datacube/data/tiles/WebODM_MavicMini_RGBA WebODM_MavicMini_RGBA
	  "

db-index-colorado-texas:
#### Index Remote Data ####
	$(docker_compose) exec -T indexer conda run -n odc bash -c \
	  "datacube product add ${LS5_C2_PROD_DEF_PATH}; \
	   nohup sh -c '${LS5_C2_IDX_SCR_BASE_CMD} ${COLORADO_EXTENTS_STD_IDX_SCR_FMT}; \
	    	  		${LS5_C2_IDX_SCR_BASE_CMD} ${TEXAS_EXTENTS_STD_IDX_SCR_FMT}' &> ls5_l2_c2_ind.txt & \
	   datacube product add ${LS7_C2_PROD_DEF_PATH}; \
	   nohup sh -c '${LS7_C2_IDX_SCR_BASE_CMD} ${COLORADO_EXTENTS_STD_IDX_SCR_FMT}; \
	    	  		${LS7_C2_IDX_SCR_BASE_CMD} ${TEXAS_EXTENTS_STD_IDX_SCR_FMT}' &> ls7_l2_c2_ind.txt & \
	   datacube product add ${LS8_C2_PROD_DEF_PATH}; \
	   nohup sh -c '${LS8_C2_IDX_SCR_BASE_CMD} ${COLORADO_EXTENTS_STD_IDX_SCR_FMT}; \
	    	  		${LS8_C2_IDX_SCR_BASE_CMD} ${TEXAS_EXTENTS_STD_IDX_SCR_FMT}' &> ls8_l2_c2_ind.txt & \
	   wait \
	  "

db-index-va:
#### Index Remote Data ####
	$(docker_compose) exec -T indexer conda run -n odc bash -c \
	  "datacube product add ${LS5_C2_PROD_DEF_PATH}; \
	   nohup ${LS5_C2_IDX_SCR_BASE_CMD} ${VIRGINIA_EXTENTS_STD_IDX_SCR_FMT} &> ls5_l2_c2_ind.txt & \
	   datacube product add ${LS7_C2_PROD_DEF_PATH}; \
	   nohup ${LS7_C2_IDX_SCR_BASE_CMD} ${VIRGINIA_EXTENTS_STD_IDX_SCR_FMT} &> ls7_l2_c2_ind.txt & \
	   datacube product add ${LS8_C2_PROD_DEF_PATH}; \
	   nohup ${LS8_C2_IDX_SCR_BASE_CMD} ${VIRGINIA_EXTENTS_STD_IDX_SCR_FMT} &> ls8_l2_c2_ind.txt & \
	   wait \
	  "

# "Index" Landsat 5/7/8 data on Google Earth Engine with the ODC-GEE extension.
# Only product definitions are added here - "indexing" happens at load time for GEE data.
db-index-va-cube:
#### Index Remote Data ####
# Landsat 7/8 C2 L2 T1/2 (GEE)
# Landsat 5/7/8 C2 L2 T1/2 (S3 - usgs-landsat)
	$(docker_compose) exec -T indexer conda run -n odc nohup bash -c \
	  "datacube product add ${LS7_C1_T1_GEE_PROD_DEF_PATH}; \
	   datacube product add ${LS7_C1_T2_GEE_PROD_DEF_PATH}; \
	   datacube product add ${LS8_C1_T1_GEE_PROD_DEF_PATH}; \
	   datacube product add ${LS8_C1_T2_GEE_PROD_DEF_PATH}; \
	   datacube product add ${S1_GRD_GEE_PROD_DEF_PATH}; \
	   datacube product add ${LS5_C2_PROD_DEF_PATH}; \
	   ${LS5_C2_IDX_SCR_BASE_CMD} &> ls5_l2_c2_ind.txt & \
	   datacube product add ${LS7_C2_PROD_DEF_PATH}; \
	   ${LS7_C2_IDX_SCR_BASE_CMD} &> ls7_l2_c2_ind.txt & \
	   datacube product add ${LS8_C2_PROD_DEF_PATH}; \
	   ${LS8_C2_IDX_SCR_BASE_CMD} &> ls8_l2_c2_ind.txt & \
	   wait \
	  "
# ${LS5_C2_IDX_SCR_BASE_CMD} ${VIRGINIA_EXTENTS_STD_IDX_SCR_FMT} &> ls5_l2_c2_ind.txt & \
# ${LS7_C2_IDX_SCR_BASE_CMD} ${VIRGINIA_EXTENTS_STD_IDX_SCR_FMT} &> ls7_l2_c2_ind.txt & \
# ${LS8_C2_IDX_SCR_BASE_CMD} ${VIRGINIA_EXTENTS_STD_IDX_SCR_FMT} &> ls8_l2_c2_ind.txt & \

# Index Landsat Collection 1 data on GEE, to be queried with the normal `Datacube` object.
# (Recommend against - takes index database capacity and ODC-GEE is better suited to using the
#  included `Datacube` wrapper to do real-time indexing for flexible data access - no upfront index time or cost of maintaining 
#  more storage capacity for the index database)
#    (echo y | index_gee --asset LANDSAT/LE07/C01/T1_SR --product ${LS7_C1_T1_GEE_PROD_NAME} ${VIRGINIA_EXTENTS_GEE_FMT} &> ${LS7_C1_T1_GEE_PROD_NAME}.txt) & \
#    (echo y | index_gee --asset LANDSAT/LE07/C01/T2_SR --product ${LS7_C1_T2_GEE_PROD_NAME} ${VIRGINIA_EXTENTS_GEE_FMT} &> ${LS7_C1_T2_GEE_PROD_NAME}.txt) & \
#    (echo y | index_gee --asset LANDSAT/LC08/C01/T1_SR --product ${LS8_C1_T1_GEE_PROD_NAME} ${VIRGINIA_EXTENTS_GEE_FMT} &> ${LS8_C1_T1_GEE_PROD_NAME}.txt) & \
#    (echo y | index_gee --asset LANDSAT/LC08/C01/T2_SR --product ${LS8_C1_T2_GEE_PROD_NAME} ${VIRGINIA_EXTENTS_GEE_FMT} &> ${LS8_C1_T2_GEE_PROD_NAME}.txt) & \

db-index-cdc-trn:
#### Index Remote Data ####
#	$(docker_compose) exec -T indexer conda run -n odc bash -c \
	  "datacube product add ${LS8_C2_PROD_DEF_PATH}; \
	   nohup ${LS8_C2_IDX_SCR_BASE_CMD} ${US_EXTENTS_STD_IDX_SCR_FMT} &> ls8_l2_c2_ind.txt & \
	   wait \
	  "
#### Index Local Data ####
# 	Copy the local data into its final directory for indexing.
	$(docker_compose) exec -T indexer conda run -n odc bash -c \
	  "mkdir -p /Datacube/data/prod_defs; \
	   mkdir -p /Datacube/data/tiles \
	  "
	docker cp data/prod_defs/ls8_l2_c2_path_123_row_032.yaml \
			  docker_indexer_1:/Datacube/data/prod_defs/ls8_l2_c2_path_123_row_032.yaml
	docker cp data/tiles/ls8_l2_c2_path_123_row_032 \
			  docker_indexer_1:/Datacube/data/tiles/ls8_l2_c2_path_123_row_032
# 	Add products from this repository.
	$(docker_compose) exec -T indexer conda run -n odc bash -c \
	  "datacube product add /Datacube/data/prod_defs/**"
# 	Index the local data.
## 	Landsat 8
	$(docker_compose) exec -T indexer conda run -n odc bash -c \
	  "datacube dataset add /Datacube/data/tiles/ls8_l2_c2_path_123_row_032/**/metadata.json"

db-index-us-landsat: # Index all Landsat 5/7/8 C2 L2 data for the US.
	$(docker_compose) exec -T indexer conda run -n odc bash -c \
	  "datacube product add ${LS5_C2_PROD_DEF_PATH}; \
	   nohup ${LS5_C2_IDX_SCR_BASE_CMD} ${US_EXTENTS_STD_IDX_SCR_FMT} &> ls5_l2_c2_ind.txt & \
	   datacube product add ${LS7_C2_PROD_DEF_PATH}; \
	   nohup ${LS7_C2_IDX_SCR_BASE_CMD} ${US_EXTENTS_STD_IDX_SCR_FMT} &> ls7_l2_c2_ind.txt & \
	   datacube product add ${LS8_C2_PROD_DEF_PATH}; \
	   nohup ${LS8_C2_IDX_SCR_BASE_CMD} ${US_EXTENTS_STD_IDX_SCR_FMT} &> ls8_l2_c2_ind.txt & \
	   wait \
	  "

# We don't set the `EXTENTS` env var here because the area indexed
# by scripts will default to the full area for the dataset.
db-index-world-landsat-8:
	$(docker_compose) exec -T indexer conda run -n odc bash -c \
	  "datacube product add ${LS8_C2_PROD_DEF_PATH}; \
	   nohup ${LS8_C2_IDX_SCR_BASE_CMD} &> ls8_l2_c2_ind.txt & \
	   wait \
	  "

db-index-world-landsat:
	$(docker_compose) exec -T indexer conda run -n odc bash -c \
	  "datacube product add ${LS5_C2_PROD_DEF_PATH}; \
	   nohup ${LS5_C2_IDX_SCR_BASE_CMD} &> ls5_l2_c2_ind.txt & \
	   datacube product add ${LS7_C2_PROD_DEF_PATH}; \
	   nohup ${LS7_C2_IDX_SCR_BASE_CMD} &> ls7_l2_c2_ind.txt & \
	   datacube product add ${LS8_C2_PROD_DEF_PATH}; \
	   nohup ${LS8_C2_IDX_SCR_BASE_CMD} &> ls8_l2_c2_ind.txt & \
	   wait \
	  "

### End Indexing Targets ###
## End Indexing ##

## Local Data Compression ##
# Compress local data (Only use in the `init-db` target 
# for the environment if the data for the `compress` command 
# is actually needed).

data-compress:
	$(docker_compose) exec -T indexer conda run -n odc bash -c \
	  "tar -czf /Datacube/data.tar.gz -C /Datacube/data .; rm -rf /Datacube/data"

## End Local Data Compression ##

db-dump:
	$(docker_compose) exec -T indexer conda run -n odc bash -c \
	  "PGPASSWORD=${ODC_DB_PASSWORD} pg_dump -h odc_db \
	     -U ${ODC_DB_USER} ${ODC_DB_DATABASE} -n agdc | gzip > db_dump.gz"

docker-commit:
#	Remove the file denoting that the container is already running.
	$(docker_compose) exec -T indexer bash -c "rm /etc/container_started"
	docker commit docker_indexer_1 ${OUT_IMG}

## Full Pipeline ##
OUT_IMG_VER_DRONE_PAPER ?= 
OUT_IMG_DRONE_PAPER ?= ${OUT_IMG_REPO}:odc${ODC_VER}_drone_paper${OUT_IMG_VER_DRONE_PAPER}
init-db-create-drone-paper: OUT_IMG ?= ${OUT_IMG_DRONE_PAPER}
init-db-create-drone-paper: restart db-init db-index-drone-paper data-compress db-dump docker-commit
init-db-drone-paper-push:
	docker push ${OUT_IMG_DRONE_PAPER}

OUT_IMG_VER_VA_CUBE ?= 
# __ls7_8_c1_gee__ls5_7_8_c2_s3
OUT_IMG_VA_CUBE ?= ${OUT_IMG_REPO}:odc${ODC_VER}__va_cube${OUT_IMG_VER_VA_CUBE}
init-db-create-va-cube: OUT_IMG ?= ${OUT_IMG_VA_CUBE}
init-db-create-va-cube: restart db-init db-index-va-cube db-dump docker-commit
# db-index-va
init-db-va-cube-push:
	docker push ${OUT_IMG_VA_CUBE}

# Contains Landsat 8 C2L2 data for Beijing, China.
OUT_IMG_VER_CDC_TRAINING ?= 
OUT_IMG_CDC_TRAINING ?= ${OUT_IMG_REPO}:odc${ODC_VER}__cdc_training${OUT_IMG_VER_CDC_TRAINING}
init-db-create-cdc-trn: OUT_IMG ?= ${OUT_IMG_CDC_TRAINING}
init-db-create-cdc-trn: restart db-init db-index-cdc-trn data-compress db-dump docker-commit
init-db-cdc-trn-push:
	docker push ${OUT_IMG_CDC_TRAINING}

OUT_IMG_VER_CDC_TRAINING ?= 
OUT_IMG_US_LANDSAT ?= ${OUT_IMG_REPO}:odc${ODC_VER}__ls5_7_8_c2l2_US${OUT_IMG_VER_CDC_TRAINING}
init-db-create-us: OUT_IMG ?= ${OUT_IMG_US_LANDSAT}
init-db-create-us: restart db-init db-index-us-landsat db-dump docker-commit
init-db-us-push:
	docker push ${OUT_IMG_US_LANDSAT}

OUT_IMG_VER_WORLD_LANDSAT ?= 
OUT_IMG_WORLD_LANDSAT ?= ${OUT_IMG_REPO}:odc${ODC_VER}__ls5_7_8_c2l2_World${OUT_IMG_VER_WORLD_LANDSAT}
init-db-create-world: OUT_IMG ?= ${OUT_IMG_WORLD_LANDSAT}
init-db-create-world: restart db-init db-index-world-landsat db-dump docker-commit
init-db-world-push:
	docker push ${OUT_IMG_WORLD_LANDSAT}
## End Full Pipeline ##

## Misc ##
sudo-ubuntu-install-docker:
	sudo apt-get update
	sudo apt install -y docker.io
	sudo curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-Linux-x86_64" -o /usr/local/bin/docker-compose
	sudo chmod +x /usr/local/bin/docker-compose
	sudo systemctl start docker
	sudo systemctl enable docker
	# The following steps are for enabling use 
	# of the `docker` command for the current user
	# without using `sudo`
	getent group docker || sudo groupadd docker
	sudo usermod -aG docker ${USER}

dkr-sys-prune:
	yes | docker system prune
## End Misc ##

