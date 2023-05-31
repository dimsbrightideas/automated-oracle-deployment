--SET SERVEROUTPUT ON;
--SELECT PROPERTY_VALUE FROM DATABASE_PROPERTIES WHERE PROPERTY_NAME = 'DEFAULT_EDITION'
DECLARE
  V_USERSCHEMA   VARCHAR2 (500);
  V_ERROR_MSG    VARCHAR2 (4000);
BEGIN
  DBMS_OUTPUT.ENABLE;
  V_USERSCHEMA := USER;

  DBMS_OUTPUT.PUT_LINE ('Identified user ' || V_USERSCHEMA);

  IF (V_USERSCHEMA = 'GITHUB_DEPLOY_USER')
  THEN
    BEGIN
      OracleCICD.Set_Default_Edition('#{commitId}#');
      DBMS_OUTPUT.PUT_LINE ('Executed procedure successfully');
    EXCEPTION
      WHEN OTHERS
      THEN
        V_ERROR_MSG := 'An error occurred: ' || SQLERRM;
        DBMS_OUTPUT.PUT_LINE (V_ERROR_MSG);
        RAISE_APPLICATION_ERROR (-20001, V_ERROR_MSG);
    END;
  END IF;

END; 