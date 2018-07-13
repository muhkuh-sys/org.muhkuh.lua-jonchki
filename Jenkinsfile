import groovy.json.JsonSlurperClassic

node {
    def ARTIFACTS_PATH = 'targets'
    def strBuilds = env.JENKINS_SELECT_BUILDS
    def atBuilds = new JsonSlurperClassic().parseText(strBuilds)

    /* Clean before the build. */
    sh 'rm -rf .[^.] .??* *'

    checkout([$class: 'GitSCM',
        branches: [[name: '*/master']],
        doGenerateSubmoduleConfigurations: false,
        extensions: [
            [$class: 'SubmoduleOption',
                disableSubmodules: false,
                recursiveSubmodules: true,
                reference: '',
                trackingSubmodules: false
            ]
        ],
        submoduleCfg: [],
        userRemoteConfigs: [[url: 'https://github.com/muhkuh-sys/org.muhkuh.lua-jonchki.git']]
    ])

    docker.image("mbs_ubuntu_1804_x86_64").inside('-u root') {
        atBuilds.each { atEntry ->
            stage("${atEntry[0]} ${atEntry[1]} ${atEntry[2]}"){
                /* Build the project. */
                sh "bash build_artifacts.sh '${atEntry[0]}' '${atEntry[1]}' '${atEntry[2]}'"

                /* Archive all artifacts. */
                archiveArtifacts artifacts: "${ARTIFACTS_PATH}/*.tar.gz,${ARTIFACTS_PATH}/*.zip"
            }
        }
    }

    /* Clean up after the build. */
    sh 'rm -rf .[^.] .??* *'
}
