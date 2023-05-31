CREATE OR REPLACE PACKAGE BODY GITHUB_DEPLOY_USER.OracleCICD
AS
  PROCEDURE Compile_Invalid_Objects
  IS
    vInvalidcount        NUMBER;
    cProcName   CONSTANT SS_ERRORLOG.PROCEDURE_NAME%TYPE
                           := $$PLSQL_UNIT || '.Compile_Invalid_Objects' ;
  BEGIN
    BEGIN
      LOGIFY.Msg ('Invalid object compiling logic invoked',
                  cProcName,
                  LOGIFY.cElvlInfo);

      SELECT COUNT (*)
        INTO vInvalidcount
        FROM DBA_OBJECTS
       WHERE STATUS = 'INVALID' AND EDITION_NAME IS NOT NULL;

      IF vInvalidcount > 0
      THEN
        LOGIFY.Msg ('Invalid object compiling started',
                    cProcName,
                    LOGIFY.cElvlInfo);
        UTL_RECOMP.RECOMP_PARALLEL (4, 'AAPEN');
        UTL_RECOMP.RECOMP_PARALLEL (4, 'GLOBAL');
        UTL_RECOMP.RECOMP_PARALLEL (4, 'DISPORT');
      END IF;

      LOGIFY.Msg ('invalid object compiling completed',
                  cProcName,
                  LOGIFY.cElvlInfo);
    EXCEPTION
      WHEN OTHERS
      THEN
        LOGIFY.Msg (
          'An error has occurred in invalid object compile process ',
          cProcName,
          LOGIFY.cElvlError,
          SQLERRM);
        DBMS_OUTPUT.PUT_LINE (
             'An error has occurred in invalid object compile process '
          || SQLERRM);
        RAISE_APPLICATION_ERROR (
          -20001,
             'An error has occurred in invalid object compile process:'
          || CHR (10)
          || SQLERRM);
    END;
  END Compile_Invalid_Objects;


  PROCEDURE Create_Publish_Edition (pCommitId IN VARCHAR2)
  IS
    lEditionName         VARCHAR2 (100);
    lExists              NUMBER := 0;
    cProcName   CONSTANT SS_ERRORLOG.PROCEDURE_NAME%TYPE
                           := $$PLSQL_UNIT || '.Create_Publish_Edition' ;
  BEGIN
    BEGIN
      IF (   NULLIF (TRIM (pCommitId), '') IS NULL
          OR TRIM (pCommitId) = '#{commitId}#')
      THEN
        LOGIFY.Msg (
          'An error has occurred while invoking create edition.Commit id missing ',
          cProcName,
          LOGIFY.cElvlError,
          SQLERRM);

        RAISE_APPLICATION_ERROR (
          -20001,
             'An error has occurred while invoking create edition.Commit Id passed : '
          || pCommitId);
      END IF;

      LOGIFY.Msg (
           'Edition creation & access granting started with pCommitId as '
        || pCommitId,
        cProcName,
        LOGIFY.cElvlInfo);

      SELECT 'E_' || GITHUB_DEPLOY_USER.SEQ_EDITION.NEXTVAL
        INTO lEditionName
        FROM DUAL;

      SELECT COUNT (1)
        INTO lExists
        FROM all_editions
       WHERE edition_name = lEditionName;

      WHILE lExists > 0
      LOOP
        SELECT 'E_' || GITHUB_DEPLOY_USER.SEQ_EDITION.NEXTVAL
          INTO lEditionName
          FROM DUAL;

        SELECT COUNT (1)
          INTO lExists
          FROM all_editions
         WHERE edition_name = lEditionName;
      END LOOP;

      EXECUTE IMMEDIATE 'CREATE EDITION ' || lEditionName;

      EXECUTE IMMEDIATE   'GRANT USE ON EDITION '
                       || lEditionName
                       || ' TO AAPEN';

      EXECUTE IMMEDIATE   'GRANT USE ON EDITION '
                       || lEditionName
                       || ' TO GLOBAL';

      EXECUTE IMMEDIATE   'GRANT USE ON EDITION '
                       || lEditionName
                       || ' TO DISPORT';

      --to do insert into lookup table
      lExists := 0;

      SELECT COUNT (1)
        INTO lExists
        FROM DEPLOYMENT_HISTORY
       WHERE COMMIT_ID = pCommitId;

      -- below use case added to handle failed deployment/reruns
      IF (lExists > 0)
      THEN
        UPDATE DEPLOYMENT_HISTORY
           SET IS_DEPLOYMENT_COMPLETED = 'Y'
         WHERE COMMIT_ID = pCommitId;

        INSERT INTO DEPLOYMENT_HISTORY (COMMIT_ID, EDITION_NAME)
          SELECT pCommitId, lEditionName FROM DUAL;
      ELSIF (lExists = 0)
      THEN
        INSERT INTO DEPLOYMENT_HISTORY (COMMIT_ID, EDITION_NAME)
          SELECT pCommitId, lEditionName FROM DUAL;
      END IF;

      COMMIT;
      DBMS_OUTPUT.Put_line (
        'Edition ' || lEditionName || ' created and published successfully.');
      LOGIFY.Msg ('Edition creation & access granting completed',
                  cProcName,
                  LOGIFY.cElvlInfo);
    EXCEPTION
      WHEN OTHERS
      THEN
        DBMS_OUTPUT.PUT_LINE (
          'An error has occurred in publish edition: ' || SQLERRM);
        LOGIFY.Msg (
          'An error has occurred in edition creation & access granting logic ',
          cProcName,
          LOGIFY.cElvlError,
          SQLERRM);
        RAISE;
    END;
  END Create_Publish_Edition;

  PROCEDURE Set_Default_Edition (pCommitId IN VARCHAR2)
  IS
    lEditionName         VARCHAR2 (100);
    cProcName   CONSTANT SS_ERRORLOG.PROCEDURE_NAME%TYPE
                           := $$PLSQL_UNIT || '.Set_Default_Edition' ;
  BEGIN
    IF (   NULLIF (TRIM (pCommitId), '') IS NULL
        OR TRIM (pCommitId) = '#{commitId}#')
    THEN
      LOGIFY.Msg (
        'An error has occurred while invoking setting default edition. Commit id missing ',
        cProcName,
        LOGIFY.cElvlError,
        SQLERRM);

      RAISE_APPLICATION_ERROR (
        -20001,
           'An error has occurred while invoking setting default edition. Commit id passed :  '
        || pCommitId);
    END IF;

    LOGIFY.Msg (
      'Database default edition altering started with CommitId:' || pCommitId,
      cProcName,
      LOGIFY.cElvlInfo);

    UPDATE DEPLOYMENT_HISTORY
       SET IS_DEPLOYMENT_COMPLETED = 'Y'
     WHERE COMMIT_ID = pCommitId;

    COMMIT;

    BEGIN
          SELECT AE.EDITION_NAME
            INTO lEditionName
            FROM ALL_EDITIONS AE
           WHERE     AE.USABLE = 'YES'
                 AND EXISTS
                       (SELECT 1
                          FROM DEPLOYMENT_HISTORY DH
                         WHERE     AE.EDITION_NAME = DH.EDITION_NAME
                               AND DH.IS_DEPLOYMENT_COMPLETED = 'Y')
      START WITH AE.PARENT_EDITION_NAME IS NULL
      CONNECT BY AE.PARENT_EDITION_NAME = PRIOR AE.EDITION_NAME
        ORDER BY LEVEL DESC
           FETCH FIRST ROW ONLY;
    EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
        lEditionName := NULL;
    END;

    IF NULLIF (TRIM (lEditionName), '') IS NOT NULL
    THEN
      EXECUTE IMMEDIATE 'ALTER DATABASE DEFAULT EDITION = ' || lEditionName;

      DBMS_OUTPUT.Put_line (
        'Edition ' || lEditionName || ' set as default edition');

      LOGIFY.Msg ('Edition ' || lEditionName || ' set as default edition',
                  cProcName,
                  LOGIFY.cElvlInfo);
    END IF;
  EXCEPTION
    WHEN OTHERS
    THEN
      LOGIFY.Msg (
        'An error has occurred in setting default edition: ' || lEditionName,
        cProcName,
        LOGIFY.cElvlError,
        SQLERRM);
      DBMS_OUTPUT.PUT_LINE (
        'An error has occurred in setting default edition: ' || SQLERRM);
      RAISE;
  END Set_Default_Edition;

  PROCEDURE Revoke_Drop_Edition
  IS
    lDateLimit           		NUMBER;
	lDefaultEditionCreatedOn  	DATE;

    CURSOR c_editions IS
        SELECT UE.EDITION_NAME
          FROM DBA_EDITIONS UE
               INNER JOIN DBA_OBJECTS AO
                 ON     UE.EDITION_NAME = AO.OBJECT_NAME
                    AND AO.OBJECT_TYPE = 'EDITION'
                    AND UE.USABLE = 'YES'
                    AND UE.EDITION_NAME <>
                        (SELECT SYS_CONTEXT ('USERENV', 'SESSION_EDITION_NAME')
                           FROM DUAL)
                    AND TRUNC (AO.CREATED) <= (TRUNC (SYSDATE) - lDateLimit)
					AND AO.CREATED < lDefaultEditionCreatedOn
      ORDER BY AO.CREATED ASC;

    CURSOR C_PRIVILEGE (edition_name VARCHAR2)
    IS
      SELECT GRANTEE
        FROM SYS.DBA_TAB_PRIVS
       WHERE     TABLE_NAME = edition_name
             AND PRIVILEGE = 'USE'
             AND GRANTEE != USER
             AND GRANTOR = USER;

    V_EDITION_NAME       VARCHAR2 (200);
    V_GRANTEE_NAME       VARCHAR2 (200);
    V_OBJECT_COUNT       NUMBER;
    cProcName   CONSTANT SS_ERRORLOG.PROCEDURE_NAME%TYPE
                           := $$PLSQL_UNIT || '.Revoke_Drop_Edition' ;
  BEGIN
    BEGIN
      SELECT CONFIG_VALUE
        INTO lDateLimit
        FROM CONFIGURATION_SETTING
       WHERE CONFIG_KEY = 'EditionDropLimit';
    EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
        lDateLimit := 30;
    END;

    IF lDateLimit IS NULL
    THEN
      lDateLimit := 30;
    END IF;
	
	SELECT AO.CREATED  
	INTO lDefaultEditionCreatedOn
    FROM DBA_OBJECTS AO
   WHERE     AO.OBJECT_TYPE = 'EDITION'
         AND AO.OBJECT_NAME = (SELECT PROPERTY_VALUE
                                 FROM DATABASE_PROPERTIES
                                WHERE PROPERTY_NAME = 'DEFAULT_EDITION');

    SELECT COUNT (1)
      INTO V_OBJECT_COUNT
      FROM DBA_OBJECTS  UO
           INNER JOIN
           (        -- Actualization should applied to drop applicable objects
            SELECT UE.EDITION_NAME, AO.CREATED
              FROM DBA_EDITIONS  UE
                   INNER JOIN DBA_OBJECTS AO
                     ON     UE.EDITION_NAME = AO.OBJECT_NAME
                        AND AO.OBJECT_TYPE = 'EDITION'
             WHERE TRUNC (AO.CREATED) <= (TRUNC (SYSDATE) - lDateLimit)) AE
             ON AE.EDITION_NAME = UO.EDITION_NAME
     WHERE     UO.EDITION_NAME !=
               SYS_CONTEXT ('USERENV', 'SESSION_EDITION_NAME')
           AND UO.OBJECT_TYPE NOT LIKE '%BODY';

    IF (V_OBJECT_COUNT = 0)
    THEN
      LOGIFY.Msg ('Revoke logic started ', cProcName, LOGIFY.cElvlInfo);

      FOR edition_rec IN c_editions
      LOOP
        V_EDITION_NAME := edition_rec.edition_name;

        BEGIN
          FOR GRANTEE_REC IN C_PRIVILEGE (V_EDITION_NAME)
          LOOP
            V_GRANTEE_NAME := GRANTEE_REC.GRANTEE;

            BEGIN
              EXECUTE IMMEDIATE   'REVOKE USE ON EDITION '
                               || V_EDITION_NAME
                               || ' FROM '
                               || V_GRANTEE_NAME;
            EXCEPTION
              WHEN OTHERS
              THEN
                DBMS_OUTPUT.PUT_LINE (
                  'Error while revoking edition - ' || V_GRANTEE_NAME);

                LOGIFY.Msg (
                  'Error while revoking edition - ' || V_GRANTEE_NAME,
                  cProcName,
                  LOGIFY.cElvlError,
                  SQLERRM);

                RAISE_APPLICATION_ERROR (
                  -20001,
                     'Error while revoking edition - '
                  || V_GRANTEE_NAME
                  || CHR (10)
                  || SQLERRM);
            END;
          END LOOP;

          LOGIFY.Msg ('Edition ' || V_EDITION_NAME || ' going to drop',
                      cProcName,
                      LOGIFY.cElvlInfo);

          EXECUTE IMMEDIATE 'DROP EDITION ' || V_EDITION_NAME || ' CASCADE';

          DBMS_OUTPUT.PUT_LINE ('Edition ' || V_EDITION_NAME || ' dropped');
          LOGIFY.Msg ('Edition ' || V_EDITION_NAME || ' dropped',
                      cProcName,
                      LOGIFY.cElvlInfo);
        EXCEPTION
          WHEN OTHERS
          THEN
            IF SQLCODE = -38805
            THEN
              LOGIFY.Msg (
                'Edition : ' || V_EDITION_NAME || ' in use exception',
                cProcName,
                LOGIFY.cElvlError,
                SQLERRM);

              DBMS_OUTPUT.PUT_LINE (
                   'Edition : '
                || V_EDITION_NAME
                || ' in use exception'
                || ': '
                || SQLERRM);

              EXECUTE IMMEDIATE   'GRANT USE ON EDITION '
                               || V_EDITION_NAME
                               || ' TO AAPEN';

              EXECUTE IMMEDIATE   'GRANT USE ON EDITION '
                               || V_EDITION_NAME
                               || ' TO GLOBAL';

              EXECUTE IMMEDIATE   'GRANT USE ON EDITION '
                               || V_EDITION_NAME
                               || ' TO DISPORT';

              EXIT;
            ELSE
              LOGIFY.Msg (
                   'Unexpected error occured while executing edition drop,Edition Name : '
                || V_EDITION_NAME,
                cProcName,
                LOGIFY.cElvlError,
                SQLERRM);
              RAISE_APPLICATION_ERROR (
                -20001,
                   'Unexpected error occured while executing edition drop,Edition Name : '
                || V_EDITION_NAME
                || CHR (10)
                || SQLERRM);
            END IF;
        END;
      END LOOP;

      LOGIFY.Msg ('Edition revoke and drop logic completed ',
                  cProcName,
                  LOGIFY.cElvlInfo);
    ELSE
      DBMS_OUTPUT.PUT_LINE (
        'The edition drop has been skipped as there are inherited objects with pending actualization. To proceed with the edition drop, please recompile the objects.');
      RAISE_APPLICATION_ERROR (
        -20001,
        'The edition drop has been skipped as there are inherited objects with pending actualization. To proceed with the edition drop, please recompile the objects.');
    END IF;

    --Built in clean up logic invoked to initiate permananent edition clean up
    DBMS_EDITIONS_UTILITIES.CLEAN_UNUSABLE_EDITIONS;
    DBMS_OUTPUT.PUT_LINE ('Edition clean up invoked');
  END Revoke_Drop_Edition;


  PROCEDURE Check_Invalid_Objects
  IS
    vInvalidCount        NUMBER;
    vErrMsg              CLOB := '';
    cProcName   CONSTANT SS_ERRORLOG.PROCEDURE_NAME%TYPE
                           := $$PLSQL_UNIT || '.Check_Invalid_Objects' ;
  BEGIN
    SELECT COUNT (*)
      INTO vInvalidCount
      FROM DBA_OBJECTS
     WHERE     STATUS = 'INVALID'
           AND EDITION_NAME IS NOT NULL
           AND EDITION_NAME <> (SELECT PROPERTY_VALUE
                                  FROM DATABASE_PROPERTIES
                                 WHERE PROPERTY_NAME = 'DEFAULT_EDITION')
           AND EDITION_NAME <>
               (SELECT SYS_CONTEXT ('USERENV', 'SESSION_EDITION_NAME')
                  FROM DUAL);

    IF vInvalidCount >= 50
    THEN
      LOGIFY.Msg ('Invalid objects identified',
                  cProcName,
                  LOGIFY.cElvlError,
                  SQLERRM);
      RAISE_APPLICATION_ERROR (
        -20001,
        'It is recommended to perform a schema compile for editioned schemas due to the presence of invalid objects.');
    ELSIF (vInvalidCount > 0 AND vInvalidCount < 50)
    THEN
      FOR C IN (SELECT OWNER,
                       OBJECT_NAME,
                       OBJECT_TYPE,
                       STATUS,
                       EDITION_NAME
                  FROM DBA_OBJECTS
                 WHERE STATUS = 'INVALID' AND EDITION_NAME IS NOT NULL)
      LOOP
        vErrMsg :=
             vErrMsg
          || C.OWNER
          || '.'
          || C.OBJECT_NAME
          || ' ('
          || C.OBJECT_TYPE
          || ') - '
          || 'invalid '
          || ' in edition '
          || C.EDITION_NAME
          || CHR (10);
      END LOOP;

      LOGIFY.Msg ('Invalid objects exists',
                  cProcName,
                  LOGIFY.cElvlError,
                  SQLERRM);
      RAISE_APPLICATION_ERROR (
        -20001,
           'There are invalid objects in editioned schemas:'
        || CHR (10)
        || vErrMsg);
    END IF;
  END Check_Invalid_Objects;

  PROCEDURE Set_Edition_Outside_Limit
  IS
    vEditionOutsideLimit   VARCHAR2 (1000);
    vDateLimit             NUMBER := 30;
    cProcName     CONSTANT SS_ERRORLOG.PROCEDURE_NAME%TYPE
                             := $$PLSQL_UNIT || '.Set_Edition_Outside_Limit' ;
  BEGIN
    DBMS_OUTPUT.put_line (
         'Current session edition before invoking Set_Edition_Outside_Limit sp: '
      || SYS_CONTEXT ('USERENV', 'SESSION_EDITION_NAME'));

    -- Fetch the EditionDropLimit value from the CONFIGURATION_SETTING table
    SELECT CONFIG_VALUE
      INTO vDateLimit
      FROM CONFIGURATION_SETTING
     WHERE CONFIG_KEY = 'EditionDropLimit';

    IF vDateLimit IS NULL OR vDateLimit = ''
    THEN
      vDateLimit := 30;
    END IF;

      SELECT UE.EDITION_NAME
        INTO vEditionOutsideLimit
        FROM DBA_EDITIONS UE
             INNER JOIN DBA_OBJECTS AO
               ON     UE.EDITION_NAME = AO.OBJECT_NAME
                  AND AO.OBJECT_TYPE = 'EDITION'
       WHERE TRUNC (AO.CREATED) >= (TRUNC (SYSDATE) - vDateLimit)
    ORDER BY AO.CREATED
       FETCH FIRST 1 ROW ONLY;

    LOGIFY.MSG (
      'Session altering identified edition :' || vEditionOutsideLimit,
      'EDITION_ACTUALIZATION_01_PRE.sql',
      LOGIFY.cElvlInfo);

    IF (vEditionOutsideLimit IS NOT NULL OR TRIM (vEditionOutsideLimit) != '')
    THEN
      DBMS_SESSION.SET_EDITION_DEFERRED (vEditionOutsideLimit);
      LOGIFY.MSG (
        'Session altering completed with edition :' || vEditionOutsideLimit,
        'EDITION_ACTUALIZATION_01_PRE.sql',
        LOGIFY.cElvlInfo);
    END IF;

    DBMS_OUTPUT.put_line (
         'Current session edition after invoking Set_Edition_Outside_Limit sp: '
      || SYS_CONTEXT ('USERENV', 'SESSION_EDITION_NAME'));
  EXCEPTION
    WHEN OTHERS
    THEN
      LOGIFY.MSG (
        'Session altering failed with edition' || vEditionOutsideLimit,
        'EDITION_ACTUALIZATION_01_PRE.sql',
        LOGIFY.cElvlInfo);
      RAISE_APPLICATION_ERROR (
        -20001,
           'Failed to set session edition. Please check the edition name '
        || vEditionOutsideLimit
        || CHR (10)
        || SQLERRM);
  END Set_Edition_Outside_Limit;
END OracleCICD;
/