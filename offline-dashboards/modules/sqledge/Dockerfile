FROM mcr.microsoft.com/azure-sql-edge-premium

USER root
# USER mssql
# WORKDIR /var/opt/mssql
# COPY mssql.conf .
# RUN chmod +r ./mssql.conf

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app
COPY initdb.sh .
COPY entrypoint.sh .
# COPY streaminit.sql .
COPY dbinit.sql .
COPY mssql.conf /var/opt/mssql
RUN chmod +x ./initdb.sh
RUN chmod +x ./entrypoint.sh
# RUN /opt/mssql/bin/mssql-conf traceflag 11515 on

# EXPOSE 1433

CMD /bin/bash ./entrypoint.sh