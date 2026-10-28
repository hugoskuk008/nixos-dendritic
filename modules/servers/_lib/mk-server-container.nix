# Reuse the OCI/Docker boilerplate for a single HTTP container.
# Ingress settings remain explicit in the service's own homelab.services entry.
{
  name,
  image,
  port,
  containerPort ? port,
  containerName ? name,
  portSuffix ? "",
  dockerAssertionMessage ? "server-${name} requires Docker enabled on this host.",
  missingAddressMessage ? "server-${name} requires homelab.address on this host.",
  oci ? { },
}:
{ config, ... }:
let
  address =
    if config.homelab.address == null
    then throw missingAddressMessage
    else config.homelab.address;
in
{
  assertions = [
    {
      assertion = config.virtualisation.docker.enable;
      message = dockerAssertionMessage;
    }
  ];

  virtualisation.oci-containers.backend = "docker";

  virtualisation.oci-containers.containers.${containerName} = oci // {
    inherit image;
    autoStart = oci.autoStart or true;
    # Published HTTP port comes first, preserving the order of extra OCI ports.
    ports = [ "${address}:${toString port}:${toString containerPort}${portSuffix}" ]
      ++ (oci.ports or [ ]);
  };
}
