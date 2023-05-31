TO DO:

1. Check for any DROP statements using a cut down version of the keyword scanning script and add it to the cd-dev.yml Flyway-Prepare.
2. If yes, then create and run script drop-statement-flag.sh, which will set the DROP_STATEMENTS output/variable to true. Similar to the table-deployment-flag.sh. It may be better to have the flag in the keyword-scanning.sh to reduce size of yml.
3. Update the Development - Tables environment to a better name e.g. Development - Approval
4. In cd-dev.yml update the needs. environment to match enviornment
5. Keep the current drop and table checks so that the PR for TEST and PROD still has those apporvers in place. good for audit and good becuase requires them to approve test and prd deployment.


line 39 for table checks in the file-versions.delta is a good template to follow for the keyword-scanning flag set. 
maybe after in same script set the output to yml as true using that flag

** Best thing to do is remove table check from file-versions-set-delta.sh and create a new script that does both table and keyword scanning checks on the schema sql folders. **
this will reduce size of file-versions-set-delta.sh and tidy the process up. also allows for additional checks later on.


Other things to consider

TABLE deployments and team coding issue.
If an oracle object is created using a script like we have for Tables using the dynamic if script, it does not create it in team coding. This is because toad handles team coding creation based on how it creates objects.

This is a problem because it is no obvious to users if multiple people are working on the same table. Find out if there is a way we can get our dynamic scripts to check in to team coding alongside saving to VCS. if not, a learning exercise is required to inform users of this. 

Basically check-in does not work for dynamic scripts. only works if create or drop or alter etc. seek help from toad forum maybe?
