def NODE_NAME = 'AWS_Instance_CentOS'
def MAIL_TO = '$DEFAULT_RECIPIENTS'
def BRANCH_NAME = 'Branch [' + env.BRANCH_NAME + ']'
def BUILD_INFO = 'Jenkins job: ' + env.BUILD_URL + '\n'

def MYSQL_DOCKER_PATH = '/home/jenkins/Docker_ExistedMulti/Server/Mysql'
def CURR = '$(pwd)'

def make_check_test(String target, String version) {
    def prefix = ""
    script {
        if (version != "") {
            version = "-" + version
        }
        if (target == "PGSpider") {
            prefix = "REGRESS_PREFIX=PGSpider"
        }
    }
    catchError() {
        sh """
            rm -rf make_check_existed_test.out || true
            docker exec -u postgres postgresserver_multi_for_mysql_existed_test /bin/bash -c '/tmp/mysql_existed_test.sh ${env.GIT_BRANCH} ${target}${version}'
            docker exec -w /home/postgres/${target}${version}/contrib/mysql_fdw postgresserver_multi_for_mysql_existed_test /bin/bash -c 'su -c "make clean && make ${prefix}" postgres'
            docker exec -w /home/postgres/${target}${version}/contrib/mysql_fdw postgresserver_multi_for_mysql_existed_test /bin/bash -c 'su -c "export LD_LIBRARY_PATH=":/usr/lib64/mysql/" && export LANGUAGE="en_US.UTF-8" && export LANG="en_US.UTF-8" && export LC_ALL="en_US.UTF-8" && make check ${prefix}| tee make_check.out" postgres'
            docker cp postgresserver_multi_for_mysql_existed_test:/home/postgres/${target}${version}/contrib/mysql_fdw/results/ results_${target}${version}
            docker cp postgresserver_multi_for_mysql_existed_test:/home/postgres/${target}${version}/contrib/mysql_fdw/make_check.out make_check_existed_test.out
        """
    }
    script {
        // Check if 'make_check_existed_test.out' contains 'All [0-9]* tests passed'
        status = sh(returnStatus: true, script: "grep -q 'All [0-9]* tests passed' 'make_check_existed_test.out'")
        if (status != 0) {
            unstable(message: "Set UNSTABLE result")
            sh "docker cp postgresserver_multi_for_mysql_existed_test:/home/postgres/${target}${version}/contrib/mysql_fdw/regression.diffs regression.diffs"
            sh 'cat regression.diffs || true'
            emailext subject: '[CI MYSQL_FDW] EXISTED_TEST: Result make check on ${target}${version} FAILED ' + BRANCH_NAME, body: BUILD_INFO +  '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
            updateGitlabCommitStatus name: 'make_check', state: 'failed'
        } else {
            updateGitlabCommitStatus name: 'make_check', state: 'success'
        }
    }
}

pipeline {
    agent {
        node {
            label NODE_NAME
        }
    }
    options {
        gitLabConnection('GitLabConnection')
    }
    triggers { 
        gitlab(
            triggerOnPush: true,
            triggerOnMergeRequest: false,
            triggerOnClosedMergeRequest: false,
            triggerOnAcceptedMergeRequest: true,
            triggerOnNoteRequest: false,
            setBuildDescription: true,
            branchFilterType: 'All',
            secretToken: "14edd1f2fc244d9f6dfc41f093db270a"
        )
    }
    stages {
        stage('Start_containers') {
            steps {
                script {
                    if (env.GIT_URL != null) {
                        BUILD_INFO = BUILD_INFO + "Git commit: " + env.GIT_URL.replace(".git", "/commit/") + env.GIT_COMMIT + "\n"
                    }
                    sh 'rm -rf results_* || true'
                }
                // Docker compose
                sh """
                    cd ${MYSQL_DOCKER_PATH}
                    docker-compose build
                    docker-compose up -d
                """
            }
            post {
                failure {
                    emailext subject: '[CI MYSQL_FDW] EXISTED_TEST: Start Containers FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false
                    updateGitlabCommitStatus name: 'Build', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Build', state: 'success'
                }
            }
        }
        stage('Init_data_Mysql_For_Testing_Postgres_12_4') {
            steps {
                catchError() {
                    sh """
                        docker exec mysqlserver_multi_for_existed_test /bin/bash -c '/tmp/start_existed_test.sh ${env.GIT_BRANCH}'
                    """
                }
            }
            post {
                failure {
                    emailext subject: '[CI MYSQL_FDW] EXISTED_TEST: Initialize data FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false
                    updateGitlabCommitStatus name: 'Init_Data', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Init_Data', state: 'success'
                }
            }
        }
        stage('make_check_FDW_Test_With_Postgres_12_4') {
            steps {
                catchError() {
                    make_check_test("postgresql","12.4")
                }
            }
        }
        stage('Init_data_Mysql_For_Testing_Postgres_13_0') {
            steps {
                catchError() {
                    sh """
                        docker exec mysqlserver_multi_for_existed_test /bin/bash -c '/tmp/start_existed_test.sh ${env.GIT_BRANCH}'
                    """
                }
            }
            post {
                failure {
                    emailext subject: '[CI MYSQL_FDW] EXISTED_TEST: Initialize data FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false
                    updateGitlabCommitStatus name: 'Init_Data', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Init_Data', state: 'success'
                }
            }
        }
        stage('make_check_FDW_Test_With_Postgre_13_0') {
            steps {
                catchError() {
                    make_check_test("postgresql","13.0")
                }
            }
        }
        stage('Build_PGSpider_For_FDW_Test') {
            steps {
                catchError() {
                    sh """
                        docker exec -u postgres postgresserver_multi_for_mysql_existed_test /bin/bash -c '/tmp/initialize_pgspider_existed_test.sh'
                        docker exec mysqlserver_multi_for_existed_test /bin/bash -c '/tmp/start_existed_test.sh ${env.GIT_BRANCH}'
                    """
                }
            }
            post {
                failure {
                    emailext subject: '[CI MYSQL_FDW] EXISTED_TEST: Build PGSpider FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false
                    updateGitlabCommitStatus name: 'Build_PGSPider', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Build_PGSPider', state: 'success'
                }
            }
        }
        stage('make_check_FDW_Test_With_PGSpider') {
            steps {
                catchError() {
                    make_check_test("PGSpider","")
                }
            }
        }
    }
    post {
        success  {
            script {
                prevResult = 'SUCCESS'
                if (currentBuild.previousBuild != null) {
                    prevResult = currentBuild.previousBuild.result.toString()
                }
                if (prevResult != 'SUCCESS') {
                    emailext subject: '[CI MYSQL_FDW] MYSQL_FDW_Test BACK TO NORMAL on ' + BRANCH_NAME, body: BUILD_INFO +  '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
                }
            }
        }
        always {
            sh """
                cd ${MYSQL_DOCKER_PATH}
                docker-compose down
            """
        }
    }
}
