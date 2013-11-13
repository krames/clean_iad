require 'fog'

def service_params(opts={})
  {:rackspace_region => :iad}.merge(opts)
end

def clean_auto_scale
  log "Cleaning Auto Scale"
  
  auto_scale = Fog::Rackspace::AutoScale.new service_params(:rackspace_region => :ord)

  auto_scale.groups.each do |g|
      config = g.group_config
      config.max_entities = 0
      config.min_entities = 0
      config.save
      g.destroy
  end
rescue => e
  puts "Unable to delete auto scale - #{e}"
end

def clean_compute_v2
  log "Cleaning Compute V2"
  compute = Fog::Compute.new service_params(:provider => 'rackspace', :version => :v2)

  clean(images_to_delete(compute))
  
  compute.servers.each do |server|
    clean(compute.attachments(:server => server))
    destroy_model server
  end

  wait_for_server_deletion(compute)
  
  clean(compute.key_pairs)
  clean(networks_to_delete(compute))
rescue => e
  puts "Unable to delete compute v2 - #{e}"
end

def clean_compute_v1
  log "Cleaning Compute V1"
  compute = Fog::Compute.new service_params(:provider => 'rackspace', :version => :v1)
  
  clean compute.servers
rescue => e
  puts "Unable to delete compute v1 - #{e}"
end

def clean_block_storage
  log "Cleaning Cloud Block Storage"
  
  cbs = Fog::Rackspace::BlockStorage.new service_params

  clean(cbs.snapshots)
  clean(cbs.volumes)
rescue => e
  puts "Unable to delete block storage - #{e}"
end

def clean_storage
  log "Cleaning Storage"
  
  storage = Fog::Storage.new  service_params(:provider => 'rackspace')
  
  storage.directories.each do |dir|
    clean(dir.files)
    destroy_model dir
  end
rescue => e
  puts "Unable to delete storage - #{e}"
end

def clean_load_balancers
  log "Cleaning Load Balancers"

  lb_service = Fog::Rackspace::LoadBalancers.new service_params
  clean(lb_service.load_balancers)
rescue => e
  puts "Unable to delete load balancers - #{e}"
end

def clean_databases
  log "Cleaning databases"
  
  service = Fog::Rackspace::Databases.new service_params
  
  clean(service.instances)
rescue => e
  puts "Unable to delete databases - #{e}"
end

def clean_monitoring
  log "Clean monitoring"
  
  service = Fog::Rackspace::Monitoring.new service_params
  clean(service.entities)
rescue => e
  puts "Unable to delete monitoring - #{e}"
end

def clean_queues
  log "Clean Queues"
  
  service = Fog::Rackspace::Queues.new service_params
  clean service.queues
rescue => e
  puts "Unable to delete queues - #{e}"
end

def wait_for_server_deletion(compute)
  while compute.servers.any? {|s| s.reload } do
    sleep 2
  end
end

def images_to_delete(compute)
  compute.images.all(:type => "snapshot")
end

def networks_to_delete(compute)
  compute.networks.reject {|n| ['00000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111'].include?(n.id)}
end

def clean(obj)
  return unless obj
  if obj.class.ancestors.include?(Fog::Collection)
    obj.each {|model| destroy_model(model)}
  else
    destroy_model(obj)
  end
end

def destroy_model(model)
  model.destroy
rescue => e
  puts "#{e.class} occurred while deleting #{description(model)}"
end

def description(item)
  return "<nil>" unless item
  id = item.respond_to?(:id) ? "[#{item.id}]" : "<unknown>"
  "#{item.class.name} #{id}"
end

def log(str)
  puts str
end


clean_auto_scale
clean_block_storage
clean_compute_v1
clean_compute_v2
clean_storage
clean_load_balancers
clean_databases
# clean_monitoring
clean_queues
