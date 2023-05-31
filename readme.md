## Getting Started

This is a test repository to explore how to use flyway with the Oracle database.


1. Make change in TOAD & push to GitHub using GitHub Desktop.
2. CD pipeline triggered for DEV. 
3. DEV CD compares branch with origin/main and identifies and SQL objects that are different to main.
4. DEV CD updates SQL files to include a new version, commits to repository and prepares files for flyway deployments.
5. DEV CD is now using new updated feature branch with new SQL file versions and triggers Flyway deployments.
6. As soon as DEV is complete, TEST is triggered but not started. TEST requires an approver.
7. Once TEST is approved, the CD is triggered and flyway commands are executed with the latest code. TEST is using the same feature branch as DEV.
8. Once TEST is complete, a pull request is created for main. 
9. PR is approved and feature merged to main. 
10. This triggers the PROD CD. PROD requires an approver. 
11. Once approved the pipeline is deployed. 
