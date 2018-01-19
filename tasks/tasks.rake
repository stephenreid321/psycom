
namespace :cleanup do
  task :organisations => :environment do
    Organisation.each { |organisation|
      organisation.destroy if organisation.affiliations.count == 0      
    }
  end 
end
task :cleanup => ['cleanup:organisations']

