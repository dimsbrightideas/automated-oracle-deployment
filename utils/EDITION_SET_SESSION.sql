--SELECT SYS_CONTEXT ('USERENV', 'SESSION_EDITION_NAME') FROM DUAL
-- Sets the current session's edition to be used as the deferred deployment edition.
DECLARE
  V_DEPLOYMENT_EDITION   NVARCHAR2 (100);
BEGIN
  BEGIN
    SELECT EDITION_NAME
      INTO V_DEPLOYMENT_EDITION
      FROM DEPLOYMENT_HISTORY DH
     WHERE DH.COMMIT_ID = '#{commitId}#' AND DH.IS_DEPLOYMENT_COMPLETED = 'N';
  EXCEPTION
    WHEN NO_DATA_FOUND
    THEN
      V_DEPLOYMENT_EDITION := NULL;
  END;

  IF (V_DEPLOYMENT_EDITION IS NOT NULL OR TRIM (V_DEPLOYMENT_EDITION) != '')
  THEN
    SSSY.MSG (
      'Altering session edition identified : ' || V_DEPLOYMENT_EDITION,
         SYS_CONTEXT ('userenv', 'current_schema')
      || '.'
      || 'EDITION_SET_SESSION.sql',
      sssy.cElvlInfo);

    DBMS_SESSION.SET_EDITION_DEFERRED (V_DEPLOYMENT_EDITION);
  ELSE
    RAISE_APPLICATION_ERROR (
      -20001,
      'The session edition could not be established. Please review the DEPLOYMENT_HISTORY table for the specified commit id: #{commitId}#.');
  END IF;
EXCEPTION
  WHEN OTHERS
  THEN
    RAISE_APPLICATION_ERROR (
      -20001,
         'Failed to set session edition. Please check the edition name '
      || V_DEPLOYMENT_EDITION
      || CHR (10)
      || SQLERRM);
END;