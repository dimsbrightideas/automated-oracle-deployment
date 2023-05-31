DECLARE
  V_USERSCHEMA   VARCHAR2 (500);
  V_ERROR_MSG    VARCHAR2 (4000);
BEGIN
  V_USERSCHEMA := USER;
  DBMS_OUTPUT.ENABLE;
  DBMS_OUTPUT.PUT_LINE ('Identified user ' || V_USERSCHEMA);

  IF (V_USERSCHEMA = 'GITHUB_DEPLOY_USER')
  THEN
    BEGIN
      EXECUTE IMMEDIATE   'BEGIN '
                       || V_USERSCHEMA
                       || '.OracleCICD.Revoke_Drop_Edition();END;';

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