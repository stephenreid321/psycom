
namespace :cleanup do
  task :organisations => :environment do
    Organisation.each { |organisation|
      organisation.destroy if organisation.affiliations.count == 0      
    }
  end
  task :sectors => :environment do
    Sector.each { |sector|
      sector.destroy if sector.sectorships.count == 0      
    }
  end  
end
task :cleanup => ['cleanup:organisations', 'cleanup:sectors']

