
-- DROP USER GITHUB_DEPLOY_USER CASCADE;
-- remove password from repo

DECLARE
  v_username          VARCHAR2 (30) := 'GITHUB_DEPLOY_USER';
  v_password          VARCHAR2 (30) := 'password123';
  v_tablespace        VARCHAR2 (30) := 'DATA02';
  v_temp_tablespace   VARCHAR2 (30) := 'TEMP';
  v_profile           VARCHAR2 (30) := 'DEFAULT';
  V_COUNT             NUMBER;
BEGIN
  IF (USER = 'SYS')
  THEN
  
    SELECT COUNT (*)
      INTO V_COUNT
      FROM DBA_USERS
     WHERE USERNAME = V_USERNAME;


    IF (V_COUNT = 0)
    THEN
      EXECUTE IMMEDIATE   'CREATE USER '
                       || v_username
                       || ' IDENTIFIED BY "'
                       || v_password
                       || '"'
                       || ' HTTP DIGEST DISABLE'
                       || ' DEFAULT TABLESPACE '
                       || v_tablespace
                       || ' TEMPORARY TABLESPACE '
                       || v_temp_tablespace
                       || ' PROFILE '
                       || v_profile
                       || ' ACCOUNT UNLOCK';
	
		  EXECUTE IMMEDIATE   'ALTER USER '
                     || V_USERNAME
                     || ' QUOTA UNLIMITED ON '
                     || v_tablespace;

    EXECUTE IMMEDIATE   'ALTER USER '
                     || V_USERNAME
                     || ' QUOTA UNLIMITED ON '
                     || 'DATA01';
    END IF;

	-- check whether editions enabled for AAPEN schema
    SELECT COUNT (1)
      INTO V_COUNT
      FROM DBA_USERS
     WHERE EDITIONS_ENABLED = 'Y' AND USERNAME = 'AAPEN';

    IF (V_COUNT = 0)
    THEN
		-- Enabling editions for AAPEN schema
      EXECUTE IMMEDIATE 'ALTER USER AAPEN ENABLE EDITIONS FORCE';
    END IF;

    SELECT COUNT (1)
      INTO V_COUNT
      FROM DBA_USERS
     WHERE EDITIONS_ENABLED = 'Y' AND USERNAME = 'DISPORT';

    IF (V_COUNT = 0)
    THEN
		-- Enabling editions for DISPORT schema
      EXECUTE IMMEDIATE 'ALTER USER DISPORT ENABLE EDITIONS FORCE';
    END IF;

    SELECT COUNT (1)
      INTO V_COUNT
      FROM DBA_USERS
     WHERE EDITIONS_ENABLED = 'Y' AND USERNAME = 'GLOBAL';

    IF (V_COUNT = 0)
    THEN
		-- Enabling editions for GLOBAL schema
      EXECUTE IMMEDIATE 'ALTER USER GLOBAL ENABLE EDITIONS FORCE';
    END IF;

		-- Granting permission for creating session
    EXECUTE IMMEDIATE 'GRANT CREATE SESSION TO ' || V_USERNAME;

    -- Granting permission for creating table.Grant used for creating flyway_schema_history table,CONFIGURATION_SETTING,DEPLOYMENT_HISTORY
    EXECUTE IMMEDIATE 'GRANT CREATE TABLE TO ' || V_USERNAME;

	-- Granting permission for CREATE,DROP ANY EDITION
    EXECUTE IMMEDIATE   'GRANT CREATE ANY EDITION, DROP ANY EDITION TO '
                     || V_USERNAME;
					 
	-- Granting permission for creating procedure.This grant is used for creating OracleCICD.
    EXECUTE IMMEDIATE 'GRANT CREATE PROCEDURE TO ' || V_USERNAME;
	
	-- Granting permission for creating procedure.This grant is used for creating synonym for sys objects and OracleCICD.
    EXECUTE IMMEDIATE 'GRANT CREATE SYNONYM TO ' || V_USERNAME;
	
	-- Granting permission for creating sequence.This grant is used for creating SEQ_EDITION,DEPHISTORY_DEPID_SEQ
    EXECUTE IMMEDIATE 'GRANT CREATE SEQUENCE TO ' || V_USERNAME;
	
	-- creating private synonym for SYS.DBA_EDITIONS
    EXECUTE IMMEDIATE   'CREATE OR REPLACE SYNONYM '
                     || V_USERNAME
                     || '.DBA_EDITIONS FOR SYS.DBA_EDITIONS';
					 
	-- creating private synonym for SYS.DBA_OBJECTS
    EXECUTE IMMEDIATE   'CREATE OR REPLACE SYNONYM '
                     || V_USERNAME
                     || '.DBA_OBJECTS FOR SYS.DBA_OBJECTS';
	
	-- creating private synonym for SYS.DBA_TAB_PRIVS
    EXECUTE IMMEDIATE   'CREATE OR REPLACE SYNONYM '
                     || V_USERNAME
                     || '.DBA_TAB_PRIVS FOR SYS.DBA_TAB_PRIVS';
	
	-- creating private synonym for SYS.UTL_RECOMP
    EXECUTE IMMEDIATE   'CREATE OR REPLACE SYNONYM '
                     || V_USERNAME
                     || '.UTL_RECOMP FOR SYS.UTL_RECOMP';
	-- creating private synonym for AAPEN.SS_ERRORLOG
    EXECUTE IMMEDIATE   'CREATE OR REPLACE SYNONYM '
                     || V_USERNAME
                     || '.SS_ERRORLOG FOR AAPEN.SS_ERRORLOG';

	-- Granting SELECT permission for DBA_OBJECTS.DBA_OBJECTS is used in EBR flow.
    EXECUTE IMMEDIATE 'GRANT SELECT ON DBA_OBJECTS TO ' || V_USERNAME;
	
	-- Granting SELECT permission for UTL_RECOMP.DBA_EDITIONS is used in EBR flow.
    EXECUTE IMMEDIATE 'GRANT EXECUTE  ON UTL_RECOMP TO ' || V_USERNAME;
	
	-- Granting SELECT permission for DBA_EDITIONS.DBA_EDITIONS is used in EBR flow.
    EXECUTE IMMEDIATE 'GRANT SELECT ON DBA_EDITIONS TO ' || V_USERNAME;
	
	-- Granting SELECT permission for DBA_EDITIONS.DBA_EDITIONS is used in EBR flow.
    EXECUTE IMMEDIATE 'GRANT SELECT ON DBA_TAB_PRIVS TO ' || V_USERNAME;
	
    EXECUTE IMMEDIATE   'GRANT INSERT,SELECT ON AAPEN.SS_ERRORLOG TO '
                     || V_USERNAME;

	--Granting ALTER permission for DATABASE. To reflect the latest deployment, it is necessary to alter the default edition of the database after deployment.
    EXECUTE IMMEDIATE 'GRANT ALTER DATABASE TO ' || V_USERNAME;

    SELECT COUNT (*)
      INTO v_count
      FROM all_objects
     WHERE     object_type = 'SEQUENCE'
           AND object_name = 'SEQ_EDITION'
           AND OWNER = v_username;

    IF v_count = 0
    THEN
		-- The naming convention for editions built using SEQ_EDITION, which results in names such as E_1, E_2, E_3, E_4, E_5, E_6, E_7, and E_8.
      EXECUTE IMMEDIATE 'CREATE SEQUENCE ' || V_USERNAME || '.SEQ_EDITION
                          START WITH 1
                          MAXVALUE 9999999999999999999999999999
                          MINVALUE 0
                          NOCYCLE
                          CACHE 20
                          NOORDER
                          NOKEEP
                          NOSCALE
                          GLOBAL';
    END IF;

    v_count := 0;

    SELECT COUNT (*)
      INTO v_count
      FROM all_objects
     WHERE     object_type = 'TABLE'
           AND object_name = 'CONFIGURATION_SETTING'
           AND OWNER = v_username;

    IF v_count = 0
    THEN
	--The CONFIGURATION_SETTING table is used for storing EBR (Edition-Based Redefinition) specific configurations, such as EditionDropLimit.
    --These configurations are important for managing and controlling the behavior of EBR.
      EXECUTE IMMEDIATE   'CREATE TABLE '
                       || V_USERNAME
                       || '.CONFIGURATION_SETTING
                          (
                            CONFIG_KEY            VARCHAR2(500 BYTE)   NOT NULL,
                            CONFIG_KEY_DESC       VARCHAR2(3000 BYTE)  NOT NULL,
                            CONFIG_VALUE          VARCHAR2(3500 BYTE)  NOT NULL,
                            CREATED_ON            DATE                 DEFAULT SYSDATE  NOT NULL
                          )TABLESPACE DATA01
                          PCTUSED    0
                          PCTFREE    10
                          INITRANS   1
                          MAXTRANS   255
                          STORAGE    (
                                      INITIAL          1M
                                      NEXT             1M
                                      MINEXTENTS       1
                                      MAXEXTENTS       UNLIMITED
                                      PCTINCREASE      0
                                      BUFFER_POOL      DEFAULT
                                     )
                          LOGGING 
                          NOCOMPRESS 
                          NOCACHE';
    END IF;


    EXECUTE IMMEDIATE   'GRANT SELECT ON '
                     || V_USERNAME
                     || '.CONFIGURATION_SETTING TO AAPEN';

    EXECUTE IMMEDIATE   'GRANT SELECT ON '
                     || V_USERNAME
                     || '.CONFIGURATION_SETTING TO GLOBAL';

    EXECUTE IMMEDIATE   'GRANT SELECT ON '
                     || V_USERNAME
                     || '.CONFIGURATION_SETTING TO DISPORT';

    EXECUTE IMMEDIATE   'CREATE OR REPLACE SYNONYM AAPEN.CONFIGURATION_SETTING FOR '
                     || V_USERNAME
                     || '.CONFIGURATION_SETTING';

    EXECUTE IMMEDIATE   'CREATE OR REPLACE SYNONYM DISPORT.CONFIGURATION_SETTING FOR '
                     || V_USERNAME
                     || '.CONFIGURATION_SETTING';

    EXECUTE IMMEDIATE   'CREATE OR REPLACE SYNONYM GLOBAL.CONFIGURATION_SETTING FOR '
                     || V_USERNAME
                     || '.CONFIGURATION_SETTING';
	-- initial seed script for EditionDropLimit as 30
    EXECUTE IMMEDIATE   'INSERT INTO '
                     || V_USERNAME
                     || '.CONFIGURATION_SETTING (
                          CONFIG_KEY,
                          CONFIG_KEY_DESC,
                          CONFIG_VALUE
                        )
                        SELECT
                          ''EditionDropLimit'' AS CONFIG_KEY,
                          ''Edition drop limit'' AS CONFIG_KEY_DESC,
                          ''30'' AS CONFIG_VALUE
                        FROM dual
                        WHERE NOT EXISTS (
                          SELECT 1
                          FROM '
                     || V_USERNAME
                     || '.CONFIGURATION_SETTING ST2
                          WHERE ST2.CONFIG_KEY = ''EditionDropLimit''
                        )';

    COMMIT;



    SELECT COUNT (*)
      INTO v_count
      FROM all_objects
     WHERE     object_type = 'SEQUENCE'
           AND object_name = 'DEPHISTORY_DEPID_SEQ'
           AND OWNER = V_USERNAME;

    IF v_count = 0
    THEN
	--  Primary key for the DEPLOYMENT_HISTORY table is established using the DEPHISTORY_DEPID_SEQ sequence.
      EXECUTE IMMEDIATE   'CREATE SEQUENCE '
                       || V_USERNAME
                       || '.DEPHISTORY_DEPID_SEQ
                          START WITH 1
                          MAXVALUE 9999999999999999999999999999
                          MINVALUE 0
                          NOCYCLE
                          CACHE 20
                          NOORDER
                          NOKEEP
                          NOSCALE
                          GLOBAL';
    END IF;

    v_count := 0;

    SELECT COUNT (*)
      INTO v_count
      FROM all_objects
     WHERE     object_type = 'TABLE'
           AND object_name = 'DEPLOYMENT_HISTORY'
           AND OWNER = V_USERNAME;

    IF v_count = 0
    THEN
		/*The DEPLOYMENT_HISTORY table is utilized to manage scenarios where parallel deployment is required. In situations where multiple developers are making changes concurrently, 
		it is essential to deploy to separate editions that have been created for each developer. This approach helps to ensure a safe rollback can be initiated in the event 
		of an issue and prevents deployment complications.
		*/
      EXECUTE IMMEDIATE   'CREATE TABLE '
                       || V_USERNAME
                       || '.DEPLOYMENT_HISTORY
                            (
                              DEP_ID                  NUMBER DEFAULT '
                       || V_USERNAME
                       || '.DEPHISTORY_DEPID_SEQ.NEXTVAL  NOT NULL,
                              COMMIT_ID                VARCHAR2(100 BYTE)   NOT NULL,
                              EDITION_NAME             VARCHAR2(50 BYTE)    NOT NULL,
                              IS_DEPLOYMENT_COMPLETED  CHAR(1 BYTE)         DEFAULT ''N'',
                              DEPLOYMENT_ON            DATE                 DEFAULT SYSDATE               NOT NULL
                            )
                            TABLESPACE DATA01
                            PCTUSED    0
                            PCTFREE    10
                            INITRANS   1
                            MAXTRANS   255
                            STORAGE    (
                                  INITIAL          1M
                                  NEXT             1M
                                  MINEXTENTS       1
                                  MAXEXTENTS       UNLIMITED
                                  PCTINCREASE      0
                                  BUFFER_POOL      DEFAULT
                                   )
                            LOGGING 
                            NOCOMPRESS 
                            NOCACHE';

      EXECUTE IMMEDIATE   'ALTER TABLE '
                       || V_USERNAME
                       || '.DEPLOYMENT_HISTORY ADD (
                            PRIMARY KEY
                            (DEP_ID)
                            USING INDEX
                            TABLESPACE DATA01
                            PCTFREE    10
                            INITRANS   2
                            MAXTRANS   255
                            STORAGE    (
                                  PCTINCREASE      0
                                  BUFFER_POOL      DEFAULT
                                   )
                            ENABLE VALIDATE)';
    END IF;

	-- creating private synonym for AAPEN.DEPLOYMENT_HISTORY
    EXECUTE IMMEDIATE   'CREATE OR REPLACE SYNONYM AAPEN.DEPLOYMENT_HISTORY FOR '
                     || V_USERNAME
                     || '.DEPLOYMENT_HISTORY';

    EXECUTE IMMEDIATE   'CREATE OR REPLACE SYNONYM DISPORT.DEPLOYMENT_HISTORY FOR '
                     || V_USERNAME
                     || '.DEPLOYMENT_HISTORY';

    EXECUTE IMMEDIATE   'CREATE OR REPLACE SYNONYM GLOBAL.DEPLOYMENT_HISTORY FOR '
                     || V_USERNAME
                     || '.DEPLOYMENT_HISTORY';

	-- Granting select access for AAPEN.DEPLOYMENT_HISTORY
    EXECUTE IMMEDIATE   'GRANT SELECT ON '
                     || v_username
                     || '.DEPLOYMENT_HISTORY TO AAPEN';

    EXECUTE IMMEDIATE   'GRANT SELECT ON '
                     || v_username
                     || '.DEPLOYMENT_HISTORY TO GLOBAL';

    EXECUTE IMMEDIATE   'GRANT SELECT ON '
                     || v_username
                     || '.DEPLOYMENT_HISTORY TO DISPORT';

    DBMS_OUTPUT.PUT_LINE ('Executed successfully');
  END IF;
EXCEPTION
  WHEN OTHERS
  THEN
    DBMS_OUTPUT.PUT_LINE ('EBR deployment schema set up failed' || SQLERRM);
END;
/