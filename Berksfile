site :opscode

group :integration do
  cookbook 'rightscaleshim', github: 'rgeyer-rs-cookbooks/rightscaleshim'
  cookbook 'rightscale',
    github: 'rightscale/rightscale_cookbooks',
    branch: 'release13.05.01',
    rel: 'cookbooks/rightscale'
  cookbook 'sys',
    github: 'rightscale/rightscale_cookbooks',
    branch: 'release13.05.01',
    rel: 'cookbooks/sys'
  cookbook 'driveclient', github: 'racker/managed-cloud-driveclient'
  cookbook 'cloudmonitoring', github: 'racker/cookbook-cloudmonitoring'
end

metadata
