#!/bin/bash
# set schema password to be user
if [[ $SCHEMA == 'AAPEN' ]]; then
    echo "ORACLE_USER=AAPEN" >> $GITHUB_ENV
    echo "ORACLE_PASSWORD=${{ secrets.AAPEN_PASSWORD }}" >> $GITHUB_ENV

elif [[ $SCHEMA == 'DISPORT' ]]; then
    echo "ORACLE_USER=DISPORT" >> $GITHUB_ENV
    echo "ORACLE_PASSWORD=${{ secrets.DISPORT_PASSWORD }}" >> $GITHUB_ENV

elif [[ $SCHEMA == 'GLOBAL' ]]; then
    echo "ORACLE_USER=GLOBAL" >> $GITHUB_ENV
    echo "ORACLE_PASSWORD=${{ secrets.GLOBAL_PASSWORD }}" >> $GITHUB_ENV
else
    echo "ORACLE_USER=DEPLOY_USER" >> $GITHUB_ENV
    echo "ORACLE_PASSWORD=${{ secrets.DEPLOY_USER_PASSWORD }}" >> $GITHUB_ENV