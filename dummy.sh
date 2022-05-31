echo "DECLARE USER_EXIST INTEGER;"$'\n'"BEGIN SELECT COUNT(*) INTO USER_EXIST FROM dba_users WHERE username='WSO2AM_DB';"$'\n'"IF (USER_EXIST > 0) THEN EXECUTE IMMEDIATE 'DROP USER WSO2AM_DB CASCADE';"$'\n'"END IF;"$'\n'"END;"$'\n'"/" > apim_oracle_user.sql
echo "DECLARE USER_EXIST INTEGER;"$'\n'"BEGIN SELECT COUNT(*) INTO USER_EXIST FROM dba_users WHERE username='WSO2AM_SHARED_DB';"$'\n'"IF (USER_EXIST > 0) THEN EXECUTE IMMEDIATE 'DROP USER WSO2AM_SHARED_DB CASCADE';"$'\n'"END IF;"$'\n'"END;"$'\n'"/" >> apim_oracle_user.sql
echo "CREATE USER WSO2AM_SHARED_DB IDENTIFIED BY wso2carbon;"$'\n'"GRANT CONNECT, RESOURCE, DBA TO WSO2AM_SHARED_DB;"$'\n'"GRANT UNLIMITED TABLESPACE TO WSO2AM_SHARED_DB;" >> apim_oracle_user.sql
echo "CREATE USER WSO2AM_DB IDENTIFIED BY wso2carbon;"$'\n'"GRANT CONNECT, RESOURCE, DBA TO WSO2AM_DB;"$'\n'"GRANT UNLIMITED TABLESPACE TO WSO2AM_DB;" >> apim_oracle_user.sql


# Create the tables
echo exit | sqlplus64 'root/test12345@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(Host=apim-profile-automation-rds.ccndgaztcixx.us-west-1.rds.amazonaws.com)(Port=1521))(CONNECT_DATA=(SID=ORCL)))' @apim_oracle_user.sql
echo exit | sqlplus64 'WSO2AM_SHARED_DB/wso2carbon@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(Host=apim-profile-automation-rds.ccndgaztcixx.us-west-1.rds.amazonaws.com)(Port=1521))(CONNECT_DATA=(SID=ORCL)))' @/home/tharsanan/Software/wso2/wso2am-4.1.0/dbscripts/oracle.sql
echo exit | sqlplus64 'WSO2AM_DB/wso2carbon@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(Host=apim-profile-automation-rds.ccndgaztcixx.us-west-1.rds.amazonaws.com)(Port=1521))(CONNECT_DATA=(SID=ORCL)))' @/home/tharsanan/Software/wso2/wso2am-4.1.0/dbscripts/apimgt/oracle.sql