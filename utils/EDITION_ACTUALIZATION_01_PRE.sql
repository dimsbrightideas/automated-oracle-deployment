
DECLARE
  v_edition_outside_limit   VARCHAR2 (1000);
  v_date_limit              NUMBER := 30;
  v_default_edition         VARCHAR2 (1000);
  v_edition                 VARCHAR2 (1000);
BEGIN
  BEGIN
    -- Fetch the EditionDropLimit value from the CONFIGURATION_SETTING table
    SELECT CONFIG_VALUE
      INTO v_date_limit
      FROM CONFIGURATION_SETTING
     WHERE CONFIG_KEY = 'EditionDropLimit';
  EXCEPTION
    WHEN NO_DATA_FOUND
    THEN
      v_date_limit := 30;
  END;

  IF v_date_limit IS NULL
  THEN
    v_date_limit := 30;
  END IF;

  BEGIN
    -- Get the default edition

    SELECT PROPERTY_VALUE
      INTO v_default_edition
      FROM DATABASE_PROPERTIES
     WHERE PROPERTY_NAME = 'DEFAULT_EDITION';

    -- Check if the default edition is within the limit
    SELECT OBJECT_NAME
      INTO v_edition
      FROM DBA_OBJECTS
     WHERE     OBJECT_TYPE = 'EDITION'
           AND OBJECT_NAME = v_default_edition
           AND TRUNC (CREATED) >= (TRUNC (SYSDATE) - v_date_limit);


    IF v_edition IS NOT NULL
    THEN
      SSSY.MSG (
        'Database default edition is within the limit, so skipping the latest active edition identification',
        SYS_CONTEXT( 'userenv', 'current_schema' )||'.'||'EDITION_ACTUALIZATION_01_PRE.sql',
        sssy.cElvlInfo);
      RETURN;
    END IF;

      --If the default edition is not within the limit, then find the latest active-edition that is outside the limit.
      SELECT UE.EDITION_NAME
        INTO v_edition_outside_limit
        FROM DBA_EDITIONS UE
             INNER JOIN DBA_OBJECTS AO
               ON     UE.EDITION_NAME = AO.OBJECT_NAME
                  AND AO.OBJECT_TYPE = 'EDITION'
       WHERE TRUNC (AO.CREATED) >= (TRUNC (SYSDATE) - v_date_limit)
    ORDER BY AO.CREATED
       FETCH FIRST 1 ROW ONLY;
  EXCEPTION
    WHEN NO_DATA_FOUND
    THEN
      v_edition_outside_limit := NULL;
      SSSY.MSG (
        'Edition not identified for altering session,Actualization should be done with database default edition',
        SYS_CONTEXT( 'userenv', 'current_schema' )||'.'||'EDITION_ACTUALIZATION_01_PRE.sql',
        sssy.cElvlInfo);
  END;

  IF (   v_edition_outside_limit IS NOT NULL
      OR TRIM (v_edition_outside_limit) != '')
  THEN
    SSSY.MSG (
      'Session altering identified edition :' || v_edition_outside_limit,
      SYS_CONTEXT( 'userenv', 'current_schema' )||'.'||'EDITION_ACTUALIZATION_01_PRE.sql',
      sssy.cElvlInfo);
    DBMS_SESSION.SET_EDITION_DEFERRED (v_edition_outside_limit);
    SSSY.MSG (
      'Session altering completed with edition :' || v_edition_outside_limit,
      SYS_CONTEXT( 'userenv', 'current_schema' )||'.'||'EDITION_ACTUALIZATION_01_PRE.sql',
      sssy.cElvlInfo);
  END IF;
EXCEPTION
  WHEN OTHERS
  THEN
    SSSY.MSG (
      'Session altering failed with edition' || v_edition_outside_limit,
      SYS_CONTEXT( 'userenv', 'current_schema' )||'.'||'EDITION_ACTUALIZATION_01_PRE.sql',
      sssy.cElvlError);
    RAISE_APPLICATION_ERROR (
      -20001,
         'Failed to set session edition. Please check the edition name '
      || v_edition_outside_limit
      || CHR (10)
      || SQLERRM);
END;