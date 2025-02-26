require "../spec_helper"
require "colorize"
require "../../src/tasks/utils/utils.cr"
require "kubectl_client"
require "helm"
require "../../src/tasks/dockerd_setup.cr"
require "file_utils"
require "sam"

describe "Microservice" do
  before_all do
    `./cnf-testsuite setup`
    $?.success?.should be_true
  end

  it "'shared_database' should be skipped no MariaDB containers are found", tags: ["shared_database"]  do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-path=sample-cnfs/sample_coredns/cnf-testsuite.yml`
      response_s = `./cnf-testsuite shared_database`
      LOGGING.info response_s
      $?.success?.should be_true
      (/SKIPPED: \[shared_database\] No MariaDB containers were found/ =~ response_s).should_not be_nil
    ensure
      LOGGING.info `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample_coredns/cnf-testsuite.yml`
      $?.success?.should be_true
    end
  end

  it "'shared_database' should pass if no database is used by two microservices", tags: ["shared_database"]  do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-path=sample-cnfs/sample-statefulset-cnf/cnf-testsuite.yml`
      response_s = `./cnf-testsuite shared_database`
      LOGGING.info response_s
      $?.success?.should be_true
      (/PASSED: No shared database found/ =~ response_s).should_not be_nil
    ensure
      LOGGING.info `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample-statefulset-cnf/cnf-testsuite.yml`
      $?.success?.should be_true
    end
  end

  it "'shared_database' should pass if one service connects to a database but other non-service connections are made to the database", tags: ["shared_database"]  do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-path=sample-cnfs/sample-multi-db-connections-exempt/cnf-testsuite.yml`
      response_s = `./cnf-testsuite shared_database`
      LOGGING.info response_s
      $?.success?.should be_true
      (/PASSED: No shared database found/ =~ response_s).should_not be_nil
    ensure
      LOGGING.info `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample-multi-db-connections-exempt/cnf-testsuite.yml`
      $?.success?.should be_true
    end
  end

  it "'shared_database' should fail if two services on the cluster connect to the same database", tags: ["shared_database"]  do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-path=sample-cnfs/ndn-multi-db-connections-fail/cnf-testsuite.yml`
      response_s = `./cnf-testsuite shared_database`
      LOGGING.info response_s
      $?.success?.should be_true
      (/FAILED: Found a shared database/ =~ response_s).should_not be_nil
    ensure
      LOGGING.info `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/ndn-multi-db-connections-fail/cnf-testsuite.yml`
      $?.success?.should be_true
    end
  end

  it "'shared_database' should pass if two services on the cluster connect to the same database but they are not in the helm chart of the cnf", tags: ["shared_database"]  do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-path=sample-cnfs/sample_coredns`
      Helm.install("multi-db sample-cnfs/ndn-multi-db-connections-fail/wordpress/")
      KubectlClient::Get.resource_wait_for_install(kind="Deployment", resource_nome="multi-db-wordpress", wait_count=180, namespace="default")
      KubectlClient::Get.resource_wait_for_install(kind="Deployment", resource_nome="multi-db-wordpress2", wait_count=180, namespace="default")
      # todo kubctl appy of all resourcesin ndn-multi-db-connections-fail
      # todo cnf_setup of coredns
      # todo run shared_database (should pass)
      # todo kubectl delete on ndn resourcws
      # toto cnf_cleanup on coredns
      response_s = `./cnf-testsuite shared_database`
      LOGGING.info response_s
      $?.success?.should be_true
      (/PASSED: No shared database found/ =~ response_s).should_not be_nil
    ensure
      Helm.delete("multi-db")
      KubectlClient::Delete.command("pvc data-multi-db-mariadb-0")
      LOGGING.info `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/ndn-multi-db-connections-fail/cnf-testsuite.yml`
      $?.success?.should be_true
    end
  end

  it "'single_process_type' should pass if the containers in the cnf have only one process type", tags: ["process_check"]  do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-path=sample-cnfs/sample_coredns`
      response_s = `./cnf-testsuite single_process_type verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/PASSED: Only one process type used/ =~ response_s).should_not be_nil
    ensure
      LOGGING.info `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample_coredns`
      $?.success?.should be_true
    end
  end

  it "'single_process_type' should fail if the containers in the cnf have more than one process type", tags: ["process_check"]  do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-path=sample-cnfs/k8s-multiple-processes`
      response_s = `./cnf-testsuite single_process_type verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/FAILED: More than one process type used/ =~ response_s).should_not be_nil
    ensure
      LOGGING.info `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/k8s-multiple-processes`
      $?.success?.should be_true
    end
  end

  it "'single_process_type' should fail if the containers in the cnf have more than one process type and in a pod", tags: ["process_check"]  do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-path=sample-cnfs/sample-multiple-processes`
      response_s = `./cnf-testsuite single_process_type verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/FAILED: More than one process type used/ =~ response_s).should_not be_nil
    ensure
      LOGGING.info `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample-multiple-processes`
      $?.success?.should be_true
    end
  end

  it "'reasonable_startup_time' should pass if the cnf has a reasonable startup time(helm_directory)", tags: ["reasonable_startup_time"]  do
    begin
      Log.info {`./cnf-testsuite cnf_setup cnf-path=sample-cnfs/sample_coredns`}
      response_s = `./cnf-testsuite reasonable_startup_time verbose`
      Log.info { response_s }
      
      (/PASSED: CNF had a reasonable startup time/ =~ response_s).should_not be_nil
    ensure
      Log.info { `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample_coredns` }
      $?.success?.should be_true
    end
  end

  it "'reasonable_startup_time' should fail if the cnf doesn't has a reasonable startup time(helm_directory)", tags: ["reasonable_startup_time"] do
    LOGGING.info `./cnf-testsuite cnf_setup cnf-config=sample-cnfs/sample_envoy_slow_startup/cnf-testsuite.yml force=true`
    begin
      response_s = `./cnf-testsuite reasonable_startup_time verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/FAILED: CNF had a startup time of/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite cnf_cleanup cnf-config=sample-cnfs/sample_envoy_slow_startup/cnf-testsuite.yml force=true`
      $?.success?.should be_true
    end
  end

  it "'reasonable_image_size' should pass if image is smaller than 5gb, when using a protected image", tags: ["reasonable_image_size"]  do
    if ENV["PROTECTED_DOCKERHUB_USERNAME"]? && ENV["PROTECTED_DOCKERHUB_PASSWORD"]? && ENV["PROTECTED_DOCKERHUB_EMAIL"]? && ENV["PROTECTED_IMAGE_REPO"]
         cnf="./sample-cnfs/sample_coredns_protected"
       else
         cnf="./sample-cnfs/sample-coredns-cnf"
    end
    LOGGING.info `./cnf-testsuite cnf_setup cnf-path=#{cnf}`
    response_s = `./cnf-testsuite reasonable_image_size verbose`
    LOGGING.info response_s
    $?.success?.should be_true
    (/Image size is good/ =~ response_s).should_not be_nil
  ensure
    LOGGING.info `./cnf-testsuite cnf_cleanup cnf-path=#{cnf}`
  end

  it "'reasonable_image_size' should fail if image is larger than 5gb", tags: ["reasonable_image_size"] do
    `./cnf-testsuite cnf_setup cnf-path=./sample-cnfs/ndn-reasonable-image-size wait_count=0`
    response_s = `./cnf-testsuite reasonable_image_size verbose`
    LOGGING.info response_s
    $?.success?.should be_true
    (/Image size too large/ =~ response_s).should_not be_nil
  ensure
    `./cnf-testsuite cnf_cleanup cnf-path=./sample-cnfs/ndn-reasonable-image-size force=true`
  end
end

it "'service_discovery' should pass if any containers in the cnf are exposed as a service", tags: ["service_discovery"]  do
  begin
    Log.info { `./cnf-testsuite cnf_setup cnf-path=sample-cnfs/sample_coredns` }
    response_s = `./cnf-testsuite service_discovery verbose`
    Log.info { response_s }
    $?.success?.should be_true
    (/PASSED: Some containers exposed as a service/ =~ response_s).should_not be_nil
  ensure
    Log.info { `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample_coredns` }
    $?.success?.should be_true
  end
end

it "'service_discovery' should fail if no containers in the cnf are exposed as a service", tags: ["service_discovery"]  do
  begin
    Log.info { `./cnf-testsuite cnf_setup cnf-path=./sample-cnfs/sample-ndn-privileged` }
    response_s = `./cnf-testsuite service_discovery verbose`
    Log.info { response_s }
    $?.success?.should be_true
    (/FAILED: No containers exposed as a service/ =~ response_s).should_not be_nil
  ensure
    Log.info { `./cnf-testsuite cnf_cleanup cnf-path=./sample-cnfs/sample-ndn-privileged` }
    $?.success?.should be_true
  end
end
