# Run Microsoft SQl Server and initialization script (at the same time)
/opt/mssql/bin/launchpadd -usens=false -usesameuser=true -sqlGroup root -- -reparentOrphanedDescendants=true & /usr/src/app/initdb.sh & /opt/mssql/bin/sqlservr
