SHELL:=/bin/bash
docker_compose = docker-compose --project-directory build/docker -f build/docker/docker-compose.yml

# Make the environment variables of the environment available here.
export $(cat build/docker/.env)

up:
	$(docker_compose) up -d --build

ssh:
	$(docker_compose) exec manual bash

ps:
	$(docker_compose) ps

db-init:
	$(docker_compose) exec manual conda run -n odc bash -c \
		"datacube system init"

db-index:
	$(docker_compose) exec manual conda run -n odc bash -c \
	  "datacube product add \
	     Landsat/collection_2/prod_defs/ls5_l2_c2.yaml; \
	   nohup python3 Landsat/collection_2/index_scripts/ls5_l2_c2_public_bucket.py \
	     usgs-landsat -p collection02/level-2/standard/tm --suffix=MTL.xml \
		 --lat1=5 --lat2=6 --lon1=5 --lon2=6 \
		 --start_date=1984-01-01 --end_date=1984-12-31 &> ls5_l2_c2_ind.txt \
	  "

db-dump:
	$(docker_compose) exec manual conda run -n odc bash -c \
	  "PGPASSWORD=$${ODC_DB_PASSWORD} pg_dump -h $${ODC_DB_HOSTNAME} \
	     -U $${ODC_DB_USER} $${ODC_DB_DATABASE} -n agdc | gzip > db_dump.gz"

move-db-dump:
	docker cp docker_manual_1:/manual_indexer/db_dump.gz .
	docker cp db_dump.gz docker_odc_db_init_1:/
	rm db_dump.gz

# restore-db:
# 	$(docker_compose) exec odc_db_init bash -c \
# 	  "gzip -dk db_dump.gz; echo PGPASSWORD=${ODC_DB_PASSWORD} psql \
# 	     -U ${ODC_DB_USER} ${ODC_DB_DATABASE}; PGPASSWORD=${ODC_DB_PASSWORD} psql \
# 	     -U ${ODC_DB_USER} ${ODC_DB_DATABASE} < db_dump"

docker-commit:
	docker commit docker_odc_db_init_1 jcrattzama/odc_db_init:odc1.8.3

init-db-create: up db-init db-index db-dump move-db-dump docker-commit


