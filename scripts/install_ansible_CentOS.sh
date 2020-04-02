#!/bin/bash
echo $@
function print_usage() {
  cat <<EOF
Installs Ansible with specific version
Command
  $0
Arguments
  --version|-v                        : Ansible version
  --service_principal_type|-sp        : The type of service principal: MSI or manual.
  --service_principal_id|-sid         : The service principal ID.
  --service_principal_secret|-ss      : The service principal secret.
  --subscription_id|-subid            : The subscription ID of the SP.
  --tenant_id|-tid                    : The tenant id of the SP.
  --help|-h                           : Help of the script.
EOF
}


while [[ $# > 0 ]]
do
  key="$1"
  shift
  case $key in
    --version|-v)
      ansible_version="$1"
      shift
      ;;
    --service_principal_type|-sp)
      service_principal_type="$1"
      shift
      ;;
    --service_principal_id|-spid)
      service_principal_id="$1"
      shift
      ;;
    --service_principal_secret|-ss)
      service_principal_secret="$1"
      shift
      ;;
    --subscription_id|-subid)
      subscription_id="$1"
      shift
      ;;
    --tenant_id|-tid)
      tenant_id="$1"
      shift
      ;;
    --help|-help|-h)
      print_usage
      exit 13
      ;;
    *)
      echo "ERROR: Unknown argument '$key' to script '$0'" 1>&2
      exit -1
  esac
done

function run_command {
    "${@}"

    if [ $? -ne 0 ]; then
        echo Failed to run "${@}"
        exit 1

    fi
}

function get_ansible_install_option {
    if [ "${ansible_version}" == "latest" ]; then
      version_option=""
    else
      version_option="==${ansible_version}"
    fi
}

sp_cred=$(cat <<EOF
[default]
subscription_id=${subscription_id}
client_id=${service_principal_id}
secret=${service_principal_secret}
tenant=${tenant_id}
EOF
)

function set_azure_credentials {
    # write Azure credentials file
    if [ "${service_principal_type}" == "manual" ]; then
        echo export AZURE_SUBSCRIPTION_ID=${subscription_id} >> /etc/profile
        echo export AZURE_CLIENT_ID=${service_principal_id} >> /etc/profile
        echo export AZURE_SECRET=${service_principal_secret} >> /etc/profile
        echo export AZURE_TENANT=${tenant_id} >> /etc/profile

        echo export AZURE_SUBSCRIPTION_ID=${subscription_id} >> /etc/bashrc
        echo export AZURE_CLIENT_ID=${service_principal_id} >> /etc/bashrc
        echo export AZURE_SECRET=${service_principal_secret} >> /etc/bashrc
        echo export AZURE_TENANT=${tenant_id} >> /etc/bashrc

    elif [ "${service_principal_type}" == "msi" ]; then
        echo export ANSIBLE_AZURE_AUTH_SOURCE=msi >> /etc/profile
        echo export ANSIBLE_AZURE_AUTH_SOURCE=msi >> /etc/bashrc
    fi
}

# install pip
sudo yum install -y epel-release
sudo yum install -y python-pip python

# update setuptools, setuptools 20.0.0+ is in Ansible prerequisites
sudo pip install --upgrade pip
sudo pip install --upgrade setuptools

# install Ansible with specific version
version_option="==${ansible_version}"
get_ansible_install_option
run_command sudo pip install ansible[azure]${version_option}

# set azure credentials
set_azure_credentials

# install common tools
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo sh -c 'echo -e "[azure-cli]\nname=Azure CLI\nbaseurl=https://packages.microsoft.com/yumrepos/azure-cli\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/azure-cli.repo'
sudo yum install -y azure-cli