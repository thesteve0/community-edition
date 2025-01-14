# Harbor Package

[Harbor](https://github.com/goharbor/harbor) is an open source trusted cloud native registry project that stores, signs, and scans content. Harbor extends the open source Docker Distribution by adding the functionalities usually required by users such as security, identity, and management.

## Components

This Harbor Package integrates [Harbor 2.2.3](https://goharbor.io/docs/2.2.0/install-config/#harbor-components).

## Configuration

The following configuration values can be set to customize the Harbor installation.

### Global

| Value | Required/Optional | Default | Description |
|:-------|:-------------------|:---------|:-------------|
| `namespace` | Optional | harbor | The namespace in which to deploy Harbor.|

### Harbor Package Configuration

Download the values.yaml file from [addons/packages/harbor/2.2.3/bundle/config/values.yaml](https://github.com/vmware-tanzu/community-edition/blob/main/addons/packages/harbor/2.2.3/bundle/config/values.yaml) to check all configuration values for Harbor Package and rename it to `harbor-values.yaml`.

or get the template configuration file by using script below:

   ```shell
   image_url=$(kubectl get packages harbor.community.tanzu.vmware.com.2.2.3 -o jsonpath='{.spec.template.spec.fetch[0].imgpkgBundle.image}')
   imgpkg pull -b $image_url -o /tmp/harbor-package-PACKAGE-VERSION
   cp /tmp/harbor-package-PACKAGE-VERSION/config/values.yaml harbor-values.yaml
   ```

> When you are using `imgpkg` to get the configuratuion file, specifying a namespace may be required
> depending on where your package repository was installed.

Please refer the following steps to configure Harbor.

## Installation

The Harbor package requires use of Contour for ingress, cert-manager for certificate generation and local-path-storage for persistent volume claims (only in case the provider is Docker)

**NOTE**: To install Harbor on Darwin with the provider as Docker, update the `/etc/docker/daemon.json` file with the following and restart Docker.

   ```shell
   {
      "insecure-registries": ["0.0.0.0/0"]
   }
   ```

1. Install local-path-storage (In case the provider is Docker)

   ```shell
   tanzu package install local-path-storage \
      --package-name local-path-storage.community.tanzu.vmware.com \
      --version ${LOCAL_PATH_STORAGE_PACKAGE_VERSION}
   ```

1. Install the cert-manager package:

   ```shell
   tanzu package install cert-manager \
      --package-name cert-manager.community.tanzu.vmware.com \
      --version ${CERT_MANAGER_PACKAGE_VERSION}
   ```

1. Install the Contour package using one of the following methods, depending on whether your workload cluster supports Service type LoadBalancer:

   If your workload cluster supports Service type LoadBalancer, execute this command:

   ```shell
   tanzu package install contour \
      --package-name contour.community.tanzu.vmware.com \
      --version ${CONTOUR_PACKAGE_VERSION}
   ```

   Or

   If your workload cluster doesn't support Service type LoadBalancer, use NodePort with hostPorts enabled instead by following these steps:

   1. Set `envoy.service.type: NodePort` and `envoy.hostPorts.enable: true` in `contour-values.yaml`
   1. Run `tanzu package install contour --package-name contour.community.tanzu.vmware.com --version ${CONTOUR_PACKAGE_VERSION} --values-file contour-values.yaml`

1. Configure Harbor Package

   Configure with the `harbor-values.yaml` file you obtained before.

   Optionally get the helper script for configuring Harbor:

   ```shell
   image_url=$(kubectl get package harbor.community.tanzu.vmware.com.2.2.3 -o jsonpath='{.spec.template.spec.fetch[0].imgpkgBundle.image}')
   imgpkg pull -b $image_url -o /tmp/harbor-package
   cp /tmp/harbor-package/config/scripts/generate-passwords.sh .
   ```

1. Specify the mandatory passwords and secrets in `harbor-values.yaml`

   or

   To generate them automatically, run

   ```shell
   bash generate-passwords.sh harbor-values.yaml
   ```

   This step is needed only once.

1. Specify other Harbor configuration (e.g. admin password, hostname, persistence setting, etc.) in `harbor-values.yaml`.

   **NOTE**: If the default storageClass in the Workload Cluster, or the specified storageClass in `harbor-values.yaml` supports the accessMode [ReadWriteMany](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#access-modes), make sure to update the accessMode from `ReadWriteOnce` to `ReadWriteMany` in `harbor-values.yaml`. [VMware vSphere 7 with vSAN 7 File Service enabled supports accessMode ReadWriteMany](https://blogs.vmware.com/virtualblocks/2020/03/12/cloud-native-storage-and-vsan-file-services-integration/) but vSphere 6.7u3 does not. If you are using vSphere 7 without vSAN File Service enabled, or you are using vSphere 6.7u3, use the default accessMode `ReadWriteOnce`.

1. Remove all the comments in the `harbor-values.yaml` file using tool [yq](https://mikefarah.gitbook.io/yq/) before installation. run

   ```shell
   yq -i eval '... comments=""' harbor-values.yaml
   ```

1. Install the Harbor package

   ```shell
   tanzu package install harbor \
      --package-name harbor.community.tanzu.vmware.com \
      --version ${HARBOR_PACKAGE_VERSION} -f harbor-values.yaml
   ```

   > You can get the `${HARBOR_PACKAGE_VERSION}` from running `tanzu package
   > available list harbor.community.tanzu.vmware.com`. Specifying a namespace may be required
   > depending on where your package repository was installed.

## Usage Example

### Connect to the Harbor User Interface

The Harbor UI is exposed via the Envoy service load balancer that is running in the Contour package. To allow users to connect to the Harbor UI, you must map the address of the Envoy service load balancer to the hostname of the Harbor service, for example `harbor.yourdomain.com`.

1. Obtain the address of the Envoy service load balancer.

   ```shell
   kubectl get svc envoy -n projectcontour -o jsonpath='{.status.loadBalancer.ingress[0]}'
   ```

   On **vSphere without NSX Advanced Load Balancer (ALB)**, the Envoy service is exposed via NodePort instead of LoadBalancer, so the above output will be empty, and you can use the IP address of any worker node in the workload cluster instead.

   On **Amazon Web Services**, it has a FQDN similar to `a82ebae93a6fe42cd66d9e145e4fb292-1299077984.us-west-2.elb.amazonaws.com`.
   On **vSphere with NSX ALB** and **Azure**, the Envoy service has a Load Balancer IP address similar to `20.54.226.44`.
   On **Docker**, the Envoy service is exposed via NodePort as it does not support LoadBalancer, so the above output will be empty.

1. Map the address of the Envoy service load balancer to the hostname of the Harbor service.

   * **vSphere**: If you deployed Harbor on a workload cluster that is running on vSphere, you must add an IP to hostname mapping in `/etc/hosts` or add corresponding `A` records in your DNS server. For example, if the IP address is `10.93.9.100`, add the following to `/etc/hosts`:

       ```shell
       10.93.9.100 harbor.yourdomain.com notary.harbor.yourdomain.com
       ```

     On Windows machines, the equivalent to `/etc/hosts/` is `C:\Windows\System32\Drivers\etc\hosts`.

   * **Amazon Web Services (AWS) or Azure**: If you deployed Harbor on a workload cluster that is running on AWS or Azure, you must create two DNS `CNAME` records (on AWS) or two DNS `A` records (on Azure) for the Harbor hostnames on a DNS server on the Internet.
      * One record for the Harbor hostname, for example, `harbor.yourdomain.com`, that you configured in `harbor-values.yaml`, that points to the FQDN or IP of the Envoy service load balancer.
      * Another record for the Notary service that is running in Harbor, for example, `notary.harbor.yourdomain.com`, that points to the FQDN or IP of the Envoy service load balancer.

   * **Docker**: If you have deployed Harbor on a workload cluster that is running on Docker, add the following to `/etc/hosts`

       ```shell
       127.0.0.1 harbor.yourdomain.com
       ```

   and run `kubectl port-forward -n projectcontour service/envoy yourport:443` to access harbor UI on `https://harbor.yourdomain.com:yourport`

Users can now connect to the Harbor UI by navigating to `https://harbor.yourdomain.com` in a Web browser and log in as user `admin` with the `harborAdminPassword` that you configured in `harbor-values.yaml`.

### Push and Pull Images to and from Harbor

1. If Harbor uses a self-signed certificate, download the Harbor CA certificate from `https://harbor.yourdomain.com/api/v2.0/systeminfo/getcert`, and install it on your local machine, so Docker can trust this CA certificate.

   * On Linux, save the certificate as `/etc/docker/certs.d/harbor.yourdomain.com/ca.crt`.
   * On macOS, follow [this procedure](https://blog.container-solutions.com/adding-self-signed-registry-certs-docker-mac).
   * On Windows, right-click the certificate file and select **Install Certificate**.

1. Log in to the Harbor registry with the user `admin`. When prompted, enter the `harborAdminPassword` that you set when you deployed the Harbor Extension on the workload cluster.

   ```shell
   docker login harbor.yourdomain.com -u admin
   ```

1. Tag an existing image that you have already pulled locally, for example `nginx:1.7.9`.

   ```shell
   docker tag nginx:1.7.9 harbor.yourdomain.com/library/nginx:1.7.9
   ```

1. Push the image to the Harbor registry.

   ```shell
   docker push harbor.yourdomain.com/library/nginx:1.7.9
   ```

1. Now you can pull the image from the Harbor registry on any machine where the Harbor CA certificate is installed.

   ```shell
   docker pull harbor.yourdomain.com/library/nginx:1.7.9
   ```
