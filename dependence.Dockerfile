#Copyright 2021 KubeCube Authors
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.

FROM busybox

# kubectl info
ARG arch=amd64
ARG kubectl_version=v1.22.2

# load dependces into image
COPY kubecube /etc/kubecube/manifests/kubecube
COPY utils.sh /etc/kubecube/manifests/utils.sh
COPY install_third_dependence.sh install_third_dependence.sh

# add helm bin
ADD helm/helm-*-${arch}.tar.gz .
RUN chmod +x ./linux-${arch}/helm && mv ./linux-${arch}/helm /bin/helm

# downloads kubectl
RUN wget https://storage.googleapis.com/kubernetes-release/release/${kubectl_version}/bin/linux/${arch}/kubectl --no-check-certificate
RUN chmod +x kubectl && mv kubectl /bin/kubectl

CMD ["/bin/sh","install_third_dependence.sh"]