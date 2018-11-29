node {
    try {
        stage('checkout') {
            checkout([
                    $class: 'GitSCM',
                    branches: scm.branches,
                    doGenerateSubmoduleConfigurations: scm.doGenerateSubmoduleConfigurations,
                    extensions: [[$class: 'CloneOption', noTags: false, shallow: false, depth: 0, reference: '']],
                    userRemoteConfigs: scm.userRemoteConfigs,
            ])
        }

        stage('build') {
            sh 'make docker'
        }

        stage('upload') {
            sh 'make release'
        }
    } catch (Exception ex) {
        echo "ERROR: ${ex.toString()}"
        slackSend color: 'danger', message: "eks-ami ${env.BRANCH_NAME}: failure: <${env.BUILD_URL}/console|(output)>"
        currentBuild.result = 'FAILURE'
    }
}
