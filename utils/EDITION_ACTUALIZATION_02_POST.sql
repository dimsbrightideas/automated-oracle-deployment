DECLARE
  v_stmt           				VARCHAR2 (2000);
  v_object_type    				VARCHAR2 (200);
  v_object_owner   				VARCHAR2 (200);
  v_object_name    				VARCHAR2 (1000);
  v_date_limit     				NUMBER := 30;
  v_default_edition_created_on  DATE;

  CURSOR c_editions IS
      SELECT USER   AS OWNER,
             UO.OBJECT_NAME,
             UO.OBJECT_TYPE,
             UO.EDITION_NAME,
             AE.CREATED
        FROM SYS.user_objects UO
             INNER JOIN
             (      -- Actualization should applied to drop applicable objects
              SELECT UE.EDITION_NAME, AO.CREATED
                FROM DBA_EDITIONS UE
                     INNER JOIN DBA_OBJECTS AO
                       ON     UE.EDITION_NAME = AO.OBJECT_NAME
                          AND AO.OBJECT_TYPE = 'EDITION'
						  -- date limit applicable record filtering
               WHERE TRUNC (AO.CREATED) <= (TRUNC (SYSDATE) - v_date_limit) 
			    -- The default edition should not be dropped even if it falls within the date range for dropping editions
			    AND AO.CREATED < v_default_edition_created_on
				) AE 
               ON AE.EDITION_NAME = UO.EDITION_NAME
       WHERE     UO.EDITION_NAME !=
                 SYS_CONTEXT ('USERENV', 'SESSION_EDITION_NAME')
             AND UO.OBJECT_TYPE NOT LIKE '%BODY'
    ORDER BY CASE
               WHEN OBJECT_TYPE = 'TYPE' THEN 1
               WHEN OBJECT_TYPE = 'LIBRARY' THEN 2
               WHEN OBJECT_TYPE = 'SYNONYM' THEN 3
               WHEN OBJECT_TYPE = 'VIEW' THEN 4
               WHEN OBJECT_TYPE = 'FUNCTION' THEN 5
               WHEN OBJECT_TYPE = 'PROCEDURE' THEN 6
               WHEN OBJECT_TYPE = 'PACKAGE' THEN 7
               WHEN OBJECT_TYPE = 'TRIGGER' THEN 8
             END;
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
  
   SELECT AO.CREATED  
	INTO v_default_edition_created_on
    FROM DBA_OBJECTS AO
   WHERE     AO.OBJECT_TYPE = 'EDITION'
         AND AO.OBJECT_NAME = (SELECT PROPERTY_VALUE
                                 FROM DATABASE_PROPERTIES
                                WHERE PROPERTY_NAME = 'DEFAULT_EDITION');

  DBMS_OUTPUT.put_line (
       'Current session edition: '
    || SYS_CONTEXT ('USERENV', 'SESSION_EDITION_NAME'));

  FOR edition_rec IN c_editions
  LOOP
    v_object_type := edition_rec.OBJECT_TYPE;
    v_object_owner := edition_rec.OWNER;
    v_object_name := edition_rec.OBJECT_NAME;

    BEGIN
      v_stmt :=
           'ALTER '
        || v_object_type
        || ' '
        || v_object_owner
        || '.'
        || '"'
        || v_object_name
        || '"'
        || ' COMPILE'
        || CASE
             WHEN v_object_type IN ('FUNCTION',
                                    'PACKAGE',
                                    'PROCEDURE',
                                    'LIBRARY',
                                    'TYPE',
                                    'TRIGGER')
             THEN
               ' REUSE SETTINGS'
           END;

      EXECUTE IMMEDIATE v_stmt;
    EXCEPTION
      WHEN OTHERS
      THEN
        DBMS_OUTPUT.put_line (v_stmt);
        DBMS_OUTPUT.put_line (SQLERRM);
        CONTINUE;
    END;
  END LOOP;

  DBMS_OUTPUT.Put_line ('Edition objects recompiled successfully.');
END;