# Twitter Postgres (Indexes)

This is a continuation of the [parallel twitter in postgres assignment](https://github.com/mikeizbicki/twitter_postgres_parallel).

I have provided you the solutions for loading data into the `pg_denormalized` and `pg_normalized_batch` services.
We're not using `pg_normalized` because it's so slow to load and the resulting database is essentially the same as `pg_normalized_batch`.

Your goal will be to create fast queries.

<img src=the-sql-queries.jpg width=400px >

## Step 0: Prepare the repo/docker

1. Fork this repo, and clone your fork onto the lambda server.

1. Remove the volumes you created in your previous assignment by first bringing down/stopping all containers, then pruning the volumes:
   ```
   $ docker stop $(docker ps -q)
   $ docker rm $(docker ps -qa)
   $ docker volume prune
   ```

1. Modify the `docker-compose.yml` file so that the ports for each of the services are distinct.

    Bring up the docker containers and ensure there are no errors
    ```
    $ docker-compose up -d --build
    ```

1. Notice that the `docker-compose.yml` file uses a [bind mount](https://docs.docker.com/storage/bind-mount/) into your `$HOME/bigdata` directory whereas all of our previous assignments stored data into a [named volume](https://docs.docker.com/storage/volumes/).


    This is necessary because in this assignment, you will be creating approximately 100GB worth of databases.
    This won't fit in your home folder on the NVME drive (10G limit), and so you must put it into the HDD drives (250G limit).

    This will create a few problems for you.
    In particular, notice that the permissions of the created folders are rather weird:
    ```
    $ cd ~/bigdata
    $ ls -l
    total 12
    drwxr-xr-x+  2 usertest usertest 4096 Feb  2 09:09 flask_web
    drwx------+ 19  4688518 usertest 4096 Apr  8 15:19 pg_denormalized
    drwx------+ 19  4688518 usertest 4096 Apr  8 15:19 pg_normalized_batch
    ```
    If you run the commands above, you will have different UIDs.
    These are the UID of the `root` user of your docker container.
    Since you are not currently logged in as that user,
    you will not be able to manipulate these files directly.

    The main way this is a problem is that if you need to reset/delete your volumes fro some reason.
    When using a named mount, this was easy to do with the
    ```
    $ docker volume prune
    ```
    command.
    This command will not work for bind mounts, however.
    Whenever you use a bind mount, everything must be done manually.
    These mounts have more flexibility (we can store the data whereever we want), but they become much more awkward to use.

    The easiest way to "reset" our containers is to do it from within docker.
    The following commands will login to the docker containers and delete all of postgres's data:
    ```
    $ docker-compose exec pg_normalized_batch bash -c 'rm -rf $PGDATA'
    $ docker-compose exec pg_denormalized bash -c 'rm -rf $PGDATA'
    ```
    After running these commands, if you bring the containers down and back up, postgres will detect that the volumes are empty and re-run the `schema.sql` scripts to populate the databases.


## Step 1: Load the Data

For this assignment, we will work with 10 days of twitter data, about 31 million tweets.
This is enough data that indexes will dramatically improve query times,
but you won't have to wait hours/days to create each index and see if it works correctly.

Load the data into docker by running the command
```
$ sh load_tweets_parallel.sh
================================================================================
load pg_denormalized
================================================================================
/data/tweets/geoTwitter21-01-02.zip
COPY 2979992
/data/tweets/geoTwitter21-01-04.zip
COPY 3044365
/data/tweets/geoTwitter21-01-05.zip
COPY 3038917
/data/tweets/geoTwitter21-01-03.zip
COPY 3143286
/data/tweets/geoTwitter21-01-01.zip
COPY 3189325
/data/tweets/geoTwitter21-01-10.zip
COPY 3129896
/data/tweets/geoTwitter21-01-09.zip
COPY 3157691
/data/tweets/geoTwitter21-01-08.zip
COPY 3148130
/data/tweets/geoTwitter21-01-07.zip
COPY 3306556
/data/tweets/geoTwitter21-01-06.zip
COPY 3376266
1587.10user 328.30system 18:18.76elapsed 174%CPU (0avgtext+0avgdata 17376maxresident)k
0inputs+27856outputs (0major+70545minor)pagefaults 0swaps
================================================================================
load pg_normalized_batch
================================================================================
2022-04-08 15:38:18.510811 /data/tweets/geoTwitter21-01-02.zip
...
...
...
23974.74user 1259.12system 51:55.11elapsed 810%CPU (0avgtext+0avgdata 3113188maxresident)k
5808inputs+86232outputs (3major+847834998minor)pagefaults 0swaps
```

Observe the runtimes in the above output to get a sense for how long your own queries should take.
Note that these operations max out the disk IO on the lambda server, and so if many students are running them at once, they could take considerably longer to complete.

### Disk Usage

We're storing the twitter data in three formats (the original zip files, the denormalized database, and the normalized database).
Let's take a minute to see the total disk usage of each of these formats to help us understand the trade-offs of using each format.

The following commands will output the disk usage inside of the databases.
```
$ docker-compose exec pg_denormalized sh -c 'du -hd0 $PGDATA'
75G	/var/lib/postgresql/data
$ docker-compose exec pg_normalized_batch sh -c 'du -hd0 $PGDATA'
25G	/var/lib/postgresql/data
```
Notice that the denormalized database is using considerably more disk space than the normalized one.

To get the disk usage of the raw zip files, we first copy the definition of the `files` variable from the `load_tweets_parallel.sh` file into the terminal:
```
$ files='/data/tweets/geoTwitter21-01-01.zip
/data/tweets/geoTwitter21-01-02.zip
/data/tweets/geoTwitter21-01-03.zip
/data/tweets/geoTwitter21-01-04.zip
/data/tweets/geoTwitter21-01-05.zip
/data/tweets/geoTwitter21-01-06.zip
/data/tweets/geoTwitter21-01-07.zip
/data/tweets/geoTwitter21-01-08.zip
/data/tweets/geoTwitter21-01-09.zip
/data/tweets/geoTwitter21-01-10.zip'
```
Then run the following command:
```
$ du -ch $files
1.7G	/data/tweets/geoTwitter21-01-01.zip
1.6G	/data/tweets/geoTwitter21-01-02.zip
1.7G	/data/tweets/geoTwitter21-01-03.zip
1.6G	/data/tweets/geoTwitter21-01-04.zip
1.6G	/data/tweets/geoTwitter21-01-05.zip
1.8G	/data/tweets/geoTwitter21-01-06.zip
1.8G	/data/tweets/geoTwitter21-01-07.zip
1.7G	/data/tweets/geoTwitter21-01-08.zip
1.7G	/data/tweets/geoTwitter21-01-09.zip
1.7G	/data/tweets/geoTwitter21-01-10.zip
17G	total
```
We can see that the "flat" zip files use the least amount of data.

Why?

Postgres will keep all of the data compressed, but it has a lot of overhead in its heap tables (each row has overhead, and each page has overhead, and we will have empty space in each page).
We haven't discussed the `JSONB` column type in detail, but this also introduces significant overhead in order to have an efficient access operations.

## Step 2: Create indexes on the normalized database

I have provided a series of 5 sql queries for you, which you can find in the `sql.normalized_batch` folder.
You can time the running of these queries with the command
```
$ time docker-compose exec pg_normalized_batch ./check_answers.sh sql.normalized_batch
sql.normalized_batch/01.sql pass
sql.normalized_batch/02.sql pass
sql.normalized_batch/03.sql pass
sql.normalized_batch/04.sql pass
sql.normalized_batch/05.sql pass

real	2m5.882s
user	0m0.561s
sys	0m0.403s
```

Your first task is to create indexes so that the command above takes less than 5 seconds to run (i.e. one second per query).
Most of this runtime is overhead of the shell script.
If you open up psql and run the queries directly,
then you should see the queries taking only milliseconds to run.

> **NOTE:**
> None of your indexes should be partial indexes.
> This is so that you could theoretically replace any of the conditions with any other value,
> and the results will still be returned quickly.

> **HINT:**
> My solution creates 3 btree indexes and 1 gin index.
> Here's the output of running the command above with the indexes created:
> ```
> $ time docker-compose exec pg_normalized_batch   ./check_answers.sh sql.normalized_batch
> sql.normalized_batch/01.sql pass
> sql.normalized_batch/02.sql pass
> sql.normalized_batch/03.sql pass
> sql.normalized_batch/04.sql pass
> sql.normalized_batch/05.sql pass
> 
> real	0m3.176s
> user	0m0.571s
> sys	0m0.377s
> ```

> **IMPORTANT:**
> As you create your indexes, you should add them to the file `services/pg_normalized_batch/schema-indexes.sql`.
> (Like the `schema.sql` file, this file would get automatically run by postgres if you were to rebuild the containers+images.)
> In general, you never want to directly modify the schema of a production database.
> Instead, you write your schema-modifying code in a sql file,
> commit the sql file to your git repo,
> then execute the sql file.
> This ensures that you can always fully recreate your database schema from the project's git repo.

## Step 3: Create queries and indexes for the denormalized database

I have provided you the sql queries for the normalized database, but not for the denormalized one.
You will have to modify the files in `sql.denormalized` so that they produce the same output as the files in `sql.normalized_batch`.
The purpose of this exercise it twofold:

1. to give you practice writing queries into a denormalized database (you've only written queries for a normalized database at this point)
2. to give you practice writing queries and indexes at the same time (the exact queries you'll write in the real world will depend on the indexes you're able to create and vice versa)

You should add all of the indexes you create into the file `services/pg_denormalized/schema-indexes.sql`,
just like you did for the normalized database.

You can check the runtime and correctness of your denormalized queries with the command
```
$ time docker-compose exec pg_denormalized ./check_answers.sh sql.denormalized
```

You will likely notice that the denormalized representation is significantly slower than the normalized representation when there are no indexes present.
My solution takes about 4 minutes without indexes, and 3 seconds with indexes.
The indexed solution is still slower than the normalized solution because there are sorts in the query plan that the indexes cannot eliminate.
In fact, no set of indexes would be able to eliminate these sorts... we'll talk later about how to eliminate them using materialized views.

> **HINT:**
> Here is the output of timing my SQL queries with no indexes present.
> ```
> $ time docker-compose exec pg_denormalized ./check_answers.sh sql.denormalized
> sql.denormalized/01.sql pass
> sql.denormalized/02.sql pass
> sql.denormalized/03.sql pass
> sql.denormalized/04.sql pass
> sql.denormalized/05.sql pass
> 
> real	39m6.800s
> user	0m0.875s
> sys	0m0.471s
> ```
> Notice that these runtimes are WAY slower than for the normalized database. 
>
> After building the indexes, the runtimes are basically the same as for the normalized database:
> ```
> $ time docker-compose exec pg_denormalized ./check_answers.sh sql.denormalized
> sql.denormalized/01.sql pass
> sql.denormalized/02.sql pass
> sql.denormalized/03.sql pass
> sql.denormalized/04.sql pass
> sql.denormalized/05.sql pass
> 
> real	0m2.903s
> user	0m0.621s
> sys	0m0.389s
> ```

## Submission

We will not use github actions in this assignment,
since this assignment uses too much disk space and computation.
In general, there are no great techniques for benchmarking/testing programs on large datasets.
The best solution is to test on small datasets (like we did for the first version of twitter\_postgres),
and carefully design those tests so that they ensure good performance on the large datasets.
We're not following this procedure, however, to ensure that you get some actual practice with these larger datasets.

To submit your assignment:

1. Run the following commands
   ```
   $ ( time docker-compose exec pg_normalized_batch ./check_answers.sh sql.normalized_batch ) > results.normalized_batch 2>&1
   $ ( time docker-compose exec pg_denormalized     ./check_answers.sh sql.denormalized     ) > results.denormalized     2>&1
   ```
   This will create two files in your repo that contain the runtimes and results of your test cases.
   In the command above:
   1. `( ... )` is called a subshell in bash.
      The `time` command is an internal built-in command in bash and not a separate executable file,
      and it is necessary to wrap it in a subshell in order to redirect its output.
   1. `2>&1` redirects stderr (2) to stdout (1), and since stdout is being redirected to a file, stderr will also be redirected to that file.
      The output of the `time` command goes to stderr, and so this combined with the subshell ensure that the time command's output gets sent into the results files.

   > **HINT:**
   > Mastering these shell redirection tricks is a HUGE timesaver,
   > and something that I'd recommend anyone working on remote servers professionally do.

1. Add the `results.*`, `sql.denormalized/*`, and `services/*/schema-indexes.sql` files to your git repo, commit, and push to github.

1. Submit a link to your forked repo to sakai.

### Grading

The assignment is worth 30 points.

1. The timing of the normalized sql queries is worth 10 points.
    If your queries take longer than 5 seconds, you will lose 2 points per second.

1. Each file in `sql.denormalized` is worth 2 points (for 10 total).
    Passing the test cases will ensure you get these points.

1. The timing of the denormalized sql queries is worth 10 points.
    If your queries take longer than 5 seconds, you will lose 2 points per second.

   You cannot get any credit for these runtimes unless ALL of the denormalized test cases pass.

I will check the `results.*` files in your github repos to grade your timing.

> **HINT:**
> Creating an index can take up to 30 minutes to complete when the lambda server is under no load.
> When other students are also creating indexes, it could take several hours to complete.
> So you shouldn't put this assignment off to the last minute.
