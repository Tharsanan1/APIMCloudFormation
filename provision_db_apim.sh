#!/bin/bash
DB_ENGINE=$1
DB_PASSWORD=$2
DB_HOST=$3
DB_USERNAME=$4
DB_PORT=$5


workingdir=$(pwd)
reldir=`dirname $0`
cd $reldir

source ./utils.sh
isEmpty $DB_ENGINE;
flag=$?
if [ $flag = 1 ];
    then echo "DB engine is empty."; exit 1
fi;

isEmpty $DB_PASSWORD;
flag=$?
if [ $flag = 1 ];
    then echo "DB password is empty."; exit 1
fi;

isEmpty $DB_HOST;
flag=$?
if [ $flag = 1 ];
    then echo "DB host is empty."; exit 1
fi;

isEmpty $DB_USERNAME;
flag=$?
if [ $flag = 1 ];
    then echo "DB username is empty."; exit 1
fi;

isEmpty $DB_PORT;
flag=$?
if [ $flag = 1 ];
    then echo "DB port is empty."; exit 1
fi;

#Run database scripts for given database engine and product version

echo "running db scripts, $DB_USERNAME $DB_HOST $DB_PORT $DB_ENGINE" 
if [[ $DB_ENGINE = "postgres" ]]; then
    export PGPASSWORD=$DB_PASSWORD
    psql -U "$DB_USERNAME" -h "$DB_HOST" -p "$DB_PORT" -d postgres -f "./$DB_ENGINE/apim.sql"
elif [[ $DB_ENGINE = "mysql" ]]; then
    echo "running db scripts as mysql, $DB_USERNAME $DB_HOST $DB_PORT $DB_ENGINE" 
    mysql -u "$DB_USERNAME" -p"$DB_PASSWORD" -h "$DB_HOST" -P "$DB_PORT" < "./$DB_ENGINE/apim.sql"
elif [[ $DB_ENGINE =~ 'oracle-se' ]]; then
    # DB Engine : Oracle | Product Version : 2.6.0
    echo "Oracle DB Engine Selected! Running WSO2-APIM 2.6.0 DB Scripts for Oracle..."
    # Create users to the required DB
    echo "DECLARE USER_EXIST INTEGER;"$'\n'"BEGIN SELECT COUNT(*) INTO USER_EXIST FROM dba_users WHERE username='WSO2AM_APIMGT_DB';"$'\n'"IF (USER_EXIST > 0) THEN EXECUTE IMMEDIATE 'DROP USER WSO2AM_APIMGT_DB CASCADE';"$'\n'"END IF;"$'\n'"END;"$'\n'"/" >> /home/ubuntu/apim/apim260/apim_oracle_user.sql
    echo "DECLARE USER_EXIST INTEGER;"$'\n'"BEGIN SELECT COUNT(*) INTO USER_EXIST FROM dba_users WHERE username='WSO2AM_COMMON_DB';"$'\n'"IF (USER_EXIST > 0) THEN EXECUTE IMMEDIATE 'DROP USER WSO2AM_COMMON_DB CASCADE';"$'\n'"END IF;"$'\n'"END;"$'\n'"/" >> /home/ubuntu/apim/apim260/apim_oracle_user.sql
    echo "DECLARE USER_EXIST INTEGER;"$'\n'"BEGIN SELECT COUNT(*) INTO USER_EXIST FROM dba_users WHERE username='WSO2AM_STAT_DB';"$'\n'"IF (USER_EXIST > 0) THEN EXECUTE IMMEDIATE 'DROP USER WSO2AM_STAT_DB CASCADE';"$'\n'"END IF;"$'\n'"END;"$'\n'"/" >> /home/ubuntu/apim/apim260/apim_oracle_user.sql
    echo "CREATE USER WSO2AM_COMMON_DB IDENTIFIED BY CF_DB_PASSWORD;"$'\n'"GRANT CONNECT, RESOURCE, DBA TO WSO2AM_COMMON_DB;"$'\n'"GRANT UNLIMITED TABLESPACE TO WSO2AM_COMMON_DB;" >> /home/ubuntu/apim/apim260/apim_oracle_user.sql
    echo "CREATE USER WSO2AM_APIMGT_DB IDENTIFIED BY CF_DB_PASSWORD;"$'\n'"GRANT CONNECT, RESOURCE, DBA TO WSO2AM_APIMGT_DB;"$'\n'"GRANT UNLIMITED TABLESPACE TO WSO2AM_APIMGT_DB;" >> /home/ubuntu/apim/apim260/apim_oracle_user.sql
    echo "CREATE USER WSO2AM_STAT_DB IDENTIFIED BY CF_DB_PASSWORD;"$'\n'"GRANT CONNECT, RESOURCE, DBA TO WSO2AM_STAT_DB;"$'\n'"GRANT UNLIMITED TABLESPACE TO WSO2AM_STAT_DB;" >> /home/ubuntu/apim/apim260/apim_oracle_user.sql
    # Create the tables
    echo exit | sqlplus64 'CF_DB_USERNAME/CF_DB_PASSWORD@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(Host=CF_DB_HOST)(Port=CF_DB_PORT))(CONNECT_DATA=(SID=WSO2AMDB)))' @/home/ubuntu/apim/apim260/apim_oracle_user.sql
    echo exit | sqlplus64 'WSO2AM_COMMON_DB/CF_DB_PASSWORD@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(Host=CF_DB_HOST)(Port=CF_DB_PORT))(CONNECT_DATA=(SID=WSO2AMDB)))' @/home/ubuntu/apim/apim260/apim_oracle_common_db.sql
    echo exit | sqlplus64 'WSO2AM_APIMGT_DB/CF_DB_PASSWORD@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(Host=CF_DB_HOST)(Port=CF_DB_PORT))(CONNECT_DATA=(SID=WSO2AMDB)))' @/home/ubuntu/apim/apim260/apim_oracle_apimgt_db.sql
elif [[ $DB_ENGINE =~ 'sqlserver-se' ]]; then
    # DB Engine : SQLServer | Product Version : 2.6.0
    echo "SQL Server DB Engine Selected! Running WSO2-APIM 2.6.0 DB Scripts for SQL Server..."
    sqlcmd -S CF_DB_HOST -U CF_DB_USERNAME -P CF_DB_PASSWORD -i /home/ubuntu/apim/apim260/apim_sql_server.sql
fi