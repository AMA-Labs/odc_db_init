SHELL:=/bin/bash
compose_file = build/docker/docker-compose.yml
# --compatibility since we are using `docker stack deploy` for resource limits.
docker_compose = docker-compose --compatibility --project-directory build/docker -f ${compose_file}
# dkr_stack_name = odc_db_init_stack

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
OUT_IMG_VER?=
export OUT_IMG_REPO
## End Output ##

# COMMON_EXPRTS=export INDEXER_BASE_IMG=${INDEXER_BASE_IMG};

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
	$(docker_compose) exec -T indexer conda run -n odc bash -c \
		"datacube system init"

## Indexing ##

### Indexing Variables ###
PROD_DEF_DIR = prod_defs
IDX_SCR_DIR = index_scripts
# Landsat
LANDSAT_PROD_DEFS_DIR = ${PROD_DEF_DIR}/Landsat
LANDSAT_IDX_SCR_DIR = ${IDX_SCR_DIR}/Landsat
LANDSAT_C2_PROD_DEFS_DIR = ${LANDSAT_PROD_DEFS_DIR}/collection_2
LANDSAT_C2_IDX_SCR_DIR = ${LANDSAT_IDX_SCR_DIR}/collection_2
## Landsat 5
LS5_C2_PROD_DEF_PATH = ${LANDSAT_C2_PROD_DEFS_DIR}/ls5_l2_c2.yaml
LS5_C2_IDX_SCR_BASE_CMD = \
	python3 ${LANDSAT_C2_IDX_SCR_DIR}/ls5_l2_c2.py \
	   usgs-landsat -p collection02/level-2/standard/tm --suffix=MTL.xml
## Landsat 7
LS7_C2_PROD_DEF_PATH = ${LANDSAT_C2_PROD_DEFS_DIR}/ls7_l2_c2.yaml
LS7_C2_IDX_SCR_BASE_CMD = \
	python3 ${LANDSAT_C2_IDX_SCR_DIR}/ls7_l2_c2_public_bucket.py \
	   usgs-landsat -p collection02/level-2/standard/etm --suffix=MTL.xml
## Landsat 8
LS8_C2_PROD_DEF_PATH = ${LANDSAT_C2_PROD_DEFS_DIR}/ls8_l2_c2.yaml
LS8_C2_IDX_SCR_BASE_CMD = \
	python3 ${LANDSAT_C2_IDX_SCR_DIR}/ls8_l2_c2_public_bucket.py \
	   usgs-landsat -p collection02/level-2/standard/oli-tirs --suffix=MTL.xml
# Mavic Mini
WEBODM_MAVICMINI_PROD_DEFS_DIR = ${PROD_DEF_DIR}/WebODM_MavicMini
## WebODM_MavicMini_RGBA
WEBODM_MAVICMINI_RGBA_PROD_DEF_PATH = ${WEBODM_MAVICMINI_PROD_DEFS_DIR}/WebODM_MavicMini_RGBA.yaml
### End Indexing Variables ###

# Index all Landsat 5/7/8 C2 L2 data for Colorado, Texas, Virginia.
COLORADO_EXTENTS = --lat1=37 --lat2=41 --lon1=-109.1 --lon2=-102
TEXAS_EXTENTS = --lat1=25.6 --lat2=36.6 --lon1=-106.75 --lon2=-93.4

db-index-drone-paper:
# 	Add products from the indexer.
	$(docker_compose) exec -T indexer conda run -n odc bash -c \
	  "datacube product add ${WEBODM_MAVICMINI_RGBA_PROD_DEF_PATH}"
# 	Copy the data into its final directory for indexing.
	$(docker_compose) exec -T indexer conda run -n odc bash -c \
	  "cp -r /Datacube/tmp /Datacube/data"
# 	Add products from this repository.
	$(docker_compose) exec -T indexer conda run -n odc bash -c \
	  "datacube product add /Datacube/data/prod_defs/**"
# 	Index the local data.
## 	Landsat 8 Colorado Springs
## 	MavicMini Colorado Springs
	$(docker_compose) exec -T indexer conda run -n odc bash -c \
	  "datacube dataset add /Datacube/data/tiles/ls8_l2_c2_colorado_springs/LC08_L2SP_033033_20210425_20210501_02_T1/metadata.json; \
	   python3 ${IDX_SCR_DIR}/drone_indexer.py /Datacube/data/tiles/WebODM_MavicMini_RGBA WebODM_MavicMini_RGBA"

db-index-va-cube:
	$(docker_compose) exec -T indexer conda run -n odc bash -c \
	  "datacube product add ${LS5_PROD_DEF_PATH}; \
	   nohup sh -c '${LS5_IDX_SCR_BASE_CMD} ${COLORADO_EXTENTS}; \
	    	  		${LS5_IDX_SCR_BASE_CMD} ${TEXAS_EXTENTS}' &> ls5_l2_c2_ind.txt & \
	   datacube product add ${LS7_PROD_DEF_PATH}; \
	   nohup sh -c '${LS7_IDX_SCR_BASE_CMD} ${COLORADO_EXTENTS}; \
	    	  		${LS7_IDX_SCR_BASE_CMD} ${TEXAS_EXTENTS}' &> ls7_l2_c2_ind.txt & \
	   datacube product add ${LS8_PROD_DEF_PATH}; \
	   nohup sh -c '${LS8_IDX_SCR_BASE_CMD} ${COLORADO_EXTENTS}; \
	    	  		${LS8_IDX_SCR_BASE_CMD} ${TEXAS_EXTENTS}' &> ls8_l2_c2_ind.txt & \
	   wait \
	  "

US_EXTENTS = --lat1=24 --lat2=50 --lon1=-127 --lon2=-66
db-index-us: # Index all Landsat 5/7/8 C2 L2 data for the US.
	$(docker_compose) exec -T indexer conda run -n odc bash -c \
	  "datacube product add ${LS5_PROD_DEF_PATH}; \
	   nohup ${LS5_IDX_SCR_BASE_CMD} ${US_EXTENTS} &> ls5_l2_c2_ind.txt & \
	   datacube product add ${LS7_PROD_DEF_PATH}; \
	   nohup ${LS7_IDX_SCR_BASE_CMD} ${US_EXTENTS} &> ls7_l2_c2_ind.txt & \
	   datacube product add ${LS8_PROD_DEF_PATH}; \
	   nohup python3 ${LS8_IDX_SCR_BASE_CMD} ${US_EXTENTS} &> ls8_l2_c2_ind.txt & \
	   wait \
	  "

## End Indexing ##

## Local Data Compression ##
# Compress local data (Only use in the `init-db` target 
# for the environment if the data for the `compress` command 
# is actually needed).

data-compress-full:
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
OUT_IMG_DRONE_PAPER ?= ${OUT_IMG_REPO}:odc${ODC_VER}_drone_paper${OUT_IMG_VER}
init-db-create-drone-paper: OUT_IMG ?= ${OUT_IMG_DRONE_PAPER}
init-db-create-drone-paper: restart db-init db-index-drone-paper data-compress-full db-dump docker-commit
init-db-drone-paper-push:
	docker push ${OUT_IMG_DRONE_PAPER}

OUT_IMG_VA_CUBE ?= ${OUT_IMG_REPO}:odc${ODC_VER}__ls5_7_8_c2l2_colorado_texas${OUT_IMG_VER}
init-db-create-va-cube: OUT_IMG ?= ${OUT_IMG_VA_CUBE}
init-db-create-va-cube: restart db-init db-index-va-cube db-dump docker-commit
init-db-va-cube-push:
	docker push ${OUT_IMG_VA_CUBE}

OUT_IMG_US ?= ${OUT_IMG_REPO}:odc${ODC_VER}__ls5_7_8_c2l2_US${OUT_IMG_VER}
init-db-create-us: OUT_IMG ?= ${OUT_IMG_US}
init-db-create-us: restart db-init db-index-us db-dump docker-commit
init-db-us-push:
	docker push ${OUT_IMG_US}
## End Full Pipeline ##

## Misc ##
dkr-sys-prune:
	yes | docker system prune
## End Misc ##

