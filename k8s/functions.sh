# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This file contains bash functions used by various scripts in this direcotry.
# Don't run this file directly -- it gets loaded by other files.

function add_secret {
  # usage:
  #   add_secret SECRETS_ENV_FILE NAME VALUE
  # Adds an environment variable to the "k8s" section of SECRETS_ENV_FILE, and also sets in
  # in the current environment for the remainder of the current process.
  secrets_env_file=$1
  name=$2
  value=$3
  date="`date`"
  escaped_value=$(echo "$3" | sed -e 's|\/|\\/|g')
  sed "s/^# kbootstrap-end: do not alter or remove this line!\$/export $name=\"$escaped_value\"  # generated by kbootstrap.sh at $date\n&/" ${secrets_env_file} > /tmp/test.env
  if [ -s /tmp/test.env ] ; then
    mv /tmp/test.env ${secrets_env_file}
    export $name="$value"
  else
    echo "Failure while updating secrets file; aborting."
    exit -1
  fi
}

function add_secret_from_file {
  # usage:
  #   add_secret SECRETS_ENV_FILE NAME FILE
  # Adds an environment variable to the "k8s" section of SECRETS_ENV_FILE, using the contents of FILE
  # as the value for the variable.  Also sets the variable in the current environment for the remainder
  # of the current process.
  secrets_env_file=$1
  name=$2
  file=$3
  date="`date`"
  (
    echo "# generated by kbootstrap.sh at ${date}:" ;
    echo "read -r -d '' ${name} <<'EOF_EOF_EOF_EOF'" ;
    cat ${file} ;
    echo "EOF_EOF_EOF_EOF";
    echo "  export ${name}"
  ) > /tmp/newvar.env
  sed $'/^# kbootstrap-end: do not alter or remove this line!$/{e cat /tmp/newvar.env\n}' ${secrets_env_file} > /tmp/test.env
  if [ -s /tmp/test.env ] ; then
    mv /tmp/test.env ${secrets_env_file}
    . /tmp/newvar.env
    rm /tmp/newvar.env
  else
    echo "Failure while updating secrets file; aborting."
    exit -1
  fi
}

function generate_password {
  # Generates a random 18-character password.
  echo "p`(date ; dd if=/dev/urandom count=2 bs=1024) 2>/dev/null | md5sum | head -c 17`"
}

function generate_bucket_suffix {
  # Generates a random 16-character password that can be used as a bucket name suffix
  echo "b`(date ; dd if=/dev/urandom count=2 bs=1024) 2>/dev/null | md5sum | head -c 15`"
}

function generate_secret_key {
  # Generates a random 16-character string that can be used as a secret key value
  echo "k`(date ; dd if=/dev/urandom count=2 bs=1024) 2>/dev/null | md5sum | head -c 15`"
}

function wait_for_k8s_job {
  # usage:
  #   wait_for_k8s_job JOB
  # Waits for the k8s job named JOB to complete.  JOB should be a k8s "Job" resource
  # that is configured to run exactly once and then terminate.
  job=$1
  job_wait_recheck_seconds=5
  job_wait_max_seconds=300
  seconds_waited=0
  while [ $seconds_waited -le $job_wait_max_seconds ] ; do 
    echo "waiting for job $job to complete..."
    sleep $job_wait_recheck_seconds
    seconds_waited=$[$seconds_waited+$job_wait_recheck_seconds]
    completions=$(kubectl get job/$job -o=jsonpath='{.status.succeeded}')
    if [ "$completions" == "1" ] ; then
      return 0
    fi
  done
  echo "job $job did not complete after $job_wait_max_seconds seconds; giving up"
  exit -1
}


function wait_for_lb_ingress_ip {
  name=$1
  wait_recheck_seconds=5
  wait_max_seconds=300
  seconds_waited=0
  while [ $seconds_waited -le $wait_max_seconds ] ; do 
    echo "waiting for load balancer ip address to become available (this might take up to 5 minutes)..."
    sleep $wait_recheck_seconds
    seconds_waited=$[$seconds_waited+$wait_recheck_seconds]
    LB_IP=$(kubectl get svc ${name} -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [ "${LB_IP}" != "" ] ; then
      return 0
    fi
  done
  echo "load balancer ip address failed to become available after $wait_max_seconds seconds; giving up"
  exit -1
}

function wait_for_k8s_deployment_app_ready {
  # usage:
  #   wait_for_k8s_deployment_app_ready DEPLOYMENT
  # Waits for the named k8s deployment's pod to become ready.  The # replicas (pods) in the deployemtn must be 1.
  deployment=$1
  deployment_wait_recheck_seconds=2
  deployment_wait_max_seconds=300
  seconds_waited=0
  while [ $seconds_waited -le $deployment_wait_max_seconds ] ; do 
    echo "waiting for $deployment to be ready..."
    sleep $deployment_wait_recheck_seconds
    seconds_waited=$[$seconds_waited+$deployment_wait_recheck_seconds]
    phase="$(kubectl get pods --selector=app=${deployment} -o=jsonpath='{.items[0].status.phase}')"
    if [ "$phase" == "Running" ] ; then
      return 0
    fi
  done
  echo "deployment $deployment not ready after $deployment_wait_max_seconds seconds; giving up"
  exit -1
}


