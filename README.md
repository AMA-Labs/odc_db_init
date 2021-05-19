# ODC DB Init

This repository provides convenient means of creating Docker images that contain compressed database dumps of ODC index databases (1 dump per docker image). The compressed database dump can be extracted and restored in the resulting container to make a prepopulated ODC index database container.
<br><br>

## Contents

* [Creating the Output Image](#create-output)
* [Using the Output Image](#use-output)
<br><br>

## <a name="create-output"></a> Creating the Output Image
-----

Run `make init-db-create` to create and tag the output image.

<br><br>

## <a name="use-output"></a> Using the Output Image
-----

To restore the database from the dump file in the output image, run the following code in a shell in resulting container:

```
gzip -dk db_dump.gz
PGPASSWORD=${ODC_DB_PASSWORD} psql \
    -U ${ODC_DB_USER} ${ODC_DB_DATABASE} < db_dump
rm db_dump.gz
```

You can then use `docker commit` to create an image containing the populated database.
