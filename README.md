# ODC DB Init

This repository provides convenient means of creating Docker images that contain compressed database dumps of ODC index databases (1 dump per docker image). The compressed database dump can be extracted and used in the resulting container to restore an ODC index database.

## Contents

* [Creating the Output Image](#create-output)
* [Using the Output Image](#use-output)
<br><br>

## <a name="create-output"></a> Creating the Output Image
-----

First run `make init` to initialize Docker.

Then run one of the `init-db-create` targets in the Makefile to create and tag the output image with the corresponding data.

Here are the targets and the data they index:

| Target                 | Description                          |
|------------------------|--------------------------------------|
| init-db-create-us      | Landsat 5/7/8 C2 L2 data for the US  |
| init-db-create-va-cube | Landsat 5/7/8 C2 L2 data for Colorado, Texas, Virginia                                                        |

For example, `make init-db-create-us`.

<br><br>

## <a name="use-output"></a> Using the Output Image
-----

To restore the database from the dump file in the output image, run the following code in a shell in the resulting container, assuming
the container (an indexing container) is connected to an empty database in which we want to restore the data:

```
# Restore index database
gzip -dkf db_dump.gz
datacube system init
PGPASSWORD=${ODC_DB_PASSWORD} psql -h ${ODC_DB_HOSTNAME} -U ${ODC_DB_USER} ${ODC_DB_DATABASE} -c "DROP SCHEMA IF EXISTS agdc CASCADE;"
PGPASSWORD=${ODC_DB_PASSWORD} psql -h ${ODC_DB_HOSTNAME} -U ${ODC_DB_USER} ${ODC_DB_DATABASE} < db_dump
rm db_dump.gz
# Restore data
tar -xzf /Datacube/data.tar.gz -C /Datacube/data
```

At least for ODC 1.8.3, Do **not** try to save the resulting database state with either `docker commit` or a Docker volume. When using ODC clients connected to index databases using either of those means of recording database state, the output of `datacube system check` may show that the database is properly initialized, but `datacube product list` may show no products.

So only the same ODC client and index database pair used to restore the database from the gzip file should be used to query it.
