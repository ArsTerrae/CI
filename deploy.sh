#!/bin/bash
set -e 
DIR=$(dirname "$(readlink -f "$0")")

keep_trying() {
    for _ in {1..20}; do
        $* && break || sleep 3
    done
}

jarpath=$(readlink -f $(ls build/libs/*.jar))
sha256=$(sha256sum $jarpath | cut -d ' ' -f 1)
cutgitsha=$(echo $TRAVIS_COMMIT | cut -c -7)
newname=$(basename $jarpath .jar)-ci${TRAVIS_JOB_NUMBER}-$cutgitsha.jar
tag=ci${TRAVIS_JOB_NUMBER}

git config --global user.name "Harvest Moon CI"
git config --global user.email "HarvestMoonCI@users.noreply.github.com"

echo "Updating files"
pushd $DIR
git clone https://github.com/HarvestMoon/CIBuilds.git builds

pushd builds
echo '*' Build.job '['${TRAVIS_JOB_NUMBER}']('https://travis-ci.org/${TRAVIS_REPO_SLUG}/jobs/${TRAVIS_JOB_ID}')', from commit '['$cutgitsha']('https://github.com/HarvestMoon/HarvestMoon/commit/${TRAVIS_BUILD_NUMBER}')', built on $(date -uR): '['$newname']('https://github.com/HarvestMoon/CIBuilds/releases/download/$tag/$newname')' >> BUILDS.md
echo $sha256 '*'$newname >> sha256sums.txt

echo "Git commiting and tagging"
git add BUILDS.md sha256sums.txt
git commit -m "Build.job ${TRAVIS_JOB_NUMBER}"
git tag $tag

echo "Dumping SSH key"
openssl aes-256-cbc -K $encrypted_2e5045b2a276_key -iv $encrypted_2e5045b2a276_iv -in $DIR/.ssh_id.enc -out $DIR/.ssh_id -d
chmod 600 $DIR/.ssh_id
ssh-keygen -y -f $DIR/.ssh_id > $DIR/.ssh_id.pub
export HM_SSH_ID=$DIR/.ssh_id

echo "Git pushing"
GIT_SSH=$DIR/gitssh.sh git push --tags git@github.com:HarvestMoon/CIBuilds.git master:master

echo "Creating release"
keep_trying $DIR/github-release release -t $tag -n "CI ${TRAVIS_JOB_NUMBER}" -d ""
echo "Uploading artifact"
keep_trying $DIR/github-release upload -t $tag -n "$newname" -f "$jarpath"
