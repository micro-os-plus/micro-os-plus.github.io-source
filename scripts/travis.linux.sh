#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Safety settings (see https://gist.github.com/ilg-ul/383869cbb01f61a51c4d).

if [[ ! -z ${DEBUG} ]]
then
  set ${DEBUG} # Activate the expand mode if DEBUG is anything but empty.
else
  DEBUG=""
fi

set -o errexit # Exit if command failed.
set -o pipefail # Exit if pipe failed.
set -o nounset # Exit if variable not set.

# Remove the initial space and instead use '\n'.
IFS=$'\n\t'

# -----------------------------------------------------------------------------

# https://docs.travis-ci.com/user/environment-variables/#Default-Environment-Variables

export build="${HOME}/build"
export slug="${TRAVIS_BUILD_DIR}-full"

# -----------------------------------------------------------------------------

export site="${HOME}/out/${GITHUB_DEST_REPO}"
export doxy="${build}${GITHUB_DOXY_REPO}"

# -----------------------------------------------------------------------------

function do_run()
{
  echo "\$ $@"
  "$@"
}

# -----------------------------------------------------------------------------

# Not available:
#   tree

# Errors in this function will break the build.
function do_before_install() {

  echo "Before install, bring extra tools..."

  # Install the html-proofer gem, to be used after jekyll build.
  cd "${HOME}"
  do_run gem install html-proofer
  do_run htmlproofer --version

  do_run gem update --system

  # http://packages.ubuntu.com/trusty-updates/
  # Install libclang, it is needed by doxygen.
  do_run sudo apt-get --yes --quiet --target-release trusty-backports install libclang1-3.8

  # https://launchpad.net/ubuntu/+source/doxygen
  # Install a newer doxygen from launchpad binaries.
  doxy_deb=doxygen_1.8.13-10_amd64.deb
  mkdir -p ${HOME}/downloads
  do_run curl -L --silent https://launchpad.net/ubuntu/+archive/primary/+files/${doxy_deb} -o ${HOME}/downloads/${doxy_deb}
  do_run sudo dpkg -i ${HOME}/downloads/${doxy_deb}
  do_run doxygen --version

  return 0
}

# Errors in this function will break the build.
function do_before_script() {

  echo "Before starting the test, clone the destination repo..."

  # For just in case.
  cd "${HOME}"

  do_run git config --global user.email "${GIT_COMMIT_USER_EMAIL}"
  do_run git config --global user.name "${GIT_COMMIT_USER_NAME}"

  # Clone again the repository, without the 50 commit limit, 
  # otherwise the last-modified-at will fail. (weird!)
  do_run git clone --branch=${TRAVIS_BRANCH} https://github.com/${TRAVIS_REPO_SLUG}.git "${slug}"
  cd "${slug}"
  do_run git checkout -qf ${TRAVIS_COMMIT}
  do_run git submodule update --init --recursive

  # Bring in the destination repository. 
  do_run git clone --branch=master https://github.com/${GITHUB_DEST_REPO}.git "${site}"

  # Bring in the µOS++ sources, for the Doxygen input.
  do_run git clone --branch=xpack --depth=1 https://github.com/${GITHUB_DOXY_REPO}.git "${doxy}"

  return 0
}

# Errors in this function will break the build.
function do_script() {

  echo "The main test code; perform the Jekyll build..."

  cd "${slug}"

  # Be sure the 'vendor/' folder is excluded, 
  # otherwise a strage error occurs.
  do_run bundle exec jekyll build --destination "${site}"

  do_run ls -lL "${site}"

  # Validate images and links (internal & external).
  if echo "${TRAVIS_COMMIT_MESSAGE}" | grep -v -e '\[skip proof\]'
  then
    do_run bundle exec htmlproofer --only-4xx \
      --url-ignore="/reference/cmsis-plus/,/pt/,/developer.apple.com/downloads/,/sourceforge.net/,/www.ukos.ch/,/https://www.element14.com/community/" \
      "${site}"
  fi

  # ---------------------------------------------------------------------------
  # The deployment code is present here not in after_success, 
  # to break the build if not successful.

  if [ "${TRAVIS_BRANCH}" != "master" ]
  then 
    echo "Not on master branch, skip deploy."
    return 0
  fi

  if [ "${TRAVIS_PULL_REQUEST}" != "false" ]
  then 
    echo "A pull request, skip deploy."
    return 0
  fi

  # Create the doxygen reference pages.
  cd "${doxy}/doxygen"
  export DOXYGEN_OUTPUT_DIRECTORY="${site}/reference"
  export DOXYGEN_STRIP_FROM_PATH="${doxy}"

  do_run doxygen config-travis.doxyfile
  do_run ls -l "${DOXYGEN_OUTPUT_DIRECTORY}"

  # Check if any changes.
  cd "${site}"
  is_dirty=`git status --porcelain`
  # Should detect new, modified, removed files.
  if [ -z "${is_dirty}" ]
  then
    echo "No changes to the output on this push; skip deploy."
    return 0
  fi

  # Commit the changes.
  cd "${site}"
  # do_run git diff

  do_run git add --all .
  do_run git commit -m "Travis CI Deploy of ${TRAVIS_COMMIT}" 

  echo "Deploy to GitHub pages..."

  # Must be quiet and have no output, to not reveal the key.
  git push --force --quiet "https://${GITHUB_TOKEN}@github.com/${GITHUB_DEST_REPO}" master > /dev/null 2>&1

  return 0
}

# Errors in the following function will not break the build.

function do_after_success() {

  echo "Nothing to do after success..."
  return 0
}

function do_after_failure() {

  echo "Nothing to do after failure..."
  return 0
}

function do_deploy() {

  echo "Nothing to do to deploy..."
  return 0
}

function do_after_script() {

  echo "Nothing to do after script..."
  return 0
}

# -----------------------------------------------------------------------------

if [ $# -ge 1 ]
then
  action=$1
  shift

  case ${action} in

  before_install)
    do_before_install "$@"
    ;;

  before_script)
    do_before_script "$@"
    ;;

  script)
    do_script "$@"
    ;;

  after_success)
    do_after_success "$@"
    ;;

  after_failure)
    do_after_failure "$@"
    ;;

  deploy)
    do_deploy "$@"
    ;;

  after_script)
    do_after_script "$@"
    ;;

  *)
    echo "Unsupported command" "${action}" "$@"
    exit 1
    ;;
    
  esac
  exit 0
else
  echo "Missing command"
  exit 1
fi

# -----------------------------------------------------------------------------
