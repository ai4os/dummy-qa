#!/usr/bin/groovy

// function to remove built images
def docker_clean() {
    def dangling_images = sh(
		returnStdout: true,
		script: "docker images -f 'dangling=true' -q"
	)
    if (dangling_images) {
        sh(script: "docker rmi --force $dangling_images")
    }
}


pipeline {
    agent {
        label 'docker'
    }
    environment {
        // Remove .git from the GIT_URL link and extract REPO_NAME from GIT_URL
        REPO_URL = "${env.GIT_URL.endsWith(".git") ? env.GIT_URL[0..-5] : env.GIT_URL}"
        REPO_NAME = "${REPO_URL.tokenize('/')[-1]}"
        TOOLS_CATALOG_URL = "https://raw.githubusercontent.com/ai4os/tools-catalog/master/.gitmodules"
        TOOLS = sh (returnStdout: true, script: "curl -s ${TOOLS_CATALOG_URL}").trim()
        METADATA_VERSION = "2.0.0"
        AI4OS_REGISTRY_CREDENTIALS = credentials('AIOS-registry-credentials')
    }
    stages {
        stage("Variable initialization") {
            steps {
                script {
                    checkout scm
                    withFolderProperties{
                        env.DOCKER_REGISTRY = env.AI4OS_REGISTRY
                        env.DOCKER_REGISTRY_ORG = env.AI4OS_REGISTRY_REPOSITORY
                        env.DOCKER_REGISTRY_CREDENTIALS = env.AI4OS_REGISTRY_CREDENTIALS
                    }
                    // docker repository
                    env.DOCKER_REPO = env.DOCKER_REGISTRY_ORG + "/" + env.REPO_NAME
                    // define base tag from branch name
                    env.IMAGE_TAG = "${env.BRANCH_NAME == 'main' ? 'latest' : env.BRANCH_NAME}"

                }
            }
        }

        stage('AI4OS Hub metadata V2 validation (YAML)') {
            when {
                // Check if ai4-metadata.yml is present in the repository
                expression {fileExists("ai4-metadata.yml")}
            }
            agent {
                docker {
                    image 'ai4oshub/ci-images:python3.12'
                }
            }
            steps {
                script {
                    if (!fileExists("ai4-metadata.yml")) {
                        error("ai4-metadata.yml file not found in the repository")
                    }
                    if (fileExists("ai4-metadata.json")) {
                        error("Both ai4-metadata.json and ai4-metadata.yml files found in the repository")
                    }
                }
                script {
                    sh "ai4-metadata validate --metadata-version ${env.METADATA_VERSION} ai4-metadata.yml"
                }
            }
        }
        stage("License validation") {
            steps {
                script {
                    // Check if LICENSE file is present in the repository
                    if (!fileExists("LICENSE")) {
                        error("LICENSE file not found in the repository")
                    }
                }
            }
        }

        stage("Check if only metadata files have changed") {
            steps {
                script {
                    // Check if only metadata files have been changed
                    // See https://github.com/ai4os/ai4os-hub-qa/issues/16
                    // If GIT_PREVIOUS_SUCCESSFUL_COMMIT fails
                    // (e.g. First time build, commits were rewritten by user),
                    // we fallback to last commit
                    try {
                        changed_files = sh (returnStdout: true, script: "git diff --name-only HEAD ${env.GIT_PREVIOUS_SUCCESSFUL_COMMIT}").trim()
                    } catch (err) {
                        println("[WARNING] Exception: ${err}")
                        println("[INFO] Considering changes only in the last commit..")
                        changed_files = sh (returnStdout: true, script: "git diff --name-only HEAD^ HEAD").trim()
                    }
                    need_build = true

                    // Check if metadata files are present in the list of changed files
                    if (changed_files.contains("ai4-metadata.yml")) {
                        // Convert to an array and pop items
                        changed_files = changed_files.tokenize()
                        changed_files.removeAll(["metadata.json", "ai4-metadata.json", "ai4-metadata.yml"])
                        // now check if the list is empty
                        if (changed_files.size() == 0) {
                            need_build = false
                        }
                    }
                }
            }
        }

        stage("Docker build and push") {
            when {
                expression {env.TOOLS.contains(env.REPO_URL)}
                anyOf {
                    branch 'main'
                    branch 'release/*'
                    buildingTag()
                }
                anyOf {
                    expression {need_build}
                    triggeredBy 'UserIdCause'
                }
            }
            steps {
                script {
                    checkout scm
                    dockerfile = "Dockerfile"
                    image_tag = env.IMAGE_TAG
                    image = (env.DOCKER_REPO + ":" + image_tag).toLowerCase()
                    println ("[DEBUG] Config for the Docker image build: ${image}, push to $env.DOCKER_REGISTRY")
                    docker.withRegistry(env.DOCKER_REGISTRY, env.DOCKER_REGISTRY_CREDENTIALS){
                         def app_image = docker.build(image,
                                                      "--no-cache --force-rm -f ${dockerfile} .")
                         app_image.push()
                    }
                }
            }
            post {
                failure {
                    docker_clean()
                }
            }
        }

        stage("Updating catalog page") {
            when {
                //expression {env.TOOLS.contains(env.REPO_URL)}
                anyOf {
                    branch 'main'
                    branch 'master'
                    branch 'release/*'
                    triggeredBy 'UserIdCause'
                }
            }
            steps {
                script {
                    //PAPI_URL = env.AI4OS_PAPI_URL
                    TOKEN = "asdfghjk"
                    CURL_CALL = "curl -si -X PUT https://api.dev.ai4eosc.eu/v1/catalog/tools/${env.REPO_NAME}/refresh -H 'accept: application/json' -H 'Authorization: Bearer ${TOKEN}'"
                    response = sh (returnStdout: true, script: "${CURL_CALL}").trim()
                    println("RESPONSE: ${response}")
                    status_code = sh (returnStdout: true, script: "echo ${response} |grep HTTP | awk '{print $2}'").trim()
                    println("STATUS_CODE: ${status_code}")
                    if (status_code != 200 && status_code != 201) {
                        error("Returned status code = $status_code when calling $CURL_CALL")
                    }
                    //catchError(stageResult: 'FAILURE', buildResult: currentBuild.result) {
                    //    error 'example of throwing an error'
                    //}
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
    }
}