CREATE OR REPLACE PACKAGE BODY LOGIFY
 AS


 PROCEDURE ERROR
    ( pMemo IN SS_ERRORLOG.DETAILS%TYPE DEFAULT NULL,
      pProcdure IN SS_ERRORLOG.PROCEDURE_NAME%TYPE DEFAULT LOGIFY.sProcedure,
      pErrorLevel IN SS_ERRORLOG.ERROR_NUMBER%TYPE DEFAULT cElvlError,
      pSlaveLog IN VARCHAR2 DEFAULT NULL,
      pSlaveID IN VARCHAR2 DEFAULT NULL
   )
  AS
  BEGIN

    IF SQLCODE=0 THEN
      -- Force a backtrace to be generated
      BEGIN
        RAISE_APPLICATION_ERROR(-20999,'SD forced backtrace');
      EXCEPTION
        WHEN OTHERS THEN
          LOGIFY.Msg(pMemo, pProcdure, pErrorLevel, SQLERRM, DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      END;
    ELSE
      LOGIFY.Msg(pMemo, pProcdure, pErrorLevel, SQLERRM, DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
    END IF;

  END ERROR;


  PROCEDURE Msg
    ( pMemo IN SS_ERRORLOG.DETAILS%TYPE,
      pProcdure IN SS_ERRORLOG.PROCEDURE_NAME%TYPE DEFAULT LOGIFY.sProcedure,
      pErrorLevel IN SS_ERRORLOG.ERROR_NUMBER%TYPE DEFAULT cElvlInfo,
      pErrorMessage IN SS_ERRORLOG.ERROR_MESSAGE%TYPE DEFAULT NULL,
      pBacktrace IN SS_ERRORLOG.BACKTRACE%TYPE DEFAULT NULL
    )
  AS
    PRAGMA AUTONOMOUS_TRANSACTION;
    
    vErrorMessage SS_ERRORLOG.ERROR_MESSAGE%TYPE;
 
  BEGIN

    vErrorMessage:=
      NVL
        ( SUBSTR(pErrorMessage,1,255),
          CASE pErrorLevel
            WHEN LOGIFY.cElvlNormal THEN 'Normal'
            WHEN LOGIFY.cElvlDebug9 THEN 'Debug9'
            WHEN LOGIFY.cElvlDebug8 THEN 'Debug8'
            WHEN LOGIFY.cElvlDebug7 THEN 'Debug7'
            WHEN LOGIFY.cElvlDebug6 THEN 'Debug6'
            WHEN LOGIFY.cElvlDebug5 THEN 'Debug5'
            WHEN LOGIFY.cElvlDebug4 THEN 'Debug4'
            WHEN LOGIFY.cElvlDebug3 THEN 'Debug3'
            WHEN LOGIFY.cElvlDebug2 THEN 'Debug2'
            WHEN LOGIFY.cElvlDebug1 THEN 'Debug1'
            WHEN LOGIFY.cElvlDebug THEN 'Debug'
            WHEN LOGIFY.cElvlInfo THEN 'Info'
            WHEN LOGIFY.cElvlWarning THEN 'Warning'
            WHEN LOGIFY.cElvlError THEN 'Error'
            WHEN LOGIFY.cElvlFatal THEN 'Fatal'
            WHEN LOGIFY.cElvlCatastrophic THEN 'Catastrophic'
          END
       );

    IF pErrorLevel>=LOGIFY.iReportLevel THEN
     
      INSERT INTO SS_ERRORLOG
      ( procedure_name, error_number, error_message, details, backtrace, sessionid,
        osuser
      )
      VALUES 
      ( SUBSTR(pProcdure,1,65), pErrorLevel, SUBSTR(vErrorMessage,1,255), SUBSTR(pMemo,1,255), SUBSTR(pBacktrace,1,1023), SYS_CONTEXT('USERENV','SESSIONID'),
        SUBSTR(NVL(SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER'),REPLACE(SYS_CONTEXT('USERENV','OS_USER'),'SPORTSKI\')),1,30)
      );
      COMMIT;
      
      DBMS_OUTPUT.PUT_LINE(TO_CHAR(SYSDATE,'DD/MM/YY HH24:MI:SS')||': '||pProcdure||': '||pMemo||': '||vErrorMessage);
    END IF;

    DBMS_APPLICATION_INFO.SET_MODULE('LOGIFY','GLOBAL.' || pProcdure);
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO(TO_CHAR(SYSDATE,'DD/MM/YY HH24:MI:SS')||': '||pMemo||': '||vErrorMessage);

  END Msg;

END LOGIFY;
/