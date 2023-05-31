CREATE OR REPLACE PACKAGE OracleCICD
  AUTHID CURRENT_USER
  --AUTHID DEFINER
AS
  /******************************************************************************
     NAME:       OracleCICD
     PURPOSE:

     REVISIONS:
     Ver        Date        Author           Description
     ---------  ----------  ---------------  ------------------------------------
     1.0        14/03/2023  Eldhose Paul       1. Created this package.
  ******************************************************************************/
  

  PROCEDURE Create_Publish_Edition (pCommitId IN  VARCHAR2);

  PROCEDURE Set_Default_Edition (pCommitId  IN  VARCHAR2);

  PROCEDURE Revoke_Drop_Edition;

  PROCEDURE Check_Invalid_Objects;

  PROCEDURE Compile_Invalid_Objects;
  
  PROCEDURE Set_Edition_Outside_Limit;
  
END OracleCICD;
/