for i in {1..50};
do
    /opt/mssql-tools/bin/sqlcmd -b -V16 -S localhost -U sa -P '#SQLEDGE_ADMIN_PASSWORD#' -d master -i /usr/src/app/dbinit.sql -o /usr/src/app/dbinit.out
    if [ $? -eq 1 ]
    then
        sleep 1
    else
        break
    fi
done