local t = ...

-- The artifact configuration and the finalizer are in the project root folder.
t:setVar(nil, 'jonchki_artifact_configuration', '${prj_root}/jonchki.xml')
t:setVar(nil, 'define_finalizer', '${prj_root}/finalizer.lua')

t:createArtifacts{
  'jonchki'
}

-- Build for ARM64 and x86_64 on Ubuntu 20.04 .
t:addBuildToAllArtifacts({
  platform_distribution_id = 'ubuntu',
  platform_distribution_version = '20.04',
  platform_cpu_architecture = 'arm64'
}, true)
t:addBuildToAllArtifacts({
  platform_distribution_id = 'ubuntu',
  platform_distribution_version = '20.04',
  platform_cpu_architecture = 'x86_64'
}, true)

-- Build for ARM64, RISCV64 and x86_64 on Ubuntu 22.04 .
t:addBuildToAllArtifacts({
  platform_distribution_id = 'ubuntu',
  platform_distribution_version = '22.04',
  platform_cpu_architecture = 'arm64'
}, true)
t:addBuildToAllArtifacts({
  platform_distribution_id = 'ubuntu',
  platform_distribution_version = '22.04',
  platform_cpu_architecture = 'riscv64'
}, true)
t:addBuildToAllArtifacts({
  platform_distribution_id = 'ubuntu',
  platform_distribution_version = '22.04',
  platform_cpu_architecture = 'x86_64'
}, true)

t:build()

return true
