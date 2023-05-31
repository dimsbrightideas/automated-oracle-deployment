SHELL=/bin/bash
# Coloured Text \
 there are no colours here

# Ensure the RUNTIME_ENV variable is set. This is used to: \
Determine whether to run commands locally, in container or in pipeline
RUNTIME_ENV_OPTS := local container
ifneq ($(filter $(RUNTIME_ENV),$(RUNTIME_ENV_OPTS)),)
    $(info $(yellow)Runtime Environment: $(RUNTIME_ENV)$(reset))
else
    $(error $(red)Variable RUNTIME_ENV is not set to one of the following: $(RUNTIME_ENV_OPTS)$(reset))
endif

# My phony commands. Be wary...
.PHONY: help
help:	## Displays the help
	@printf "\nUsage : make <command> \n\nThe following commands are available: \n\n"
	@egrep '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@printf "\n"

.PHONY: docker-build
docker-build:	## Builds the docker image
	docker-compose -f docker/docker-compose.yml build

.PHONY: docker-stop
docker-stop:	## Stops and Remove the docker container
	docker-compose -f docker/docker-compose.yml stop ${IMAGE}
	docker rm ${IMAGE}

.PHONY: docker-restart
docker-restart: stop start	## Restart the docker container

.PHONY: docker-exec
docker-exec: docker-start	## Runs the docker container
	docker exec -it ${IMAGE} bash

.PHONY: flyway-baseline
flyway-baseline:	## Runs the flyway baseline command
ifeq ($(strip $(RUNTIME_ENV)),local)
	flyway -configFiles=${FLYWAY_CONF_PATH}/flyway.conf -connectRetries=60 baseline
else ifeq ($(strip $(RUNTIME_ENV)),container)
	docker-compose -f docker/docker-compose.yml up -d baseline
endif

.PHONY: flyway-info
flyway-info:	## Runs the flyway info command
ifeq ($(strip $(RUNTIME_ENV)),local)
	flyway -configFiles=${FLYWAY_CONF_PATH}/flyway.conf -connectRetries=60 info
else ifeq ($(strip $(RUNTIME_ENV)),container)
	docker-compose -f docker/docker-compose.yml up -d info
endif

.PHONY: flyway-validate
flyway-validate:	## Runs the flyway validate command
ifeq ($(strip $(RUNTIME_ENV)),local)
	flyway -configFiles=${FLYWAY_CONF_PATH}/flyway.conf -connectRetries=60 validate
else ifeq ($(strip $(RUNTIME_ENV)),container)
	docker-compose -f docker/docker-compose.yml up -d validate
endif

.PHONY: flyway-repair
flyway-repair:	## Runs the flyway repair command
ifeq ($(strip $(RUNTIME_ENV)),local)
	flyway -configFiles=${FLYWAY_CONF_PATH}/flyway.conf -connectRetries=60 repair
else ifeq ($(strip $(RUNTIME_ENV)),container)
	docker-compose -f docker/docker-compose.yml up -d repair
endif

.PHONY: flyway-migrate
flyway-migrate:	## Runs  the flyway migrate command
ifeq ($(strip $(RUNTIME_ENV)),local)
	flyway -configFiles=${FLYWAY_CONF_PATH}/flyway.conf -connectRetries=60 migrate
else ifeq ($(strip $(RUNTIME_ENV)),container)
	docker-compose -f docker/docker-compose.yml up -d migrate
endif

.PHONY: flyway-clean
flyway-clean:	## Runs the flyway clean command
ifeq ($(strip $(RUNTIME_ENV)),local)
	flyway -configFiles=${FLYWAY_CONF_PATH}/flyway.conf -connectRetries=60 clean
else ifeq ($(strip $(RUNTIME_ENV)),container)
	docker-compose -f docker/docker-compose.yml up -d clean
endif

.PHONY: flyway-deploy
flyway-deploy:	## Runs the flyway deployment script
ifeq ($(strip $(RUNTIME_ENV)),local)
	scripts/flyway.sh flyway_deploy
else ifeq ($(strip $(RUNTIME_ENV)),container)
	docker-compose -f docker/docker-compose.yml up -d flyway-deploy
endif

.PHONY: pull-request
pull-request:	## Runs the create pull request script
	scripts/pull-request.sh

.PHONY: get-schema-credentials
get-schema-credentials:	## Runs the get schema credentials script
	scripts/get-schema-credentials.sh

.PHONY: download-artifacts
download-artifacts:	## Runs the download-artifacts script
	scripts/download-artifacts.sh

.PHONY: add-labels
add-labels:	## Runs the add-labels script
	scripts/add-labels.sh

.PHONY: remove-workflow
remove-workflow:	## Runs the remove-workflow script
	scripts/remove-workflow.sh

.PHONY: table-deployment-flag
table-deployment-flag:	## Runs the table-deployment-flag script
	scripts/table-deployment-flag.sh